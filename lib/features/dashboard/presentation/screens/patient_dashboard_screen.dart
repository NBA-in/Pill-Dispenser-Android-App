import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../dispenser/presentation/providers/dispenser_providers.dart';
// For types
import '../widgets/dispenser_dashboard_widget.dart';

class PatientDashboardScreen extends ConsumerStatefulWidget {
  const PatientDashboardScreen({super.key});

  @override
  ConsumerState<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends ConsumerState<PatientDashboardScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresh UI every minute for countdown
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
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user.linkedDispensers.isEmpty) {
      return _buildNoDeviceView();
    }

    final dispenserId = user.linkedDispensers.first; // Support multiple later?
    final dispenserAsync = ref.watch(dispenserProvider(dispenserId));

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Medicine"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
               context.push('/settings/$dispenserId');
            }, 
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: dispenserAsync.when(
        data: (dispenser) {
          if (dispenser == null) return const Center(child: Text("Device not found"));
          return DispenserDashboardWidget(dispenser: dispenser);
        },
        error: (err, stack) => Center(child: Text("Error: $err")),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildNoDeviceView() {
    return Scaffold(
      appBar: AppBar(title: const Text("Welcome")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("No Device Linked", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/setup'),
              icon: const Icon(Icons.add),
              label: const Text("Setup Device"),
            ),
          ],
        ),
      ),
    );
  }
}
