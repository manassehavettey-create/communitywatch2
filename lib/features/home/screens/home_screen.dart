import 'package:flutter/material.dart';
import 'dart:ui';
import '../widgets/animated_incident_card.dart';
import '../widgets/safety_pulse_hub.dart';
import '../widgets/security_ticker.dart';
import '../widgets/risk_matrix.dart';
import '../../report/screens/report_screen.dart';
import '../../../core/widgets/three_d_grid_background.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/notification_service.dart';
import 'dart:async';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _incidents = [];
  bool _isLoading = true;
  late Timer _aiTimer;
  
  // Tactical Alert State
  Map<String, dynamic>? _activeTacticalAlert;
  late AnimationController _alertController;

  @override
  void initState() {
    super.initState();
    _alertController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _refreshIncidents();
    _startAiAutomation();
    NotificationService.instance.addListener(_onNotificationUpdate);
  }

  @override
  void dispose() {
    _aiTimer.cancel();
    _alertController.dispose();
    NotificationService.instance.removeListener(_onNotificationUpdate);
    super.dispose();
  }

  void _onNotificationUpdate() {
    if (!mounted) return;
    final latest = NotificationService.instance.notifications.isNotEmpty 
        ? NotificationService.instance.notifications.first 
        : null;

    if (latest != null && !latest['isRead'] && (latest['type'] == 'ADMIN' || latest['type'] == 'AI')) {
      setState(() {
        _activeTacticalAlert = latest;
      });
      _alertController.forward();
      
      // Auto-dismiss after 8 seconds
      Future.delayed(const Duration(seconds: 8), () {
        if (mounted && _activeTacticalAlert == latest) {
          _alertController.reverse().then((_) {
            setState(() => _activeTacticalAlert = null);
          });
        }
      });
    }
    setState(() {});
  }

  void _startAiAutomation() {
    _aiTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (Random().nextBool()) {
        final alertTypes = ['AI SCAN', 'INTELLIGENCE', 'SYSTEM ALERT'];
        final cities = ['Accra', 'Kumasi', 'Tema', 'Tamale'];
        final type = alertTypes[Random().nextInt(alertTypes.length)];
        final city = cities[Random().nextInt(cities.length)];
        
        NotificationService.instance.addNotification(
          '[$type] Anomaly Detected',
          'AI sensors detect unusual gathering pattern in $city sector.',
          type: 'AI'
        );
      }
    });
  }

  Future<void> _refreshIncidents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await DatabaseService.instance.readAllIncidents()
          .timeout(const Duration(seconds: 5), onTimeout: () => []);
      if (mounted) setState(() { _incidents = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _incidents = []; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          const ThreeDGridBackground(),
          RefreshIndicator(
            onRefresh: _refreshIncidents,
            color: const Color(0xFF0A5CFF),
            backgroundColor: const Color(0xFF1E293B),
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(),
                const SliverToBoxAdapter(child: SecurityTicker()),
                const SliverToBoxAdapter(child: SafetyPulseHub()),
                _buildSectionLabel('REGIONAL RISK STATUS'),
                const SliverToBoxAdapter(child: RiskMatrix()),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(child: _buildProtocolGrid()),
                _buildIntelligenceHeader(),
                _buildIncidentList(),
                const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
              ],
            ),
          ),
          
          // TACTICAL ALERT OVERLAY
          if (_activeTacticalAlert != null)
            _buildTacticalAlertOverlay(),
        ],
      ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140.0,
      floating: true, pinned: true, stretch: true,
      backgroundColor: const Color(0xFF0F172A).withOpacity(0.8),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text('COMMUNITY WATCH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 3.0)),
        background: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF0A5CFF).withOpacity(0.15), const Color(0xFF020617).withOpacity(0)]))),
      ),
      actions: [_buildNotificationBadge()],
    );
  }

  Widget _buildNotificationBadge() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(color: const Color(0xFF1E293B), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.05))),
          child: IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 20),
            onPressed: () => _showNotifications(context),
          ),
        ),
        if (NotificationService.instance.unreadCount > 0)
          Positioned(right: 18, top: 10, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFFF3B30), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF1E293B), width: 2)))),
      ],
    );
  }

  Widget _buildTacticalAlertOverlay() {
    final isAdmin = _activeTacticalAlert!['type'] == 'ADMIN';
    final accentColor = isAdmin ? const Color(0xFFFB923C) : const Color(0xFF0A5CFF);

    return Positioned(
      top: 100, left: 20, right: 20,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(_alertController),
        child: FadeTransition(
          opacity: _alertController,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withOpacity(0.9),
                  border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
                  boxShadow: [BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 30, spreadRadius: 5)],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(isAdmin ? Icons.gavel_rounded : Icons.radar_rounded, color: accentColor, size: 20),
                        const SizedBox(width: 12),
                        Text(isAdmin ? 'PRIORITY_COMMAND' : 'AI_INTERCEPT', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)),
                        const Spacer(),
                        IconButton(onPressed: () => _alertController.reverse().then((_) => setState(() => _activeTacticalAlert = null)), icon: const Icon(Icons.close, color: Colors.white24, size: 18))
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(_activeTacticalAlert!['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(_activeTacticalAlert!['body'], style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: Text(text, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
      ),
    );
  }

  Widget _buildIntelligenceHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('INTELLIGENCE FEED', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
                Text(_isLoading ? 'SYNCING ENCRYPTED DATA...' : (_incidents.isEmpty ? 'SECTOR CLEAR' : 'LIVE SECURITY UPDATES'), style: const TextStyle(color: Color(0xFF0A5CFF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              ],
            ),
            Container(decoration: BoxDecoration(color: const Color(0xFF0A5CFF).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: IconButton(icon: const Icon(Icons.tune_rounded, color: Color(0xFF0A5CFF), size: 18), onPressed: () {})),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentList() {
    if (_isLoading) {
      return const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(color: Color(0xFF0A5CFF))));
    }
    if (_incidents.isEmpty) {
      return SliverFillRemaining(hasScrollBody: false, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_moon_rounded, size: 64, color: Colors.white.withOpacity(0.05)), const SizedBox(height: 16), const Text('SECTOR SECURE', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, letterSpacing: 2))])));
    }
    return SliverList(delegate: SliverChildBuilderDelegate((context, index) => AnimatedIncidentCard(index: index, incident: _incidents[index]), childCount: _incidents.length));
  }

  Widget _buildFAB() {
    return Container(
      height: 64, margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(32), boxShadow: [BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 10))]),
      child: FloatingActionButton.extended(
        onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportScreen())); _refreshIncidents(); },
        backgroundColor: const Color(0xFF0A5CFF), elevation: 0,
        icon: const Icon(Icons.add_moderator_rounded, color: Colors.white, size: 24),
        label: const Text('SIGNAL ALERT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    NotificationService.instance.markAllAsRead();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(color: Color(0xFF0F172A), borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('INTEL BRIEFING', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
              const SizedBox(height: 20),
              Expanded(
                child: NotificationService.instance.notifications.isEmpty 
                  ? const Center(child: Text('NO NEW INTEL', style: TextStyle(color: Colors.white24, letterSpacing: 1)))
                  : ListView.builder(
                      controller: controller, itemCount: NotificationService.instance.notifications.length,
                      itemBuilder: (context, index) {
                        final note = NotificationService.instance.notifications[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF0A5CFF).withOpacity(0.1))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [Icon(Icons.security_rounded, size: 14, color: const Color(0xFF0A5CFF)), const SizedBox(width: 8), Text(note['title'], style: const TextStyle(color: Color(0xFF0A5CFF), fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1))]),
                            const SizedBox(height: 8), Text(note['body'], style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
                          ]),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtocolGrid() {
    final protocols = [
      {'code': '10-4', 'mean': 'AFFIRMATIVE', 'icon': Icons.check_circle_outline},
      {'code': '10-20', 'mean': 'GPS_LOC', 'icon': Icons.my_location},
      {'code': '10-33', 'mean': 'EMERGENCY', 'icon': Icons.emergency_share},
      {'code': '10-70', 'mean': 'FIRE_ALERT', 'icon': Icons.local_fire_department},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.8),
        itemCount: protocols.length,
        itemBuilder: (context, index) {
          final p = protocols[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(color: const Color(0xFF1E293B).withOpacity(0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
                child: Row(children: [const SizedBox(width: 16), Icon(p['icon'] as IconData, color: const Color(0xFF0A5CFF), size: 18), const SizedBox(width: 12), Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p['code'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)), Text(p['mean'] as String, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold))])]),
              ),
            ),
          );
        },
      ),
    );
  }
}
