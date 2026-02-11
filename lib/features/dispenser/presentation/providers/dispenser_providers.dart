import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/dispenser_repository.dart';
import '../../data/repositories/dispenser_repository_impl.dart';
import '../../data/models/dispenser_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

// ... (imports)
import '../../domain/repositories/command_repository.dart';
import '../../data/repositories/command_repository_impl.dart';
import '../../domain/repositories/auxiliary_repositories.dart';
import '../../data/repositories/auxiliary_repositories_impl.dart';

final dispenserRepositoryProvider = Provider<DispenserRepository>((ref) {
  return DispenserRepositoryImpl(); // Default Firebase instances
});

final commandRepositoryProvider = Provider<CommandRepository>((ref) {
  return CommandRepositoryImpl();
});

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepositoryImpl();
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl();
});

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepositoryImpl();
});

final dispenserProvider = StreamProvider.family<DispenserModel?, String>((ref, dispenserId) {
  return ref.watch(dispenserRepositoryProvider).streamDispenser(dispenserId);
});

// Setup Controller
final deviceSetupControllerProvider = StateNotifierProvider<DeviceSetupController, AsyncValue<void>>((ref) {
  return DeviceSetupController(ref.read(dispenserRepositoryProvider), ref);
});

class DeviceSetupController extends StateNotifier<AsyncValue<void>> {
  final DispenserRepository _repo;
  final Ref _ref;

  DeviceSetupController(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> pairDevice(String deviceId, {String? deviceName}) async {
    state = const AsyncValue.loading();
    try {
      final user = _ref.read(authStateProvider).value;
      if (user == null) throw Exception("User not logged in");

      await _repo.pairDevice(
        deviceId: deviceId, 
        userId: user.uid, 
        role: user.role.name, // Enum to string
        deviceName: deviceName,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// Dispenser Actions Controller
final dispenserControllerProvider = StateNotifierProvider<DispenserController, AsyncValue<void>>((ref) {
  return DispenserController(
    ref.read(commandRepositoryProvider),
    ref.read(dispenserRepositoryProvider),
  );
});

class DispenserController extends StateNotifier<AsyncValue<void>> {
  final CommandRepository _commandRepo;
  final DispenserRepository _dispenserRepo; // Injected

  DispenserController(this._commandRepo, this._dispenserRepo) : super(const AsyncValue.data(null));

  Future<void> sendCommand(String dispenserId, String command, {Map<String, dynamic>? payload}) async {
    state = const AsyncValue.loading();
    try {
      await _commandRepo.sendCommand(dispenserId, command, payload: payload);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markDoseTaken(String dispenserId) async {
    state = const AsyncValue.loading();
    try {
      // 1. Send Command (as before)
      await _commandRepo.sendCommand(dispenserId, 'MARK_TAKEN');

      // 2. SIMULATE DEVICE LOGIC (Update State Directly)
      final dispenser = await _dispenserRepo.getDispenser(dispenserId);
      if (dispenser != null) {
        int currentDay = dispenser.currentState.operational.currentDay;
        int dailyDosesLeft = dispenser.currentState.operational.dosesRemaining;
        int totalDosesLeft = dispenser.currentState.totalDosesRemaining;
        
        // Decrement
        if (dailyDosesLeft > 0) dailyDosesLeft--;
        if (totalDosesLeft > 0) totalDosesLeft--;

        // Check for Day Increment
        if (dailyDosesLeft == 0 && totalDosesLeft > 0) {
           // Move to next day if we have total doses left
           currentDay++;
           
           // Calculate doses for the NEW current day from schedule
           int newDailyDoses = 0;
           if (dispenser.schedule.days.length >= currentDay) {
             final daySchedule = dispenser.schedule.days[currentDay - 1]; // 0-indexed
             if (daySchedule.morning.enabled) newDailyDoses++;
             if (daySchedule.lunch.enabled) newDailyDoses++;
             if (daySchedule.night.enabled) newDailyDoses++;
           }
           
           dailyDosesLeft = newDailyDoses;
        }

        // Update State
        await _dispenserRepo.updateCurrentState(dispenserId, {
          'doses_remaining': totalDosesLeft, // Root (Total)
          'operational': {
            'doses_remaining': dailyDosesLeft, // Inner (Daily)
            'current_day': currentDay,
            'dose_ready': false, // Dose taken
          }
        });
      }

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> unlockDevice(String dispenserId) async {
    await sendCommand(dispenserId, 'UNLOCK');
  }
}
