import 'package:flutter/material.dart';
import 'features/auth/screens/terms_conditions_screen.dart';

void main() {
  runApp(const CommunityWatchApp());
}

class CommunityWatchApp extends StatelessWidget {
  const CommunityWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Community Watch',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A5CFF),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF0A5CFF),
          secondary: const Color(0xFFFB923C),
          surface: const Color(0xFF0F172A),
          error: const Color(0xFFFF3B30),
        ),
        scaffoldBackgroundColor: const Color(0xFF020617),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2.0,
            color: Colors.white,
          ),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B).withOpacity(0.7),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0F172A),
          indicatorColor: const Color(0xFF0A5CFF).withOpacity(0.15),
          labelTextStyle: MaterialStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          iconTheme: MaterialStateProperty.all(
            const IconThemeData(size: 24),
          ),
        ),
      ),
      home: const TermsConditionsScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
