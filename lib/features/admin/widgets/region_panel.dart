import 'package:flutter/material.dart';

class RegionPanel extends StatelessWidget {
  const RegionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> regions = [
      {'name': 'Greater Accra', 'alerts': 24, 'active_users': 450, 'status': 'High'},
      {'name': 'Ashanti', 'alerts': 18, 'active_users': 320, 'status': 'Medium'},
      {'name': 'Western', 'alerts': 8, 'active_users': 150, 'status': 'Low'},
      {'name': 'Central', 'alerts': 12, 'active_users': 210, 'status': 'Medium'},
      {'name': 'Eastern', 'alerts': 5, 'active_users': 130, 'status': 'Low'},
      {'name': 'Northern', 'alerts': 3, 'active_users': 95, 'status': 'Low'},
      {'name': 'Volta', 'alerts': 7, 'active_users': 110, 'status': 'Low'},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: regions.length,
      itemBuilder: (context, index) {
        final region = regions[index];
        final Color statusColor = region['status'] == 'High' 
            ? Colors.red 
            : (region['status'] == 'Medium' ? Colors.orange : Colors.green);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: ExpansionTile(
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.map_rounded, color: statusColor, size: 20),
            ),
            title: Text(
              region['name'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${region['alerts']} Active Alerts',
              style: TextStyle(color: statusColor.withOpacity(0.7), fontSize: 12),
            ),
            trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.white24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),
                    _buildRegionStat('Active Users', region['active_users'].toString(), Icons.people_outline),
                    _buildRegionStat('Alert Severity', region['status'], Icons.warning_amber_rounded),
                    _buildRegionStat('Last Sync', '2 mins ago', Icons.sync),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A5CFF).withOpacity(0.1),
                          foregroundColor: const Color(0xFF0A5CFF),
                          elevation: 0,
                        ),
                        child: const Text('Deploy Regional Alert'),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegionStat(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
