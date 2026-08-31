import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class IntelligencePanel extends StatefulWidget {
  const IntelligencePanel({super.key});

  @override
  State<IntelligencePanel> createState() => _IntelligencePanelState();
}

class _IntelligencePanelState extends State<IntelligencePanel> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Timer _dataTimer;
  double _threatLevel = 14.2;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _dataTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _threatLevel = 10 + Random().nextDouble() * 20;
        });
      }
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _dataTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntelligenceHeader(),
              const SizedBox(height: 32),
              _buildLiveThreatMeter(),
              const SizedBox(height: 32),
              const Text('RESTRICTED_SIGNALS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              _buildIntelCard('ANOMALY_04', 'Multiple unregistered nodes detected near Tema Harbor. AI scanning in progress.', 'High'),
              _buildIntelCard('SECTOR_SYNC', 'Synchronization between Sector A and B is at 98.4%. No data loss reported.', 'Low'),
              _buildIntelCard('THREAT_SCAN', 'Pattern recognition identifies increased risk of "Theft" in Osu area.', 'Medium'),
              _buildIntelCard('ENCRYPTION_ALERT', 'Brute force attempt detected on NODE_77. Countermeasures deployed.', 'High'),
            ],
          ),
        ),
        
        // SCAN LINE EFFECT
        AnimatedBuilder(
          animation: _scanController,
          builder: (context, child) {
            return Positioned(
              top: MediaQuery.of(context).size.height * _scanController.value,
              left: 0, right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.3), blurRadius: 10, spreadRadius: 2)],
                  gradient: LinearGradient(colors: [Colors.transparent, const Color(0xFF0A5CFF).withOpacity(0.5), Colors.transparent]),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildIntelligenceHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.psychology_rounded, color: Color(0xFF0A5CFF), size: 24),
            const SizedBox(width: 12),
            const Text('AI_CORE_INTELLIGENCE', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
          ],
        ),
        const SizedBox(height: 8),
        const Text('CLASSIFIED DATA FOR OFFICIAL USE ONLY', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildLiveThreatMeter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SECTOR_THREAT_INDEX', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${_threatLevel.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF0A5CFF).withOpacity(0.3), width: 4)),
            child: Center(child: Icon(Icons.security_rounded, color: _threatLevel > 20 ? Colors.orangeAccent : const Color(0xFF0A5CFF))),
          ),
        ],
      ),
    );
  }

  Widget _buildIntelCard(String code, String detail, String severity) {
    final Color color = severity == 'High' ? Colors.redAccent : (severity == 'Medium' ? Colors.orangeAccent : Colors.greenAccent);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(code, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                child: Text(severity.toUpperCase(), style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(detail, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 10, color: Colors.white24),
              const SizedBox(width: 6),
              Text('SCAN_TIME: ${DateTime.now().toIso8601String().substring(11, 16)} GMT', style: const TextStyle(color: Colors.white24, fontSize: 9)),
              const Spacer(),
              const Text('NODE_ID: CW-X9', style: TextStyle(color: Colors.white10, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}
