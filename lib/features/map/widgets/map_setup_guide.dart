import 'package:flutter/material.dart';

class MapSetupGuide extends StatelessWidget {
  const MapSetupGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.map_rounded, size: 64, color: Colors.redAccent),
              ),
              const SizedBox(height: 24),
              const Text(
                'GOOGLE MAPS NOT INITIALIZED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'The map cannot load because a valid API Key is missing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 32),
              _buildStep(
                '1',
                'Get an API Key from Google Cloud Console (ensure Maps JavaScript API is enabled).',
              ),
              _buildStep(
                '2',
                'Open web/index.html and replace YOUR_GOOGLE_MAPS_API_KEY_HERE on line 30.',
              ),
              _buildStep(
                '3',
                'Open android/app/src/main/AndroidManifest.xml and replace the key on line 12.',
              ),
              const SizedBox(height: 40),
              const Text(
                '⚠️ Without this key, the map will display "InvalidKeyMapError".',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF0A5CFF),
            child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
