import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/puzzle.dart';
import '../models/puzzle_stats.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';
import 'leaderboard_page.dart';
import 'puzzle_play_page.dart';

class PuzzleSetDef {
  PuzzleSetDef({
    required this.id,
    required this.title,
    required this.assetPath,
  });

  final String id;
  final String title;
  final String assetPath;
}

class PuzzleListPage extends StatefulWidget {
  const PuzzleListPage({super.key});

  @override
  State<PuzzleListPage> createState() => _PuzzleListPageState();
}

class _PuzzleListPageState extends State<PuzzleListPage> {
  final _sets = <PuzzleSetDef>[
    PuzzleSetDef(
        id: 'c1_easy',
        title: 'Chapter 1  Easy',
        assetPath: 'assets/puzzles/chapter1_easy_puzzles.json'),
    PuzzleSetDef(
      id: 'c2_intermediate',
      title: 'Chapter 2  Intermediate',
      assetPath: 'assets/puzzles/chapter2_intermediate_puzzles.json',
    ),
    PuzzleSetDef(
      id: 'c3_advanced',
      title: 'Chapter 3  Advanced',
      assetPath: 'assets/puzzles/chapter3_advanced_puzzles.json',
    ),
  ];

  int _setIndex = 0;
  bool _shuffleRun = true;

  List<Puzzle> _puzzles = <Puzzle>[];
  Map<String, PuzzleStats> _stats = <String, PuzzleStats>{};

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final setDef = _sets[_setIndex];
      final raw = await rootBundle.loadString(setDef.assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw Exception('Puzzle JSON must be a list.');
      }

      final puzzles = decoded
          .map((e) => Puzzle.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final stats = await StorageService.instance.loadAllPuzzleStats();

      setState(() {
        _puzzles = puzzles;
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshStats() async {
    final stats = await StorageService.instance.loadAllPuzzleStats();
    setState(() => _stats = stats);
  }

  void _openLeaderboard() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const LeaderboardPage()));
  }

  void _startRun() async {
    if (_puzzles.isEmpty) return;

    final setDef = _sets[_setIndex];

    final list = List<Puzzle>.from(_puzzles);
    if (_shuffleRun) {
      list.shuffle(Random());
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzlePlayPage(
          puzzles: list,
          startIndex: 0,
          setId: setDef.id,
          setTitle: setDef.title,
          runMode: true,
        ),
      ),
    );

    await _refreshStats();
  }

  @override
  Widget build(BuildContext context) {
    final setDef = _sets[_setIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Woodpecker Trainer'),
        actions: [
          IconButton(
              onPressed: _openLeaderboard,
              icon: const Icon(Icons.emoji_events_outlined)),
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _startRun,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start Run'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _setIndex,
                            decoration:
                                const InputDecoration(labelText: 'Puzzle Set'),
                            items: [
                              for (var i = 0; i < _sets.length; i++)
                                DropdownMenuItem(
                                    value: i, child: Text(_sets[i].title)),
                            ],
                            onChanged: (v) async {
                              if (v == null) return;
                              setState(() => _setIndex = v);
                              await _loadAll();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Shuffle Run'),
                            Switch(
                              value: _shuffleRun,
                              onChanged: (v) => setState(() => _shuffleRun = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Loaded: ${setDef.assetPath}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _puzzles.isEmpty
                          ? const Center(child: Text('No puzzles found.'))
                          : ListView.separated(
                              itemCount: _puzzles.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final p = _puzzles[index];
                                final st = _stats[p.puzzleKey];

                                final best = st?.bestTimeMs == null
                                    ? '-'
                                    : formatDurationMs(st!.bestTimeMs!);
                                final attempts = st?.attempts ?? 0;
                                final solves = st?.solves ?? 0;

                                return Card(
                                  child: ListTile(
                                    title: Text('${index + 1}. ${p.title}'),
                                    subtitle: Text(
                                      'Attempts $attempts  Solves $solves  Best $best  Page ${p.bookPage ?? '-'}',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => PuzzlePlayPage(
                                            puzzles: _puzzles,
                                            startIndex: index,
                                            setId: setDef.id,
                                            setTitle: setDef.title,
                                            runMode: false,
                                          ),
                                        ),
                                      );
                                      await _refreshStats();
                                    },
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
