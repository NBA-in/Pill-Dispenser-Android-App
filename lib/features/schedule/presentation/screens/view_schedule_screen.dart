import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../dispenser/presentation/providers/dispenser_providers.dart';
import '../../../dispenser/presentation/widgets/compartment_guide_widget.dart';

class ViewScheduleScreen extends ConsumerWidget {
  final String dispenserId;

  const ViewScheduleScreen({super.key, required this.dispenserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispenserAsync = ref.watch(dispenserProvider(dispenserId));

    return Scaffold(
      appBar: AppBar(title: const Text("My Medicine Schedule")),
      body: dispenserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text("Error: $e")),
        data: (dispenser) {
          if (dispenser == null) return const Center(child: Text("Device not found"));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "This is your medicine schedule for the 5-day cycle.",
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Medicine Plan",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                CompartmentGuideWidget(
                  schedule: dispenser.schedule,
                  readOnly: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
