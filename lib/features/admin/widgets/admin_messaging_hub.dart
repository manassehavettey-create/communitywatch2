import 'package:flutter/material.dart';
import '../../../core/services/database_service.dart';

class AdminMessagingHub extends StatefulWidget {
  const AdminMessagingHub({super.key});

  @override
  State<AdminMessagingHub> createState() => _AdminMessagingHubState();
}

class _AdminMessagingHubState extends State<AdminMessagingHub> {
  List<Map<String, dynamic>> _allMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllMessages();
  }

  Future<void> _loadAllMessages() async {
    final data = await DatabaseService.instance.readAllAdminMessages();
    setState(() {
      _allMessages = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    // Group messages by user (excluding 'ADMIN')
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var msg in _allMessages) {
      final sender = msg['sender'] as String? ?? "Unknown";
      final recipient = msg['recipient'] as String? ?? "Unknown";
      final user = sender == 'ADMIN' ? recipient : sender;
      if (!grouped.containsKey(user)) grouped[user] = [];
      grouped[user]!.add(msg);
    }

    if (grouped.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, color: Colors.white10, size: 64),
            SizedBox(height: 16),
            Text('No active citizen threads', style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final userName = grouped.keys.elementAt(index);
        final messages = grouped[userName]!;
        final lastMsg = messages.first; // Latest because of ORDER BY DESC
        final unreadCount = messages.where((m) => m['is_admin_reply'] == 0).length;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: unreadCount > 0 ? const Color(0xFF0A5CFF).withOpacity(0.3) : Colors.white10),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: const Color(0xFF0A5CFF).withOpacity(0.1),
                child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : "?", style: const TextStyle(color: Color(0xFF0A5CFF), fontWeight: FontWeight.bold)),
              ),
              title: Row(
                children: [
                  Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF0A5CFF), borderRadius: BorderRadius.circular(10)),
                      child: Text('$unreadCount NEW', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  lastMsg['content'] as String? ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                ),
              ),
              trailing: const Icon(Icons.reply_rounded, color: Colors.white24, size: 20),
              onTap: () => _showChatThread(userName, messages),
            ),
          ),
        );
      },
    );
  }

  void _showChatThread(String userName, List<Map<String, dynamic>> thread) {
    final TextEditingController replyController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Row(
                  children: [
                    Text('Inquiry: $userName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  reverse: true, // Show latest at bottom
                  padding: const EdgeInsets.all(20),
                  itemCount: thread.length,
                  itemBuilder: (context, index) {
                    final msg = thread[index];
                    bool isAdmin = (msg['sender'] as String? ?? "") == 'ADMIN';
                    return Align(
                      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAdmin ? const Color(0xFF0A5CFF) : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(msg['content'] as String? ?? "", style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                color: const Color(0xFF1E293B),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Type official reply...',
                          hintStyle: TextStyle(color: Colors.white24),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFF0A5CFF)),
                      onPressed: () async {
                        if (replyController.text.isNotEmpty) {
                          final reply = {
                            'sender': 'ADMIN',
                            'recipient': userName,
                            'content': replyController.text,
                            'timestamp': DateTime.now().toIso8601String(),
                            'is_admin_reply': 1,
                          };
                          await DatabaseService.instance.createMessage(reply);
                          replyController.clear();
                          
                          // Refresh thread locally in modal
                          final updatedData = await DatabaseService.instance.readAllAdminMessages();
                          setModalState(() {
                            thread.clear();
                            final Map<String, List<Map<String, dynamic>>> grouped = {};
                            for (var msg in updatedData) {
                              final u = msg['sender'] == 'ADMIN' ? msg['recipient'] : msg['sender'];
                              if (!grouped.containsKey(u)) grouped[u] = [];
                              grouped[u]!.add(msg);
                            }
                            thread.addAll(grouped[userName]!);
                          });
                          _loadAllMessages(); // Refresh background list
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
