import 'package:cloud_firestore/cloud_firestore.dart';

class RFIDTagModel {
  final String id;
  final String name;
  final DateTime createdAt;

  const RFIDTagModel({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory RFIDTagModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RFIDTagModel(
      id: doc.id,
      name: data['name'] ?? 'Unknown Tag',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }
}
