import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/database_service.dart';
import '../../navigation/main_navigation_shell.dart';
import '../../map/screens/map_screen.dart';

class AllReportsView extends StatefulWidget {
  final bool isAdminView;
  const AllReportsView({super.key, this.isAdminView = false});

  @override
  State<AllReportsView> createState() => _AllReportsViewState();
}

class _AllReportsViewState extends State<AllReportsView> {
  List<Map<String, dynamic>> _incidents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // PRO FIX: Immediate fetch for Web to avoid "Infinite Loading"
      final data = await DatabaseService.instance.readAllIncidents();
      
      if (mounted) {
        setState(() {
          _incidents = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _incidents = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0A5CFF)),
            SizedBox(height: 16),
            Text('Decrypting Intel...', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      );
    }

    if (_incidents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security_rounded, size: 48, color: Colors.white.withOpacity(0.05)),
            const SizedBox(height: 16),
            const Text('Sector is currently clear.', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _incidents.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final incident = _incidents[index];
        final severity = incident['severity'] as String? ?? "Medium";
        final Color color = severity == 'High' ? Colors.red : (severity == 'Medium' ? Colors.orange : Colors.green);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: ExpansionTile(
            collapsedIconColor: Colors.white24,
            iconColor: color,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.report_problem_rounded, color: color, size: 20),
            ),
            title: Text(
              'SIGNAL #GH-${incident['id']}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'BY: ${incident['reporter_name'] as String? ?? "ANONYMOUS"} @ ${incident['location'] as String? ?? "GHANA"}',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    Text(
                      incident['description'] as String? ?? "No data provided.",
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('TIMESTAMP: ${incident['timestamp']}', style: const TextStyle(color: Colors.white24, fontSize: 9)),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final lat = incident['lat'] as double? ?? 5.6037;
                            final lng = incident['lng'] as double? ?? -0.1870;
                            
                            // Set target in Map state
                            MapNavigationState.setTarget(LatLng(lat, lng), 'INCIDENT ${incident['id']}');

                            // Navigate to Map in Shell
                            Navigator.pop(context); // Close admin dashboard
                            MainNavigationShell.of(context)?.navigateToMapWithDestination(
                              LatLng(lat, lng),
                              'INCIDENT ${incident['id']}'
                            );
                          },
                          icon: const Icon(Icons.navigation_rounded, size: 12),
                          label: const Text('TACTICAL NAV'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A5CFF).withOpacity(0.1),
                            foregroundColor: const Color(0xFF0A5CFF),
                            elevation: 0,
                            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.1),
                            foregroundColor: Colors.redAccent,
                            elevation: 0,
                            textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          child: const Text('PURGE REPORT'),
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
