import 'package:flutter/material.dart';

import '../models/run_result.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late Future<List<RunResult>> _runsFuture;

  @override
  void initState() {
    super.initState();
    _runsFuture = StorageService.instance.loadRuns();
  }

  Future<void> _refresh() async {
    setState(() {
      _runsFuture = StorageService.instance.loadRuns();
    });
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Clear leaderboard?'),
          content: const Text('This removes all saved runs on this device.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Clear')),
          ],
        );
      },
    );

    if (ok != true) return;

    await StorageService.instance.clearRuns();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _clear, icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: FutureBuilder<List<RunResult>>(
        future: _runsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final runs = snap.data ?? <RunResult>[];
          if (runs.isEmpty) {
            return const Center(
                child: Text('No runs yet. Start a run to appear here.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: runs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = runs[i];
              return Card(
                child: ListTile(
                  title: Text('${i + 1}. ${r.setTitle}'),
                  subtitle: Text(
                    'Score ${r.score}  Time ${formatDurationMs(r.durationMs)}  Wrong ${r.wrongMoves}  Hints ${r.hintsUsed}\n'
                    '${formatDateTimeShort(r.startedAt)}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
