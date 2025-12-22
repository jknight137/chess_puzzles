import 'package:flutter/material.dart';

import 'screens/puzzle_list_page.dart';

void main() {
  runApp(const WoodpeckerApp());
}

class WoodpeckerApp extends StatelessWidget {
  const WoodpeckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Woodpecker Trainer',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B82F6),
      ),
      home: const PuzzleListPage(),
    );
  }
}
