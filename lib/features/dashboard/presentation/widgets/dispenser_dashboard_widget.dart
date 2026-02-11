import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/dose_calculator.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../dispenser/data/models/dispenser_model.dart';
import '../../../dispenser/presentation/providers/dispenser_providers.dart';
import '../../../dispenser/presentation/screens/refill_wizard_screen.dart';

class DispenserDashboardWidget extends ConsumerStatefulWidget {
  final DispenserModel dispenser;
  final bool isCaregiver;

  const DispenserDashboardWidget({
    super.key, 
    required this.dispenser,
    this.isCaregiver = false,
  });

  @override
  ConsumerState<DispenserDashboardWidget> createState() => _DispenserDashboardWidgetState();
}

class _DispenserDashboardWidgetState extends ConsumerState<DispenserDashboardWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Update UI every minute to refresh countdown
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nextDose = DoseCalculator.getNextDoseTime(
        widget.dispenser.schedule, 
        widget.dispenser.currentState.operational.currentDay
    );
    final isReady = widget.dispenser.currentState.operational.doseReady; 

    ref.listen<AsyncValue<void>>(dispenserControllerProvider, (prev, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${next.error}"), backgroundColor: AppColors.error),
        );
      } else if (!next.isLoading && next.hasValue) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Command Sent"), backgroundColor: AppColors.success),
        );
      }
    });

    final actionState = ref.watch(dispenserControllerProvider);
    final isActionLoading = actionState.isLoading;

    final currState = widget.dispenser.currentState; // Helper to shorten access

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(dispenserProvider(widget.dispenser.id));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // HEADER CARD
          Card(
            color: currState.connectivity.wifiConnected ? AppColors.primaryContainer : AppColors.error.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                   Icon(
                     currState.connectivity.wifiConnected ? Icons.wifi : Icons.wifi_off,
                     color: currState.connectivity.wifiConnected ? AppColors.primary : AppColors.error,
                   ),
                   const SizedBox(width: 16),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         widget.dispenser.deviceName,
                         style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                       ),
                       Text(
                         currState.connectivity.wifiConnected ? AppConstants.onlineText : AppConstants.offlineText,
                         style: TextStyle(
                           color: currState.connectivity.wifiConnected ? AppColors.primary : AppColors.error,
                         ),
                       ),
                     ],
                   ),
                   const Spacer(),
                   Icon(Icons.battery_full, color: _getBatteryColor(currState.battery.percent.toInt())),
                   const SizedBox(width: 4),
                   Text("${currState.battery.percent.toInt()}%"),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // COUNTDOWN OR STATUS
          Center(
             child: Container(
               width: 260,
               height: 260,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 gradient: isReady 
                     ? LinearGradient(colors: [AppColors.error, AppColors.error.withAlpha(200)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                     : const LinearGradient(colors: [Colors.white, Color(0xFFF0F5FF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                 border: Border.all(
                   color: isReady ? AppColors.error : AppColors.primary,
                   width: 5,
                 ),
                 boxShadow: [
                   BoxShadow(
                     color: Colors.black.withOpacity(0.1),
                     blurRadius: 20,
                     spreadRadius: 5,
                   )
                 ]
               ),
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   if (isReady) ...[
                      const Icon(Icons.medication, size: 60, color: Colors.white),
                      const Text(
                        "TAKE\nMEDICINE",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                   ] else if (nextDose != null) ...[
                      const Icon(Icons.timer, size: 50, color: AppColors.primary),
                      const SizedBox(height: 8),
                      Text(
                         DoseCalculator.getTimeUntil(nextDose),
                         style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const Text("Until next dose", style: TextStyle(color: Colors.grey)),
                      Text(
                        "${nextDose.hour}:${nextDose.minute.toString().padLeft(2,'0')}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                   ] else ...[
                      const Icon(Icons.check_circle_outline, size: 60, color: AppColors.success),
                      const Text("All Done", style: TextStyle(fontSize: 24, color: AppColors.success)),
                      const Text("No doses scheduled", style: TextStyle(color: Colors.grey)),
                   ]
                 ],
               ),
             ),
          ),

          const SizedBox(height: 32),
          
          // STATS ROWS
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  "Doses Left\n(Total)", 
                  "${widget.dispenser.currentState.totalDosesRemaining}", 
                  Icons.medication_liquid,
                  widget.dispenser.currentState.totalDosesRemaining < 5 ? AppColors.warning : AppColors.primary,
                )
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  "Day ${currState.operational.currentDay}", 
                  "${currState.operational.dosesRemaining} Left", 
                  Icons.today,
                  AppColors.secondary,
                )
              ),
            ],
          ),
          
          const SizedBox(height: 24),

          // ACTIONS SECTION
          const Text("Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
               if (widget.isCaregiver)
                 ActionChip(
                   avatar: const Icon(Icons.edit_calendar),
                   label: const Text("Edit Schedule"),
                   onPressed: () {
                     context.push('/schedule/${widget.dispenser.id}');
                   },
                 )
               else
                 ActionChip(
                   avatar: const Icon(Icons.calendar_month),
                   label: const Text("View Schedule"),
                   onPressed: () {
                     context.push('/view-schedule/${widget.dispenser.id}');
                   },
                 ),
               ActionChip(
                 avatar: const Icon(Icons.history),
                 label: const Text("History"),
                 onPressed: () {
                   context.push('/history/${widget.dispenser.id}');
                 },
               ),
               ActionChip(
                 avatar: const Icon(Icons.analytics),
                 label: const Text("Stats"),
                 onPressed: () {
                   context.push('/stats/${widget.dispenser.id}');
                 },
               ),
               if (widget.isCaregiver)
                 ActionChip(
                   avatar: const Icon(Icons.lock_open),
                   label: const Text(AppConstants.unlockAction),
                   onPressed: isActionLoading ? null : () {
                      ref.read(dispenserControllerProvider.notifier).unlockDevice(widget.dispenser.id);
                      ref.read(dispenserControllerProvider.notifier).unlockDevice(widget.dispenser.id);
                   },
                 ),
               if (widget.isCaregiver)
                 ActionChip(
                   avatar: const Icon(Icons.autorenew),
                   label: const Text("Refill"),
                   onPressed: () {
                     Navigator.of(context).push(
                       MaterialPageRoute(builder: (_) => RefillWizardScreen(dispenserId: widget.dispenser.id)),
                     );
                   },
                 ),
            ],
          ),

          // MANUAL DISPENSE / TAKE CONFIRMATION
           if (isReady && !widget.isCaregiver) ...[
             const SizedBox(height: 24),
             ElevatedButton.icon(
               onPressed: isActionLoading ? null : () {
                  ref.read(dispenserControllerProvider.notifier).markDoseTaken(widget.dispenser.id);
               }, 
               icon: isActionLoading 
                  ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(color:Colors.white)) 
                  : const Icon(Icons.check),
               label: const Text(AppConstants.takeMedicineAction),
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppColors.success,
                 padding: const EdgeInsets.symmetric(vertical: 16),
               ),
             )
          ]
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
  
  Color _getBatteryColor(int percent) {
    if (percent > 50) return Colors.green;
    if (percent > 20) return Colors.orange;
    return Colors.red;
  }
}
