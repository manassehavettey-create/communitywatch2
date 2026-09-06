import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../../../core/services/database_service.dart';

class TacticalDispatchCenter extends StatefulWidget {
  const TacticalDispatchCenter({super.key});

  @override
  State<TacticalDispatchCenter> createState() => _TacticalDispatchCenterState();
}

class _TacticalDispatchCenterState extends State<TacticalDispatchCenter> {
  List<Map<String, dynamic>> _emergencies = [];
  bool _isLoading = true;

  final Map<String, Map<String, dynamic>> _agencyMap = {
    'Theft': {
      'agency': 'GHANA POLICE SERVICE',
      'number': '191',
      'icon': Icons.local_police_rounded,
      'color': const Color(0xFF0A5CFF)
    },
    'Violence': {
      'agency': 'GHANA POLICE SERVICE',
      'number': '191',
      'icon': Icons.local_police_rounded,
      'color': const Color(0xFF0A5CFF)
    },
    'Fire': {
      'agency': 'GHANA FIRE SERVICE',
      'number': '192',
      'icon': Icons.local_fire_department_rounded,
      'color': Colors.redAccent
    },
    'Medical': {
      'agency': 'AMBULANCE SERVICE',
      'number': '193',
      'icon': Icons.medical_services_rounded,
      'color': Colors.greenAccent
    },
    'Suspicious': {
      'agency': 'INTELLIGENCE UNIT',
      'number': '191',
      'icon': Icons.radar_rounded,
      'color': Colors.orangeAccent
    },
  };

  @override
  void initState() {
    super.initState();
    _loadEmergencies();
  }

  Future<void> _loadEmergencies() async {
    final all = await DatabaseService.instance.readAllIncidents();
    // Filter for high priority or recent emergencies
    if (mounted) {
      setState(() {
        _emergencies = all;
        _isLoading = false;
      });
    }
  }

  Future<void> _initiateDispatch(String agency, String number) async {
    final Uri url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('UNABLE_TO_LINK: $agency')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading 
      ? const Center(child: CircularProgressIndicator(color: Color(0xFF0A5CFF)))
      : RefreshIndicator(
          onRefresh: _loadEmergencies,
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: _emergencies.length,
            itemBuilder: (context, index) {
              final incident = _emergencies[index];
              final type = incident['type'] as String? ?? 'Other';
              final agencyInfo = _agencyMap[type] ?? {
                'agency': 'GENERAL RESPONSE',
                'number': '999',
                'icon': Icons.emergency_rounded,
                'color': Colors.white38
              };

              return _buildDispatchCard(incident, agencyInfo);
            },
          ),
        );
  }

  Widget _buildDispatchCard(Map<String, dynamic> incident, Map<String, dynamic> agency) {
    final Color color = agency['color'];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'GH-SIGNAL: ${incident['type']}'.toUpperCase(),
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                    ),
                    Text(
                      incident['timestamp'].toString().substring(11, 16),
                      style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  incident['description'] ?? 'NO_DATA_PROVIDED',
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 12, color: Colors.white24),
                    const SizedBox(width: 8),
                    Text(
                      incident['location'] ?? 'UNKNOWN_SECTOR',
                      style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Colors.white10, height: 1),
                ),
                Row(
                  children: [
                    Icon(agency['icon'], color: color, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ASSIGNED_AGENCY',
                            style: TextStyle(color: color.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                          Text(
                            agency['agency'],
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _initiateDispatch(agency['agency'], agency['number']),
                      icon: const Icon(Icons.call_rounded, size: 16),
                      label: const Text('DISPATCH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
