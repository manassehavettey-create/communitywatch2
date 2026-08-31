import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../home/screens/home_screen.dart';
import '../map/screens/map_screen.dart';
import '../report/screens/report_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../messages/screens/messages_screen.dart';
import '../auth/screens/location_permission_screen.dart';

class MainNavigationShell extends StatefulWidget {
  static _MainNavigationShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MainNavigationShellState>();

  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  LatLng? _mapDestination;
  String? _mapLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifyLocationMandate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyLocationMandate();
    }
  }

  /// PRO SECURITY: Ensures the user has not revoked location while app was in background
  Future<void> _verifyLocationMandate() async {
    LocationPermission permission = await Geolocator.checkPermission();
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever || 
        !serviceEnabled) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LocationPermissionScreen()),
          (route) => false,
        );
      }
    }
  }

  void navigateToMapWithDestination(LatLng destination, String label) {
    setState(() {
      _mapDestination = destination;
      _mapLabel = label;
      _selectedIndex = 1; // Map index
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      const HomeScreen(),
      CommunityWatchMap(targetDestination: _mapDestination, targetLabel: _mapLabel),
      const ReportScreen(),
      const MessagesScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
