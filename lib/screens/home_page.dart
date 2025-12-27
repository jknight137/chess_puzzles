import 'package:flutter/material.dart';

import '../models/puzzle_set_def.dart';
import 'endgame_list_page.dart';
import 'leaderboard_page.dart';
import 'puzzle_set_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static final List<PuzzleSetDef> _woodpeckerSets = [
    PuzzleSetDef(
      id: 'woodpecker_ch1_easy',
      title: 'Woodpecker: Chapter 1 (Easy)',
      assetPath: 'assets/puzzles/chapter1_easy_puzzles.json',
    ),
    PuzzleSetDef(
      id: 'woodpecker_ch2_intermediate',
      title: 'Woodpecker: Chapter 2 (Intermediate)',
      assetPath: 'assets/puzzles/chapter2_intermediate_puzzles.json',
    ),
    PuzzleSetDef(
      id: 'woodpecker_ch3_advanced',
      title: 'Woodpecker: Chapter 3 (Advanced)',
      assetPath: 'assets/puzzles/chapter3_advanced_puzzles.json',
    ),
  ];

  void _openLeaderboard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LeaderboardPage()),
    );
  }

  void _openSet(BuildContext context, PuzzleSetDef setDef) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PuzzleSetPage(setDef: setDef)),
    );
  }

  void _openEndgames(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EndgameListPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            const Text("Knight's Gambit"),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _openLeaderboard(context),
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Leaderboard',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.06,
                child: Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 320,
                    height: 320,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: ExpansionTile(
                  initiallyExpanded: false,
                  leading: const Icon(Icons.flash_on_outlined),
                  title: const Text('Tactics (Woodpecker Method)'),
                  subtitle: const Text('3 sets'),
                  children: [
                    for (final s in _woodpeckerSets)
                      ListTile(
                        title: Text(s.title),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openSet(context, s),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Keep new content at the bottom: put Endgame Trainer after tactics.
              Card(
                child: ListTile(
                  leading: const Icon(Icons.flag),
                  title: const Text('Endgame Trainer'),
                  subtitle: const Text('200 endgames'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openEndgames(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
