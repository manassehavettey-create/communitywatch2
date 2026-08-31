import 'package:flutter/material.dart';
import '../widgets/user_activity_log.dart';
import '../widgets/all_reports_view.dart';
import '../widgets/user_directory.dart';
import '../widgets/three_d_tab_bar.dart';
import '../widgets/system_monitor.dart';
import '../widgets/region_panel.dart';
import '../widgets/admin_messaging_hub.dart';
import '../widgets/intelligence_panel.dart';
import '../../map/screens/map_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        backgroundColor: const Color(0xFF020617),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 160.0,
              floating: true,
              pinned: true,
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 24, bottom: 85),
                title: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMMAND CENTER',
                      style: TextStyle(
                        fontWeight: FontWeight.w900, 
                        letterSpacing: 3.0,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'HIGH SECURITY ACCESS: LEVEL 4',
                      style: TextStyle(color: Color(0xFF0A5CFF), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                  ],
                ),
                background: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _AdminPatternPainter()),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF0A5CFF).withOpacity(0.1),
                            const Color(0xFF020617).withOpacity(0.9),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(70),
                child: Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ThreeDTabBar(
                    tabs: [
                      Tab(text: 'MONITOR'),
                      Tab(text: 'MAP'),
                      Tab(text: 'INTEL'),
                      Tab(text: 'REGIONS'),
                      Tab(text: 'COMM'),
                      Tab(text: 'REPORTS'),
                      Tab(text: 'USERS'),
                      Tab(text: 'LOGS'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              const SystemMonitor(),
              CommunityWatchMap(isAdminMode: true),
              const IntelligencePanel(),
              const RegionPanel(),
              const AdminMessagingHub(),
              const AllReportsView(isAdminView: true),
              const UserDirectory(isAdminView: true),
              const UserActivityLog(isDetailed: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A5CFF).withOpacity(0.05)
      ..strokeWidth = 1.0;
    
    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i + 50, size.height), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
