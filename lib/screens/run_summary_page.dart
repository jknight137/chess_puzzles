import 'package:flutter/material.dart';

import '../models/run_result.dart';
import '../utils/format.dart';

class RunSummaryPage extends StatelessWidget {
  const RunSummaryPage({
    super.key,
    required this.result,
    required this.onPlayAgain,
  });

  final RunResult result;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Run Complete')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(result.setTitle,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Text('Score: ${result.score}',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('Time: ${formatDurationMs(result.durationMs)}'),
                    Text(
                        'Solved: ${result.puzzlesSolved}/${result.puzzlesTotal}'),
                    Text('Wrong moves: ${result.wrongMoves}'),
                    Text('Hints used: ${result.hintsUsed}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPlayAgain,
                child: const Text('Play Another Run'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
