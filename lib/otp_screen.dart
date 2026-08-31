import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'features/auth/screens/location_permission_screen.dart';
import 'core/widgets/three_d_grid_background.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  
  // Intelligence: Auto-detect correct backend address based on platform
  String get _baseUrl {
    // If you are using a real phone (not emulator), replace 'localhost' 
    // with your computer's IP address (e.g., 'http://192.168.1.5:3000/api')
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) {
        // 10.0.2.2 is the special IP to reach your computer from an Android EMULATOR
        return 'http://10.0.2.2:3000/api';
      }
    } catch (_) {}
    return 'http://localhost:3000/api';
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
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();
    
    // ENSURE OTP IS TRIGGERED ON LOAD
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resendOtp();
    });
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
      final response = await http.post(
        Uri.parse('$_baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'code': code}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (mounted) {
          _showMessage('VERIFICATION_SUCCESS: NODE_ACTIVATED');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LocationPermissionScreen()),
          );
        }
      } else {
        _showMessage('ERROR ${response.statusCode}: ${data['message'] ?? 'INVALID_SECURITY_TOKEN'}');
      }
    } catch (e) {
      _showMessage('COMM_ERROR: SERVER_UNREACHABLE ($e)');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      ).timeout(const Duration(seconds: 10));
      
      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        _showMessage('NEW_TOKEN_TRANSMITTED to ${widget.email}');
      } else {
        _showMessage('SERVER_REJECTED [${response.statusCode}]: ${data['message'] ?? 'UNKNOWN_ERR'}');
      }
    } catch (e) {
      _showMessage('RESEND_FAILED: CHECK_CONNECTION ($e)');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        backgroundColor: message.contains('SUCCESS') ? const Color(0xFF34C759) : Colors.redAccent,
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
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white38, size: 20),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'VERIFY_IDENTITY',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3.0),
                    ),
                    Text(
                      'TOKEN_SENT_TO: ${widget.email.toUpperCase()}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF0A5CFF), fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 60),
                    
                    const Text(
                      'ENTER_6_DIGIT_TOKEN',
                      style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
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
                          BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A5CFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('VERIFY_PROTOCOL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    Center(
                      child: TextButton(
                        onPressed: _isLoading ? null : _resendOtp,
                        child: const Text('RESEND_SECURITY_TOKEN', style: TextStyle(color: Color(0xFFFB923C), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Opacity(
                        opacity: 0.1,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LocationPermissionScreen()),
                            );
                          },
                          child: const Text('BYPASS_FOR_TESTING_ONLY', style: TextStyle(color: Colors.white, fontSize: 8)),
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
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 12.0),
            decoration: InputDecoration(
              hintText: hint,
              counterText: "",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.05), fontSize: 32, letterSpacing: 12.0),
              prefixIcon: Icon(icon, color: const Color(0xFF0A5CFF), size: 24),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ),
      ),
    );
  }
}
