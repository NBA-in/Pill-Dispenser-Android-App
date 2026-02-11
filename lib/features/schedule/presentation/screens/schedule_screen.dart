import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dispenser/data/models/dispenser_model.dart';
import '../../../dispenser/presentation/providers/dispenser_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/user_entity.dart';

class ScheduleScreen extends ConsumerStatefulWidget {
  final String dispenserId;
  const ScheduleScreen({super.key, required this.dispenserId});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> with SingleTickerProviderStateMixin {
  // Local state for editing
  ScheduleModel? _editingSchedule;
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    
    // Load initial data
    final dispenserAsync = ref.read(dispenserProvider(widget.dispenserId));
    dispenserAsync.whenData((dispenser) {
      if (dispenser != null) {
        setState(() {
          _editingSchedule = dispenser.schedule;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveSchedule() async {
    if (_editingSchedule == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(dispenserRepositoryProvider).updateSchedule(
        widget.dispenserId, 
        _editingSchedule!
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Schedule Updated"), backgroundColor: AppColors.success),
        );
        Navigator.pop(context); // Go back
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

  Future<void> _pickTime(int dayIndex, String type, DoseTimeModel currentSettings) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentSettings.hour, minute: currentSettings.minute),
    );

    if (picked != null) {
      _updateDose(dayIndex, type, currentSettings.copyWith(hour: picked.hour, minute: picked.minute));
    }
  }

  void _toggleEnabled(int dayIndex, String type, bool value, DoseTimeModel currentSettings) {
    _updateDose(dayIndex, type, currentSettings.copyWith(enabled: value));
  }

  void _updateDose(int dayIndex, String type, DoseTimeModel newDose) {
    if (_editingSchedule == null) return;
    
    // Create a copy of the days list
    final List<DailyScheduleModel> newDays = List.from(_editingSchedule!.days);
    final currentDay = newDays[dayIndex];
    
    DailyScheduleModel newDay;
    switch (type) {
      case 'Morning':
        newDay = DailyScheduleModel(
          morning: newDose,
          lunch: currentDay.lunch,
          night: currentDay.night
        );
        break;
      case 'Lunch':
         newDay = DailyScheduleModel(
          morning: currentDay.morning,
          lunch: newDose,
          night: currentDay.night
        );
        break;
      case 'Night':
         newDay = DailyScheduleModel(
          morning: currentDay.morning,
          lunch: currentDay.lunch,
          night: newDose
        );
        break;
      default:
        return;
    }
    
    newDays[dayIndex] = newDay;

    setState(() {
      _editingSchedule = ScheduleModel(
        days: newDays,
        syncStatus: _editingSchedule!.syncStatus // preserve status
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // If local state is null, try to get from provider again (first load)
    if (_editingSchedule == null) {
      final dispenserAsync = ref.watch(dispenserProvider(widget.dispenserId));
      
      return Scaffold(
        appBar: AppBar(title: const Text("Edit Schedule")),
        body: dispenserAsync.when(
          data: (d) {
             if (d == null) return const Center(child: Text("Error loading"));
             // Initialize local state
             Future.microtask(() => setState(() => _editingSchedule = d.schedule));
             return const Center(child: CircularProgressIndicator());
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e,s) => Center(child: Text("$e")),
        ),
      );
    }

    // Check Permissions
    final authState = ref.watch(authStateProvider);
    final isCaregiver = authState.value?.role == UserRole.caregiver;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Schedule"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.black,
          indicatorColor: Colors.white,
          tabs: List.generate(5, (index) => Tab(text: "Day ${index + 1}")),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
           if (!isCaregiver)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Card(
                color: Color(0xFFFFF3E0),
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text("Only caregivers can edit the schedule.", textAlign: TextAlign.center),
                ),
              ),
            ),
           Expanded(
             child: TabBarView(
               controller: _tabController,
               children: List.generate(5, (dayIndex) {
                 final daySchedule = _editingSchedule!.days[dayIndex];
                 return ListView(
                   padding: const EdgeInsets.all(16),
                   children: [
                      _buildDoseTile(dayIndex, "Morning", daySchedule.morning, isCaregiver),
                      const SizedBox(height: 16),
                      _buildDoseTile(dayIndex, "Lunch", daySchedule.lunch, isCaregiver),
                      const SizedBox(height: 16),
                      _buildDoseTile(dayIndex, "Night", daySchedule.night, isCaregiver),
                   ],
                 );
               }),
             ),
           ),
           Padding(
             padding: const EdgeInsets.all(16.0),
             child: SizedBox(
               width: double.infinity,
               child: FilledButton(
                 onPressed: (_isLoading || !isCaregiver) ? null : _saveSchedule,
                 style: FilledButton.styleFrom(
                   padding: const EdgeInsets.symmetric(vertical: 16),
                 ),
                 child: _isLoading 
                   ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                   : const Text("Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
               ),
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildDoseTile(int dayIndex, String label, DoseTimeModel dose, bool isEditable) {
    return Card(
      child: ListTile(
        leading: Icon(
          label == 'Morning' ? Icons.wb_twilight :
          label == 'Lunch' ? Icons.wb_sunny : Icons.nightlight_round,
          color: AppColors.primary
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          "${TimeOfDay(hour: dose.hour, minute: dose.minute).format(context)}${dose.enabled ? '' : ' (Disabled)'}",
          style: TextStyle(
            color: dose.enabled ? null : Colors.grey,
          ),
        ),
        trailing: Switch(
          value: dose.enabled,
          onChanged: isEditable ? (val) => _toggleEnabled(dayIndex, label, val, dose) : null,
        ),
        onTap: isEditable ? () => _pickTime(dayIndex, label, dose) : null,
      ),
    );
  }
}

// Helper extension to copyWith
extension DoseTimeModelCopy on DoseTimeModel {
  DoseTimeModel copyWith({int? hour, int? minute, bool? enabled}) {
    return DoseTimeModel(
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
    );
  }
}
