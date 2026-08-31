import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:ui';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/map_intelligence_service.dart';

// Unified Navigation State for cross-screen communication
class MapNavigationState {
  static LatLng? targetDestination;
  static String? targetLabel;
  static VoidCallback? onTargetChanged;

  static void setTarget(LatLng destination, String label) {
    targetDestination = destination;
    targetLabel = label;
    if (onTargetChanged != null) onTargetChanged!();
  }

  static void clearTarget() {
    targetDestination = null;
    targetLabel = null;
    if (onTargetChanged != null) onTargetChanged!();
  }
}

class CommunityWatchMap extends StatefulWidget {
  final LatLng? targetDestination;
  final String? targetLabel;
  final bool isAdminMode;

  const CommunityWatchMap({
    super.key, 
    this.targetDestination, 
    this.targetLabel,
    this.isAdminMode = false,
  });

  @override
  State<CommunityWatchMap> createState() => _CommunityWatchMapState();
}

class _CommunityWatchMapState extends State<CommunityWatchMap> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(5.6037, -0.1870); // Default Accra
  List<LatLng> routePolyline = [];
  bool _isFirstLocationSync = true;
  bool isRouting = false;
  bool _autoFollow = true;
  bool isLoading = true; // RE-DEFINED MISSING VARIABLE
  
  // Tiles (KEY-FREE)
  bool isSatellite = false;

  // Travel Mode
  String _travelMode = 'driving-car';

  // Search Functionality
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  // Route Info
  String _routeDistance = "";
  String _routeDuration = "";
  String _currentAddress = "Locating Sector...";

  // Admin Mode: User tracking
  List<Map<String, dynamic>> _allUsers = [];
  Timer? _userRefreshTimer;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    MapNavigationState.onTargetChanged = () {
      if (mounted) _fetchRoute();
    };
    _startLiveTracking();
    _loadAllUsers();
    _userRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _loadAllUsers());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _userRefreshTimer?.cancel();
    _positionStream?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CommunityWatchMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetDestination != oldWidget.targetDestination) {
      _fetchRoute();
    }
  }

  Future<void> _loadAllUsers() async {
    final users = await DatabaseService.instance.readAllUsers();
    if (mounted) {
      setState(() {
        _allUsers = users;
      });
    }
  }

  Future<void> _startLiveTracking() async {
    // Ensure permission is granted before starting
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    // 1. Immediate high-precision check
    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
      ).timeout(const Duration(seconds: 5));
      _updateUserLocation(pos);
    } catch (e) {
      debugPrint("Initial lock delayed: $e");
    }

    // 2. Start continuous stream for perfect real-time movement
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
      ),
    ).listen((Position p) {
      _updateUserLocation(p);
    });
  }

  void _updateUserLocation(Position p) {
    if (!mounted) return;
    final latLng = LatLng(p.latitude, p.longitude);
    
    setState(() {
      _currentLocation = latLng;
      isLoading = false; 
    });

    // Fetch surrounding neighborhood name
    _fetchCurrentAddress(latLng);

    if (_isFirstLocationSync) {
      _mapController.move(latLng, 16.0);
      _isFirstLocationSync = false;
    } else if (_autoFollow) {
      _mapController.move(latLng, _mapController.camera.zoom);
    }

    // Update global presence in DB
    final email = AuthService.instance.currentUserEmail;
    if (email != null) {
      DatabaseService.instance.updateUserLocation(email, p.latitude, p.longitude);
    }
  }

  Future<void> _fetchCurrentAddress(LatLng pos) async {
    final address = await MapIntelligenceService.instance.getAddressFromLatLng(pos);
    if (mounted) {
      setState(() {
        _currentAddress = address;
      });
    }
  }

  Future<void> _fetchRoute() async {
    final destination = widget.targetDestination ?? MapNavigationState.targetDestination;
    if (destination == null) {
      if (mounted) setState(() { routePolyline = []; _routeDistance = ""; _routeDuration = ""; });
      return;
    }

    setState(() => isRouting = true);
    const String apiKey = 'EyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjIzZmQ0MDA0ZWI2YTQzNTQ5N2YzMmU2ZjkwNzYwZDljIiwiaCI6Im11cm11cjY0In0=';
    final Uri url = Uri.parse('https://api.openrouteservice.org/v2/directions/$_travelMode?api_key=$apiKey&start=${_currentLocation.longitude},${_currentLocation.latitude}&end=${destination.longitude},${destination.latitude}');

    try {
      final response = await http.get(url, headers: {'User-Agent': 'CommunityWatch/1.0'});
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final route = data['features'][0];
        final summary = route['properties']['summary'];
        if (mounted) {
          setState(() {
            routePolyline = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1].toDouble(), c[0].toDouble())).toList();
            _routeDistance = "${(summary['distance'] / 1000).toStringAsFixed(1)} km";
            _routeDuration = "${(summary['duration'] / 60).toStringAsFixed(0)} min";
            isRouting = false;
          });
          _fitRoute(destination);
        }
      }
    } catch (e) { if (mounted) setState(() => isRouting = false); }
  }

  void _fitRoute(LatLng destination) {
    if (routePolyline.isEmpty) return;
    final bounds = LatLngBounds.fromPoints([_currentLocation, destination, ...routePolyline]);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)));
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.length > 2) _performSearch(query);
      else setState(() { _searchResults = []; _isSearching = false; });
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query,Ghana&format=json&limit=5');
    try {
      final response = await http.get(url, headers: {'User-Agent': 'CommunityWatch/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) setState(() { _searchResults = data; _isSearching = false; });
      }
    } catch (e) { if (mounted) setState(() => _isSearching = false); }
  }

  void _selectSearchResult(dynamic result) {
    final destination = LatLng(double.parse(result['lat']), double.parse(result['lon']));
    final label = result['display_name'].split(',')[0];
    _searchController.text = label;
    setState(() => _searchResults = []);
    FocusScope.of(context).unfocus();
    MapNavigationState.setTarget(destination, label);
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.targetDestination ?? MapNavigationState.targetDestination;
    final label = widget.targetLabel ?? MapNavigationState.targetLabel;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 15.0,
              maxZoom: 20.0, // High max zoom to prevent blurriness
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _autoFollow) setState(() => _autoFollow = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: isSatellite 
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', 
                subdomains: const ['a', 'b', 'c', 'd'],
                maxZoom: 20,
              ),
              // ADDED: TRANSPARENT LABEL LAYER FOR SATELLITE MODE
              if (isSatellite)
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  maxZoom: 20,
                ),
              if (routePolyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: routePolyline, strokeWidth: 5.0, color: const Color(0xFF0A5CFF).withOpacity(0.8)),
                    Polyline(points: routePolyline, strokeWidth: 10.0, color: const Color(0xFF0A5CFF).withOpacity(0.1)),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(point: _currentLocation, width: 60, height: 60, child: const _PulseMarker(color: Color(0xFF0A5CFF), isSelf: true)),
                  if (destination != null)
                    Marker(point: destination, width: 50, height: 50, child: const Icon(Icons.location_on, color: Colors.redAccent, size: 45)),
                  
                  // Community Markers: All registered users
                  ..._allUsers.map((user) {
                    final lat = user['lat'] as double? ?? 5.6037;
                    final lng = user['lng'] as double? ?? -0.1870;
                    final username = user['username'] as String? ?? "User";
                    
                    // Don't show duplicate marker for yourself
                    final currentUserEmail = AuthService.instance.currentUserEmail;
                    if (user['email'] == currentUserEmail && !widget.isAdminMode) {
                      return const Marker(point: LatLng(0,0), child: SizedBox());
                    }

                    return Marker(
                      point: LatLng(lat, lng),
                      width: 100, height: 100,
                      child: GestureDetector(
                        onTap: () => _showUserDetails(user),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.8), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
                              child: Text(username, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const _PulseMarker(color: Colors.blueAccent, isSelf: false),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),

          // SEARCH BAR (Always Visible)
          Positioned(top: 50, left: 15, right: 15, child: _buildSearchBarDeck()),

          // RIGHT SIDE CONTROLS
          Positioned(
            right: 15, bottom: destination != null ? 240 : 100,
            child: Column(
              children: [
                _buildMapAction(icon: Icons.layers_rounded, onTap: () => setState(() => isSatellite = !isSatellite), label: 'Layer', active: isSatellite),
                const SizedBox(height: 12),
                _buildMapAction(icon: Icons.navigation_rounded, onTap: () => setState(() => _autoFollow = !_autoFollow), label: 'Follow', active: _autoFollow),
                const SizedBox(height: 12),
                _buildMapAction(icon: Icons.add, onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1), label: 'Zoom'),
                _buildMapAction(icon: Icons.remove, onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1), label: 'Out'),
              ],
            ),
          ),

          // RECENTER BUTTON (HIGH PRIORITY)
          Positioned(
            right: 15, bottom: 30,
            child: FloatingActionButton(
              heroTag: 'recenter_map',
              onPressed: () {
                setState(() => _autoFollow = true);
                _mapController.move(_currentLocation, 16.0);
              },
              backgroundColor: const Color(0xFF1E293B),
              child: const Icon(Icons.gps_fixed_rounded, color: Color(0xFF0A5CFF)),
            ),
          ),

          // HUD INFO
          if (destination != null)
            Positioned(bottom: 25, left: 15, right: 85, child: _buildTacticalHUD(label)),
        ],
      ),
    );
  }

  Widget _buildSearchBarDeck() {
    return Column(
      children: [
        // SURROUNDING NAME LABEL (NEW)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0A5CFF).withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 14),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _currentAddress.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95), // GOOGLE STYLE WHITE
                borderRadius: BorderRadius.circular(30), 
                border: Border.all(color: Colors.black.withOpacity(0.05)), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15)]
              ),
              child: Row(
                children: [
                  const SizedBox(width: 15),
                  const Icon(Icons.search_rounded, color: Color(0xFF0A5CFF)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: Colors.black87), // DARK TEXT ON WHITE
                      decoration: InputDecoration(
                        hintText: 'Search Ghana sectors...', 
                        border: InputBorder.none, 
                        hintStyle: TextStyle(color: Colors.black.withOpacity(0.3), fontSize: 14)
                      ),
                    ),
                  ),
                  if (_isSearching)
                    const Padding(padding: EdgeInsets.only(right: 12.0), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A5CFF)))),
                  if (_searchController.text.isNotEmpty)
                    IconButton(icon: const Icon(Icons.close_rounded, size: 18, color: Colors.black38), onPressed: () { _searchController.clear(); setState(() => _searchResults = []); }),
                  const CircleAvatar(radius: 16, backgroundColor: Color(0xFF0A5CFF), child: Icon(Icons.security_rounded, color: Colors.white, size: 16)),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ),
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95), 
              borderRadius: BorderRadius.circular(20), 
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]
            ),
            child: Column(
              children: _searchResults.map((res) => ListTile(
                dense: true,
                leading: const Icon(Icons.location_searching_rounded, color: Color(0xFF0A5CFF), size: 18),
                title: Text(res['display_name'].split(',')[0], style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                subtitle: Text(res['display_name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.black.withOpacity(0.4), fontSize: 9)),
                onTap: () => _selectSearchResult(res),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTacticalHUD(String? label) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95), // GOOGLE STYLE WHITE
            borderRadius: BorderRadius.circular(24), 
            border: Border.all(color: Colors.black.withOpacity(0.05)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF0A5CFF).withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.near_me_rounded, color: Color(0xFF0A5CFF), size: 20)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label?.toUpperCase() ?? 'TARGET', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)), Text(isRouting ? 'CALCULATING...' : 'Directions Active', style: TextStyle(color: Colors.black.withOpacity(0.4), fontSize: 10))])),
                  IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: Colors.black38), onPressed: () => MapNavigationState.clearTarget()),
                ],
              ),
              if (!isRouting && _routeDistance.isNotEmpty) ...[
                const Divider(color: Colors.black12, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildRouteInfo(Icons.straighten_rounded, _routeDistance, 'DISTANCE'),
                    _buildRouteInfo(Icons.timer_rounded, _routeDuration, 'DURATION'),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteInfo(IconData icon, String value, String label) {
    return Column(children: [Row(children: [Icon(icon, size: 10, color: const Color(0xFF0A5CFF)), const SizedBox(width: 4), Text(label, style: TextStyle(color: Colors.black.withOpacity(0.4), fontSize: 8, fontWeight: FontWeight.bold))]), Text(value, style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w900))]);
  }

  Widget _buildMapAction({required IconData icon, required VoidCallback onTap, required String label, bool active = false}) {
    return Column(children: [GestureDetector(onTap: onTap, child: Container(width: 45, height: 45, decoration: BoxDecoration(color: active ? const Color(0xFF0A5CFF) : Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]), child: Icon(icon, color: active ? Colors.white : Colors.black87, size: 20))), const SizedBox(height: 4), Text(label.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.5), letterSpacing: 0.5))]);
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        maxChildSize: 0.6,
        minChildSize: 0.3,
        builder: (_, controller) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95), // WHITE FOR LIGHT THEME
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF0A5CFF).withOpacity(0.1), shape: BoxShape.circle),
                        child: Text(
                          (user['username'] as String)[0].toUpperCase(),
                          style: const TextStyle(color: Color(0xFF0A5CFF), fontWeight: FontWeight.bold, fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['username'].toUpperCase(), style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                            Text(user['email'], style: const TextStyle(color: Colors.black38, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildDetailRow(Icons.verified_user_rounded, 'PROTOCOL_STATUS', user['is_verified'] == 1 ? 'VERIFIED' : 'UNVERIFIED'),
                  _buildDetailRow(Icons.military_tech_rounded, 'TRUST_REPUTATION', '${user['reputation_score']} PTS'),
                  _buildDetailRow(Icons.location_on_rounded, 'LAST_GPS_SYNC', 'ACTIVE'),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        MapNavigationState.setTarget(LatLng(user['lat'], user['lng']), user['username']);
                      },
                      icon: const Icon(Icons.navigation_rounded),
                      label: const Text('ENGAGE TACTICAL INTERCEPT', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A5CFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0A5CFF)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _PulseMarker extends StatefulWidget {
  final Color color;
  final bool isSelf;
  const _PulseMarker({required this.color, required this.isSelf});
  @override
  State<_PulseMarker> createState() => _PulseMarkerState();
}

class _PulseMarkerState extends State<_PulseMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(); }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 10 + (35 * _controller.value), height: 10 + (35 * _controller.value), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: widget.color.withOpacity(1 - _controller.value), width: 2))),
          Icon(widget.isSelf ? Icons.navigation_rounded : Icons.circle, color: widget.color, size: widget.isSelf ? 22 : 12),
        ],
      ),
    );
  }
}
