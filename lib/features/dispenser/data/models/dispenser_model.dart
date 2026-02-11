import 'package:cloud_firestore/cloud_firestore.dart';

class DispenserModel {
  final String id; // Document ID (MAC Address)
  final String deviceId; // Same as ID usually
  final String deviceName;
  final ScheduleModel schedule;
  final CurrentStateModel currentState;
  final ConfigurationModel configuration;

  const DispenserModel({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.schedule,
    required this.currentState,
    required this.configuration,
  });

  factory DispenserModel.fromFirestore(DocumentSnapshot doc, {Map<String, dynamic>? overrideData}) {
    final data = overrideData ?? (doc.data() as Map<String, dynamic>? ?? {});
    return DispenserModel(
      id: doc.id,
      deviceId: doc.id, // Assuming doc ID is MAC
      deviceName: (data['device_info'] as Map<String, dynamic>?)?['device_name'] ?? data['device_name'] ?? 'Smart Dispenser',
      schedule: ScheduleModel.fromMap(Map<String, dynamic>.from(data['schedule'] ?? {})),
      currentState: CurrentStateModel.fromMap(Map<String, dynamic>.from(data['current_state'] ?? {})),
      configuration: ConfigurationModel.fromMap(Map<String, dynamic>.from(data['configuration'] ?? {})),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'device_name': deviceName,
      'schedule': schedule.toMap(),
      'current_state': currentState.toMap(),
      'configuration': configuration.toMap(),
    };
  }
}

// --- Sub Models ---

// --- Sub Models ---

class ScheduleModel {
  final List<DailyScheduleModel> days; // Fixed size: 5
  final String syncStatus;

  const ScheduleModel({
    required this.days,
    this.syncStatus = '',
  });

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> daysList = map['days'] ?? [];
    List<DailyScheduleModel> days = [];
    if (daysList.isNotEmpty) {
      days = daysList.map((d) => DailyScheduleModel.fromMap(d)).toList();
    } else {
      // Create valid defaults for 5 days if missing
      days = List.generate(5, (_) => const DailyScheduleModel());
    }

    return ScheduleModel(
      days: days,
      syncStatus: map['schedule_metadata']?['sync_status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'days': days.map((d) => d.toMap()).toList(),
    'schedule_metadata': {'sync_status': syncStatus},
  };
}

class DailyScheduleModel {
  final DoseTimeModel morning;
  final DoseTimeModel lunch;
  final DoseTimeModel night;

  const DailyScheduleModel({
    this.morning = const DoseTimeModel(hour: 8, minute: 0, enabled: false),
    this.lunch = const DoseTimeModel(hour: 13, minute: 0, enabled: false),
    this.night = const DoseTimeModel(hour: 20, minute: 0, enabled: false),
  });

  factory DailyScheduleModel.fromMap(Map<String, dynamic> map) {
    return DailyScheduleModel(
      morning: DoseTimeModel.fromMap(Map<String, dynamic>.from(map['morning'] ?? {})),
      lunch: DoseTimeModel.fromMap(Map<String, dynamic>.from(map['lunch'] ?? {})),
      night: DoseTimeModel.fromMap(Map<String, dynamic>.from(map['night'] ?? {})),
    );
  }

  Map<String, dynamic> toMap() => {
    'morning': morning.toMap(),
    'lunch': lunch.toMap(),
    'night': night.toMap(),
  };
}

class DoseTimeModel {
  final int hour;
  final int minute;
  final bool enabled; 

  const DoseTimeModel({this.hour = 8, this.minute = 0, this.enabled = false});

  factory DoseTimeModel.fromMap(Map<String, dynamic> map) {
    return DoseTimeModel(
      hour: map['hour'] ?? 8,
      minute: map['minute'] ?? 0,
      enabled: map['enabled'] ?? false, // Default to false if not specified
    );
  }

  Map<String, dynamic> toMap() => {
    'hour': hour,
    'minute': minute,
    'enabled': enabled,
  };
}

class CurrentStateModel {
  final OperationalState operational;
  final HardwareState hardware;
  final BatteryState battery;
  final ConnectivityState connectivity;
  final TimestampsState timestamps;
  final int totalDosesRemaining; // New field for cycle total

  const CurrentStateModel({
    required this.operational,
    required this.hardware,
    required this.battery,
    required this.connectivity,
    required this.timestamps,
    this.totalDosesRemaining = 0,
  });

  factory CurrentStateModel.fromMap(Map<String, dynamic> map) {
    return CurrentStateModel(
      operational: OperationalState.fromMap(Map<String, dynamic>.from(map['operational'] ?? {})),
      hardware: HardwareState.fromMap(Map<String, dynamic>.from(map['hardware'] ?? {})),
      battery: BatteryState.fromMap(Map<String, dynamic>.from(map['battery'] ?? {})),
      connectivity: ConnectivityState.fromMap(Map<String, dynamic>.from(map['connectivity'] ?? {})),
      timestamps: TimestampsState.fromMap(Map<String, dynamic>.from(map['timestamps'] ?? {})),
      totalDosesRemaining: map['doses_remaining'] ?? 0, // Read from root of current_state
    );
  }

  Map<String, dynamic> toMap() => {
    'operational': operational.toMap(),
    'hardware': hardware.toMap(),
    'battery': battery.toMap(),
    'connectivity': connectivity.toMap(),
    'timestamps': timestamps.toMap(),
    'doses_remaining': totalDosesRemaining,
  };
}

class OperationalState {
  final int currentDay;
  final int dosesRemaining;
  final bool doseReady;
  final String doseName;
  final bool refillModeActive;

  const OperationalState({
    this.currentDay = 1,
    this.dosesRemaining = 0,
    this.doseReady = false,
    this.doseName = '',
    this.refillModeActive = false,
  });

  factory OperationalState.fromMap(Map<String, dynamic> map) {
    return OperationalState(
      currentDay: map['current_day'] ?? 1,
      dosesRemaining: map['doses_remaining'] ?? 0,
      doseReady: map['dose_ready'] ?? false,
      doseName: map['dose_name'] ?? '',
      refillModeActive: map['refill_mode_active'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'current_day': currentDay,
    'doses_remaining': dosesRemaining,
    'dose_ready': doseReady,
    'dose_name': doseName,
    'refill_mode_active': refillModeActive,
  };
}

class HardwareState {
  final bool latchLocked;
  final bool displayOn;
  final bool lidOpen;

  const HardwareState({
    this.latchLocked = true,
    this.displayOn = true,
    this.lidOpen = false,
  });

  factory HardwareState.fromMap(Map<String, dynamic> map) {
    return HardwareState(
      latchLocked: map['latch_locked'] ?? true,
      displayOn: map['display_on'] ?? true,
      lidOpen: map['lid_open'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'latch_locked': latchLocked,
    'display_on': displayOn,
    'lid_open': lidOpen,
  };
}

class BatteryState {
  final double percent;
  final double voltage;
  final bool lowBatteryWarning;
  final bool criticalBattery;

  const BatteryState({
    this.percent = 100.0,
    this.voltage = 4.2,
    this.lowBatteryWarning = false,
    this.criticalBattery = false,
  });

  factory BatteryState.fromMap(Map<String, dynamic> map) {
    return BatteryState(
      percent: (map['percent'] ?? 100).toDouble(),
      voltage: (map['voltage'] ?? 4.2).toDouble(),
      lowBatteryWarning: map['low_battery_warning'] ?? false,
      criticalBattery: map['critical_battery'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'percent': percent,
    'voltage': voltage,
    'low_battery_warning': lowBatteryWarning,
    'critical_battery': criticalBattery,
  };
}

class ConnectivityState {
  final bool wifiConnected;
  final bool firebaseConnected;
  final Timestamp? lastTimeSync;

  const ConnectivityState({
    this.wifiConnected = false,
    this.firebaseConnected = false,
    this.lastTimeSync,
  });

  factory ConnectivityState.fromMap(Map<String, dynamic> map) {
    return ConnectivityState(
      wifiConnected: map['wifi_connected'] ?? false,
      firebaseConnected: map['firebase_connected'] ?? false,
      lastTimeSync: map['last_time_sync'],
    );
  }

  Map<String, dynamic> toMap() => {
    'wifi_connected': wifiConnected,
    'firebase_connected': firebaseConnected,
    'last_time_sync': lastTimeSync,
  };
}

class TimestampsState {
  final Timestamp? lastStateUpdate;
  final int uptimeSeconds;

  const TimestampsState({this.lastStateUpdate, this.uptimeSeconds = 0});

  factory TimestampsState.fromMap(Map<String, dynamic> map) {
    return TimestampsState(
      lastStateUpdate: map['last_state_update'],
      uptimeSeconds: map['uptime_seconds'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'last_state_update': lastStateUpdate,
    'uptime_seconds': uptimeSeconds,
  };
}

class ConfigurationModel {
  final bool notificationsEnabled;
  final int timezoneOffset;
  final int volume; 

  const ConfigurationModel({
    this.notificationsEnabled = true,
    this.timezoneOffset = 0,
    this.volume = 50,
  });

  factory ConfigurationModel.fromMap(Map<String, dynamic> map) {
    return ConfigurationModel(
      notificationsEnabled: map['notifications_enabled'] ?? true,
      timezoneOffset: map['timezone_offset'] ?? 0,
      volume: map['volume'] ?? 50,
    );
  }

  Map<String, dynamic> toMap() => {
    'notifications_enabled': notificationsEnabled,
    'timezone_offset': timezoneOffset,
    'volume': volume,
  };
    
  ConfigurationModel copyWith({bool? notificationsEnabled, int? timezoneOffset, int? volume}) {
    return ConfigurationModel(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      timezoneOffset: timezoneOffset ?? this.timezoneOffset,
      volume: volume ?? this.volume,
    );
  }
}
