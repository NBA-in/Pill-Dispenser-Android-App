import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.email,
    super.name,
    super.phone,
    required super.role,
    super.relationship,
    super.patientIds,
    super.linkedDispensers,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'],
      phone: data['phone'],
      role: UserRole.values.firstWhere(
        (e) => e.name == (data['role'] ?? 'patient'),
        orElse: () => UserRole.patient,
      ),
      relationship: data['relationship'],
      patientIds: List<String>.from(data['patientIds'] ?? []),
      linkedDispensers: List<String>.from(data['linked_dispensers'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'phone': phone,
      'role': role.name,
      'relationship': relationship,
      'patientIds': patientIds,
      // We usually don't write linked_dispensers here as it's modified by Pair Device Logic
      // But if we do complete update, we should include it.
      'linked_dispensers': linkedDispensers,
    };
  }
}
