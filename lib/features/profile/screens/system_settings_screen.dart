import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';

class SystemSettingsScreen extends StatefulWidget {
  const SystemSettingsScreen({super.key});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  bool _intelAlerts = true;
  bool _locationPrivacy = false;
  bool _biometricUnlock = true;
  String _themeMode = 'Tactical Dark';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('SYSTEM_CONFIG'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeader('ALERT_PROTOCOLS'),
          _buildSwitchTile(
            'INTEL_PUSH_NOTIFICATIONS', 
            'Receive real-time security signals from nearby sectors.', 
            _intelAlerts, 
            (v) => setState(() => _intelAlerts = v),
            Icons.sensors_rounded,
          ),
          const SizedBox(height: 24),

          _buildHeader('PRIVACY_FIREWALL'),
          _buildSwitchTile(
            'ANONYMOUS_REPORTING', 
            'Mask your Unit ID when transmitting intelligence signals.', 
            _locationPrivacy, 
            (v) => setState(() => _locationPrivacy = v),
            Icons.vpn_lock_rounded,
          ),
          const SizedBox(height: 24),

          _buildHeader('SECURITY_ACCESS'),
          _buildSwitchTile(
            'BIOMETRIC_LOCK', 
            'Require facial axis verification to open terminal.', 
            _biometricUnlock, 
            (v) => setState(() => _biometricUnlock = v),
            Icons.face_retouching_natural_rounded,
          ),
          const SizedBox(height: 24),

          _buildHeader('INTERFACE_SYNC'),
          _buildSelectionTile('TERMINAL_THEME', _themeMode, Icons.palette_rounded),
          
          const SizedBox(height: 60),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('SYSTEM_PARAMETERS_SAVED'), backgroundColor: Colors.green),
              );
              Navigator.pop(context);
            },
            child: const Text('SAVE_CONFIGURATION'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title, 
        style: const TextStyle(color: Color(0xFF0A5CFF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0A5CFF), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value, 
            onChanged: onChanged,
            activeColor: const Color(0xFF0A5CFF),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0A5CFF), size: 24),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
          Text(value, style: const TextStyle(color: Color(0xFF0A5CFF), fontSize: 12, fontWeight: FontWeight.bold)),
          const Icon(Icons.chevron_right, color: Colors.white10),
        ],
      ),
    );
  }
}
