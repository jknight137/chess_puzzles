import 'package:flutter/material.dart';

import '../models/endgame_lesson.dart';
import '../services/storage_service.dart';

class EndgamePlayPage extends StatefulWidget {
  const EndgamePlayPage({
    super.key,
    required this.lessons,
    required this.initialIndex,
    required this.completed,
  });

  final List<EndgameLesson> lessons;
  final int initialIndex;
  final Set<int> completed;

  @override
  State<EndgamePlayPage> createState() => _EndgamePlayPageState();
}

class _EndgamePlayPageState extends State<EndgamePlayPage> {
  late int _index;
  bool _showSolution = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.lessons.length - 1);
  }

  EndgameLesson get _lesson => widget.lessons[_index];

  bool get _isCompleted => widget.completed.contains(_lesson.id);

  Future<void> _toggleCompleted() async {
    final completed = await StorageService.instance.loadEndgameCompleted();
    if (completed.contains(_lesson.id)) {
      completed.remove(_lesson.id);
    } else {
      completed.add(_lesson.id);
    }
    await StorageService.instance.saveEndgameCompleted(completed);
    setState(() {
      widget.completed
        ..clear()
        ..addAll(completed);
    });
  }

  void _next() {
    if (_index < widget.lessons.length - 1) {
      setState(() {
        _index += 1;
        _showSolution = false;
      });
    }
  }

  void _prev() {
    if (_index > 0) {
      setState(() {
        _index -= 1;
        _showSolution = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = _lesson;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ending ${l.id}'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final contentWidth = maxWidth > 560 ? 560.0 : maxWidth;
            final solutionMaxHeight = (constraints.maxHeight * 0.42).clamp(180.0, 420.0);
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DiagramCard(imageAsset: l.imageAsset),
                      const SizedBox(height: 12),
                      Text(
                        l.header,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l.cue,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () => setState(() => _showSolution = !_showSolution),
                              child: Text(_showSolution ? 'Hide solution' : 'Show solution'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _toggleCompleted,
                            icon: Icon(_isCompleted ? Icons.check_circle : Icons.circle_outlined),
                            label: Text(_isCompleted ? 'Completed' : 'Mark complete'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        crossFadeState: _showSolution ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outlineVariant),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: solutionMaxHeight),
                            child: Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                child: Text(
                                  l.solutionText,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _index == 0 ? null : _prev,
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Prev'),
                          ),
                          Text('${_index + 1}/${widget.lessons.length}', style: theme.textTheme.labelLarge),
                          OutlinedButton.icon(
                            onPressed: _index == widget.lessons.length - 1 ? null : _next,
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Next'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Source page: ${l.sourcePdfPage}',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

}

class _DiagramCard extends StatelessWidget {
  const _DiagramCard({required this.imageAsset});

  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary, width: 2),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          imageAsset,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
