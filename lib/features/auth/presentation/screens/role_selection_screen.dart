import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../../domain/entities/user_entity.dart';
import '../../../setup/presentation/screens/qr_code_scanner_screen.dart';
import '../../../../core/theme/app_colors.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  UserRole? _selectedRole;

  Future<void> _handleGoogleSignIn() async {
    // 1. Validate Inputs
    if (_selectedRole == null) {
      _showSnack("Please select your role (Caregiver or Patient).");
      return;
    }

    try {
      // Pass the role to signInWithGoogle.
      await ref.read(authControllerProvider.notifier).signInWithGoogle(
        role: _selectedRole,
      );
      // Navigation is handled automatically by router listening to authState
    } catch (e) {
      // Error handling is also done via listener, but we catch here if needed or just let listener handle it
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth error states
    ref.listen<AsyncValue<void>>(authControllerProvider, (prev, next) {
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
          _showSnack("Login Error: $errorMsg");
        }
      }
    });

    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Setup & Login"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 100, // Adjust size as needed
              child: Image.asset(
                'assets/images/first-aid-kit_transparent.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Welcome to CFP",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              "Select Role to Sign In",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            
            const SizedBox(height: 40),
            const Text("I am the...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // --- 2. ROLE CARDS (SELECTABLE) ---
            Row(
              children: [
                Expanded(
                  child: _buildRoleCard(
                    label: "Caregiver",
                    icon: Icons.family_restroom,
                    color: const Color(0xFFFFA34F),
                    role: UserRole.caregiver,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildRoleCard(
                    label: "Patient",
                    icon: Icons.elderly,
                    color: const Color(0xFF5AB9A8),
                    role: UserRole.patient,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),



            // --- 3. SIGN IN BUTTON ---
            ElevatedButton.icon(
              onPressed: isLoading ? null : _handleGoogleSignIn,
              icon: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.login),
              label: Text(isLoading ? "Signing up..." : "Sign Up with Google"),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({required String label, required IconData icon, required Color color, required UserRole role}) {
    final isSelected = _selectedRole == role;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final hintColor = Theme.of(context).disabledColor;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 160,
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(51) : surfaceColor, // Background
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : hintColor, // Border color
            width: isSelected ? 3 : 1
          ),
          boxShadow: isSelected 
              ? [BoxShadow(color: color.withAlpha(77), blurRadius: 10, offset: const Offset(0, 4))] 
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: surfaceColor,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: (isSelected ? color : hintColor).withAlpha(77), blurRadius: 10)],
              ),
              child: Icon(icon, size: 30, color: isSelected ? color : hintColor),
            ),
            const SizedBox(height: 15),
            Text(
              label,
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold, 
                color: isSelected ? color : hintColor
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 5),
              const Icon(Icons.check_circle, size: 20, color: Colors.green), // Checkmark
            ]
          ],
        ),
      ),
    );
  }
}