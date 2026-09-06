import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';

class AdminManagementPanel extends StatefulWidget {
  const AdminManagementPanel({super.key});

  @override
  State<AdminManagementPanel> createState() => _AdminManagementPanelState();
}

class _AdminManagementPanelState extends State<AdminManagementPanel> {
  List<Map<String, dynamic>> _adminUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    final allUsers = await DatabaseService.instance.readAllUsers();
    setState(() {
      _adminUsers = allUsers.where((u) => u['is_admin'] == 1).toList();
      _isLoading = false;
    });
  }

  Future<void> _promoteToAdmin() async {
    final allUsers = await DatabaseService.instance.readAllUsers();
    final nonAdmins = allUsers.where((u) => u['is_admin'] != 1).toList();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('SELECT_USER_FOR_PROMOTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 20),
            Expanded(
              child: nonAdmins.isEmpty 
                ? const Center(child: Text('NO_ELIGIBLE_USERS', style: TextStyle(color: Colors.white24)))
                : ListView.builder(
                    itemCount: nonAdmins.length,
                    itemBuilder: (context, index) {
                      final user = nonAdmins[index];
                      return ListTile(
                        title: Text(user['username'], style: const TextStyle(color: Colors.white)),
                        subtitle: Text(user['email'], style: const TextStyle(color: Colors.white38)),
                        trailing: const Icon(Icons.add_moderator_rounded, color: Color(0xFF0A5CFF)),
                        onTap: () async {
                          // In a real app, you'd have an updateIsAdmin method. 
                          // For now we use raw update via DatabaseService if possible or add it.
                          final db = await DatabaseService.instance.database;
                          await db.update('users', {'is_admin': 1}, where: 'id = ?', whereArgs: [user['id']]);
                          
                          await DatabaseService.instance.createAdminLog({
                            'admin_id': 'COMMAND',
                            'action': 'Promote Admin',
                            'timestamp': DateTime.now().toIso8601String().substring(11, 16),
                            'details': 'User ${user['username']} granted Level 4 clearance.'
                          });

                          if (context.mounted) Navigator.pop(context);
                          _loadAdmins();
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ADMIN_COMMAND_STAFF', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  Text('AUTHORIZED_PERSONNEL_ONLY', style: TextStyle(color: Color(0xFF0A5CFF), fontSize: 8, fontWeight: FontWeight.bold)),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _promoteToAdmin,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('ADD_ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A5CFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _adminUsers.length,
                itemBuilder: (context, index) {
                  final admin = _adminUsers[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF0A5CFF).withOpacity(0.1)),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0A5CFF),
                        child: Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                      ),
                      title: Text(admin['username'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      subtitle: const Text('ACCESS_LEVEL: 4 (COMMAND)', style: TextStyle(color: Color(0xFF0A5CFF), fontSize: 10, fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () async {
                          final db = await DatabaseService.instance.database;
                          await db.update('users', {'is_admin': 0}, where: 'id = ?', whereArgs: [admin['id']]);
                          _loadAdmins();
                        },
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
}
