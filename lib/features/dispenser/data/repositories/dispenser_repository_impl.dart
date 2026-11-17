import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/dispenser_repository.dart';
import '../models/dispenser_model.dart';
import '../models/dose_history_model.dart';
import '../models/rfid_tag_model.dart';
import '../../../auth/domain/entities/user_entity.dart'; // For UserRole
import '../../../../core/utils/notification_service.dart';
import 'package:rxdart/rxdart.dart';

class DispenserRepositoryImpl implements DispenserRepository {
  final FirebaseFirestore _firestore;

  DispenserRepositoryImpl({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;


  @override
  Stream<DispenserModel?> streamDispenser(String dispenserId) {
    final dispatchDoc = _firestore.collection('dispensers').doc(dispenserId);
    final stateDoc = dispatchDoc.collection('current_state').doc('data'); // Assuming 'data' or 'current'

    return Rx.combineLatest2<DocumentSnapshot, DocumentSnapshot, DispenserModel?>(
      dispatchDoc.snapshots(),
      stateDoc.snapshots(),
      (dispenserSnapshot, stateSnapshot) {
        if (!dispenserSnapshot.exists) return null;

        // Base data from parent doc
        final data = dispenserSnapshot.data() as Map<String, dynamic>? ?? {};
        
        // State data from subcollection and transform it
        final rawStateData = stateSnapshot.exists 
            ? stateSnapshot.data() as Map<String, dynamic>? ?? {}
            : <String, dynamic>{};
        
        final stateData = _transformStateData(rawStateData);

        // Merge state into the main map for the Model Factory
        data['current_state'] = stateData;

        return DispenserModel.fromFirestore(dispenserSnapshot, overrideData: data);
      },
    );
  }

  Map<String, dynamic> _transformStateData(Map<String, dynamic> flat) {
    print("DEBUG Repo: _transformStateData flat input: $flat");
    final operational = flat['operational'] is Map ? Map<String, dynamic>.from(flat['operational']) : null;
    final transformed = {
      'battery': {
        'percent': flat['battery_percent'] ?? 0,
        'voltage': flat['voltage'] ?? 0.0,
      },
      'operational': {
        'doses_remaining': operational?['doses_remaining'] ?? flat['doses_remaining'], // Inner: Daily
        'current_day': operational?['current_day'] ?? flat['current_day'],
        'dose_ready': flat['dose_ready'] ?? false,
        'refill_mode_active': flat['refill_mode_active'] ?? false,
      },
      'doses_remaining': flat['doses_remaining'] ?? 0, // Outer: Total
      'connectivity': {
        'wifi_connected': flat['wifi_connected'] ?? false,
        'last_time_sync': flat['last_updated'],
      },
      'hardware': {
        'latch_locked': flat['is_locked'] ?? true,
      },
      'timestamps': {
        'last_state_update': flat['last_updated'],
      }
    };
    print("DEBUG Repo: _transformStateData transformed result: $transformed");
    return transformed;
  }

  @override
  Future<DispenserModel?> getDispenser(String dispenserId) async {
    final dispatchDocRef = _firestore.collection('dispensers').doc(dispenserId);
    final stateDocRef = dispatchDocRef.collection('current_state').doc('data');

    final results = await Future.wait([dispatchDocRef.get(), stateDocRef.get()]);
    final dispenserSnapshot = results[0];
    final stateSnapshot = results[1];

    if (!dispenserSnapshot.exists) return null;

    final data = dispenserSnapshot.data() ?? {};
    final rawStateData = stateSnapshot.exists 
        ? stateSnapshot.data() ?? {}
        : <String, dynamic>{};
    
    final stateData = _transformStateData(rawStateData);
    data['current_state'] = stateData;
    
    // We need a way to pass this merged data to fromFirestore, 
    // or just use fromMap if we expose it or use a hacked Factory.
    // I will add an optional 'overrideData' to fromFirestore in the Model.
    return DispenserModel.fromFirestore(dispenserSnapshot, overrideData: data);
  }

  @override
  Future<void> updateCurrentState(String dispenserId, Map<String, dynamic> partialState) async {
    // Updates go to the subcollection now
    await _firestore
        .collection('dispensers')
        .doc(dispenserId)
        .collection('current_state')
        .doc('data')
        .set(partialState, SetOptions(merge: true));
        
    // Also update 'last_updated' in timestamps
    await _firestore
        .collection('dispensers')
        .doc(dispenserId)
        .collection('current_state')
        .doc('data')
        .update({'timestamps.last_state_update': FieldValue.serverTimestamp()});
  }

  @override
  Future<bool> pairDevice({required String deviceId, required String userId, required String role, String? deviceName, String? relationship}) async {
    final docRef = _firestore.collection('dispensers').doc(deviceId);
    final doc = await docRef.get();
    
    if (!doc.exists) {
      if (role == 'patient' || role == UserRole.patient.name) {
        throw Exception('DEVICE_NOT_FOUND');
      }

       // Auto-create for development/testing convenience (Caregivers or others)
       await docRef.set({
         'device_info': {
           'device_name': deviceName ?? 'Smart Dispenser',
           'serial_number': deviceId,
           'model': 'V1',
         },
         'created_at': FieldValue.serverTimestamp(),
         'schedule': {
            'days': List.generate(5, (index) => {
               'morning': {'hour': 8, 'minute': 0, 'enabled': false},
               'lunch': {'hour': 13, 'minute': 0, 'enabled': false},
               'night': {'hour': 20, 'minute': 0, 'enabled': false},
            }),
         },
         'configuration': {
            'timezone': 'UTC',
            'volume': 50
         }
       });
       
       // Initialize valid state
       // We DO NOT write to current_state/data here anymore. 
       // The ESP32 Hardware owns this subcollection uniquely.
       // The app will simply wait idly until the ESP32 pushes its first 5-minute heartbeat.
    } else {
      // Update Device Name if provided and doc existed
      if (deviceName != null && deviceName.isNotEmpty) {
         await docRef.update({'device_info.device_name': deviceName});
      }
    }

    // Update Dispenser Users Subcollection
    if (role == 'patient' || role == UserRole.patient.name) {
       await docRef.collection('users').doc('patient').set({
         'user_id': userId, 
         'notifications_enabled': true,
       }, SetOptions(merge: true));
    } else {
       await docRef.collection('users').doc('caregivers').collection('list').doc(userId).set({
         'user_id': userId,
         'role': 'caregiver',
         'notifications_enabled': true,
         'relation': relationship ?? 'Caregiver',
       });
    }

    // ALSO update the Root User document to link to this dispenser
    final Map<String, dynamic> updateData = {
      'linked_dispensers': FieldValue.arrayUnion([deviceId]),
      'role': role, // Ensure role is set
    };
    if (relationship != null && relationship.isNotEmpty) {
      updateData['relationship'] = relationship;
    }

    await _firestore.collection('users').doc(userId).set(updateData, SetOptions(merge: true));

    // Subscribe to FCM Topic for this device
    String topicRole = (role == 'patient' || role == UserRole.patient.name) ? 'patient' : 'family';
    await NotificationService.subscribeToDeviceTopic(deviceId, topicRole);

    return true;
  }

  @override
  Future<void> updateSchedule(String dispenserId, ScheduleModel schedule) async {
    // 1. Update the 'schedule' field
    await _firestore.collection('dispensers').doc(dispenserId).update({
      'schedule': schedule.toMap(),
      'schedule.schedule_metadata.sync_status': 'pending', // Reset status so we know it's pending
    });
    
    // 2. Increment 'command_counter' so device knows to sync
    await _incrementCommandCounter(dispenserId);
  }

  @override
  Future<void> updateConfiguration(String dispenserId, ConfigurationModel config) async {
    await _firestore.collection('dispensers').doc(dispenserId).update({
      'configuration': config.toMap(),
    });
    // Config updates also surely need a sync signal?
    await _incrementCommandCounter(dispenserId);
  }

  @override
  Future<List<DoseHistoryModel>> getDoseHistory(String dispenserId) async {
    try {
      final querySnapshot = await _firestore
          .collection('dose_history')
          .doc(dispenserId) 
          .collection('doses')
          .orderBy('consumption_info.taken_time', descending: true) 
          .limit(50) 
          .get();

      return querySnapshot.docs
          .map((doc) => DoseHistoryModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }
  @override
  Future<Map<String, List<Map<String, dynamic>>>> getLinkedUsers(String dispenserId) async {
    final usersRef = _firestore.collection('dispensers').doc(dispenserId).collection('users');
    
    // 1. Get Patient
    final patientDoc = await usersRef.doc('patient').get();
    Map<String, dynamic>? patientData;
    if (patientDoc.exists) {
      patientData = patientDoc.data();
      if (patientData != null) patientData['role'] = 'patient';
    }

    // 2. Get Caregivers
    final caregiversSnapshot = await usersRef.doc('caregivers').collection('list').get();
    final caregiversList = caregiversSnapshot.docs.map((doc) {
       final data = doc.data();
       data['role'] = 'caregiver';
       return data;
    }).toList();

    return {
      'patient': patientData != null ? [patientData] : [],
      'caregivers': caregiversList,
    };
  }

  @override
  Future<void> removeUser(String dispenserId, String userId, String role) async {
    // 1. Remove from Dispenser
    if (role == 'patient') {
      await _firestore
          .collection('dispensers')
          .doc(dispenserId)
          .collection('users')
          .doc('patient')
          .delete();
    } else {
      await _firestore
          .collection('dispensers')
          .doc(dispenserId)
          .collection('users')
          .doc('caregivers')
          .collection('list')
          .doc(userId)
          .delete();
    }

    // 2. Remove from User Profile (unlink)
    await _firestore.collection('users').doc(userId).update({
      'linked_dispensers': FieldValue.arrayRemove([dispenserId]),
    });

    // Unsubscribe from FCM topic
    String topicRole = role == 'patient' ? 'patient' : 'family';
    await NotificationService.unsubscribeFromDeviceTopic(dispenserId, topicRole);
  }

  @override
  Stream<List<RFIDTagModel>> streamRFIDTags(String dispenserId) {
    return _firestore
        .collection('dispensers')
        .doc(dispenserId)
        .collection('rfid_tags')
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => RFIDTagModel.fromFirestore(doc)).toList();
    });
  }

  @override
  Future<void> deleteRFIDTag(String dispenserId, String tagId) async {
    await _firestore
        .collection('dispensers')
        .doc(dispenserId)
        .collection('rfid_tags')
        .doc(tagId)
        .delete();
  }

  @override
  Future<void> resetDispenser(String dispenserId, {ScheduleModel? schedule}) async {
    // 1. Calculate Total Scheduled Doses AND Day 1 Doses
    int totalDoses = 0;
    int dailyDosesInitial = 0;
    
    if (schedule != null) {
      // Use the provided schedule (most accurate/recent)
      print("DEBUG: Using provided schedule for reset.");
       // Calculate Total
       for (final day in schedule.days) {
         if (day.morning.enabled) totalDoses++;
         if (day.lunch.enabled) totalDoses++;
         if (day.night.enabled) totalDoses++;
       }
       // Calculate Daily (Day 1)
       if (schedule.days.isNotEmpty) {
         final day1 = schedule.days[0];
         if (day1.morning.enabled) dailyDosesInitial++;
         if (day1.lunch.enabled) dailyDosesInitial++;
         if (day1.night.enabled) dailyDosesInitial++;
       }

       print("DEBUG: Total: $totalDoses, Day 1: $dailyDosesInitial");
    } else {
      // Fallback: Fetch from DB
      print("DEBUG: Fetching schedule from DB for reset fallback.");
      final docSnapshot = await _firestore.collection('dispensers').doc(dispenserId).get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null && data.containsKey('schedule')) {
           final scheduleMap = data['schedule'] as Map<String, dynamic>;
           final fetchedSchedule = ScheduleModel.fromMap(scheduleMap);
           
           for (final day in fetchedSchedule.days) {
             if (day.morning.enabled) totalDoses++;
             if (day.lunch.enabled) totalDoses++;
             if (day.night.enabled) totalDoses++;
           }
           if (fetchedSchedule.days.isNotEmpty) {
             final day1 = fetchedSchedule.days[0];
             if (day1.morning.enabled) dailyDosesInitial++;
             if (day1.lunch.enabled) dailyDosesInitial++;
             if (day1.night.enabled) dailyDosesInitial++;
           }
        }
      }
    }

    // 2. Reset Internal State
    await _firestore
        .collection('dispensers')
        .doc(dispenserId)
        .collection('current_state')
        .doc('data')
        .set({
      'doses_remaining': totalDoses, // Outer: Total Cycle
      'operational': {
         'doses_remaining': dailyDosesInitial, // Inner: Daily
         'current_day': 1,
         'refill_mode_active': false,
         'dose_ready': false 
      }
    }, SetOptions(merge: true));

    // 2. Increment command counter to sync this state change or trigger device logic
    await _incrementCommandCounter(dispenserId);
  }

  Future<void> _incrementCommandCounter(String dispenserId) async {
    final counterRef = _firestore
        .collection('device_commands')
        .doc(dispenserId)
        .collection('pending_commands')
        .doc('command_counter');

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      if (!snapshot.exists) {
        transaction.set(counterRef, {'count': 1});
      } else {
        final current = snapshot.data()?['count'] ?? 0;
        transaction.update(counterRef, {'count': current + 1});
      }
    });
  }
}
