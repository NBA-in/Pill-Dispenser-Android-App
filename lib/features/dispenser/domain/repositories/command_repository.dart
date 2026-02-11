
abstract class CommandRepository {
  Future<void> sendCommand(String dispenserId, String commandType, {Map<String, dynamic>? payload});
}
