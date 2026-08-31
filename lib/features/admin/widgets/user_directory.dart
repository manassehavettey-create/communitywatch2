import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../../../core/services/database_service.dart';
import '../../navigation/main_navigation_shell.dart';
import '../../map/screens/map_screen.dart';

class UserDirectory extends StatefulWidget {
  final bool isAdminView;
  const UserDirectory({super.key, this.isAdminView = false});

  @override
  State<UserDirectory> createState() => _UserDirectoryState();
}

class _UserDirectoryState extends State<UserDirectory> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    try {
      final data = await DatabaseService.instance.readAllUsers()
          .timeout(const Duration(seconds: 5), onTimeout: () => []);

      if (mounted) {
        setState(() {
          _users = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _users = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            style: TextStyle(color: widget.isAdminView ? Colors.white : null),
            decoration: InputDecoration(
              hintText: 'Search users by name, email or ID...',
              hintStyle: TextStyle(color: widget.isAdminView ? Colors.white38 : null),
              prefixIcon: Icon(Icons.search, color: widget.isAdminView ? Colors.white54 : null),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: widget.isAdminView ? const Color(0xFF1E293B) : Colors.grey.shade100,
            ),
          ),
        ),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty 
              ? const Center(child: Text('No users registered yet', style: TextStyle(color: Colors.white38)))
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: widget.isAdminView ? Colors.white10 : null),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isVerified = user['is_verified'] == 1;
                    final reputation = user['reputation_score'] as int? ?? 0;
                    final username = user['username'] as String? ?? "Unknown";
                    final isFrozen = user['is_frozen'] == 1;
                    
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: widget.isAdminView 
                              ? (isFrozen ? Colors.white10 : const Color(0xFF0A5CFF).withOpacity(0.2)) 
                              : Colors.blue.shade100,
                          child: Text(username.isNotEmpty ? username[0].toUpperCase() : "?", style: TextStyle(color: isFrozen ? Colors.white24 : Colors.white)),
                        ),
                        title: Row(
                          children: [
                            Text(username, style: TextStyle(color: isFrozen ? Colors.white24 : Colors.white, decoration: isFrozen ? TextDecoration.lineThrough : null)),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified, size: 16, color: Colors.blue),
                            ],
                            if (isFrozen) ...[
                              const SizedBox(width: 8),
                              const Text('FROZEN', style: TextStyle(color: Colors.orange, fontSize: 8, fontWeight: FontWeight.bold)),
                            ]
                          ],
                        ),
                        subtitle: Text(
                          'Joined ${user['joined_date'] as String? ?? "N/A"} • ID: CW-${user['id']}',
                          style: TextStyle(color: isFrozen ? Colors.white10 : Colors.white54),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$reputation Rep',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isFrozen ? Colors.white10 : (reputation > 80 ? Colors.green : (reputation > 50 ? Colors.orange : Colors.red)),
                              ),
                            ),
                            Text(
                              isFrozen ? 'INACTIVE' : 'Active', 
                              style: TextStyle(fontSize: 10, color: isFrozen ? Colors.orange.withOpacity(0.2) : Colors.white24),
                            ),
                          ],
                        ),
                        onTap: () => _showUserActions(context, index, user),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showUserActions(BuildContext context, int index, Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: const Color(0xFF0A5CFF).withOpacity(0.1),
                    child: Text((user['username'] as String? ?? "?")[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Color(0xFF0A5CFF), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['username'] as String? ?? "Unknown", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        Text('ID: CW-${user['id']}', style: const TextStyle(color: Colors.white38)),
                      ],
                    ),
                  ),
                  if (user['is_verified'] == 1)
                    const Icon(Icons.verified, color: Color(0xFF0A5CFF), size: 28),
                ],
              ),
              const SizedBox(height: 32),
              const Text('CITIZEN PROFILE DETAILS', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const SizedBox(height: 16),
              _buildDetailItem(Icons.email_outlined, 'Email Address', user['email'] as String? ?? "N/A"),
              _buildDetailItem(Icons.calendar_today_outlined, 'Registration Date', user['joined_date'] as String? ?? "N/A"),
              _buildDetailItem(Icons.trending_up_rounded, 'Reputation Score', '${user['reputation_score']} Points'),
              _buildDetailItem(Icons.security_rounded, 'Account Status', user['is_frozen'] == 1 ? 'ACCOUNT FROZEN' : (user['is_verified'] == 1 ? 'Verified Citizen' : 'Standard Member')),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final lat = user['lat'] as double? ?? 5.6037;
                    final lng = user['lng'] as double? ?? -0.1870;
                    
                    // Set target in Map state
                    MapNavigationState.setTarget(ll.LatLng(lat, lng), user['username'] as String? ?? "CITIZEN");
                    
                    // Navigate to Map in Shell
                    if (context.mounted) {
                      Navigator.pop(context);
                      Navigator.pop(context);
                      MainNavigationShell.of(context)?.navigateToMapWithDestination(
                        ll.LatLng(lat, lng), 
                        user['username'] as String? ?? "CITIZEN"
                      );
                    }
                  },
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('GET TACTICAL DIRECTIONS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A5CFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final newStatus = user['is_frozen'] == 1 ? 0 : 1;
                        await DatabaseService.instance.updateUserStatus(user['id'] as int, newStatus);
                        await DatabaseService.instance.createAdminLog({
                          'admin_id': 'ADMIN',
                          'action': newStatus == 1 ? 'Account Frozen' : 'Account Reinstated',
                          'timestamp': DateTime.now().toIso8601String().substring(11, 16),
                          'details': 'User ${user['username']} status modified.'
                        });
                        if (mounted) {
                          Navigator.pop(context);
                          _loadUsers();
                        }
                      },
                      icon: Icon(user['is_frozen'] == 1 ? Icons.ac_unit : Icons.block_flipped),
                      label: Text(user['is_frozen'] == 1 ? 'Unfreeze' : 'Freeze User'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: user['is_frozen'] == 1 ? Colors.greenAccent : Colors.orangeAccent,
                        side: BorderSide(color: user['is_frozen'] == 1 ? Colors.greenAccent.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await DatabaseService.instance.deleteUser(user['id'] as int);
                        await DatabaseService.instance.createAdminLog({
                          'admin_id': 'ADMIN',
                          'action': 'Account Purged',
                          'timestamp': DateTime.now().toIso8601String().substring(11, 16),
                          'details': 'User ${user['username']} deleted from system.'
                        });
                        if (mounted) {
                          Navigator.pop(context);
                          _loadUsers();
                        }
                      },
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: const Color(0xFF0A5CFF), size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
