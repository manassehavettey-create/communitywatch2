import 'package:flutter/material.dart';
import 'dart:ui';
import '../../admin/screens/admin_dashboard.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/three_d_grid_background.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> with TickerProviderStateMixin {
  final _adminIdController = TextEditingController();
  final _securityKeyController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _adminIdController.dispose();
    _securityKeyController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final id = _adminIdController.text.trim();
    final key = _securityKeyController.text.trim();

    if (id.isEmpty || key.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // 10/10 SECURITY: Admin now logs in via central link to get Master Token
      final result = await AuthService.instance.secureLogin(id, key);

      if (result['success'] && AuthService.instance.isAdmin) {
        _proceedToDashboard();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']?.toString() ?? 'MASTER_CREDENTIALS_REQUIRED'),
              backgroundColor: Colors.redAccent,
            )
          );
        }
      }
    } catch (e) {
      debugPrint("Admin Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _proceedToDashboard() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, anim1, anim2) => const AdminDashboard(),
        transitionsBuilder: (context, anim1, anim2, child) => FadeTransition(opacity: anim1, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          const ThreeDGridBackground(),
          
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white24, size: 20),
                    ),
                    const SizedBox(height: 40),
                    
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A5CFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF0A5CFF).withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.05), blurRadius: 40)]
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0A5CFF), size: 48),
                    ),
                    
                    const SizedBox(height: 40),
                    const Text('COMMAND_ENTRY', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const Text('Initialize restricted administrative terminal.', style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold)),
                    
                    const SizedBox(height: 60),
                    _buildTacticalField(_adminIdController, 'ADMIN_IDENTIFIER', Icons.badge_rounded),
                    const SizedBox(height: 20),
                    _buildTacticalField(_securityKeyController, 'SECURITY_KEY', Icons.lock_open_rounded, obscure: true),
                    
                    const SizedBox(height: 60),
                    Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A5CFF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text('AUTHENTICATE_LEVEL_04'),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    const Center(
                      child: Text(
                        'WARNING: UNAUTHORIZED ACCESS ATTEMPTS ARE LOGGED AND TRACED BY SATELLITE NETWORK.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white10, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTacticalField(TextEditingController controller, String label, IconData icon, {bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1),
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF0A5CFF), size: 18),
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        ),
      ),
    );
  }
}
