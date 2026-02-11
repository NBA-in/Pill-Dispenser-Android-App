import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/auxiliary_repositories.dart';

// --- EVENTS ---
class EventsRepositoryImpl implements EventsRepository {
  final FirebaseFirestore _firestore;

  EventsRepositoryImpl({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> logEvent(String dispenserId, String type, String details, {String? component}) async {
    await _firestore.collection('events_log').add({
      'dispenser_id': dispenserId,
      'type': type,
      'details': details,
      'component': component,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getEvents(String dispenserId, {int limit = 50}) async {
    final query = await _firestore.collection('events_log')
        .where('dispenser_id', isEqualTo: dispenserId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    
    return query.docs.map((d) => d.data()..['id'] = d.id).toList();
  }
}

// --- NOTIFICATIONS ---
class NotificationRepositoryImpl implements NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepositoryImpl({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<Map<String, dynamic>>> streamNotifications(String userId, {int limit = 20}) {
    return _firestore.collection('notifications')
        .where('user_id', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()..['id'] = d.id).toList());
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({'read': true});
  }
}

// --- ALERTS ---
class AlertRepositoryImpl implements AlertRepository {
  final FirebaseFirestore _firestore;

  AlertRepositoryImpl({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<Map<String, dynamic>>> streamActiveAlerts(String dispenserId) {
    return _firestore.collection('alerts')
        .where('dispenser_id', isEqualTo: dispenserId)
        .where('active', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((d) => d.data()..['id'] = d.id).toList());
  }

  @override
  Future<void> resolveAlert(String alertId, String resolvedByUserId) async {
    await _firestore.collection('alerts').doc(alertId).update({
      'active': false,
      'resolved_at': FieldValue.serverTimestamp(),
      'resolved_by': resolvedByUserId,
    });
  }
}
