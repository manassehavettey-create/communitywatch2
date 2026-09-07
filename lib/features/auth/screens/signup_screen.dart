import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'face_biometric_screen.dart';
import '../../../otp_screen.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/map_intelligence_service.dart';
import '../../../core/widgets/three_d_grid_background.dart';
import 'package:latlong2/latlong.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final _fNameController = TextEditingController();
  final _mNameController = TextEditingController();
  final _lNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedRegion;
  String? _selectedBlood;

  final List<String> _regions = [
    'Greater Accra',
    'Ashanti',
    'Central',
    'Eastern',
    'Western',
    'Northern',
    'Upper East',
    'Upper West',
    'Volta',
    'Bono',
    'Bono East',
    'Ahafo',
    'Savannah',
    'North East',
    'Oti',
    'Western North',
  ];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _fNameController.dispose();
    _mNameController.dispose();
    _lNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEnrollment() async {
    if (_fNameController.text.isEmpty ||
        _lNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showSnack('REQUISITE_DATA_MISSING', Colors.redAccent);
      return;
    }

    setState(() => _isLocating = true);

    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition().timeout(
          const Duration(seconds: 10),
        );
      } catch (_) {}

      final userData = {
        'username': '${_fNameController.text} ${_lNameController.text}',
        'first_name': _fNameController.text,
        'middle_name': _mNameController.text,
        'last_name': _lNameController.text,
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'phone': _phoneController.text,
        'region': _selectedRegion,
        'blood_group': _selectedBlood,
        'reputation_score': 100,
        'is_verified': 0,
        'joined_date': DateTime.now().toIso8601String().substring(0, 10),
        'lat': position?.latitude ?? 5.6037,
        'lng': position?.longitude ?? -0.1870,
      };

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FaceBiometricScreen(
              userData: userData,
              onComplete: (finalData, captures) =>
                  _finalizeSignup(finalData, captures),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _finalizeSignup(
    Map<String, dynamic> user,
    Map<String, String?> captures,
  ) async {
    // 10/10 SECURITY: Server-side password hashing and Biometric Signal Upload
    final result = await AuthService.instance.secureRegister({
      'username': user['username'],
      'email': user['email'],
      'password': user['password'],
      'firstName': user['first_name'],
      'lastName': user['last_name'],
      'phone': user['phone'],
      'region': user['region'],
    }, captures);

    if (result['success']) {
      // Create local copy for offline support
      await DatabaseService.instance.createUser(user);

      // Trigger OTP
      _triggerOtp(user['email']);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              email: user['email'] as String,
              username: user['username'] as String,
            ),
          ),
        );
      }
    } else {
      _showSnack(result['message'], Colors.redAccent);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'monospace')),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('CITIZEN_ENROLLMENT'),
        backgroundColor: const Color(0xFF0F172A),
      ),
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
                    const Text(
                      'IDENTITY_INITIATION',
                      style: TextStyle(
                        color: Color(0xFF0A5CFF),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 32),

                    _buildField(
                      _fNameController,
                      'FIRST_NAME',
                      Icons.person_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      _mNameController,
                      'MIDDLE_NAME (OPTIONAL)',
                      Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      _lNameController,
                      'LAST_NAME',
                      Icons.person_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      _emailController,
                      'SECURE_EMAIL',
                      Icons.alternate_email_rounded,
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      _phoneController,
                      'SIGNAL_LINE',
                      Icons.phone_android_rounded,
                      type: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      _passwordController,
                      'ENCRYPTION_KEY',
                      Icons.lock_outline_rounded,
                      obscure: true,
                    ),

                    const SizedBox(height: 32),
                    _buildDropdown(
                      'REGION_ASSIGNMENT',
                      _selectedRegion,
                      _regions,
                      (v) => setState(() => _selectedRegion = v),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      'BLOOD_TYPE',
                      _selectedBlood,
                      ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
                      (v) => setState(() => _selectedBlood = v),
                    ),

                    const SizedBox(height: 48),

                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _isLocating ? null : _handleEnrollment,
                        child: _isLocating
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              )
                            : const Text('BEGIN_BIOMETRIC_SYNC'),
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

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    TextInputType? type,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: type,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, size: 18),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            label,
            style: const TextStyle(
              color: Colors.white24,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          dropdownColor: const Color(0xFF0F172A),
          isExpanded: true,
          icon: const Icon(
            Icons.arrow_drop_down_rounded,
            color: Color(0xFF0A5CFF),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
