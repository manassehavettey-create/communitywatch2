import 'package:flutter/material.dart';
import '../../admin/screens/admin_dashboard.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _adminIdController = TextEditingController();
  final _securityKeyController = TextEditingController();

  void _login() {
    if (_adminIdController.text == 'ADMIN' && _securityKeyController.text == 'Admin@123') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboard()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('INVALID_ADMIN_CREDENTIALS'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A5CFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0A5CFF).withOpacity(0.3)),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0A5CFF), size: 48),
            ),
            const SizedBox(height: 32),
            const Text('COMMAND_ACCESS', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 8),
            const Text('Initialize secure admin terminal session.', style: TextStyle(color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 48),
            TextField(
              controller: _adminIdController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'ADMIN_ID',
                hintStyle: const TextStyle(color: Colors.white10),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _securityKeyController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'SECURITY_KEY',
                hintStyle: const TextStyle(color: Colors.white10),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A5CFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  shadowColor: const Color(0xFF0A5CFF).withOpacity(0.5),
                  elevation: 10,
                ),
                child: const Text('AUTHENTICATE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
