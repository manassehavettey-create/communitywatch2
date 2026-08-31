import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/services/database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/map_intelligence_service.dart';
import 'package:latlong2/latlong.dart' as ll;

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _currentStep = 0;
  String? _selectedType;
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<Map<String, dynamic>> _incidentTypes = [
    {'icon': Icons.security, 'label': 'Theft', 'color': const Color(0xFFFF3B30)},
    {'icon': Icons.warning_amber_rounded, 'label': 'Suspicious', 'color': const Color(0xFFFB923C)},
    {'icon': Icons.gavel_rounded, 'label': 'Violence', 'color': Colors.purpleAccent},
    {'icon': Icons.car_repair_rounded, 'label': 'Traffic', 'color': const Color(0xFF0A5CFF)},
    {'icon': Icons.visibility_rounded, 'label': 'Harassment', 'color': Colors.pinkAccent},
    {'icon': Icons.help_outline_rounded, 'label': 'Other', 'color': Colors.white38},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('TRANSMIT SIGNAL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3.0)),
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.8),
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: SlideTransition(
                    position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(animation),
                    child: child,
                  ));
                },
                child: _currentStep == 0 ? _buildStepOne() : _buildStepTwo(),
              ),
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      color: const Color(0xFF0F172A).withOpacity(0.5),
      child: Row(
        children: [
          _progressDot(0, 'INCIDENT'),
          _progressLine(0),
          _progressDot(1, 'DETAILS'),
        ],
      ),
    );
  }

  Widget _progressDot(int step, String label) {
    bool isActive = _currentStep >= step;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF0A5CFF) : Colors.white10,
            shape: BoxShape.circle,
            boxShadow: isActive ? [BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.4), blurRadius: 10, spreadRadius: 2)] : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.white24, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
      ],
    );
  }

  Widget _progressLine(int step) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Container(
          height: 1,
          color: _currentStep > step ? const Color(0xFF0A5CFF).withOpacity(0.5) : Colors.white10,
        ),
      ),
    );
  }

  Widget _buildStepOne() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SIGNAL TYPE', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        const Text('Select the classification for this security transmission.', style: TextStyle(color: Colors.white38, fontSize: 13)),
        const SizedBox(height: 32),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: _incidentTypes.length,
          itemBuilder: (context, index) {
            final type = _incidentTypes[index];
            final isSelected = _selectedType == type['label'];
            return GestureDetector(
              onTap: () => setState(() => _selectedType = type['label']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0A5CFF).withOpacity(0.1) : const Color(0xFF1E293B).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: isSelected ? const Color(0xFF0A5CFF) : Colors.white.withOpacity(0.05), width: 1.5),
                  boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.2), blurRadius: 20)] : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(type['icon'], size: 32, color: isSelected ? const Color(0xFF0A5CFF) : type['color'].withOpacity(0.7)),
                    const SizedBox(height: 12),
                    Text(
                      type['label'].toString().toUpperCase(),
                      style: TextStyle(fontWeight: FontWeight.w900, color: isSelected ? Colors.white : Colors.white54, fontSize: 11, letterSpacing: 1.5),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DATA INJECTION', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        const SizedBox(height: 32),
        _buildInputField(
          label: 'LOCATION_SECTOR',
          hint: 'DETECTING GPS...',
          icon: Icons.location_searching_rounded,
          controller: _locationController,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              setState(() => _locationController.text = "SCANNING...");
              final address = await MapIntelligenceService.instance.getAddressFromLatLng(const ll.LatLng(5.6037, -0.1870));
              setState(() => _locationController.text = address);
            },
            icon: const Icon(Icons.gps_fixed_rounded, size: 14, color: const Color(0xFF0A5CFF)),
            label: const Text('SYNC SECTOR GPS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF0A5CFF), letterSpacing: 1.0)),
          ),
        ),
        const SizedBox(height: 24),
        _buildInputField(
          label: 'SIGNAL_DESCRIPTION',
          hint: 'PROVIDE INTEL DETAILS...',
          icon: Icons.terminal_rounded,
          maxLines: 5,
          controller: _descriptionController,
        ),
        const SizedBox(height: 32),
        const Text('ATTACHMENTS_OPTIONAL', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white38, fontSize: 10, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildMediaButton(Icons.camera_rounded, 'CAMERA_FEED'),
            const SizedBox(width: 16),
            _buildMediaButton(Icons.folder_shared_rounded, 'LOCAL_STORAGE'),
          ],
        ),
      ],
    );
  }

  Widget _buildInputField({required String label, required String hint, required IconData icon, int maxLines = 1, TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFF0A5CFF), letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.white10),
                prefixIcon: Icon(icon, size: 18, color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.03),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF0A5CFF))),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaButton(IconData icon, String label) {
    return Expanded(
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white38, size: 20),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 1.0)),
          ],
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (_selectedType == null || _locationController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('FIELDS_EMPTY: COMPLIANCE REQUIRED'), backgroundColor: Colors.redAccent));
      return;
    }

    final incident = {
      'type': _selectedType,
      'description': _descriptionController.text,
      'location': _locationController.text,
      'timestamp': DateTime.now().toIso8601String(),
      'severity': 'Medium',
      'is_resolved': 0,
      'lat': 5.6037,
      'lng': -0.1870,
      'reporter_name': AuthService.instance.currentUserName,
    };

    await DatabaseService.instance.createIncident(incident);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SIGNAL TRANSMITTED SUCCESSFULLY'), backgroundColor: const Color(0xFF34C759)));
      Navigator.pop(context);
    }
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            IconButton(
              onPressed: () => setState(() => _currentStep--),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54, size: 20),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (_currentStep == 0) {
                    if (_selectedType != null) setState(() => _currentStep++);
                  } else {
                    _submitReport();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A5CFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: Text(
                  _currentStep == 0 ? 'NEXT_PHASE' : 'DEPLOY_SIGNAL',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
