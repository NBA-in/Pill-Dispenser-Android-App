class AppConstants {
  static const String appName = "Smart Pill Dispenser";
  
  // Dispenser Limits
  static const int maxDosesPerTray = 15;
  
  // Default Settings
  static const bool defaultNotificationsEnabled = true;
  static const int defaultTimezoneOffset = 0;
  
  // UI Strings (Fallback for l10n)
  static const String onlineText = "Online";
  static const String offlineText = "Offline";
  static const String takeMedicineAction = "I have taken my medicine";
  static const String unlockAction = "Unlock";
  
  // Error Messages
  static const String deviceNotFound = "Device not found";
  static const String pairingSuccess = "Device Paired Successfully!";
  
  // Mock Data (if needed for previews)
  static const String mockDeviceId = "PILL-001";
}
