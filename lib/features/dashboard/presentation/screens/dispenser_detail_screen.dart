import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dispenser/presentation/providers/dispenser_providers.dart';
import '../widgets/dispenser_dashboard_widget.dart';

class DispenserDetailScreen extends ConsumerWidget {
  final String dispenserId;
  const DispenserDetailScreen({super.key, required this.dispenserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispenserAsync = ref.watch(dispenserProvider(dispenserId));

    return Scaffold(
      appBar: AppBar(title: const Text("Device Details")),
      body: dispenserAsync.when(
        data: (dispenser) {
          if (dispenser == null) return const Center(child: Text("Device not found"));
          return DispenserDashboardWidget(
            dispenser: dispenser, 
            isCaregiver: true, // Hide "I took it" button from caregiver? Or allow if necessary?
            // User requirements: "Manual Controls (Admin/Caregiver)" ... yes.
            // But "I have taken my medicine" is for Patient.
            // I'll set isCaregiver=true to hide the quick take button, 
            // but Caregiver might have other controls.
          );
        },
        error: (err, stack) => Center(child: Text("Error: $err")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
