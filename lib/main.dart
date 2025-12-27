import 'package:flutter/material.dart';

import 'screens/splash_page.dart';

void main() {
  runApp(const KnightsGambitApp());
}

class KnightsGambitApp extends StatelessWidget {
  const KnightsGambitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Knight's Gambit",
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B82F6),
      ),
      home: const SplashPage(),
    );
  }
}
