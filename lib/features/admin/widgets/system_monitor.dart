import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'stat_card.dart';
import '../../../core/services/notification_service.dart';

class SystemMonitor extends StatefulWidget {
  const SystemMonitor({super.key});

  @override
  State<SystemMonitor> createState() => _SystemMonitorState();
}

class _SystemMonitorState extends State<SystemMonitor> with SingleTickerProviderStateMixin {
  late Timer _timer;
  final List<double> _dataPoints = List.generate(30, (index) => 0.5);
  final List<String> _detectionLogs = [
    "[INFO] System initialized.",
    "[SCAN] Monitoring Greater Accra sector...",
    "[INFO] AI Core synchronized.",
  ];
  final TextEditingController _intelligenceController = TextEditingController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        setState(() {
          _dataPoints.removeAt(0);
          _dataPoints.add(0.2 + Random().nextDouble() * 0.6);
          
          if (Random().nextDouble() > 0.8) {
            final sectors = ['Accra', 'Kumasi', 'Tema', 'Tamale', 'Ho', 'Koforidua'];
            final sector = sectors[Random().nextInt(sectors.length)];
            _detectionLogs.insert(0, "[DETECT] Anomaly in $sector - PING: ${(Random().nextInt(100))}ms");
            if (_detectionLogs.length > 15) _detectionLogs.removeLast();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    _intelligenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLiveStatusHeader(),
          const SizedBox(height: 32),
          
          _buildSectionHeader('SYSTEM_TELEMETRY', Icons.analytics_rounded),
          Container(
            height: 120,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: CustomPaint(painter: SparklinePainter(_dataPoints)),
          ),
          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(child: _buildMetricCard('NODES_ACTIVE', '1.4k', Colors.greenAccent)),
              const SizedBox(width: 16),
              Expanded(child: _buildMetricCard('THREATS_LOCKED', '03', Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 32),
          
          _buildSectionHeader('REAL_TIME_LOGS', Icons.terminal_rounded),
          Container(
            height: 200,
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.builder(
              itemCount: _detectionLogs.length,
              itemBuilder: (context, index) {
                final log = _detectionLogs[index];
                final isDetect = log.contains('DETECT');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    log,
                    style: TextStyle(
                      color: isDetect ? Colors.orangeAccent : Colors.greenAccent.withOpacity(0.7),
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 32),
          
          _buildSectionHeader('GLOBAL_BROADCAST', Icons.campaign_rounded),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF0A5CFF).withOpacity(0.2)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _intelligenceController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'COMMAND_INPUT...',
                    hintStyle: const TextStyle(color: Colors.white10),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_intelligenceController.text.isNotEmpty) {
                        NotificationService.instance.addNotification(
                          'EMERGENCY BROADCAST', 
                          _intelligenceController.text,
                          type: 'ADMIN'
                        );
                        _intelligenceController.clear();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('COMMAND_TRANSMITTED'), backgroundColor: Color(0xFF0A5CFF)),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A5CFF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('EXECUTE_BROADCAST', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0A5CFF), size: 18),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
      ),
    );
  }

  Widget _buildLiveStatusHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF34C759).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF34C759).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _pulseController,
            child: const Icon(Icons.circle, color: Color(0xFF34C759), size: 10),
          ),
          const SizedBox(width: 12),
          const Text(
            'NETWORK_ONLINE • SECURE_LINK_ACTIVE',
            style: TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> points;
  SparklinePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A5CFF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double stepX = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (points[i] * size.height);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    
    // Add glow
    canvas.drawPath(path, paint..color = const Color(0xFF0A5CFF).withOpacity(0.8));
    canvas.drawPath(path, paint..strokeWidth = 6.0..color = const Color(0xFF0A5CFF).withOpacity(0.1));
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) => true;
}
