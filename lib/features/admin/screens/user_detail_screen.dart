import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/utils/image_helper.dart';
import '../../../core/services/auth_service.dart';

class UserDetailScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const UserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('CITIZEN_DOSSIER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Tactical Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.network(
                'https://img.freepik.com/free-vector/cyber-security-background-design_23-2148540702.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                
                const Text('BIOMETRIC_PROFILE', style: TextStyle(color: Color(0xFF0A5CFF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                const SizedBox(height: 16),
                _buildBiometricSection(),
                
                const SizedBox(height: 32),
                const Text('IDENTIFICATION_DATA', style: TextStyle(color: Color(0xFF0A5CFF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                const SizedBox(height: 16),
                _buildDataGrid(),
                
                const SizedBox(height: 32),
                const Text('SYSTEM_SECURITY_STATUS', style: TextStyle(color: Color(0xFF0A5CFF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                const SizedBox(height: 16),
                _buildSecurityStatus(),
                
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF0A5CFF).withOpacity(0.3), width: 2),
            boxShadow: [BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.1), blurRadius: 20)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: ImageHelper.buildFileImage(
              user['face_image'],
              placeholder: const Icon(Icons.person, size: 40, color: Colors.white24),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (user['username'] as String? ?? "UNKNOWN_UNIT").toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              Text(
                'SERIAL_ID: CW-${user['id']}',
                style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (user['is_verified'] == 1) ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (user['is_verified'] == 1) ? 'STATUS: VERIFIED' : 'STATUS: UNVERIFIED',
                  style: TextStyle(
                    color: (user['is_verified'] == 1) ? Colors.blue : Colors.red,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBiometricSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBiometricDirection(Icons.arrow_upward_rounded, 'UP', true),
              _buildBiometricDirection(Icons.center_focus_strong_rounded, 'CENTER', true),
              _buildBiometricDirection(Icons.arrow_back_rounded, 'LEFT', true),
              _buildBiometricDirection(Icons.arrow_forward_rounded, 'RIGHT', true),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.fingerprint_rounded, color: Color(0xFF0A5CFF), size: 16),
              SizedBox(width: 12),
              Text('FACIAL_AXIS_ENCRYPTION_ACTIVE', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricDirection(IconData icon, String label, bool active) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0A5CFF).withOpacity(0.1) : Colors.white10,
            shape: BoxShape.circle,
            border: Border.all(color: active ? const Color(0xFF0A5CFF).withOpacity(0.3) : Colors.transparent),
          ),
          child: Icon(icon, color: active ? const Color(0xFF0A5CFF) : Colors.white24, size: 20),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: active ? Colors.white70 : Colors.white10, fontSize: 8, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDataGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildInfoCard('EMAIL_PROTOCOL', user['email'] ?? 'N/A', Icons.alternate_email_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoCard('SIGNAL_LINE', user['phone'] ?? 'N/A', Icons.phone_android_rounded)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildInfoCard('DEPLOY_REGION', user['region'] ?? 'N/A', Icons.map_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoCard('ID_CLASS', user['id_type'] ?? 'N/A', Icons.badge_rounded)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildInfoCard('BLOOD_GROUP', user['blood_group'] ?? 'NOT_SET', Icons.bloodtype_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoCard('EMERGENCY_LINK', user['emergency_contact'] ?? 'NONE', Icons.contact_emergency_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0A5CFF), size: 16),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildSecurityStatus() {
    final reputation = user['reputation_score'] as int? ?? 100;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A5CFF).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0A5CFF).withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TRUST_REPUTATION', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              Text('$reputation PTS', style: const TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: reputation / 100,
              backgroundColor: Colors.white10,
              color: const Color(0xFF34C759),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 20),
          _buildStatusRow('ACCOUNT_ENCRYPTION', 'AES-256-ACTIVE', Colors.blue),
          _buildStatusRow('FROZEN_PROTOCOL', user['is_frozen'] == 1 ? 'LOCKED' : 'ACTIVE', user['is_frozen'] == 1 ? Colors.orange : Colors.green),
          _buildStatusRow('GEO_SYNC', 'ACTIVE_REAL_TIME', Colors.blue),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
