import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dispenser/presentation/providers/dispenser_providers.dart';

class CaregiverDashboardScreen extends ConsumerWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user.linkedDispensers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Caregiver Portal")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.group_add, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text("No Patients Linked", style: TextStyle(fontSize: 20)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.push('/setup'),
                icon: const Icon(Icons.add),
                label: const Text("Add Patient Device"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Patients"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/setup'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Confirm Logout"),
                    content: const Text("Do you want to logout?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Cancel"),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ref.read(authControllerProvider.notifier).signOut();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                        child: const Text("Logout"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: user.linkedDispensers.length,
        itemBuilder: (context, index) {
          final dispenserId = user.linkedDispensers[index];
          final dispenserAsync = ref.watch(dispenserProvider(dispenserId));

          return dispenserAsync.when(
            data: (dispenser) {
              if (dispenser == null) {
                return Card(child: ListTile(title: Text("Device $dispenserId not found")));
              }
              // We reuse the dashboard widget but wrap it in an ExpansionTile or Card?
              // Or better: Just show a Summary Card that expands or navigates?
              // The DispenserDashboardWidget is full screen-ish (ListView).
              // Let's create a Summary Card here, tapping it opens a Detail Screen (which uses DispenserDashboardWidget).
              
              // Wait, I can navigate to a Detail Route? 
              // Route: /dispenser/:id
              // I didn't create that route yet. I should.
              
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: Icon(Icons.medical_services, color: AppColors.primary),
                  title: Row(
                    children: [
                      Text(dispenser.deviceName.isNotEmpty ? dispenser.deviceName : "Smart Dispenser"),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dispenserId,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text("Status: ${dispenser.currentState.connectivity.wifiConnected ? 'Online' : 'Offline'} | Bat: ${dispenser.currentState.battery.percent.toInt()}%"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                     context.push('/dispenser/$dispenserId');
                  },
                ),
              );
            },
            error: (e,s) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text("Error: $e"))),
            loading: () => const Card(child: Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))),
          );
        },
      ),
    );
  }
}
