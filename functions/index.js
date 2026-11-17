const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
admin.initializeApp();

// Configuration for notifications
const NOTIFICATION_TYPES = {
  "MISSED_DOSE": { title: "Missed Medication!", body: "A scheduled medication was missed." },
  "LOW_BATTERY": { title: "Low Battery Warning", body: "A pill dispenser battery is running low." },
  "REFILL_NEEDED": { title: "Refill Needed", body: "Pill dispenser is almost empty." },
  "DEVICE_DISCONNECTED": { title: "Device Offline", body: "Dispenser lost connection." },
  "DOSE_TAKEN": { title: "Medication Taken ✅", body: "Patient has successfully taken their medication." },
};

/**
 * Trigger: When a new document is added to the 'alerts' collection.
 * This handles system-wide warnings (Battery, Refill, Disconnected, Missed Dose)
 * Audience: Caregivers (and Patients if applicable).
 */
exports.onAlertCreated = onDocumentCreated("alerts/{alertId}", async (event) => {
    const snap = event.data;
    if (!snap) return null;
    
    const alertData = snap.data();
    const dispenserId = alertData.dispenser_id;
    const type = alertData.type; // e.g., 'MISSED_DOSE'
    
    if (!dispenserId || !type) return null;

    // 1. Get Dispenser Users
    const usersSnapshot = await admin.firestore()
      .collection("dispensers")
      .doc(dispenserId)
      .collection("users")
      .get();
      
    const tokensToNotify = [];

    // 2. Collect FCM tokens for users who have notifications enabled
    for (const doc of usersSnapshot.docs) {
      if (doc.id === "patient") {
         const patientData = doc.data();
         if (patientData.notifications_enabled && patientData.user_id) {
           const tokens = await getUserTokens(patientData.user_id);
           tokensToNotify.push(...tokens);
         }
      } else if (doc.id === "caregivers") {
         const caregiversListSnap = await doc.ref.collection("list").get();
         for (const cgDoc of caregiversListSnap.docs) {
            const cgData = cgDoc.data();
            if (cgData.notifications_enabled && cgData.user_id) {
               const tokens = await getUserTokens(cgData.user_id);
               tokensToNotify.push(...tokens);
            }
         }
      }
    }

    if (tokensToNotify.length === 0) return null;

    // 3. Construct Payload
    const notificationInfo = NOTIFICATION_TYPES[type] || { title: "New Alert", body: "Check your dispenser app." };
    const payload = {
      notification: {
        title: notificationInfo.title,
        body: notificationInfo.body,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        alertId: event.params.alertId,
        dispenserId: dispenserId,
        type: type,
      }
    };

    // 4. Send Push Notification
    return admin.messaging().sendToDevice(tokensToNotify, payload);
});

/**
 * Trigger: Scheduled Cron Job (Runs every minute)
 * Checks for upcoming doses and sends a "Time for Medication" alert to PATIENTS ONLY.
 * Note: Requires Blaze plan to deploy 'pubsub.schedule' functions.
 */
exports.checkScheduledDoses = onSchedule("every 1 minutes", async (event) => {
  const now = new Date();
  const currentHour = now.getUTCHours(); // Adjust for timezone in real implementation
  const currentMinute = now.getUTCMinutes();

  const dispensersSnap = await admin.firestore().collection("dispensers").get();

  const notifications = [];

  for (const doc of dispensersSnap.docs) {
     const data = doc.data();
     if (!data.schedule || !data.schedule.days) continue;

     // Simplification: Check Day 1 schedule for current time
     const todaySchedule = data.schedule.days[0]; 
     if (!todaySchedule) continue;

     // Check Morning, Lunch, Night
     const times = [todaySchedule.morning, todaySchedule.lunch, todaySchedule.night];
     
     let shouldNotify = false;
     for (const time of times) {
       // If it's the exact minute
       if (time.enabled && time.hour === currentHour && time.minute === currentMinute) {
         shouldNotify = true;
         break;
       }
     }

     if (shouldNotify) {
        // Find Patient token
        const patientDoc = await admin.firestore()
          .collection("dispensers")
          .doc(doc.id)
          .collection("users")
          .doc("patient")
          .get();
        
        if (patientDoc.exists && patientDoc.data().notifications_enabled) {
          const tokens = await getUserTokens(patientDoc.data().user_id);
          if (tokens.length > 0) {
            notifications.push(admin.messaging().sendToDevice(tokens, {
              notification: {
                title: "Time for Medication! 💊",
                body: "Please take your scheduled dose from the dispenser.",
              },
              data: { click_action: "FLUTTER_NOTIFICATION_CLICK", type: "TAKE_MEDS" }
            }));
          }
        }
     }
  }

  return Promise.all(notifications);
});


// Helper function to get a user's FCM tokens
async function getUserTokens(userId) {
  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  if (userDoc.exists) {
    const data = userDoc.data();
    if (data.fcm_tokens && Array.isArray(data.fcm_tokens)) {
      return data.fcm_tokens;
    }
  }
  return [];
}
