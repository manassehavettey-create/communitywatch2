import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/map_intelligence_service.dart';
import '../../../core/services/auth_service.dart';

class TacticalGhanaMap extends StatefulWidget {
  const TacticalGhanaMap({super.key});

  @override
  State<TacticalGhanaMap> createState() => _TacticalGhanaMapState();
}

class _TacticalGhanaMapState extends State<TacticalGhanaMap> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  List<LatLng> _currentRoute = [];
  bool _isLoading = true;
  final MapController _mapController = MapController();
  
  bool _showTraffic = false;
  bool _isSatellite = false;

  @override
  void initState() {
    super.initState();
    _loadCitizenLocations();
  }

  Future<void> _loadCitizenLocations() async {
    final data = await DatabaseService.instance.readAllUsers();
    if (mounted) {
      setState(() {
        _users = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAndShowRoute(double destLat, double destLng) async {
    const start = LatLng(5.6037, -0.1870);
    final end = LatLng(destLat, destLng);
    
    final route = await MapIntelligenceService.instance.getRoute(start, end);
    setState(() {
      _currentRoute = route;
    });

    _mapController.move(end, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF020617),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(5.6037, -0.1870),
              initialZoom: 13.0,
              maxZoom: 18.0,
              minZoom: 5.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite 
                    ? 'https://{s}.google.com/vt/lyrs=s,h&x={x}&y={y}&z={z}'
                    : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: _isSatellite ? const ['mt0', 'mt1', 'mt2', 'mt3'] : const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.communitywatch',
              ),
              
              if (_currentRoute.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _currentRoute,
                      color: const Color(0xFF0A5CFF).withOpacity(0.8),
                      strokeWidth: 4.0,
                      isDotted: true,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: _users.map((user) {
                  double lat = user['lat'] as double? ?? 5.6037;
                  double lng = user['lng'] as double? ?? -0.1870;
                  return Marker(
                    point: LatLng(lat, lng),
                    width: 120,
                    height: 120,
                    child: GestureDetector(
                      onTap: () => _fetchAndShowRoute(lat, lng),
                      child: _CyberHologramMarker(
                        label: user['username'] as String? ?? "CITIZEN",
                        isAlert: user['is_frozen'] == 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          const Positioned.fill(child: _WildProHUD()),
          
          Positioned(
            right: 20,
            bottom: 140,
            child: Column(
              children: [
                _buildMapButton(
                  icon: _isSatellite ? Icons.map_rounded : Icons.satellite_rounded, 
                  onTap: () => setState(() => _isSatellite = !_isSatellite),
                  label: 'TYPE',
                ),
                const SizedBox(height: 12),
                _buildMapButton(
                  icon: Icons.traffic_rounded, 
                  onTap: () => setState(() => _showTraffic = !_showTraffic),
                  color: _showTraffic ? const Color(0xFF0A5CFF) : Colors.white,
                  label: 'TRAFFIC',
                ),
                const SizedBox(height: 12),
                _buildMapButton(icon: Icons.add, onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1), label: 'ZOOM'),
                const SizedBox(height: 12),
                _buildMapButton(icon: Icons.remove, onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1), label: 'OUT'),
                const SizedBox(height: 12),
                _buildMapButton(icon: Icons.center_focus_strong, onTap: () => _mapController.move(const LatLng(5.6037, -0.1870), 13.0), label: 'CENTER'),
              ],
            ),
          ),

          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: _buildBottomHUD(),
          ),

          const ScanningLine(),
        ],
      ),
    );
  }

  Widget _buildMapButton({required IconData icon, required VoidCallback onTap, Color color = Colors.white, required String label}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBottomHUD() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF0A5CFF).withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.security_rounded, color: Color(0xFF0A5CFF), size: 24),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('TACTICAL INTEL OVERLAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2)),
                  Text('Live structural mapping active in Ghana', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A5CFF))),
            ],
          ),
        ),
      ),
    );
  }
}

class _CyberHologramMarker extends StatefulWidget {
  final String label;
  final bool isAlert;
  const _CyberHologramMarker({required this.label, required this.isAlert});

  @override
  State<_CyberHologramMarker> createState() => _CyberHologramMarkerState();
}

class _CyberHologramMarkerState extends State<_CyberHologramMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    Color color = widget.isAlert ? Colors.orangeAccent : const Color(0xFF0A5CFF);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                ...List.generate(2, (i) {
                  double p = (_controller.value + (i / 2)) % 1.0;
                  return Opacity(
                    opacity: 1 - p,
                    child: Container(
                      width: 40 + (40 * p),
                      height: 20 + (20 * p),
                      decoration: BoxDecoration(
                        border: Border.all(color: color, width: 1),
                        borderRadius: const BorderRadius.all(Radius.elliptical(40, 20)),
                      ),
                    ),
                  );
                }),
                Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002)
                    ..rotateX(-0.5)
                    ..rotateY(_controller.value * pi * 2),
                  alignment: Alignment.center,
                  child: Container(
                    width: 25,
                    height: 25,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.8),
                      border: Border.all(color: Colors.white, width: 1),
                      boxShadow: [BoxShadow(color: color, blurRadius: 15)],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
              child: Text(widget.label.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class _WildProHUD extends StatelessWidget {
  const _WildProHUD();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          const _HUDCorner(top: 40, left: 20, angle: 0),
          const _HUDCorner(top: 40, right: 20, angle: 90),
          const _HUDCorner(bottom: 40, left: 20, angle: 270),
          const _HUDCorner(bottom: 40, right: 20, angle: 180),
          Positioned(
            left: 20,
            top: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: ["DATA_STREAM: ACTIVE", "OSM_LAYER: LOADED", "ORS_API: CONNECTED"].map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(t, style: const TextStyle(color: Color(0xFF0A5CFF), fontSize: 8, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HUDCorner extends StatelessWidget {
  final double? top, bottom, left, right;
  final double angle;
  const _HUDCorner({this.top, this.bottom, this.left, this.right, required this.angle});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Transform.rotate(
        angle: angle * pi / 180,
        child: Container(
          width: 30, height: 30,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF0A5CFF), width: 2), left: BorderSide(color: Color(0xFF0A5CFF), width: 2)),
          ),
        ),
      ),
    );
  }
}

class ScanningLine extends StatefulWidget {
  const ScanningLine({super.key});
  @override
  State<ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<ScanningLine> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).size.height * _controller.value,
          left: 0, right: 0,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              boxShadow: [BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.5), blurRadius: 10)],
              gradient: LinearGradient(colors: [Colors.transparent, const Color(0xFF0A5CFF).withOpacity(0.8), Colors.transparent]),
            ),
          ),
        );
      },
    );
  }
}
