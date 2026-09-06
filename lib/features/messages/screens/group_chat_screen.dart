import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../core/services/auth_service.dart';
import '../../../core/services/database_service.dart';
import '../../map/screens/map_screen.dart';
import 'package:latlong2/latlong.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupName;
  const GroupChatScreen({super.key, required this.groupName});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Simulated Group Messages
  final List<Map<String, dynamic>> _messages = [
    {'sender': 'Officer_Kofi', 'content': 'Unit 4, reporting a suspicious vehicle near the north gate.', 'time': '10:05 AM', 'isMe': false},
    {'sender': 'Ama_Citizen', 'content': 'I see it too. Black SUV, no license plate?', 'time': '10:06 AM', 'isMe': false},
    {'sender': 'System', 'content': 'WATCH_LINK_ACTIVE: Sector surveillance synchronized.', 'type': 'SYSTEM', 'time': '10:07 AM'},
  ];

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'sender': AuthService.instance.currentUserName,
        'content': _controller.text,
        'time': 'Just now',
        'isMe': true,
      });
      _controller.clear();
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _activateWatchLink() {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blueAccent.withOpacity(0.3))),
          title: const Row(
            children: [
              Icon(Icons.hub_rounded, color: Colors.blueAccent),
              SizedBox(width: 12),
              Text('INITIALIZE_WATCH_LINK', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
            ],
          ),
          content: const Text(
            'Watch Link synchronizes your GPS and Camera with all members of this group for 30 minutes. This creates a virtual "Safe-Net" around your current sector.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL', style: TextStyle(color: Colors.white24))),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _messages.add({
                    'sender': 'System',
                    'content': 'WATCH_LINK_INITIALIZED: ${AuthService.instance.currentUserName} has established a secure link.',
                    'type': 'SYSTEM',
                    'time': 'Just now'
                  });
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WATCH_LINK_ESTABLISHED'), backgroundColor: Colors.blueAccent));
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text('ACTIVATE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.groupName.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            const Text('12 UNITS ACTIVE IN SECTOR', style: TextStyle(fontSize: 8, color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _activateWatchLink,
            icon: const Icon(Icons.hub_rounded, color: Colors.blueAccent),
            tooltip: 'Activate Watch Link',
          ),
          IconButton(
            onPressed: () {
               MapNavigationState.setTarget(const LatLng(5.6037, -0.1870), widget.groupName);
               // Switch to Map would happen in shell, but for now we just show feedback
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GROUP_MAP_SYNCED')));
            },
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          // Surveillance Status Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
            color: Colors.blueAccent.withOpacity(0.05),
            child: const Row(
              children: [
                Icon(Icons.security_rounded, size: 12, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('ENCRYPTED_GROUP_CHANNEL_ACTIVE', style: TextStyle(color: Colors.blueAccent, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                
                if (msg['type'] == 'SYSTEM') {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.05))),
                      child: Text(msg['content'], style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                  );
                }

                bool isMe = msg['isMe'] ?? false;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isMe ? const Color(0xFF0A5CFF) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMe ? 20 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Text(msg['sender'], style: const TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        if (!isMe) const SizedBox(height: 4),
                        Text(msg['content'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(msg['time'], style: const TextStyle(color: Colors.white24, fontSize: 8)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // INPUT DOCK
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            decoration: const BoxDecoration(color: Color(0xFF0F172A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Row(
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white24)),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(30)),
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(hintText: 'Transmit message...', hintStyle: TextStyle(color: Colors.white10), border: InputBorder.none),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Color(0xFF0A5CFF), shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
