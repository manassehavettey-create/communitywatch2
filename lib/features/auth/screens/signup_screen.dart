import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'location_permission_screen.dart';
import '../../../otp_screen.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/three_d_grid_background.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _agreedToTerms = false;
  bool _isLocating = false;
  
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('REQUISITE_DATA_MISSING'), backgroundColor: Colors.redAccent));
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('COMPLIANCE_REQUIRED: AGREE_TO_TERMS'), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // PRO FEATURE: Find user location during signup - High Precision
      Position? position;
      try {
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
            ),
          ).timeout(const Duration(seconds: 10));
        }
      } catch (e) {
        debugPrint("Location discovery skipped: $e");
      }

      final user = {
        'username': _nameController.text,
        'email': _emailController.text,
        'reputation_score': 100,
        'is_verified': 0,
        'joined_date': 'Oct 2023',
        'is_frozen': 0,
        'lat': position?.latitude ?? 5.6037,
        'lng': position?.longitude ?? -0.1870,
      };

      await DatabaseService.instance.createUser(user);
      
      // TRIGGER BACKEND TO SEND OTP EMAIL
      try {
        String baseUrl = kIsWeb ? 'http://localhost:3000/api' : (Platform.isAndroid ? 'http://10.0.2.2:3000/api' : 'http://localhost:3000/api');
        await http.post(
          Uri.parse('$baseUrl/send-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': user['email']}),
        );
      } catch (e) {
        debugPrint("Background OTP Trigger Error: $e");
      }
      
      await DatabaseService.instance.createAdminLog({
        'admin_id': 'SYS',
        'action': 'New Registration',
        'timestamp': DateTime.now().toIso8601String().substring(11, 16),
        'details': 'User ${user['username']} joined from GPS: ${user['lat']}, ${user['lng']}'
      });

      AuthService.instance.loginUser(user['username'] as String, user['email'] as String);

      if (mounted) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => OtpVerificationScreen(email: user['email'] as String))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('REGISTRATION_ERROR: $e'), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLocating = false);
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white38, size: 20),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'CREATE_NODE',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3.0),
                    ),
                    const Text(
                      'INITIALIZING_CITIZEN_ONBOARDING',
                      style: TextStyle(fontSize: 10, color: Color(0xFF0A5CFF), fontWeight: FontWeight.bold, letterSpacing: 2.0),
                    ),
                    const SizedBox(height: 48),
                    
                    _buildGlassField(
                      controller: _nameController,
                      hint: 'NODE_IDENTIFIER (FULL NAME)',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildGlassField(
                      controller: _emailController,
                      hint: 'COMM_PROTOCOL (EMAIL)',
                      icon: Icons.alternate_email_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildGlassField(
                      controller: _passwordController,
                      hint: 'ENCRYPTION_KEY (PASSWORD)',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                      obscureText: !_isPasswordVisible,
                      toggleVisibility: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    GestureDetector(
                      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _agreedToTerms ? const Color(0xFF0A5CFF) : Colors.transparent,
                              border: Border.all(color: _agreedToTerms ? const Color(0xFF0A5CFF) : Colors.white24, width: 1.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: _agreedToTerms ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'I ACCEPT ALL SECURITY PROTOCOLS AND DATA TERMS',
                              style: TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                            ),
                          ),
                        ],
                      ),
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
                        onPressed: _isLocating ? null : _handleSignup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A5CFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isLocating 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('INITIALIZE_ENROLLMENT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('BACK_TO_TERMINAL_LOGIN', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
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
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 10, letterSpacing: 1.5),
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
}
