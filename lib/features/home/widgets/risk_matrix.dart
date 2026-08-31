import 'package:flutter/material.dart';

class RiskMatrix extends StatelessWidget {
  const RiskMatrix({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildRiskCard('Accra', 'Low', Colors.greenAccent),
          const SizedBox(width: 16),
          _buildRiskCard('Kumasi', 'Med', Colors.orangeAccent),
          const SizedBox(width: 16),
          _buildRiskCard('Tema', 'High', Colors.redAccent),
          const SizedBox(width: 16),
          _buildRiskCard('Tamale', 'Low', Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildRiskCard(String city, String level, Color color) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(city, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            Row(
              children: [
                Text(level, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
                const Spacer(),
                Icon(Icons.analytics_rounded, size: 14, color: color.withOpacity(0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
