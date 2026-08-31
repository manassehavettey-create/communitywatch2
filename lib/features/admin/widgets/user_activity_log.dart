import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/services/database_service.dart';

class UserActivityLog extends StatefulWidget {
  final bool isDetailed;
  const UserActivityLog({super.key, this.isDetailed = false});

  @override
  State<UserActivityLog> createState() => _UserActivityLogState();
}

class _UserActivityLogState extends State<UserActivityLog> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await DatabaseService.instance.readAllAdminLogs()
          .timeout(const Duration(seconds: 4), onTimeout: () => []);
      
      if (!mounted) return;
      
      setState(() {
        _logs = data;
        _isLoading = false;
      });
      
      // Seed if empty on mobile
      if (data.isEmpty && !kIsWeb) {
        await _seedInitialLogs();
        final refreshedData = await DatabaseService.instance.readAllAdminLogs()
            .timeout(const Duration(seconds: 2), onTimeout: () => []);
        if (mounted) {
          setState(() {
            _logs = refreshedData;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logs = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _seedInitialLogs() async {
    final seedData = [
      {'admin_id': 'SYS', 'action': 'System Check', 'timestamp': 'Just now', 'details': 'All nodes responding.'},
      {'admin_id': 'Admin_1', 'action': 'Login', 'timestamp': '5m ago', 'details': 'Authorized access.'},
    ];
    for (var log in seedData) {
      await DatabaseService.instance.createAdminLog(log);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0A5CFF)),
            SizedBox(height: 16),
            Text('Accessing activity logs...', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 48, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            const Text('No system activity recorded', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _logs.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final log = _logs[index];
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_toggle_off, color: Colors.blue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: widget.isDetailed ? Colors.white : Colors.black, 
                          fontSize: 14
                        ),
                        children: [
                          TextSpan(
                            text: '${log['admin_id'] as String? ?? "SYS"} ',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: log['action'] as String? ?? "Activity",
                            style: TextStyle(color: widget.isDetailed ? Colors.white70 : null),
                          ),
                        ],
                      ),
                    ),
                    if (log['details'] != null)
                      Text(
                        log['details'],
                        style: TextStyle(color: widget.isDetailed ? Colors.white38 : Colors.grey, fontSize: 12),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '${log['timestamp']}',
                      style: TextStyle(
                        fontSize: 11, 
                        color: widget.isDetailed ? Colors.white24 : Colors.grey
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
