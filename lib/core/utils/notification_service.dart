import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Requests permission from the user to display notifications.
  /// This is required for iOS and newer versions of Android.
  static Future<void> requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('User granted notification permission: ${settings.authorizationStatus}');
    }
  }

  /// Fetches the FCM token for this device and saves it to the user's Firestore document.
  static Future<void> saveTokenToDatabase(String userId) async {
    try {
      // 1. Get the token
      String? token = await _messaging.getToken();
      
      if (token != null) {
        if (kDebugMode) {
          print('FCM Token: $token');
        }
        
        // 2. Save it to the user's document
        // We use an array so a user can be logged into multiple devices
        await _firestore.collection('users').doc(userId).set({
          'fcm_tokens': FieldValue.arrayUnion([token]),
        }, SetOptions(merge: true));
      }

      // 3. Listen for token refreshes
      _messaging.onTokenRefresh.listen((newToken) async {
        await _firestore.collection('users').doc(userId).set({
          'fcm_tokens': FieldValue.arrayUnion([newToken]),
        }, SetOptions(merge: true));
      });
      
    } catch (e) {
      if (kDebugMode) {
        print('Error saving FCM token: $e');
      }
    }
  }

  /// Removes the current device's token from the user's Firestore document 
  /// (called during logout).
  static Future<void> removeTokenFromDatabase(String userId) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).set({
          'fcm_tokens': FieldValue.arrayRemove([token]),
        }, SetOptions(merge: true));
      }
      // Also delete the token locally so a new one is generated next time
      await _messaging.deleteToken();
    } catch (e) {
      if (kDebugMode) {
        print('Error removing FCM token: $e');
      }
    }
  }
  /// Subscribes to a device topic (e.g. dispenser_123_patient)
  static Future<void> subscribeToDeviceTopic(String deviceId, String role) async {
    try {
      String topic = 'dispenser_${deviceId}_$role';
      await _messaging.subscribeToTopic(topic);
      if (kDebugMode) {
        print('Subscribed to topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to topic: $e');
      }
    }
  }

  /// Unsubscribes from a device topic
  static Future<void> unsubscribeFromDeviceTopic(String deviceId, String role) async {
    try {
      String topic = 'dispenser_${deviceId}_$role';
      await _messaging.unsubscribeFromTopic(topic);
      if (kDebugMode) {
        print('Unsubscribed from topic: $topic');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from topic: $e');
      }
    }
  }
}
