import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import '../../navigation/main_navigation_shell.dart';
import '../../../core/widgets/three_d_grid_background.dart';

class LocationPermissionScreen extends StatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  State<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends State<LocationPermissionScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _checkInitialStatus();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkInitialStatus() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled && mounted) {
        _proceedToApp();
      }
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _isLoading = true);
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            _showProtocolAlert('SIGNAL_LOST: PLEASE ENABLE GPS IN SYSTEM SETTINGS');
          }
        } else {
          if (mounted) _proceedToApp();
        }
      } else if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showProtocolAlert('ACCESS_BLOCKED: LOCATION PERMISSION PERMANENTLY DENIED');
        }
      } else {
        if (mounted) {
          _showProtocolAlert('COMPLIANCE_REQUIRED: LOCATION DATA IS MANDATORY');
        }
      }
    } catch (e) {
      if (mounted) _showProtocolAlert('COMM_ERROR: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _proceedToApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const MainNavigationShell()),
    );
  }

  void _showProtocolAlert(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          const ThreeDGridBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // PULSING SATELLITE ICON
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A5CFF).withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF0A5CFF).withOpacity(0.3 * _controller.value)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0A5CFF).withOpacity(0.1 * _controller.value),
                              blurRadius: 40,
                              spreadRadius: 20 * _controller.value,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.satellite_alt_rounded, size: 80, color: Color(0xFF0A5CFF)),
                      );
                    },
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    'GPS_SYNCHRONIZATION',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3.0),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'TO PROVIDE REAL-TIME SECURITY ALERTS AND SECTOR MAPPING IN GHANA, THIS TERMINAL REQUIRES ACTIVE GEOLOCATION DATA.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.white38, fontWeight: FontWeight.bold, height: 1.6, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 60),
                  if (_isLoading)
                    const CircularProgressIndicator(color: Color(0xFF0A5CFF))
                  else
                    Container(
                      width: double.infinity,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _requestPermission,
                        icon: const Icon(Icons.gps_fixed_rounded),
                        label: const Text('INITIALIZE_LOCATION_LINK', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A5CFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'MISSION STATUS: WAITING_FOR_COORDINATES',
                    style: TextStyle(color: Colors.white10, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
