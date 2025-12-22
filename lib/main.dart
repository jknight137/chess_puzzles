import 'package:flutter/material.dart';

import 'screens/puzzle_list_page.dart';

void main() {
  runApp(const ChessPuzzlesApp());
}

class ChessPuzzlesApp extends StatelessWidget {
  const ChessPuzzlesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Woodpecker Chess Puzzles',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF1E40AF),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
        ),
        cardTheme: const CardTheme(
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
        ),
      ),
      home: const PuzzleListPage(),
    );
  }
}
