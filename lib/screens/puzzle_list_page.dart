import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/puzzle.dart';
import 'puzzle_play_page.dart';

class PuzzleListPage extends StatefulWidget {
  const PuzzleListPage({super.key});

  @override
  State<PuzzleListPage> createState() => _PuzzleListPageState();
}

class _PuzzleListPageState extends State<PuzzleListPage> {
  static const _sets = <_PuzzleSetSpec>[
    _PuzzleSetSpec(
      key: 'easy',
      title: 'Easy (Chapter 1)',
      assetPath: 'assets/puzzles/chapter1_easy_puzzles.json',
    ),
    _PuzzleSetSpec(
      key: 'intermediate',
      title: 'Intermediate (Chapter 2)',
      assetPath: 'assets/puzzles/chapter2_intermediate_puzzles.json',
    ),
    _PuzzleSetSpec(
      key: 'advanced',
      title: 'Advanced (Chapter 3)',
      assetPath: 'assets/puzzles/chapter3_advanced_puzzles.json',
    ),
  ];

  bool _loading = true;
  String? _error;

  final Map<String, List<Puzzle>> _puzzlesBySet = {};
  String _selectedSetKey = _sets.first.key;

  String _query = '';
  int _runSize = 25;

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
      for (final spec in _sets) {
        final jsonStr = await rootBundle.loadString(spec.assetPath);
        final raw = jsonDecode(jsonStr);

        if (raw is! List) {
          throw FormatException('Expected a JSON list at ${spec.assetPath}');
        }

        final list = raw
            .cast<Map<String, dynamic>>()
            .map(Puzzle.fromJson)
            .toList(growable: false);

        _puzzlesBySet[spec.key] = list;
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load puzzles.\n\n$e';
      });
    }
  }

  List<Puzzle> get _currentPuzzles =>
      _puzzlesBySet[_selectedSetKey] ?? const [];

  List<Puzzle> get _filteredPuzzles {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _currentPuzzles;

    return _currentPuzzles.where((p) {
      final pageText = (p.bookPage ?? '').toString();
      return p.title.toLowerCase().contains(q) ||
          p.id.toLowerCase().contains(q) ||
          pageText.contains(q);
    }).toList();
  }

  void _startRun({required bool shuffle}) {
    final base = List<Puzzle>.from(_filteredPuzzles);
    if (base.isEmpty) return;

    if (shuffle) base.shuffle(math.Random());

    final run =
        base.take(_runSize.clamp(1, base.length)).toList(growable: false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzlePlayPage(
          puzzles: run,
          setTitle: _setTitleForKey(_selectedSetKey),
        ),
      ),
    );
  }

  void _openSingle(Puzzle p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzlePlayPage(
          puzzles: [p],
          setTitle: _setTitleForKey(_selectedSetKey),
        ),
      ),
    );
  }

  String _setTitleForKey(String key) {
    return _sets.firstWhere((s) => s.key == key).title;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Woodpecker Puzzles'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(_error!),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final puzzles = _filteredPuzzles;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 12),
              _buildControlsCard(),
              const SizedBox(height: 12),
              Expanded(
                child: puzzles.isEmpty
                    ? const Center(child: Text('No puzzles found.'))
                    : ListView.separated(
                        itemCount: puzzles.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) =>
                            _buildPuzzleTile(puzzles[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final total = _currentPuzzles.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Training set',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedSetKey,
              items: _sets
                  .map((s) =>
                      DropdownMenuItem(value: s.key, child: Text(s.title)))
                  .toList(growable: false),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _selectedSetKey = v);
              },
              decoration: const InputDecoration(
                labelText: 'Choose set',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text('Puzzles: $total',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search by title, id, or book page',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Run size',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v.trim());
                      if (parsed == null) return;
                      setState(() => _runSize = parsed);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _filteredPuzzles.isEmpty
                        ? null
                        : () => _startRun(shuffle: true),
                    child: const Text('Start run'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuzzleTile(Puzzle p) {
    final page = p.bookPage == null ? '' : 'Page: ${p.bookPage}';

    return InkWell(
      onTap: () => _openSingle(p),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text('#${p.id}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title,
                        style: Theme.of(context).textTheme.titleSmall),
                    if (page.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(page, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text('Open'),
            ],
          ),
        ),
      ),
    );
  }
}

class _PuzzleSetSpec {
  const _PuzzleSetSpec({
    required this.key,
    required this.title,
    required this.assetPath,
  });

  final String key;
  final String title;
  final String assetPath;
}
