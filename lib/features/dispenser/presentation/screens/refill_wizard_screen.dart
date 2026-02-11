import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dispenser/data/models/dispenser_model.dart';
import '../../../dispenser/presentation/providers/dispenser_providers.dart';
import '../widgets/compartment_guide_widget.dart';

class RefillWizardScreen extends ConsumerStatefulWidget {
  final String dispenserId;
  const RefillWizardScreen({super.key, required this.dispenserId});

  @override
  ConsumerState<RefillWizardScreen> createState() => _RefillWizardScreenState();
}

class _RefillWizardScreenState extends ConsumerState<RefillWizardScreen> {
  int _currentStep = 0;
  bool _isProcessing = false;
  
  // Local schedule state to hold changes before committing
  ScheduleModel? _pendingSchedule;

  @override
  void initState() {
    super.initState();
    // Pre-load schedule so we can edit it locally
    // We do this in build or dedicated method since we need ref.
  }

  void _nextStep() {
    setState(() => _currentStep++);
  }

  void _prevStep() {
    setState(() => _currentStep--);
  }

  Future<void> _completeRefill() async {
    if (_pendingSchedule == null) return;

    setState(() => _isProcessing = true);
    try {
      // 1. Update Schedule in DB
      await ref.read(dispenserRepositoryProvider).updateSchedule(widget.dispenserId, _pendingSchedule!);
      
      // 2. Reset Dispenser State (counters, etc.)
      await ref.read(dispenserRepositoryProvider).resetDispenser(widget.dispenserId, schedule: _pendingSchedule);
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("Refill Complete"),
            content: const Text("The dispenser has been updated and reset."),
            actions: [
              TextButton(
                onPressed: () {
                   context.pop(); // Close Dialog
                   context.pop(); // Close Wizard
                },
                child: const Text("Done"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _editSlot(int dayIndex, String type, DoseTimeModel currentDose) async {
    // Show Dialog to Edit Time and Enable/Disable
    TimeOfDay selectedTime = TimeOfDay(hour: currentDose.hour, minute: currentDose.minute);
    bool isEnabled = currentDose.enabled;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Edit Day ${dayIndex + 1} - $type"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   // Instructions / Tick mark info
                   const Padding(
                     padding: EdgeInsets.only(bottom: 8.0),
                     child: Text("Enable to schedule this dose.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                   ),
                  ListTile(
                    title: const Text("Enabled"),
                    trailing: Switch(
                      value: isEnabled,
                      onChanged: (val) {
                         setDialogState(() => isEnabled = val);
                      },
                    ),
                  ),
                  ListTile(
                    title: const Text("Time"),
                    subtitle: Text(selectedTime.format(context)),
                    trailing: const Icon(Icons.access_time),
                    enabled: isEnabled, // Only allow time edit if enabled? Or always?
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context, 
                        initialTime: selectedTime
                      );
                      if (picked != null) {
                         setDialogState(() => selectedTime = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Update Local State ONLY
                    _updateLocalSchedule(dayIndex, type, selectedTime, isEnabled);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _updateLocalSchedule(int dayIndex, String type, TimeOfDay time, bool enabled) {
    if (_pendingSchedule == null) return;

    final newDays = List<DailyScheduleModel>.from(_pendingSchedule!.days);
    final currentDay = newDays[dayIndex];
    
    final newDose = DoseTimeModel(hour: time.hour, minute: time.minute, enabled: enabled);
    
    DailyScheduleModel newDay;
    switch (type) {
      case 'morning':
        newDay = DailyScheduleModel(morning: newDose, lunch: currentDay.lunch, night: currentDay.night);
        break;
      case 'lunch':
         newDay = DailyScheduleModel(morning: currentDay.morning, lunch: newDose, night: currentDay.night);
         break;
      case 'night':
         newDay = DailyScheduleModel(morning: currentDay.morning, lunch: currentDay.lunch, night: newDose);
         break;
      default:
        return;
    }
    
    newDays[dayIndex] = newDay;
    
    setState(() {
      _pendingSchedule = ScheduleModel(days: newDays, syncStatus: _pendingSchedule!.syncStatus);
    });
    // No Snackbar, No DB call.
  }

  @override
  Widget build(BuildContext context) {
    final dispenserAsync = ref.watch(dispenserProvider(widget.dispenserId));

    return Scaffold(
      appBar: AppBar(title: const Text("Refill Wizard")),
      body: dispenserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,s) => Center(child: Text("$e")),
        data: (dispenser) {
          if (dispenser == null) return const Center(child: Text("Dispenser not found"));

          // Initialize pending schedule on first load
          if (_pendingSchedule == null) {
             // We use microtask to avoid setState during build if possible, 
             // but here we are in build. 
             // Better pattern: initialize in initState? But we need ref load.
             // We can do it here safely if we guard it.
             _pendingSchedule = dispenser.schedule;
          }

          return Stepper(
            currentStep: _currentStep,
            onStepContinue: _currentStep < 2 ? _nextStep : _completeRefill,
            onStepCancel: _currentStep > 0 ? _prevStep : () => context.pop(),
            controlsBuilder: (context, details) {
              return Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Row(
                  children: [
                    FilledButton(
                      onPressed: _isProcessing ? null : details.onStepContinue,
                      child: Text(_currentStep == 2 ? "Complete Refill" : "Next"),
                    ),
                    const SizedBox(width: 12),
                    if (_currentStep > 0)
                      OutlinedButton(
                        onPressed: _isProcessing ? null : details.onStepCancel,
                        child: const Text("Back"),
                      ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text("Preparation"),
                content: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("1. Unlock the dispenser latch."),
                    Text("2. Open the lid."),
                    Text("3. Ensure all compartments are empty if any old pills remain."),
                    SizedBox(height: 10),
                    Card(
                       color: AppColors.surface,
                       child: Padding(
                         padding: EdgeInsets.all(12.0),
                         child: Row(
                           children: [
                             Icon(Icons.warning_amber, color: AppColors.warning),
                             SizedBox(width: 10),
                             Expanded(child: Text("Ensure device is powered ON during refill.")),
                           ],
                         ),
                       ),
                    )
                  ],
                ),
                isActive: _currentStep >= 0,
                state: _currentStep > 0 ? StepState.complete : StepState.editing,
              ),
              Step(
                title: const Text("Fill Compartments"),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Fill the compartments according to your schedule:"),
                    const Text("Tap a slot to edit time or enable/disable.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    // Use _pendingSchedule here to reflect local edits!
                    CompartmentGuideWidget(
                      schedule: _pendingSchedule!, 
                      onSlotTap: (dayIndex, type, dose) => _editSlot(dayIndex, type, dose),
                    ),
                  ],
                ),
                isActive: _currentStep >= 1,
                state: _currentStep > 1 ? StepState.complete : StepState.editing,
              ),
              Step(
                title: const Text("Confirmation"),
                content: const Text(
                  "1. Close the lid securely.\n"
                  "2. Ensure the latch is locked.\n\n"
                  "Tap 'Complete Refill' to save schedule changes and reset the dispenser."
                ),
                isActive: _currentStep >= 2,
                state: _currentStep == 2 ? StepState.indexed : StepState.indexed,
              ),
            ],
          );
        },
      ),
    );
  }
}
