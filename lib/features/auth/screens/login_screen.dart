import 'package:flutter/material.dart';
import 'dart:ui';
import 'signup_screen.dart';
import 'location_permission_screen.dart';
import 'admin_login_screen.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/widgets/three_d_grid_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          const ThreeDGridBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LOGO & HEADER
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A5CFF).withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0A5CFF).withOpacity(0.2)),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.1), blurRadius: 40, spreadRadius: 10),
                                ],
                              ),
                              child: const Icon(Icons.shield_rounded, size: 60, color: Color(0xFF0A5CFF)),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'COMMUNITY WATCH',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 4.0),
                            ),
                            const Text(
                              'SECURE_TERMINAL_V5.0',
                              style: TextStyle(fontSize: 10, color: Color(0xFF0A5CFF), fontWeight: FontWeight.bold, letterSpacing: 2.0),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 60),
                      
                      const Text(
                        'ACCESS_CREDENTIALS',
                        style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 16),
                      
                      // EMAIL FIELD
                      _buildGlassField(
                        controller: _emailController,
                        hint: 'IDENTIFIER (EMAIL)',
                        icon: Icons.alternate_email_rounded,
                      ),
                      const SizedBox(height: 20),
                      
                      // PASSWORD FIELD
                      _buildGlassField(
                        controller: _passwordController,
                        hint: 'SECURITY_TOKEN',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        obscureText: !_isPasswordVisible,
                        toggleVisibility: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                      ),
                      
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text('FORGOT_KEY?', style: TextStyle(color: Color(0xFF0A5CFF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // LOGIN BUTTON
                      Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A5CFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('AUTHENTICATE', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // SIGNUP LINK
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("NO_ACCOUNT_DETECTED?", style: TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen()));
                            },
                            child: const Text('INITIALIZE_SIGNUP', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFFB923C), fontSize: 11)),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // ADMIN ACCESS
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminLoginScreen()));
                          },
                          icon: const Icon(Icons.admin_panel_settings_outlined, size: 14, color: Colors.white10),
                          label: const Text('RESTRICTED_ADMIN_ENTRY', style: TextStyle(color: Colors.white10, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? toggleVisibility,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 12, letterSpacing: 1.5),
              prefixIcon: Icon(icon, color: const Color(0xFF0A5CFF), size: 20),
              suffixIcon: isPassword ? IconButton(
                icon: Icon(obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white12, size: 20),
                onPressed: toggleVisibility,
              ) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('IDENTIFIER_OR_TOKEN_MISSING'), backgroundColor: Colors.redAccent));
      return;
    }

    final user = await DatabaseService.instance.getUserByEmail(_emailController.text);

    if (user != null) {
      if (user['is_frozen'] == 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ACCESS_DENIED: NODE_FROZEN'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      await DatabaseService.instance.createAdminLog({
        'admin_id': 'SYS',
        'action': 'User Login',
        'timestamp': DateTime.now().toIso8601String().substring(11, 16),
        'details': 'User ${user['username']} authenticated.'
      });

      AuthService.instance.loginUser(user['username'] as String, user['email'] as String);
      
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LocationPermissionScreen()));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('INVALID_NODE_ID'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}
