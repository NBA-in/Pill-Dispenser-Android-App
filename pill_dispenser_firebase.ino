/* =====================================================================
   SMART 5-DAY PILL DISPENSER – FIREBASE VERSION (FULL LOGIC)
   
   Replaced Telegram with Firebase Firestore & FCM Push Notifications.
   Incorporates full ArduinoJson payload parsing & direct cloud functions.
   Required Libraries: 
    - "Firebase ESP Client" by Mobizt
    - "ArduinoJson"
====================================================================== */

#include "soc/soc.h"
#include "soc/rtc_cntl_reg.h"
#include "esp_task_wdt.h"

#include <WiFi.h>
#include <WiFiClientSecure.h>

// === FIREBASE LIBRARY ===
#include <Firebase_ESP_Client.h>
#include "addons/TokenHelper.h"

#include <Wire.h>
#include <SPI.h>
#include <EEPROM.h>
#include <RTClib.h>
#include <MFRC522.h>
#include <Adafruit_PWMServoDriver.h>
#include <Adafruit_INA219.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "DFRobotDFPlayerMini.h"
#include <ArduinoJson.h>
#include <time.h>

// ================= USER CONFIGURATION =================

const char* ssid_1     = "YOUR_WIFI_SSID";
const char* password_1 = "YOUR_WIFI_PASS";

const char* ssid_2     = "";
const char* password_2 = "";

const long  gmtOffset_sec      = 19800; // India Time (+5:30)
const int   daylightOffset_sec = 0;

// === FIREBASE CONFIG ===
#define API_KEY "YOUR_API_KEY"
#define FIREBASE_PROJECT_ID "YOUR_FIREBASE_PROJECT_ID"
#define USER_EMAIL "YOUR_USER_EMAIL" // Setup a user in Firebase Auth
#define USER_PASSWORD "YOUR_USER_PASSWORD"
#define DISPENSER_ID "YOUR_DISPENSER_ID"  // The Document ID in the dispensers collection

// ================= PINS =================
#define REED_PIN    14
#define REFILL_PIN  25
#define RFID_SS      5
#define RFID_RST    13
#define DF_RX       26
#define DF_TX       27

#define EEPROM_SIZE 64
#define SCREEN_W   128
#define SCREEN_H    64
#define TFT_TEXT    SSD1306_WHITE

// ================= SERVO TICKS (CALIBRATED) =================
#define LATCH_CH          15
#define LATCH_LOCK_TICK   220
#define LATCH_UNLOCK_TICK 320

#define MORNING_OPEN_TICK  150
#define MORNING_CLOSE_TICK 450

#define LUNCH_OPEN_TICK    450
#define LUNCH_CLOSE_TICK   200

#define NIGHT_OPEN_TICK    450
#define NIGHT_CLOSE_TICK   200

// ================= AUDIO TRACKS =================
const uint8_t TRACK_PILL_TAKEN     =  4;
const uint8_t TRACK_REFILL_EXIT    =  5;
const uint8_t TRACK_REFILL_AUTH    =  6;
const uint8_t TRACK_MORNING_ALERT  =  8;
const uint8_t TRACK_LUNCH_ALERT    =  9;
const uint8_t TRACK_NIGHT_ALERT    = 10;
const uint8_t TRACK_ACCESS_DENIED  = 11;
const uint8_t TRACK_LATCH_UNLOCKED = 12;
const uint8_t TRACK_LATCH_LOCKED   = 13;

// ================= BATTERY =================
const float EMA_ALPHA            = 0.15f;
const float BATTERY_WARN_VOLTAGE = 10.5f;
const float BAT_MIN_VOLTAGE      =  9.6f;
const float BAT_MAX_VOLTAGE      = 12.6f;

// ================= OBJECTS =================
Adafruit_SSD1306        display(128, 64, &Wire, -1);
RTC_DS3231              rtc;
MFRC522                 rfid(RFID_SS, RFID_RST);
Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver();
Adafruit_INA219         ina219(0x41);

HardwareSerial          mp3Serial(2);
DFRobotDFPlayerMini     mp3;

// Firebase App & Auth
FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
unsigned long lastFirebaseUpdate = 0;
unsigned long lastCommandCheck = 0;

// ================= VARIABLES =================
int morningHr = 8,  morningMin = 0;
int lunchHr   = 13, lunchMin   = 0;
int nightHr   = 20, nightMin   = 0;
int currentDay = 1;
int dosesLeft  = 15;

String authorizedCards[] = {
  "821F995C",
  "EEFB4E06",
  ""
};
int numberOfCards = sizeof(authorizedCards) / sizeof(authorizedCards[0]);

bool refillModeActive = false;
bool isLatchLocked    = true;
bool doseReadyToTake  = false;

String        doseName = "";
unsigned long doseTime = 0;
int           lastTriggeredMinute = -1;
int           lastSyncMinute = -1;

unsigned long lastScreenUpdate     = 0;
const unsigned long screenInterval = 250;
#define DISP_TIMEOUT 30000
unsigned long lastInteraction = 0;
bool          displayOn       = true;

enum ScreenState {
  HOME, READY, OPENED, TAKEN, MISSED,
  RFID_STATUS, REFILL, ERROR, LOW_BATTERY, CREDITS
};
ScreenState currentScreen = HOME;

volatile bool btnInterruptTriggered = false;
unsigned long btnPressStart         = 0;
const unsigned long LONG_PRESS_TIME = 3000;

int           pendingClicks = 0;
unsigned long clickTimer    = 0;

float batVoltage       = 12.0f;
float batVoltageSmooth = 12.0f;
unsigned long lastBatteryWarnAt = 0UL;

// ================= FIREBASE CLOUD FUNCTION EQUIVALENTS (IMPLEMENTED IN C++) =================

/**
 * Direct Firebase Cloud Messaging (FCM) Push Notifications 
 * Completely bypasses the need for a separate NodeJS Cloud Function server.
 * The App MUST subscribe to the topics: 
 *   - "dispenser_[ID]_patient"
 *   - "dispenser_[ID]_family"
 */
void sendFCMNotification(String title, String body, bool toPatient, bool toFamily) {
  if (!Firebase.ready()) return;

  Serial.println(">>> Sending direct FCM Push Notification...");
  
  if (toPatient) {
    FirebaseJson payload;
    String topic = String("dispenser_") + DISPENSER_ID + "_patient";
    payload.set("message/topic", topic);
    payload.set("message/notification/title", title);
    payload.set("message/notification/body", body);
    
    if (Firebase.FCM.send(&fbdo, &payload)) {
      Serial.println("  -> Patient Notified successfully.");
    } else {
      Serial.println("  -> FCM Failed: " + fbdo.errorReason());
    }
  }

  if (toFamily) {
    FirebaseJson payload;
    String topic = String("dispenser_") + DISPENSER_ID + "_family";
    payload.set("message/topic", topic);
    payload.set("message/notification/title", title);
    payload.set("message/notification/body", body);
    
    if (Firebase.FCM.send(&fbdo, &payload)) {
      Serial.println("  -> Family Notified successfully.");
    } else {
      Serial.println("  -> FCM Failed: " + fbdo.errorReason());
    }
  }
}

void updateFirebaseState() {
  if (!Firebase.ready()) return;

  FirebaseJson content;
  content.set("fields/battery_percent/integerValue", map((long)(batVoltage * 100), (long)(BAT_MIN_VOLTAGE * 100), (long)(BAT_MAX_VOLTAGE * 100), 0, 100));
  content.set("fields/voltage/doubleValue", batVoltage);
  content.set("fields/is_locked/booleanValue", isLatchLocked);
  
  content.set("fields/operational/mapValue/fields/doses_remaining/integerValue", dosesLeft);
  content.set("fields/operational/mapValue/fields/current_day/integerValue", currentDay);
  content.set("fields/operational/mapValue/fields/dose_ready/booleanValue", doseReadyToTake);
  content.set("fields/operational/mapValue/fields/refill_mode_active/booleanValue", refillModeActive);
  
  content.set("fields/wifi_connected/booleanValue", WiFi.status() == WL_CONNECTED);

  String documentPath = "dispensers/" + String(DISPENSER_ID) + "/current_state/data";
  
  if (Firebase.Firestore.patchDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), content.raw(), 
      "battery_percent,voltage,is_locked,operational,wifi_connected")) {
      Serial.println("State synced to Firestore.");
  } else {
      Serial.println("State Sync Error: " + fbdo.errorReason());
  }
}

void fetchScheduleFromFirebase() {
  if (!Firebase.ready()) return;

  String documentPath = "dispensers/" + String(DISPENSER_ID);
  
  // Use mask to only grab schedule field, saving huge bandwidth
  if (Firebase.Firestore.getDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), "schedule")) {
      DynamicJsonDocument doc(4096);
      DeserializationError err = deserializeJson(doc, fbdo.payload());
      
      if (!err) {
        // Deep navigation through the messy Firestore REST API JSON structure
        JsonArray daysArray = doc["fields"]["schedule"]["mapValue"]["fields"]["days"]["arrayValue"]["values"];
        
        if (daysArray.size() > 0) {
          // Taking the first day's configuration (assuming they're daily repeats right now)
          JsonObject day1 = daysArray[0]["mapValue"]["fields"];
          
          morningHr  = day1["morning"]["mapValue"]["fields"]["hour"]["integerValue"].as<int>();
          morningMin = day1["morning"]["mapValue"]["fields"]["minute"]["integerValue"].as<int>();
          
          lunchHr    = day1["lunch"]["mapValue"]["fields"]["hour"]["integerValue"].as<int>();
          lunchMin   = day1["lunch"]["mapValue"]["fields"]["minute"]["integerValue"].as<int>();
          
          nightHr    = day1["night"]["mapValue"]["fields"]["hour"]["integerValue"].as<int>();
          nightMin   = day1["night"]["mapValue"]["fields"]["minute"]["integerValue"].as<int>();
          
          EEPROM.write(0, morningHr); EEPROM.write(1, lunchHr); EEPROM.write(2, nightHr);
          EEPROM.write(5, morningMin); EEPROM.write(6, lunchMin); EEPROM.write(7, nightMin);
          EEPROM.commit();
          
          Serial.printf("Schedule Parsed Successfully -> Morning: %02d:%02d, Lunch: %02d:%02d, Night: %02d:%02d\n", 
            morningHr, morningMin, lunchHr, lunchMin, nightHr, nightMin);
        }
      } else {
        Serial.println("Schedule JSON Parse Failed!");
      }
  }
}

void processDeviceCommand(String commandAction) {
    Serial.println("Processing Command: " + commandAction);
    if(commandAction == "UNLOCK_LATCH") {
      unlockLatch();
      sendFCMNotification("Dispenser Unlocked", "Caregiver remotely unlocked your dispenser.", true, true);
    } else if (commandAction == "LOCK_LATCH") {
      lockLatch(); 
      sendFCMNotification("Dispenser Locked", "Caregiver remotely locked your dispenser.", true, true);
    } else if (commandAction == "DISPENSE_NOW_MORNING") {
      dispense(currentDay, 0);
    } else if (commandAction == "DISPENSE_NOW_LUNCH") {
      dispense(currentDay, 1);
    } else if (commandAction == "DISPENSE_NOW_NIGHT") {
      dispense(currentDay, 2);
    }
}

void logDoseHistory(String eventType, String medicineName) {
  if (!Firebase.ready()) return;

  FirebaseJson content;
  content.set("fields/status/stringValue", eventType);
  content.set("fields/consumption_info/mapValue/fields/taken_time/timestampValue", "REQUEST_TIME"); 
  content.set("fields/dose_name/stringValue", medicineName);
  
  String documentPath = "dose_history/" + String(DISPENSER_ID) + "/doses";
  
  if (Firebase.Firestore.createDocument(&fbdo, FIREBASE_PROJECT_ID, "", documentPath.c_str(), content.raw())) {
      Serial.println("Dose history documented in Firestore.");
  }
}

// ================= PROTOTYPES =================
void IRAM_ATTR isr_buttonPress();
void lockLatch();
void unlockLatch();
void closeAllServos();
void play(uint8_t t);
void saveSettings();
void loadSettings();
String readRFIDUID();
bool checkAuthorization(String uid);
void dispense(int day, int type);
void readINA219andComputePercent();
void syncTimeFromInternet();
void wakeDisplay();
void handleDisplay();
void drawHomeScreen();
void showDoseReadyScreen();
void showCompartmentOpenedScreen();
void showDoseTakenScreen();
void showMissedDoseScreen();
void showRefillModeScreen();
void showErrorScreen(const char* err, int code = 0);
void showAccessDenied();
void performShortPressToggle();
void performLongPressRefill();
void disableWatchdog();

// ================= IMPLEMENTATION =================

void play(uint8_t t) {
  Serial.print(">>> AUDIO TRACK: "); Serial.println(t);
  mp3.play(t);
  delay(50);
  yield();
}

void IRAM_ATTR isr_buttonPress() {
  btnInterruptTriggered = true;
}

void lockLatch() {
  pwm.setPWM(LATCH_CH, 0, LATCH_LOCK_TICK);
  isLatchLocked = true;
  Serial.println("Latch: LOCKED");
  updateFirebaseState();
}

void unlockLatch() {
  pwm.setPWM(LATCH_CH, 0, LATCH_UNLOCK_TICK);
  isLatchLocked = false;
  Serial.println("Latch: UNLOCKED");
  updateFirebaseState();
}

void closeAllServos() {
  for (int ch = 0; ch < 15; ch++) {
    int tick = 0;
    if      (ch % 3 == 0) tick = MORNING_CLOSE_TICK; 
    else if (ch % 3 == 1) tick = LUNCH_CLOSE_TICK;   
    else                   tick = NIGHT_CLOSE_TICK;   
    pwm.setPWM(ch, 0, tick);
    delay(150);
  }
  lockLatch();
}

String readRFIDUID() {
  if (!rfid.PICC_IsNewCardPresent()) return "";
  if (!rfid.PICC_ReadCardSerial())   return "";
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

bool checkAuthorization(String uid) {
  for (int i = 0; i < numberOfCards; i++) {
    if (uid == authorizedCards[i]) return true;
  }
  return false;
}

void saveSettings() {
  EEPROM.write(0, morningHr);  EEPROM.write(1, lunchHr);   EEPROM.write(2, nightHr);
  EEPROM.write(3, dosesLeft);  EEPROM.write(4, currentDay);
  EEPROM.write(5, morningMin); EEPROM.write(6, lunchMin);   EEPROM.write(7, nightMin);
  EEPROM.commit();
}

void loadSettings() {
  if (EEPROM.read(0) != 255) {
    morningHr  = EEPROM.read(0); lunchHr   = EEPROM.read(1); nightHr   = EEPROM.read(2);
    dosesLeft  = EEPROM.read(3); currentDay = EEPROM.read(4);
    morningMin = EEPROM.read(5); lunchMin   = EEPROM.read(6); nightMin  = EEPROM.read(7);
  }
}

void syncTimeFromInternet() {
  display.clearDisplay(); display.setTextSize(1);
  display.setCursor(0, 10); display.println("Syncing Time...");
  display.display();
  configTime(gmtOffset_sec, daylightOffset_sec, "pool.ntp.org", "time.nist.gov");
  struct tm timeinfo;
  int retry = 0;
  while (!getLocalTime(&timeinfo) && retry < 5) { delay(1000); retry++; }
  if (retry < 5) {
    rtc.adjust(DateTime(
      timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
      timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec));
    display.clearDisplay(); display.setCursor(0, 10); display.println("TIME SYNC SUCCESS!"); display.display();
  } else {
    display.clearDisplay(); display.println("TIME SYNC FAILED"); display.display();
  }
  delay(1000);
}

void dispense(int day, int type) {
  wakeDisplay();
  lockLatch();
  delay(500);

  int base = (day - 1) * 3;
  int ch = base + type;
  uint8_t track = 0;
  int openTick = 0, closeTick = 0;

  if (type == 0) {
    doseName = "Morning"; track = TRACK_MORNING_ALERT;
    openTick = MORNING_OPEN_TICK; closeTick = MORNING_CLOSE_TICK;
  } else if (type == 1) {
    doseName = "Lunch"; track = TRACK_LUNCH_ALERT;
    openTick = LUNCH_OPEN_TICK; closeTick = LUNCH_CLOSE_TICK;
  } else {
    doseName = "Night"; track = TRACK_NIGHT_ALERT;
    openTick = NIGHT_OPEN_TICK; closeTick = NIGHT_CLOSE_TICK;
  }

  pwm.setPWM(ch, 0, openTick);
  delay(4000);
  pwm.setPWM(ch, 0, closeTick);
  delay(500);

  dosesLeft--;
  saveSettings();
  doseReadyToTake = true;
  doseTime = millis();

  play(track);
  showDoseReadyScreen();

  // Send Push Notifications Alerting them directly
  String msg = "Your " + doseName + " medication is dispensed and waiting!";
  sendFCMNotification("Medication Ready 💊", msg, true, false);

  
  if (dosesLeft == 3) {
      sendFCMNotification("Refill Reminder ⚠️", "Only 1 day of medication left (3 doses). Please refill the dispenser soon.", false, true); // Only to family
  } else if (dosesLeft == 0) {
      sendFCMNotification("Cycle Finished 🔴", "The medication cycle is complete. Please refill the dispenser.", false, true); // Only to family
  }
  
  logDoseHistory("DISPENSED", doseName);
  updateFirebaseState();
}

void readINA219andComputePercent() {
  float v = ina219.getBusVoltage_V();
  batVoltageSmooth = (EMA_ALPHA * v) + ((1.0 - EMA_ALPHA) * batVoltageSmooth);
  batVoltage = batVoltageSmooth;
  if (batVoltage < BATTERY_WARN_VOLTAGE && (millis() - lastBatteryWarnAt > 300000)) {
    sendFCMNotification("Voltage Low", "Voltage Low", true, true);
    lastBatteryWarnAt = millis();
  }
}

// ================= SETUP =================
void setup() {
  WRITE_PERI_REG(RTC_CNTL_BROWN_OUT_REG, 0);
  Serial.begin(115200);

  EEPROM.begin(EEPROM_SIZE);
  loadSettings();

  pinMode(REED_PIN,   INPUT_PULLUP);
  pinMode(REFILL_PIN, INPUT);

  Wire.begin(); Wire.setClock(100000); SPI.begin();
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) { for(;;); }
  disableWatchdog();
  
  display.clearDisplay(); display.setTextColor(SSD1306_WHITE); display.setTextSize(2);
  display.setCursor(45, 20); display.println("CFP"); display.display();
  delay(2000);
  wakeDisplay();

  rfid.PCD_Init();
  pwm.begin(); pwm.setOscillatorFrequency(27000000); pwm.setPWMFreq(50);
  delay(100); closeAllServos();

  if (!ina219.begin()) Serial.println("INA219 fails");
  if (!rtc.begin()) Serial.println("RTC fails");

  mp3Serial.begin(9600, SERIAL_8N1, DF_RX, DF_TX);
  if (mp3.begin(mp3Serial, false, false)) {
    delay(1000); mp3.volume(30); mp3.EQ(DFPLAYER_EQ_ROCK);
  }

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid_1, password_1);
  display.clearDisplay(); display.setTextSize(1); display.setCursor(0, 10); 
  display.println("Connecting:"); display.println(ssid_1); display.display();
  
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); display.print("."); display.display(); }
  Serial.println("\nWiFi Connected");

  syncTimeFromInternet();

  // Initialize Firebase using Token Auth
  config.api_key = API_KEY;
  auth.user.email = USER_EMAIL;
  auth.user.password = USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;
  
  // Setting timeout and buffer sizes
  fbdo.setResponseSize(4096);
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
  
  // Initial syncs
  if(Firebase.ready()) {
    updateFirebaseState();
    fetchScheduleFromFirebase();
    sendFCMNotification("Dispenser Online ✅", "Your smart dispenser has started successfully and connected to Firebase.", false, true); // only family
  }

  delay(500); play(TRACK_PILL_TAKEN);
  attachInterrupt(digitalPinToInterrupt(REFILL_PIN), isr_buttonPress, RISING);
  drawHomeScreen();
}

// ================= LOOP =================
void loop() {
  // 1. Maintain Firebase State Sync
  if (millis() - lastFirebaseUpdate > 300000) {  // Every 5 Minutes
    lastFirebaseUpdate = millis();
    updateFirebaseState();
  }

  // 2. Poll Schedule Sync occasionally
  DateTime now = rtc.now();
  if (now.minute() != lastSyncMinute && now.minute() % 15 == 0) { // Every 15 mins
    lastSyncMinute = now.minute();
    fetchScheduleFromFirebase();
  }

  // 3. User Interface Logic (Button/RFID)
  if (pendingClicks > 0 && (millis() - clickTimer > 400)) {
    if (pendingClicks <= 2) {
      if (!refillModeActive) performShortPressToggle();
      else showRefillModeScreen();
    }
    pendingClicks = 0;
  }

  if (btnInterruptTriggered || digitalRead(REFILL_PIN) == HIGH) {
    btnInterruptTriggered = false;
    bool wasDisplayOff = !displayOn;
    wakeDisplay();

    if (wasDisplayOff) {
      while (digitalRead(REFILL_PIN) == HIGH) { delay(10); }
      lastInteraction = millis();
      if(!doseReadyToTake) drawHomeScreen();
    } else {
      lastInteraction = millis();
      if (digitalRead(REFILL_PIN) == HIGH) {
        btnPressStart = millis();
        bool longPressDetected = false;
        while (digitalRead(REFILL_PIN) == HIGH) {
          unsigned long holdTime = millis() - btnPressStart;
          if (holdTime >= LONG_PRESS_TIME) { longPressDetected = true; break; }
          delay(20);
        }
        if (longPressDetected) performLongPressRefill();
        else { pendingClicks++; clickTimer = millis(); }
      } else {
        pendingClicks++; clickTimer = millis(); 
      }
      while (digitalRead(REFILL_PIN) == HIGH) { delay(10); }
    }
  }

  readINA219andComputePercent();

  // 4. Dose Checking Logic
  if (now.minute() != lastTriggeredMinute) {
    bool minuteTriggered = false;

    if (doseReadyToTake) {
      int currentMins = now.hour() * 60 + now.minute();
      int mMin = morningHr * 60 + morningMin - 45; if (mMin < 0) mMin += 1440;
      int lMin = lunchHr * 60 + lunchMin - 45; if (lMin < 0) lMin += 1440;
      int nMin = nightHr * 60 + nightMin - 45; if (nMin < 0) nMin += 1440;

      if (currentMins == mMin || currentMins == lMin || currentMins == nMin) {
         doseReadyToTake = false;
         logDoseHistory("MISSED", doseName);
         sendFCMNotification("Missed Dose ⚠️", "The patient missed their " + doseName + " medication.", true, true);
         updateFirebaseState();
         drawHomeScreen();
         minuteTriggered = true;
      }
    }

    if (!doseReadyToTake) {
      if (now.hour() == morningHr && now.minute() == morningMin) {
        minuteTriggered = true; dispense(currentDay, 0);
      } else if (now.hour() == lunchHr && now.minute() == lunchMin) {
        minuteTriggered = true; dispense(currentDay, 1);
      } else if (now.hour() == nightHr && now.minute() == nightMin) {
        minuteTriggered = true; dispense(currentDay, 2);
        currentDay++; if (currentDay > 5) currentDay = 1; saveSettings();
      }
    }
    
    if (minuteTriggered) {
      lastTriggeredMinute = now.minute();
    }
  }

  // 5. Patient Taking Medication (Reed Switch)
  if (doseReadyToTake) {
    static unsigned long lidStart = 0;
    static bool lidActive = false;
    if (digitalRead(REED_PIN) == HIGH && !lidActive) {
      lidActive = true; lidStart = millis();
    }
    if (lidActive && (millis() - lidStart >= 50)) {
      if (digitalRead(REED_PIN) == HIGH) {
        wakeDisplay();
        play(TRACK_PILL_TAKEN);
        showDoseTakenScreen();
        doseReadyToTake = false;
        
        Serial.println(">>> PILLS TAKEN BY PATIENT!");

        // Send direct native FCM Push!
        sendFCMNotification(
          "Medication Taken ✅", 
          "The patient has successfully retrieved their " + doseName + " medication.", 
          true, true
        );

        // Submitting log history
        logDoseHistory("TAKEN", doseName);
        updateFirebaseState();

        delay(1500); drawHomeScreen();
      }
      lidActive = false;
    }
  }

  // 6. Display Maintenance
  if (millis() - lastScreenUpdate > screenInterval) {
    lastScreenUpdate = millis();
    if (refillModeActive) showRefillModeScreen();
    else if (currentScreen == HOME || currentScreen == READY || currentScreen == MISSED) {
      if (doseReadyToTake) showDoseReadyScreen();
    }
  }
  handleDisplay();
}

// ================= ACTIONS =================
// Full logic implementations for RFID, Locks & Display
void showAccessDenied() {
  display.clearDisplay(); display.setTextSize(2);
  display.setCursor(10, 20); display.print("DENIED");
  display.display();
  play(TRACK_ACCESS_DENIED);
  delay(2000);
}

void performShortPressToggle() {
  wakeDisplay();
  display.clearDisplay(); display.setTextSize(2); display.setCursor(10, 25); display.print("SCAN RFID"); display.display();
  unsigned long scanStart = millis();
  bool cardFound = false;
  while (millis() - scanStart < 3000) {
    String uid = readRFIDUID();
    if (uid != "") {
      if (checkAuthorization(uid)) { cardFound = true; break; }
      else { showAccessDenied(); return; }
    } delay(20);
  }

  if (cardFound) {
    display.clearDisplay();
    if (isLatchLocked) {
      unlockLatch(); play(TRACK_LATCH_UNLOCKED);
      display.setCursor(15, 10); display.setTextSize(2); display.print("UNLOCKED");
      // Logging interaction 
      logDoseHistory("UNLOCKED", "Manual Authorization");
      sendFCMNotification("Dispenser Unlocked 🔓", "The system was unlocked directly with an RFID tag.", false, true);
    } else {
      lockLatch(); play(TRACK_LATCH_LOCKED);
      display.setCursor(30, 10); display.setTextSize(2); display.print("LOCKED");
    }
    display.display();
    rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
    delay(1500); drawHomeScreen();
  } else { showAccessDenied(); drawHomeScreen(); }
}

void performLongPressRefill() {
  wakeDisplay();
  display.clearDisplay(); display.setTextSize(1); display.setCursor(0, 0);
  display.print(refillModeActive ? "EXIT REFILL?" : "ENTER REFILL?");
  display.setCursor(0, 20); display.print("Scan Tag (6s)..."); display.display();

  unsigned long scanStart = millis();
  bool cardFound = false;
  while (millis() - scanStart < 6000) {
    String uid = readRFIDUID();
    if (uid != "") {
      if (checkAuthorization(uid)) { cardFound = true; break; }
      else { showAccessDenied(); if (refillModeActive) showRefillModeScreen(); else drawHomeScreen(); return; }
    } delay(20);
  }

  display.clearDisplay(); display.setTextSize(2); display.setCursor(0, 10); display.print("ACCESS");
  display.setCursor(0, 35);

  if (cardFound) {
    display.print("GRANTED"); display.display();
    play(TRACK_REFILL_AUTH); delay(500);

    if (refillModeActive) {
      refillModeActive = false;
      lockLatch(); closeAllServos();
      play(TRACK_REFILL_EXIT);
      sendFCMNotification("Refill Mode Exited 🔒", "The device servos are reset and latches locked.", false, true);
      display.clearDisplay(); display.setCursor(20, 20); display.print("EXITED"); display.display();
      delay(1500); drawHomeScreen();
    } else {
      refillModeActive = true; unlockLatch();
      dosesLeft = 15; currentDay = 1; saveSettings();
      sendFCMNotification("Refill Mode Entered 🔓", "A caregiver has activated refill mode. All doors are accessible.", false, true);
      display.clearDisplay(); display.setCursor(20, 20); display.print("REFILL"); display.display();
      delay(1500); showRefillModeScreen();
    }
    rfid.PICC_HaltA(); rfid.PCD_StopCrypto1();
    updateFirebaseState();
  } else {
    showAccessDenied();
    if (refillModeActive) showRefillModeScreen(); else drawHomeScreen();
  }
}

// ================= DISPLAY HELPERS =================
void wakeDisplay() {
  displayOn = true; lastInteraction = millis();
  display.ssd1306_command(SSD1306_DISPLAYON);
}
void handleDisplay() {
  if (displayOn && (millis() - lastInteraction > DISP_TIMEOUT) && !refillModeActive && !doseReadyToTake) {
    displayOn = false; display.ssd1306_command(SSD1306_DISPLAYOFF);
  }
}
void drawHomeScreen() {
  currentScreen = HOME;
  display.clearDisplay(); display.setTextSize(1); display.setTextColor(SSD1306_WHITE);
  display.setCursor(85, 0); display.print(batVoltage, 1); display.print("V");
  display.drawLine(0, 10, SCREEN_W, 10, SSD1306_WHITE);
  DateTime now = rtc.now();
  char buf[6]; snprintf(buf, sizeof(buf), "%02d:%02d", now.hour(), now.minute());
  display.setTextSize(3); display.setCursor(20, 18); display.print((String)buf);
  display.setTextSize(1);
  display.setCursor(0, 45); display.print("Day: "); display.print(currentDay);
  display.setCursor(0, 56); display.print("Left: "); display.print(dosesLeft);
  display.display();
}

void showDoseReadyScreen() {
  currentScreen = READY;
  display.clearDisplay(); display.setTextSize(2); display.setTextColor(SSD1306_WHITE);
  display.setCursor(10,  5); display.print("MEDICINE");
  display.setCursor(30, 25); display.print("READY");
  display.setTextSize(1); display.setCursor(0, 50); display.print("Open Lid to Take");
  display.display();
}

void showDoseTakenScreen() {
  currentScreen = TAKEN;
  display.clearDisplay(); display.setTextSize(2);
  display.setCursor(20, 20); display.print("THANK");
  display.setCursor(30, 40); display.print("YOU!");
  display.display();
}

void showRefillModeScreen() {
  currentScreen = REFILL;
  display.clearDisplay(); display.setTextSize(1); display.setTextColor(SSD1306_WHITE);
  display.setCursor(30, 0); display.print("Refill Mode");
  display.drawLine(0, 10, SCREEN_W, 10, SSD1306_WHITE);
  display.setCursor(0, 20); display.print("Latch: UNLOCKED");
  display.setCursor(0, 35); display.print("Fill all slots.");
  display.setCursor(0, 56); display.print("Hold 3s to Finish");
  display.display();
}

void disableWatchdog() {
  esp_task_wdt_deinit();
}
