import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/three_d_grid_background.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String identifier;
  const ResetPasswordScreen({super.key, required this.identifier});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  Future<void> _reset() async {
    if (_passController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KEY_MISMATCH: Passwords do not match.')));
      return;
    }

    setState(() => _isLoading = true);
    
    final result = await AuthService.instance.resetPassword(widget.identifier, _passController.text);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['status'] == 'SUCCESS') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ PASSWORD_SYNCHRONIZED'), backgroundColor: Colors.green));
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'RESET_FAILURE')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          const ThreeDGridBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  const Text('SYNC_NEW_KEY', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const Text('Establish a new encrypted access key for your terminal.', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 60),
                  
                  _buildField(_passController, 'NEW_SECURITY_KEY', true),
                  const SizedBox(height: 16),
                  _buildField(_confirmController, 'CONFIRM_SECURITY_KEY', true),
                  
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _reset,
                      child: const Text('OVERWRITE_ACCESS_PROTOCOL'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String hint, bool obscure) {
    return Container(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(hintText: hint, contentPadding: const EdgeInsets.all(20), prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF0A5CFF))),
      ),
    );
  }
}
