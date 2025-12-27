import 'dart:async';
import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:simple_chess_board/simple_chess_board.dart';

import '../models/puzzle.dart';
import '../models/puzzle_stats.dart';
import '../models/run_result.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';
import 'run_summary_page.dart';

class PuzzlePlayPage extends StatefulWidget {
  const PuzzlePlayPage({
    super.key,
    required this.puzzles,
    this.startIndex = 0,
    required this.setId,
    required this.setTitle,
    required this.runMode,
  });

  final List<Puzzle> puzzles;
  final int startIndex;

  final String setId;
  final String setTitle;

  final bool runMode;

  @override
  State<PuzzlePlayPage> createState() => _PuzzlePlayPageState();
}

class _PuzzlePlayPageState extends State<PuzzlePlayPage> {
  static const double _pagePadding = 16;

  late int _index;

  late chess.Chess _game;
  String _fen = '';

  late String _solverSide; // 'w' or 'b' at starting position
  List<String> _line = <String>[];
  int _plyIndex = 0;

  bool _solved = false;
  bool _autoPlaying = false;

  String? _statusText;

  bool _showCoordinates = true;

  // Rotation behavior:
  // true  => side-to-move at bottom
  // false => solver side stays at bottom
  bool _rotateToSideToMove = true;

  BoardArrow? _lastMoveArrow;
  final Map<String, Color> _cellHighlights = <String, Color>{};

  // Gamification state
  late final int _runStartMs;
  int _runElapsedMs = 0;

  int _runScore = 0;
  int _runWrongMoves = 0;
  int _runHintsUsed = 0;
  int _runSolvedCount = 0;

  int _puzzleStartMs = 0;
  int _puzzleElapsedMs = 0;
  int _puzzleWrongMoves = 0;
  bool _puzzleHintUsed = false;

  Timer? _ticker;

  Puzzle get _puzzle => widget.puzzles[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, widget.puzzles.length - 1);

    _runStartMs = DateTime.now().millisecondsSinceEpoch;

    _loadPuzzle();

    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _runElapsedMs = now - _runStartMs;
        _puzzleElapsedMs = now - _puzzleStartMs;
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _loadPuzzle() {
    _game = _safeFromFen(_puzzle.fen);
    _fen = _game.fen;

    _solverSide = _sideToMoveFromFen(_puzzle.fen);

    _line = _parseSolutionTextToSanList(
      _puzzle.solutionLine,
      startFen: _puzzle.fen,
      fallbackBestMove: _puzzle.bestMoveSan,
    );

    _plyIndex = 0;
    _solved = false;
    _autoPlaying = false;
    _statusText = null;

    _cellHighlights.clear();
    _lastMoveArrow = null;

    _puzzleStartMs = DateTime.now().millisecondsSinceEpoch;
    _puzzleElapsedMs = 0;
    _puzzleWrongMoves = 0;
    _puzzleHintUsed = false;

    setState(() {});
    unawaited(_autoPlayUntilSolverTurnOrDone());
  }

  chess.Chess _safeFromFen(String fen) {
    try {
      return chess.Chess.fromFEN(fen);
    } catch (_) {
      return chess.Chess();
    }
  }

  String _sideToMoveFromFen(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && (parts[1] == 'w' || parts[1] == 'b'))
      return parts[1];
    return 'w';
  }

  String _currentSideToMove() => _sideToMoveFromFen(_fen);

  bool _isSolverTurn() => _currentSideToMove() == _solverSide;

  String _normalizeSan(String san) {
    var s = san.trim();

    s = s.replaceAll('0-0-0', 'O-O-O');
    s = s.replaceAll('0-0', 'O-O');

    s = s.replaceAll(RegExp(r'\s+'), '');

    while (s.isNotEmpty && (s.endsWith('!') || s.endsWith('?'))) {
      s = s.substring(0, s.length - 1);
    }

    while (s.isNotEmpty) {
      final last = s[s.length - 1];
      if (last == '.' ||
          last == ',' ||
          last == ';' ||
          last == ':' ||
          last == ')' ||
          last == '"' ||
          last == '\'') {
        s = s.substring(0, s.length - 1);
        continue;
      }
      break;
    }

    return s;
  }

  bool _isBareSquareToken(String s) {
    return RegExp(r'^[a-h][1-8](?:\+{1,2}|#)?$').hasMatch(s);
  }

  bool _looksLikeSanMove(String s) {
    final t = _normalizeSan(s);

    if (t == 'O-O' || t == 'O-O-O') return true;
    if (t == 'O-O+' || t == 'O-O#' || t == 'O-O-O+' || t == 'O-O-O#')
      return true;

    final r = RegExp(
      r'^(?:[KQRBN])?(?:[a-h]|[1-8])?(?:[a-h]|[1-8])?x?[a-h][1-8](?:=[QRBN])?(?:\+{1,2}|#)?$',
    );
    return r.hasMatch(t);
  }

  List<String> _parseSolutionTextToSanList(
    String raw, {
    required String startFen,
    required String fallbackBestMove,
  }) {
    final text = raw.trim();
    if (text.isEmpty) {
      final b = _normalizeSan(fallbackBestMove);
      return b.isEmpty ? <String>[] : <String>[b];
    }

    final words =
        text.replaceAll('\n', ' ').replaceAll('\r', ' ').split(RegExp(r'\s+'));
    final out = <String>[];

    String prevLower = '';
    bool haveSeenMove = false;

    for (final rawTok in words) {
      final rawToken = rawTok.trim();
      if (rawToken.isEmpty) continue;

      final rawLower = rawToken.toLowerCase();

      final hadMovePrefix = RegExp(r'^\d+\.+').hasMatch(rawToken);

      var t = rawToken;
      t = t.replaceFirst(RegExp(r'^\d+\.+'), '');

      while (t.isNotEmpty) {
        final c = t[0];
        if (c == '(' || c == '[' || c == '{' || c == '"' || c == '\'') {
          t = t.substring(1);
          continue;
        }
        break;
      }

      t = _normalizeSan(t);

      if (t.isEmpty) {
        prevLower = rawLower;
        continue;
      }

      // Handle cases where + or # gets separated into its own token.
      if ((t == '#' || t == '##') && out.isNotEmpty) {
        out[out.length - 1] = _normalizeSan(out.last + '#');
        prevLower = rawLower;
        continue;
      }
      if ((t == '+' || t == '++') && out.isNotEmpty) {
        out[out.length - 1] = _normalizeSan(out.last + t);
        prevLower = rawLower;
        continue;
      }

      if (!_looksLikeSanMove(t)) {
        prevLower = rawLower;
        continue;
      }

      // Avoid accidentally treating bare-square commentary like "on d6" as a move.
      if (_isBareSquareToken(t)) {
        final prevIsCommentWord = <String>{
          'on',
          'at',
          'from',
          'to',
          'in',
          'of',
          'with',
          'without',
          'bishop',
          'knight',
          'rook',
          'queen',
          'king',
          'pawn',
          'pinned',
        }.contains(prevLower);

        if (!haveSeenMove && !hadMovePrefix) {
          prevLower = rawLower;
          continue;
        }
        if (prevIsCommentWord) {
          prevLower = rawLower;
          continue;
        }
      }

      out.add(t);
      haveSeenMove = true;
      prevLower = rawLower;
    }

    // Verify candidates against the actual position so we do not include
    // continuation moves from commentary (example: "after 9.Nxg4").
    final verified = <String>[];
    final probe = _safeFromFen(startFen);

    Map<dynamic, dynamic>? findVerboseBySan(chess.Chess g, String expectedSan) {
      final target = _normalizeSan(expectedSan);
      final moves = g.moves(<String, dynamic>{'verbose': true});
      if (moves is! List) return null;
      for (final item in moves) {
        if (item is! Map) continue;
        final san = item['san']?.toString();
        if (san == null) continue;
        if (_normalizeSan(san) == target) return item;
      }
      return null;
    }

    bool applyVerbose(chess.Chess g, Map<dynamic, dynamic> m) {
      final from = m['from']?.toString().toLowerCase();
      final to = m['to']?.toString().toLowerCase();
      final promo = m['promotion']?.toString().toLowerCase();

      if (from == null || to == null) return false;

      final payload = <String, dynamic>{'from': from, 'to': to};
      if (promo != null && promo.isNotEmpty) payload['promotion'] = promo;
      return g.move(payload) == true;
    }

    for (final candidate in out) {
      final m = findVerboseBySan(probe, candidate);
      if (m == null) continue;
      if (!applyVerbose(probe, m)) continue;

      final san = m['san']?.toString();
      if (san == null) continue;
      verified.add(_normalizeSan(san));
    }

    if (verified.isNotEmpty) return verified;

    final b = _normalizeSan(fallbackBestMove);
    return b.isEmpty ? <String>[] : <String>[b];
  }

  String? _promotionToLetter(PieceType? promo) {
    if (promo == null) return null;
    switch (promo.name.toLowerCase()) {
      case 'queen':
        return 'q';
      case 'rook':
        return 'r';
      case 'bishop':
        return 'b';
      case 'knight':
        return 'n';
      default:
        return 'q';
    }
  }

  List<dynamic> _legalVerboseMoves() {
    final moves = _game.moves(<String, dynamic>{'verbose': true});
    if (moves is List) return moves;
    return const <dynamic>[];
  }

  Map<dynamic, dynamic>? _findVerboseMoveBySan(String expectedSan) {
    final target = _normalizeSan(expectedSan);
    for (final item in _legalVerboseMoves()) {
      if (item is! Map) continue;
      final san = item['san']?.toString();
      if (san == null) continue;
      if (_normalizeSan(san) == target) return item;
    }
    return null;
  }

  Map<dynamic, dynamic>? _findVerboseMoveByShortMove(ShortMove move) {
    final from = move.from.toLowerCase();
    final to = move.to.toLowerCase();
    final promo = _promotionToLetter(move.promotion);

    for (final item in _legalVerboseMoves()) {
      if (item is! Map) continue;

      final mFrom = item['from']?.toString().toLowerCase();
      final mTo = item['to']?.toString().toLowerCase();
      final mPromo = item['promotion']?.toString().toLowerCase();

      if (mFrom != from || mTo != to) continue;

      final promoOk = (promo == null && (mPromo == null || mPromo.isEmpty)) ||
          (promo != null && mPromo == promo);

      if (!promoOk) continue;
      return item;
    }

    return null;
  }

  bool _applyShortMove(ShortMove move) {
    final payload = <String, dynamic>{
      'from': move.from.toLowerCase(),
      'to': move.to.toLowerCase(),
    };

    final promo = _promotionToLetter(move.promotion);
    if (promo != null) payload['promotion'] = promo;

    final ok = _game.move(payload) == true;
    if (ok) {
      _fen = _game.fen;
      _lastMoveArrow =
          BoardArrow(from: move.from.toLowerCase(), to: move.to.toLowerCase());
    }
    return ok;
  }

  bool _applyVerboseMove(Map<dynamic, dynamic> m) {
    final from = m['from']?.toString().toLowerCase();
    final to = m['to']?.toString().toLowerCase();
    final promo = m['promotion']?.toString().toLowerCase();

    if (from == null || to == null) return false;

    final payload = <String, dynamic>{
      'from': from,
      'to': to,
    };
    if (promo != null && promo.isNotEmpty) payload['promotion'] = promo;

    final ok = _game.move(payload) == true;
    if (ok) {
      _fen = _game.fen;
      _lastMoveArrow = BoardArrow(from: from, to: to);
    }
    return ok;
  }

  void _resetToStart(String message, {required bool countedWrong}) {
    _game = _safeFromFen(_puzzle.fen);
    _fen = _game.fen;
    _plyIndex = 0;

    _solved = false;
    _autoPlaying = false;

    _statusText = message;

    _cellHighlights.clear();
    _lastMoveArrow = null;

    if (countedWrong) {
      _puzzleWrongMoves += 1;
      _runWrongMoves += 1;
      HapticFeedback.vibrate();
    }

    setState(() {});
    unawaited(_autoPlayUntilSolverTurnOrDone());
  }

  Future<void> _autoPlayUntilSolverTurnOrDone() async {
    if (_autoPlaying || _solved) return;
    if (!mounted) return;

    if (_isSolverTurn()) return;

    setState(() => _autoPlaying = true);

    try {
      while (mounted && !_solved && !_isSolverTurn()) {
        if (_plyIndex >= _line.length) {
          _solved = true;
          _statusText = 'Solved.';
          break;
        }

        final expected = _line[_plyIndex];
        final m = _findVerboseMoveBySan(expected);

        if (m == null) {
          _statusText = 'Could not apply response: $expected';
          break;
        }

        final ok = _applyVerboseMove(m);
        if (!ok) {
          _statusText = 'Could not apply response: $expected';
          break;
        }

        _plyIndex += 1;

        if (_plyIndex >= _line.length) {
          _solved = true;
          _statusText = 'Solved.';
          break;
        }

        await Future.delayed(const Duration(milliseconds: 160));
      }
    } finally {
      if (mounted) setState(() => _autoPlaying = false);
    }
  }

  int _computePuzzleScore() {
    const base = 1000;

    final seconds = (_puzzleElapsedMs / 1000).floor();
    final timePenalty = seconds * 10;

    final wrongPenalty = _puzzleWrongMoves * 200;
    final hintPenalty = _puzzleHintUsed ? 150 : 0;

    var score = base - timePenalty - wrongPenalty - hintPenalty;

    if (_puzzleWrongMoves == 0 && !_puzzleHintUsed) {
      score += 150;
      if (seconds <= 10) score += 100;
    }

    if (score < 0) score = 0;
    return score;
  }

  Future<void> _onSolved() async {
    final puzzleScore = _computePuzzleScore();

    _runScore += puzzleScore;
    _runSolvedCount += 1;

    HapticFeedback.lightImpact();

    final nowIso = DateTime.now().toIso8601String();

    final existing =
        await StorageService.instance.getPuzzleStats(_puzzle.puzzleKey);
    final updatedBest = (existing.bestTimeMs == null)
        ? _puzzleElapsedMs
        : math.min(existing.bestTimeMs!, _puzzleElapsedMs);

    final updated = existing.copyWith(
      attempts: existing.attempts + 1,
      solves: existing.solves + 1,
      bestTimeMs: updatedBest,
      lastSolvedIso: nowIso,
    );

    await StorageService.instance.upsertPuzzleStats(updated);

    setState(() {
      _solved = true;
      _statusText = 'Solved. +$puzzleScore';
    });
  }

  void _onUserMove(ShortMove move) async {
    if (_solved || _autoPlaying) return;

    if (!_isSolverTurn()) {
      setState(() => _statusText = 'Wait for the response.');
      return;
    }

    if (_plyIndex >= _line.length) {
      await _onSolved();
      return;
    }

    final expected = _normalizeSan(_line[_plyIndex]);

    final verbose = _findVerboseMoveByShortMove(move);
    if (verbose == null) {
      _resetToStart('Illegal move.', countedWrong: true);
      return;
    }

    final playedSan = verbose['san']?.toString() ?? '';
    final played = _normalizeSan(playedSan);

    if (played != expected) {
      _resetToStart('Incorrect.', countedWrong: true);
      return;
    }

    final ok = _applyShortMove(move);
    if (!ok) {
      _resetToStart('Illegal move.', countedWrong: true);
      return;
    }

    _plyIndex += 1;
    _cellHighlights.clear();

    if (_plyIndex >= _line.length) {
      await _onSolved();
      return;
    }

    setState(() => _statusText = 'Correct.');
    unawaited(_autoPlayUntilSolverTurnOrDone());
  }

  void _revealHint() {
    if (_solved) return;

    if (!_isSolverTurn()) {
      setState(() => _statusText = 'Wait for the response.');
      return;
    }

    if (_plyIndex >= _line.length) {
      setState(() => _statusText = 'Solved.');
      return;
    }

    final expected = _line[_plyIndex];
    _cellHighlights.clear();

    final m = _findVerboseMoveBySan(expected);
    if (m != null) {
      final from = m['from']?.toString().toLowerCase();
      final to = m['to']?.toString().toLowerCase();
      if (from != null) _cellHighlights[from] = Colors.yellow.withAlpha(90);
      if (to != null) _cellHighlights[to] = Colors.yellow.withAlpha(90);
    }

    if (!_puzzleHintUsed) {
      _puzzleHintUsed = true;
      _runHintsUsed += 1;
    }

    setState(() => _statusText = 'Hint shown.');
  }

  Future<void> _finishRunIfNeeded() async {
    if (!widget.runMode) return;
    if (_index + 1 < widget.puzzles.length) return;

    final now = DateTime.now();
    final started = DateTime.fromMillisecondsSinceEpoch(_runStartMs);

    final result = RunResult(
      id: '${started.millisecondsSinceEpoch}_${widget.setId}',
      setId: widget.setId,
      setTitle: widget.setTitle,
      startedIso: started.toIso8601String(),
      finishedIso: now.toIso8601String(),
      durationMs: _runElapsedMs,
      puzzlesTotal: widget.puzzles.length,
      puzzlesSolved: _runSolvedCount,
      wrongMoves: _runWrongMoves,
      hintsUsed: _runHintsUsed,
      score: _runScore,
    );

    await StorageService.instance.addRun(result);

    if (!mounted) return;

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RunSummaryPage(
          result: result,
          onPlayAgain: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _goNext() async {
    if (_index + 1 >= widget.puzzles.length) {
      await _finishRunIfNeeded();
      if (!widget.runMode && mounted) Navigator.of(context).pop();
      return;
    }

    _index += 1;
    _loadPuzzle();
  }

  List<String> _files(bool blackAtBottom) {
    final aToH = <String>['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    return blackAtBottom ? aToH.reversed.toList() : aToH;
  }

  List<String> _ranksTopToBottom(bool blackAtBottom) {
    final eightToOne = <String>['8', '7', '6', '5', '4', '3', '2', '1'];
    final oneToEight = <String>['1', '2', '3', '4', '5', '6', '7', '8'];
    return blackAtBottom ? oneToEight : eightToOne;
  }

  TextStyle _coordTextStyle(BuildContext context, double fontSize) {
    final base = Theme.of(context).textTheme.labelSmall ?? const TextStyle();
    return base.copyWith(fontSize: fontSize, height: 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final currentSide = _currentSideToMove();
    final blackAtBottom =
        _rotateToSideToMove ? (currentSide == 'b') : (_solverSide == 'b');

    final whiteType =
        _solverSide == 'w' ? PlayerType.human : PlayerType.computer;
    final blackType =
        _solverSide == 'b' ? PlayerType.human : PlayerType.computer;

    final runTime = formatDurationMs(_runElapsedMs);
    final puzzleTime = formatDurationMs(_puzzleElapsedMs);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setTitle),
        actions: [
          Center(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Run $runTime'))),
          Center(
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('Score $_runScore'))),
          IconButton(
              onPressed: _revealHint,
              icon: const Icon(Icons.lightbulb_outline)),
          IconButton(
            onPressed: () =>
                setState(() => _showCoordinates = !_showCoordinates),
            icon: Icon(_showCoordinates ? Icons.grid_on : Icons.grid_off),
          ),
          IconButton(
            onPressed: () =>
                setState(() => _rotateToSideToMove = !_rotateToSideToMove),
            icon: const Icon(Icons.screen_rotation_alt_outlined),
          ),
          IconButton(
            onPressed: () => _resetToStart('Reset.', countedWrong: false),
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: OrientationBuilder(
            builder: (context, orientation) {
              final info = _buildInfoPanel(puzzleTime);
              final board =
                  _buildBoardArea(blackAtBottom, whiteType, blackType);

              if (orientation == Orientation.landscape) {
                return Row(
                  children: [
                    Expanded(child: board),
                    const SizedBox(width: 16),
                    SizedBox(width: 340, child: info),
                  ],
                );
              }

              return Column(
                children: [
                  info,
                  const SizedBox(height: 12),
                  Expanded(child: board),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel(String puzzleTime) {
    final total = _line.length;
    final step = total == 0 ? '-' : '${math.min(_plyIndex + 1, total)}/$total';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_puzzle.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              _isSolverTurn() ? 'Your move' : 'Response',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Puzzle ${_index + 1}/${widget.puzzles.length}  Line $step',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Puzzle time $puzzleTime  Wrong $_puzzleWrongMoves  Hint ${_puzzleHintUsed ? "Yes" : "No"}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (_statusText != null) ...[
              Text(_statusText!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
            ],
            if (_autoPlaying)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator())),
            if (_solved)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _goNext,
                  child: Text((_index + 1 >= widget.puzzles.length)
                      ? (widget.runMode ? 'Finish Run' : 'Back')
                      : 'Next Puzzle'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardArea(
      bool blackAtBottom, PlayerType whiteType, PlayerType blackType) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final minSide = math.min(maxW, maxH);

        final coordThickness = _showCoordinates
            ? math.max(18.0, math.min(28.0, minSide * 0.07))
            : 0.0;
        final gap = _showCoordinates ? 6.0 : 0.0;

        final boardSide =
            math.max(220.0, minSide - (coordThickness * 2) - (gap * 2));
        final totalSide = boardSide + (coordThickness * 2) + (gap * 2);

        final files = _files(blackAtBottom);
        final ranks = _ranksTopToBottom(blackAtBottom);

        final coordFont = math.max(11.0, coordThickness * 0.55);

        final boardWidget = Container(
          width: boardSide,
          height: boardSide,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF3B82F6), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x663B82F6),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SimpleChessBoard(
              chessBoardColors: ChessBoardColors(),
              fen: _fen,
              engineThinking: _autoPlaying,
              blackSideAtBottom: blackAtBottom,
              whitePlayerType: whiteType,
              blackPlayerType: blackType,
              showPossibleMoves: true,
              showCoordinatesZone: false,
              cellHighlights: _cellHighlights,
              lastMoveToHighlight: _lastMoveArrow,
              onTap: ({required String cellCoordinate}) {},
              onMove: ({required ShortMove move}) => _onUserMove(move),
              onPromote: () async => PieceType.queen,
              onPromotionCommited: ({
                required ShortMove moveDone,
                required PieceType pieceType,
              }) {
                moveDone.promotion = pieceType;
                _onUserMove(moveDone);
              },
            ),
          ),
        );

        if (!_showCoordinates) {
          return Center(
              child: SizedBox(
                  width: boardSide, height: boardSide, child: boardWidget));
        }

        return Center(
          child: SizedBox(
            width: totalSide,
            height: totalSide,
            child: Column(
              children: [
                SizedBox(
                  height: coordThickness,
                  child: Row(
                    children: [
                      SizedBox(width: coordThickness),
                      SizedBox(width: gap),
                      Expanded(
                        child: Row(
                          children: [
                            for (final f in files)
                              Expanded(
                                  child: Center(
                                      child: Text(f,
                                          style: _coordTextStyle(
                                              context, coordFont)))),
                          ],
                        ),
                      ),
                      SizedBox(width: gap),
                      SizedBox(width: coordThickness),
                    ],
                  ),
                ),
                SizedBox(height: gap),
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: coordThickness,
                        child: Column(
                          children: [
                            for (final r in ranks)
                              Expanded(
                                  child: Center(
                                      child: Text(r,
                                          style: _coordTextStyle(
                                              context, coordFont)))),
                          ],
                        ),
                      ),
                      SizedBox(width: gap),
                      SizedBox(
                          width: boardSide,
                          height: boardSide,
                          child: boardWidget),
                      SizedBox(width: gap),
                      SizedBox(
                        width: coordThickness,
                        child: Column(
                          children: [
                            for (final r in ranks)
                              Expanded(
                                  child: Center(
                                      child: Text(r,
                                          style: _coordTextStyle(
                                              context, coordFont)))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: gap),
                SizedBox(
                  height: coordThickness,
                  child: Row(
                    children: [
                      SizedBox(width: coordThickness),
                      SizedBox(width: gap),
                      Expanded(
                        child: Row(
                          children: [
                            for (final f in files)
                              Expanded(
                                  child: Center(
                                      child: Text(f,
                                          style: _coordTextStyle(
                                              context, coordFont)))),
                          ],
                        ),
                      ),
                      SizedBox(width: gap),
                      SizedBox(width: coordThickness),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
