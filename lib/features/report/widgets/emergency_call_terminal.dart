import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import '../../../core/services/browser_call_service.dart';
import '../../../core/services/auth_service.dart';

class EmergencyCallTerminal extends StatefulWidget {
  final String phoneNumber;
  final String agencyName;

  const EmergencyCallTerminal({
    super.key, 
    required this.phoneNumber, 
    required this.agencyName
  });

  @override
  State<EmergencyCallTerminal> createState() => _EmergencyCallTerminalState();
}

class _EmergencyCallTerminalState extends State<EmergencyCallTerminal> {
  bool _isConnecting = false;
  bool _isActive = false;
  bool _isMuted = false;
  int _seconds = 0;
  Timer? _timer;

  void _startTimer() {
    _timer?.cancel();
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String _formatDuration(int seconds) {
    final min = (seconds / 60).floor().toString().padLeft(2, '0');
    final sec = (seconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Future<void> _handleInitiateCall() async {
    setState(() => _isConnecting = true);
    
    // Initialize WebRTC device with user identity
    final success = await BrowserCallService.instance.initialize(AuthService.instance.currentUserName);
    
    if (success) {
      BrowserCallService.instance.makeCall(widget.phoneNumber);
      _isActive = true;
      _isConnecting = false;
      _startTimer();
    } else {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('VOICE_BRIDGE_FAILED: CHECK SERVER'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _handleEndCall() {
    BrowserCallService.instance.endCall();
    _timer?.cancel();
    if (mounted) setState(() => _isActive = false);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusHeader(),
          const SizedBox(height: 48),
          _buildIdentityVisual(),
          const SizedBox(height: 48),
          if (!_isActive && !_isConnecting) 
            _buildInitiateButton()
          else if (_isConnecting)
            _buildConnectingVisual()
          else
            _buildActiveCallControls(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Column(
      children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),
        Text(
          _isActive ? 'VOICE_LINK_ESTABLISHED' : (_isConnecting ? 'ESTABLISHING_ENCRYPTED_BRIDGE' : 'READY_TO_TRANSMIT'),
          style: TextStyle(
            color: _isActive ? const Color(0xFF34C759) : const Color(0xFF0A5CFF),
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 2.0
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityVisual() {
    return Column(
      children: [
        Text(
          widget.agencyName.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        Text(
          'SIGNAL_DEST: ${widget.phoneNumber}',
          style: const TextStyle(color: Colors.white24, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        if (_isActive) ...[
          const SizedBox(height: 24),
          Text(
            _formatDuration(_seconds),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w100, fontFamily: 'monospace'),
          ),
        ]
      ],
    );
  }

  Widget _buildInitiateButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        onPressed: _handleInitiateCall,
        icon: const Icon(Icons.call_rounded),
        label: const Text('INITIATE_WEB_CALL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A5CFF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildConnectingVisual() {
    return const Column(
      children: [
        CircularProgressIndicator(color: Color(0xFF0A5CFF)),
        SizedBox(height: 24),
        Text('SYNCING_WEBRTC_LAYERS...', style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActiveCallControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCircularAction(
          icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: _isMuted ? Colors.orangeAccent : Colors.white10,
          onTap: () {
            setState(() => _isMuted = !_isMuted);
            BrowserCallService.instance.setMute(_isMuted);
          },
        ),
        _buildCircularAction(
          icon: Icons.call_end_rounded,
          color: Colors.redAccent,
          iconColor: Colors.white,
          onTap: _handleEndCall,
          size: 72,
        ),
        _buildCircularAction(
          icon: Icons.volume_up_rounded,
          color: Colors.white10,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildCircularAction({required IconData icon, required Color color, required VoidCallback onTap, double size = 56, Color iconColor = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: size * 0.45),
      ),
    );
  }
}
