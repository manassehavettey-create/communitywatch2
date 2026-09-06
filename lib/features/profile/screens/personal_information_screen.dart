import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/services/database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../otp_screen.dart';

class PersonalInformationScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const PersonalInformationScreen({super.key, required this.userData});

  @override
  State<PersonalInformationScreen> createState() => _PersonalInformationScreenState();
}

class _PersonalInformationScreenState extends State<PersonalInformationScreen> {
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _emergencyController;
  String? _selectedRegion;
  String? _selectedBloodGroup;

  final List<String> _regions = [
    'Greater Accra', 'Ashanti', 'Central', 'Eastern', 'Western', 'Northern',
    'Upper East', 'Upper West', 'Volta', 'Bono', 'Bono East', 'Ahafo',
    'Savannah', 'North East', 'Oti', 'Western North'
  ];

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.userData['username']);
    _phoneController = TextEditingController(text: widget.userData['phone']);
    _emergencyController = TextEditingController(text: widget.userData['emergency_contact']);
    _selectedRegion = widget.userData['region'];
    _selectedBloodGroup = widget.userData['blood_group'];
  }

  Future<void> _startUpdateProtocol() async {
    // 1. Trigger OTP
    try {
      String baseUrl = 'http://172.20.10.3:3000/api';
      if (kIsWeb) baseUrl = 'http://localhost:3000/api';
      
      await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.userData['email']}),
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              email: widget.userData['email'],
              onSuccess: () => _finalizeUpdate(),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP_LINK_FAILURE')));
    }
  }

  Future<void> _finalizeUpdate() async {
    final updatedUser = {
      ...widget.userData,
      'username': _usernameController.text,
      'phone': _phoneController.text,
      'emergency_contact': _emergencyController.text,
      'region': _selectedRegion,
      'blood_group': _selectedBloodGroup,
    };

    await DatabaseService.instance.updateUser(updatedUser);
    
    if (mounted) {
      // Return to Profile (Pop OTP and this screen)
      Navigator.pop(context); // Pop OTP
      Navigator.pop(context, true); // Pop this screen with refresh signal
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DOSSIER_UPDATED_SUCCESSFULLY'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('IDENTITY_DOSSIER_EDIT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PRIMARY_IDENTIFIERS', style: TextStyle(color: Color(0xFF0A5CFF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 20),
            _buildField(_usernameController, 'FULL_NAME', Icons.person),
            const SizedBox(height: 16),
            _buildReadOnlyField('COMM_PROTOCOL (EMAIL)', widget.userData['email'], Icons.alternate_email),
            const SizedBox(height: 16),
            _buildField(_phoneController, 'SIGNAL_LINE', Icons.phone_android),
            const SizedBox(height: 32),
            
            const Text('SECTOR_ASSIGNMENT', style: TextStyle(color: Color(0xFF0A5CFF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 16),
            _buildDropdown('DEPLOY_REGION', _selectedRegion, _regions, (v) => setState(() => _selectedRegion = v)),
            const SizedBox(height: 32),

            const Text('BIOMETRIC_DATA', style: TextStyle(color: Color(0xFF0A5CFF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 16),
            _buildDropdown('BLOOD_GROUP', _selectedBloodGroup, ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], (v) => setState(() => _selectedBloodGroup = v)),
            const SizedBox(height: 16),
            _buildField(_emergencyController, 'EMERGENCY_LINK', Icons.contact_emergency),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startUpdateProtocol,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A5CFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('AUTHORIZE_CHANGES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white24, fontSize: 10),
        prefixIcon: Icon(icon, color: const Color(0xFF0A5CFF), size: 18),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white10, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white10, fontSize: 8)),
              Text(value, style: const TextStyle(color: Colors.white38, fontSize: 14)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.lock_rounded, color: Colors.white10, size: 14),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF1E293B),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white24, fontSize: 10),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: onChanged,
    );
  }
}
