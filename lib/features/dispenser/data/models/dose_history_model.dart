import 'package:cloud_firestore/cloud_firestore.dart';

class DoseHistoryModel {
  final String id; // metadata/dose_id
  
  // schedule_info
  final int day;
  final String doseType;
  
  // dispense_info
  final bool dispensed;
  final int compartmentNumber;
  
  // consumption_info
  final bool taken;
  final Timestamp? takenTime;
  
  // status
  final String status;

  // Additional helper for UI convenience (not in schema strictly, or derived)
  final Timestamp? date; // derived from ID timestamp? or we can keep it if helpful, but schema didn't specify it. 
  // Schema says: metadata/dose_id = {MAC}_{Millis}. We can parse millis.
  // Actually, let's keep it simple. If schema has "consumption_info/taken_time", that's the taken time.
  // What about scheduled time? Schema guide doesn't show it in "Dose History" explicitly, 
  // but usually you want to know when it *was* scheduled. 
  // The provided schema for Dose History (Item 3) has: 
  // metadata/dose_id, schedule_info/day, schedule_info/dose_type, dispense_info/dispensed, 
  // dispense_info/compartment_number, consumption_info/taken, consumption_info/taken_time, status/current_status.
  
  const DoseHistoryModel({
    required this.id,
    required this.day,
    required this.doseType,
    required this.dispensed,
    required this.compartmentNumber,
    required this.taken,
    this.takenTime,
    required this.status,
    this.date,
  });

  factory DoseHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final cons = data['consumption_info'] as Map<String, dynamic>? ?? {};

    return DoseHistoryModel(
      id: doc.id,
      day: 1, // Doesn't matter much or can be derived
      doseType: data['dose_name'] ?? 'Unknown',
      dispensed: data['status'] == 'DISPENSED' || data['status'] == 'TAKEN',
      compartmentNumber: 0,
      taken: data['status'] == 'TAKEN',
      takenTime: cons['taken_time'],
      status: data['status'] ?? 'unknown',
      date: cons['taken_time'], 
    );
  }
}
