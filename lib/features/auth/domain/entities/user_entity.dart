import 'package:equatable/equatable.dart';

enum UserRole { patient, caregiver, admin }

class UserEntity extends Equatable {
  final String uid;
  final String email;
  final String? name;
  final String? phone;
  final UserRole role;
  // Caregiver specific
  final String? relationship;
  final List<String> patientIds; // For caregivers managing multiple patients
  final List<String> linkedDispensers; // Device IDs linked to this user

  const UserEntity({
    required this.uid,
    required this.email,
    this.name,
    this.phone,
    required this.role,
    this.relationship,
    this.patientIds = const [],
    this.linkedDispensers = const [],
  });

  @override
  List<Object?> get props => [uid, email, name, phone, role, relationship, patientIds, linkedDispensers];
}
