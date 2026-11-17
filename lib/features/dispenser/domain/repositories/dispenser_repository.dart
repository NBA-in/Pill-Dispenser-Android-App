// import '../entities/dispenser_entity.dart'; 

import '../../data/models/dispenser_model.dart';
import '../../data/models/dose_history_model.dart';
import '../../data/models/rfid_tag_model.dart';

abstract class DispenserRepository {
  Stream<DispenserModel?> streamDispenser(String dispenserId);
  
  Future<DispenserModel?> getDispenser(String dispenserId);
  
  Future<void> updateSchedule(String dispenserId, ScheduleModel schedule);
  
  Future<void> updateConfiguration(String dispenserId, ConfigurationModel config);
  
  Future<void> updateCurrentState(String dispenserId, Map<String, dynamic> partialState); // For specific updates
  
  // Device Pairing
  Future<bool> pairDevice({required String deviceId, required String userId, required String role, String? deviceName, String? relationship});

  // History
  Future<List<DoseHistoryModel>> getDoseHistory(String dispenserId);
  // User Management
  Future<Map<String, List<Map<String, dynamic>>>> getLinkedUsers(String dispenserId);
  Future<void> removeUser(String dispenserId, String userId, String role);

  // RFID Management
  Stream<List<RFIDTagModel>> streamRFIDTags(String dispenserId);
  Future<void> deleteRFIDTag(String dispenserId, String tagId);

  // Refill Mode
  Future<void> resetDispenser(String dispenserId, {ScheduleModel? schedule});
}
