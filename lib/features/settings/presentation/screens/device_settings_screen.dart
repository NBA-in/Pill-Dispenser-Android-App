import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dispenser/data/models/dispenser_model.dart';
import '../../../dispenser/presentation/providers/dispenser_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/user_entity.dart';
import 'hardware_controls_screen.dart';

class DeviceSettingsScreen extends ConsumerStatefulWidget {
  final String dispenserId;
  const DeviceSettingsScreen({super.key, required this.dispenserId});

  @override
  ConsumerState<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends ConsumerState<DeviceSettingsScreen> {
  bool _isLoading = false;
  ConfigurationModel? _currentConfig;

  @override
  void initState() {
    super.initState();
    // Fetch initial config
    final dispenserAsync = ref.read(dispenserProvider(widget.dispenserId));
    dispenserAsync.whenData((data) {
      if (data != null) {
        setState(() => _currentConfig = data.configuration);
      }
    });
  }

  Future<void> _updateConfig(ConfigurationModel newConfig) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(dispenserRepositoryProvider)
          .updateConfiguration(widget.dispenserId, newConfig);
      
      setState(() => _currentConfig = newConfig);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Settings updated"), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentConfig == null) {
       final dispenserAsync = ref.watch(dispenserProvider(widget.dispenserId));
       return Scaffold(
         appBar: AppBar(title: const Text("Device Settings")),
         body: dispenserAsync.when(
           data: (d) {
             if (d == null) return const Center(child: Text("Device not found"));
             Future.microtask(() => setState(() => _currentConfig = d.configuration));
             return const Center(child: CircularProgressIndicator());
           },
           error: (e,s) => Center(child: Text("$e")),
           loading: () => const Center(child: CircularProgressIndicator()),
         ),
       );
    }

    // Check Permissions
    final authState = ref.watch(authStateProvider);
    final isCaregiver = authState.value?.role == UserRole.caregiver;

    return Scaffold(
      appBar: AppBar(title: const Text("Device Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!isCaregiver)
             const Padding(
               padding: EdgeInsets.only(bottom: 16),
               child: Card(color: Color(0xFFE3F2FD), child: ListTile(leading: Icon(Icons.info), title: Text("View Only Mode"))),
             ),
          SwitchListTile(
            title: const Text("Notifications Enabled"),
            subtitle: const Text("Receive alerts for doses and warnings"),
            value: _currentConfig!.notificationsEnabled,
            onChanged: (_isLoading || !isCaregiver) 
                ? null 
                : (val) => _updateConfig(_currentConfig!.copyWith(notificationsEnabled: val)),
          ),
          const Divider(),
          ListTile(
            title: const Text("Timezone Offset"),
            subtitle: Text("${_currentConfig!.timezoneOffset} seconds"),
            trailing: isCaregiver ? const Icon(Icons.edit) : null,
            onTap: isCaregiver ? () {
              // Timezone picker logic here
            } : null,
          ),
          if (isCaregiver) ...[
            const Divider(),
            ListTile(
              title: const Text("WiFi Configuration"),
              subtitle: const Text("Manage saved networks"),
              trailing: const Icon(Icons.wifi),
              onTap: () {
                 // WiFi Setup logic 
              },
            ),
            const Divider(),
             ListTile(
               title: const Text("Hardware Controls"),
               subtitle: const Text("RFID, Latch, & Dispense"),
               trailing: const Icon(Icons.settings_remote),
               onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => HardwareControlsScreen(dispenserId: widget.dispenserId)),
                  );
               },
             ),
             const Divider(),
             ListTile(
               title: const Text("Manage Users"),
               subtitle: const Text("View and remove caregivers"),
               trailing: const Icon(Icons.people),
               onTap: () {
                  context.push('/settings/caregivers/${widget.dispenserId}');
               },
             ),
            const SizedBox(height: 16),
             SizedBox(
               width: double.infinity,
               child: OutlinedButton.icon(
                 onPressed: () {
                   // Reboot / Diagnostics
                 }, 
                 icon: const Icon(Icons.restart_alt),
                 label: const Text("Reboot Device"),
               ),
             )
          ]
        ],
      ),
    );
  }
}

extension ConfigCopy on ConfigurationModel {
  ConfigurationModel copyWith({bool? notificationsEnabled, int? timezoneOffset}) {
    return ConfigurationModel(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      timezoneOffset: timezoneOffset ?? this.timezoneOffset,
    );
  }
}
