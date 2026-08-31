import 'package:flutter/material.dart';
import 'dart:ui';
import 'login_screen.dart';
import '../../../core/widgets/three_d_grid_background.dart';

class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({super.key});

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> with SingleTickerProviderStateMixin {
  bool _agreed = false;
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: Stack(
        children: [
          const ThreeDGridBackground(),
          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LEGAL_PROTOCOL',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3.0),
                    ),
                    const Text(
                      'USER_AGREEMENT_V1.4',
                      style: TextStyle(fontSize: 10, color: Color(0xFF0A5CFF), fontWeight: FontWeight.bold, letterSpacing: 2.0),
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: const SingleChildScrollView(
                              physics: BouncingScrollPhysics(),
                              child: Text(
                                'WELCOME TO THE COMMUNITY WATCH SECURE NETWORK.\n\n'
                                '1. GEOLOCATION_SYNC: We utilize real-time GPS tracking to map safety signals and coordinate tactical responses in Ghana sectors.\n\n'
                                '2. INTEL_INTEGRITY: Users are bound by oath to report accurate surveillance data. False signals result in immediate node termination.\n\n'
                                '3. ENCRYPTION_PRIVACY: Your identifying markers are protected by AES-256 protocols. Anonymity is optional but respected.\n\n'
                                '4. RESPONSE_PROTOCOL: This terminal is a visual intelligence tool. It does not replace emergency enforcement units.\n\n'
                                'INITIALIZING THIS TERMINAL CONSTITUTES ACCEPTANCE OF ALL DATA HARVESTING POLICIES.',
                                style: TextStyle(fontSize: 13, height: 1.8, color: Colors.white60, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () => setState(() => _agreed = !_agreed),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _agreed ? const Color(0xFF0A5CFF) : Colors.transparent,
                              border: Border.all(color: _agreed ? const Color(0xFF0A5CFF) : Colors.white24, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _agreed ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Text(
                              'I ACCEPT ALL MISSION PARAMETERS AND PRIVACY ENCRYPTION',
                              style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _agreed ? [
                          BoxShadow(color: const Color(0xFF0A5CFF).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                        ] : [],
                      ),
                      child: ElevatedButton(
                        onPressed: _agreed
                            ? () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                                )
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A5CFF),
                          disabledBackgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text('INITIALIZE_TERMINAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
