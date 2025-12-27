import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/puzzle.dart';
import '../models/puzzle_set_def.dart';
import '../models/puzzle_stats.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';
import 'leaderboard_page.dart';
import 'puzzle_play_page.dart';

class PuzzleSetPage extends StatefulWidget {
  const PuzzleSetPage({super.key, required this.setDef});

  final PuzzleSetDef setDef;

  @override
  State<PuzzleSetPage> createState() => _PuzzleSetPageState();
}

class _PuzzleSetPageState extends State<PuzzleSetPage> {  bool _shuffleRun = true;

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
      final setDef = widget.setDef;
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

    final setDef = widget.setDef;

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
    final setDef = widget.setDef;

    return Scaffold(
      appBar: AppBar(
        title: Text(setDef.title),
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
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(setDef.title),
                subtitle: const Text('Select a puzzle and solve the full line.'),
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
