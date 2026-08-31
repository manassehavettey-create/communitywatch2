import 'dart:async';
import 'package:flutter/material.dart';

class SecurityTicker extends StatefulWidget {
  const SecurityTicker({super.key});

  @override
  State<SecurityTicker> createState() => _SecurityTickerState();
}

class _SecurityTickerState extends State<SecurityTicker> {
  late Timer _timer;
  int _currentIndex = 0;
  final List<String> _codes = [
    "CODE 10-4: System Heartbeat Normal",
    "CODE 10-20: Monitoring Greater Accra",
    "STATUS 502: Patrol Unit 4 Active",
    "SIGNAL 30: All Clear - East Legon",
    "CODE 10-33: Emergency Priority High",
    "INTEL 88: New community lead verified",
    "CODE 10-7: Out of service - Maintenance",
    "SIGNAL 12: Suspicious activity flagged",
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _codes.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: double.infinity,
      color: const Color(0xFF0A5CFF).withOpacity(0.1),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Text(
            _codes[_currentIndex],
            key: ValueKey(_codes[_currentIndex]),
            style: const TextStyle(
              color: Color(0xFF0A5CFF),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }
}
