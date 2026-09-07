import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'features/auth/screens/location_permission_screen.dart';
import 'core/widgets/three_d_grid_background.dart';
import 'core/services/database_service.dart';
import 'core/services/auth_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String? username;
  final VoidCallback? onSuccess; // Generic callback for reuse

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.username,
    this.onSuccess,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();

  String get _baseUrl {
    return 'https://communitywatch2.onrender.com/api';
  }

  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();

    if (code.length != 6) {
      _showMessage('INVALID_PROTOCOL: 6_DIGITS_REQUIRED');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 10/10 SECURITY: Backend-side token establishment
      final success = await AuthService.instance.verifyOtpAndEstablishLink(
        widget.email,
        code,
      );

      if (success) {
        if (widget.onSuccess != null) {
          widget.onSuccess!();
          return;
        }

        // AUTO-ACTIVATION FLOW
        await DatabaseService.instance.verifyUser(widget.email);

        if (mounted) {
          _showMessage('VERIFICATION_SUCCESS: NODE_ACTIVATED');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LocationPermissionScreen(),
            ),
          );
        }
      } else {
        _showMessage('ERROR: INVALID_SECURITY_TOKEN');
      }
    } catch (e) {
      _showMessage('COMM_ERROR: SERVER_UNREACHABLE');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    try {
      final response = await http
          .post(
            Uri.parse('${AuthService.instance.getBaseUrl()}/send-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': widget.email}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        _showMessage('NEW_TOKEN_TRANSMITTED to ${widget.email}');
      } else {
        String errorMsg = 'SERVER_REJECTED [${response.statusCode}]';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['message'] ?? errorMsg;
        } catch (_) {
          // If body is not JSON, it might be an HTML error page
          errorMsg = "COMM_ERROR: SERVER_RECOVERY_FAILED";
        }
        _showMessage('OTP_DELIVERY_FAILED: $errorMsg');
      }
    } catch (e) {
      _showMessage('RESEND_FAILED: SERVER_WAKE_OR_CONNECTION_TIMEOUT');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: message.contains('SUCCESS')
            ? const Color(0xFF34C759)
            : Colors.redAccent,
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
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    const Text(
                      'VERIFY_IDENTITY',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 3.0,
                      ),
                    ),
                    Text(
                      'TOKEN_SENT_TO: ${widget.email.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF0A5CFF),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 60),

                    const Text(
                      'ENTER_6_DIGIT_TOKEN',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildGlassField(
                      controller: _otpController,
                      hint: '000000',
                      icon: Icons.vpn_key_rounded,
                    ),

                    const SizedBox(height: 48),

                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0A5CFF).withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A5CFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          shadowColor: const Color(0xFF0A5CFF).withOpacity(0.3),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'VERIFY_PROTOCOL',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : _resendOtp,
                        child: const Text(
                          'RESEND_SECURITY_TOKEN',
                          style: TextStyle(
                            color: Color(0xFFFB923C),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
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

  Widget _buildGlassField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
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
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 12.0,
            ),
            decoration: InputDecoration(
              hintText: hint,
              counterText: "",
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.05),
                fontSize: 32,
                letterSpacing: 12.0,
              ),
              prefixIcon: Icon(icon, color: const Color(0xFF0A5CFF), size: 24),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
