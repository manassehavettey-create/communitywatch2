import 'dart:math';
import 'package:flutter/material.dart';

class SafetyPulseHub extends StatefulWidget {
  const SafetyPulseHub({super.key});

  @override
  State<SafetyPulseHub> createState() => _SafetyPulseHubState();
}

class _SafetyPulseHubState extends State<SafetyPulseHub> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Glow
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A5CFF).withOpacity(0.08),
                  const Color(0xFF1E293B).withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
          ),
          
          // Pulsing Rings
          ...List.generate(4, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final progress = (_controller.value + (index / 4)) % 1.0;
                return Transform.scale(
                  scale: 1.0 + progress * 2.5,
                  child: Opacity(
                    opacity: (1.0 - progress) * 0.8,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0A5CFF).withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.2), blurRadius: 10, spreadRadius: -2),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Central Data Core
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A5CFF).withOpacity(0.4),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
              border: Border.all(color: const Color(0xFF0A5CFF).withOpacity(0.3), width: 2),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                  Text('SECURE', style: TextStyle(color: Color(0xFF0A5CFF), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ],
              ),
            ),
          ),
          
          // Peripheral Stats
          Positioned(
            top: 40, left: 40,
            child: _buildMiniStat('SCAN_RATE', '99.2%', Icons.radar_rounded),
          ),
          Positioned(
            bottom: 40, right: 40,
            child: _buildMiniStat('LATENCY', '0.4ms', Icons.bolt_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF0A5CFF), size: 10),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
