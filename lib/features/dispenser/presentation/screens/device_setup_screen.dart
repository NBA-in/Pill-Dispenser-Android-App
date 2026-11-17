import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/dispenser_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../setup/presentation/screens/qr_code_scanner_screen.dart';

class DeviceSetupScreen extends ConsumerStatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  ConsumerState<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends ConsumerState<DeviceSetupScreen> {
  final _deviceIdController = TextEditingController();
  final _relationshipController = TextEditingController();

  @override
  void dispose() {
    _deviceIdController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _handlePair() async {
    if (_deviceIdController.text.trim().isEmpty) return;
    
    final role = ref.read(authStateProvider).value?.role;
    if (role == UserRole.caregiver && _relationshipController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter your relationship to the patient."), backgroundColor: AppColors.error),
        );
        return;
    }

    await ref.read(deviceSetupControllerProvider.notifier)
        .pairDevice(
          _deviceIdController.text.trim(),
          relationship: role == UserRole.caregiver ? _relationshipController.text.trim() : null,
        );
  }

  Future<void> _scanQR() async {
    // Navigate to QR Scanner
    // We can use the existing widget or push a route. 
    // Since it's a widget, we can push MaterialPageRoute.
    final scannedCode = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const QRCodeScannerScreen())
    );

    if (scannedCode != null && scannedCode is String) {
      setState(() {
        _deviceIdController.text = scannedCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(deviceSetupControllerProvider, (prev, next) {
      if (next.hasError) {
        final errorMsg = next.error.toString();
        if (errorMsg.contains('DEVICE_NOT_FOUND')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Device Not Found"),
              content: const Text("The Device ID you entered does not exist in our system. Please check the ID and try again, or ensure the device has been registered by a caregiver."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Try Again"),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $errorMsg"), backgroundColor: AppColors.error),
          );
        }
      } else if (!next.isLoading && next.hasValue) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Device Paired Successfully!"), backgroundColor: AppColors.success),
        );
        // Navigate to Dashboard
        final role = ref.read(authStateProvider).value?.role;
        if (role == UserRole.patient) {
           context.go('/patient');
        } else {
           context.go('/caregiver');
        }
      }
    });

    final state = ref.watch(deviceSetupControllerProvider);
    final isLoading = state.isLoading;
    final role = ref.watch(authStateProvider).value?.role;

    return Scaffold(
      appBar: AppBar(title: const Text("Setup Device")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.router, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text(
              "Pair your CFP Device",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Scan the QR code on your device or enter the Device ID manually.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).disabledColor),
            ),
            const SizedBox(height: 32),
            
            // Scan Button
            OutlinedButton.icon(
              onPressed: isLoading ? null : _scanQR,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Scan QR Code"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
              ),
            ),
            
            const SizedBox(height: 24),
            const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.all(8.0), child: Text("OR")), Expanded(child: Divider())]),
            const SizedBox(height: 24),

            TextField(
              controller: _deviceIdController,
              decoration: const InputDecoration(
                labelText: "Device ID",
                hintText: "Enter ID manually (e.g. PILL-001)",
                prefixIcon: Icon(Icons.qr_code),
                border: OutlineInputBorder(),
              ),
            ),
            
            if (role == UserRole.caregiver) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _relationshipController,
                decoration: InputDecoration(
                  labelText: "Relationship with Patient (e.g. Son, Daughter)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.people_outline),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const SizedBox(height: 40), // Replaces Spacer
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handlePair,
                child: isLoading 
                    ? SizedBox(width:20, height:20, child: CircularProgressIndicator(color: Theme.of(context).colorScheme.onPrimary))
                    : const Text("Connect Device"),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
