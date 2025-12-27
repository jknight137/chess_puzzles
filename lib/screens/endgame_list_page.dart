import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/endgame_lesson.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';
import 'endgame_play_page.dart';

class EndgameListPage extends StatefulWidget {
  const EndgameListPage({super.key});

  @override
  State<EndgameListPage> createState() => _EndgameListPageState();
}

class _EndgameListPageState extends State<EndgameListPage> {
  static const String _assetPath =
      'assets/puzzles/endgame_trainer_endings_cleaned.json';

  bool _loading = true;
  String? _error;

  List<EndgameLesson> _lessons = <EndgameLesson>[];
  Set<int> _completed = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw Exception('Unexpected JSON format for endgame lessons.');
      }

      final lessons = <EndgameLesson>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          lessons.add(EndgameLesson.fromJson(item));
        } else if (item is Map) {
          lessons.add(EndgameLesson.fromJson(item.cast<String, dynamic>()));
        }
      }

      final completed = await StorageService.instance.loadEndgameCompleted();

      setState(() {
        _lessons = lessons;
        _completed = completed;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openLesson(int index) async {
    final lesson = _lessons[index];
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EndgamePlayPage(
          lessons: _lessons,
          initialIndex: index,
          completed: _completed,
        ),
      ),
    );

    final completed = await StorageService.instance.loadEndgameCompleted();
    setState(() => _completed = completed);
  }

  Future<void> _resetProgress() async {
    await StorageService.instance.clearEndgameCompleted();
    setState(() => _completed = <int>{});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Endgame Trainer'),
        actions: [
          IconButton(
            tooltip: 'Reset progress',
            onPressed: _completed.isEmpty
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Reset endgame progress?'),
                        content: const Text(
                            'This will clear all completed endgames.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Reset')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await _resetProgress();
                    }
                  },
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: theme.textTheme.bodyLarge),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Find the best continuation. Tap an ending to study it.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${_completed.length}/${_lessons.length} completed',
                            style: theme.textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _lessons.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final l = _lessons[i];
                          final done = _completed.contains(l.id);
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: done
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceVariant,
                              foregroundColor: done
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                              child: Text(l.id.toString()),
                            ),
                            title: Text('${l.title}  ${l.header}'.trim()),
                            subtitle: Text(l.cue.isEmpty ? '' : l.cue),
                            trailing: done
                                ? const Icon(Icons.check_circle)
                                : const Icon(Icons.chevron_right),
                            onTap: () => _openLesson(i),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
