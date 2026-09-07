import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'signup_screen.dart';
import 'admin_login_screen.dart';
import 'forgot_password_screen.dart';
import '../../../otp_screen.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/three_d_grid_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnack('IDENTIFIER_OR_TOKEN_MISSING', Colors.redAccent);
      return;
    }

    setState(() => _isAuthenticating = true);

    try {
      // 10/10 SECURITY: Backend-side Hashed Verification
      final result = await AuthService.instance.secureLogin(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (result['success']) {
        // Trigger OTP (Backend will handle rate limiting)
        _triggerOtp(_emailController.text.trim());

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, anim1, anim2) => OtpVerificationScreen(
                email: _emailController.text.trim(),
                username: AuthService.instance.currentUserName,
              ),
              transitionsBuilder: (context, anim1, anim2, child) =>
                  FadeTransition(opacity: anim1, child: child),
            ),
          );
        }
      } else {
        _showSnack(result['message'], Colors.redAccent);
      }
    } catch (e) {
      _showSnack('COMM_LINK_ERROR', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  void _triggerOtp(String email) async {
    try {
      String baseUrl = 'https://communitywatch2.onrender.com/api';
      final response = await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode != 200) {
        final data = jsonDecode(response.body);
        _showSnack(data['message'] ?? 'OTP_TRANSMISSION_FAILED', Colors.orange);
      }
    } catch (_) {}
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

          // GLOATING LIGHT EFFECT
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0A5CFF).withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A5CFF).withOpacity(0.1),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    children: [
                      // TACTICAL LOGO
                      _buildLogo(),
                      const SizedBox(height: 60),

                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'TERMINAL_ACCESS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Provide credentials to establish encrypted link.',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 48),

                      _buildTacticalField(
                        controller: _emailController,
                        hint: 'IDENTIFIER_ID',
                        icon: Icons.qr_code_scanner_rounded,
                      ),
                      const SizedBox(height: 20),
                      _buildTacticalField(
                        controller: _passwordController,
                        hint: 'SECURITY_KEY',
                        icon: Icons.security_rounded,
                        isPassword: true,
                        obscureText: !_isPasswordVisible,
                        toggleVisibility: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen(),
                            ),
                          ),
                          child: const Text(
                            'FORGOT_SECURITY_KEY?',
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      _buildLoginButton(),

                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "NO_ACCOUNT?",
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupScreen(),
                              ),
                            ),
                            child: const Text(
                              'ENROLL_NODE',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFB923C),
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 60),
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AdminLoginScreen(),
                          ),
                        ),
                        icon: const Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 16,
                          color: Colors.white12,
                        ),
                        label: const Text(
                          'RESTRICTED_ADMIN_ENTRY',
                          style: TextStyle(
                            color: Colors.white12,
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
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

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF0A5CFF).withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF0A5CFF).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A5CFF).withOpacity(0.05),
            blurRadius: 40,
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // PRIMARY TACTICAL FALLBACK
            const Icon(
              Icons.shield_rounded,
              size: 70,
              color: Color(0xFF0A5CFF),
            ),
            // ATTEMPT TO OVERLAY ASSET
            Image.asset(
              'assets/images/app_icon.png',
              width: 80,
              height: 80,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTacticalField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? toggleVisibility,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white24,
                    size: 18,
                  ),
                  onPressed: toggleVisibility,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A5CFF).withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isAuthenticating ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          shadowColor: const Color(0xFF0A5CFF).withOpacity(0.3),
        ),
        child: _isAuthenticating
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              )
            : const Text('ESTABLISH_LINK'),
      ),
    );
  }
}
