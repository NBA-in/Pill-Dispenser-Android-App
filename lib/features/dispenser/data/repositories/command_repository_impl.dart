import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/command_repository.dart';

class CommandRepositoryImpl implements CommandRepository {
  final FirebaseFirestore _firestore;

  CommandRepositoryImpl({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> sendCommand(String dispenserId, String commandType, {Map<String, dynamic>? payload}) async {
    await _firestore
        .collection('dispensers')
        .doc(dispenserId)
        .collection('device_commands')
        .add({
      'command': commandType,
      'payload': payload ?? {},
      'status': 'PENDING',
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
