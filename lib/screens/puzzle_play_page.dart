import 'dart:async';
import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:simple_chess_board/simple_chess_board.dart';

import '../models/puzzle.dart';

class PuzzlePlayPage extends StatefulWidget {
  const PuzzlePlayPage({
    super.key,
    required this.puzzles,
    this.startIndex = 0,
    this.setTitle,
  });

  final List<Puzzle> puzzles;
  final int startIndex;
  final String? setTitle;

  @override
  State<PuzzlePlayPage> createState() => _PuzzlePlayPageState();
}

class _PuzzlePlayPageState extends State<PuzzlePlayPage> {
  static const double _pagePadding = 16;

  late int _index;

  int _wrong = 0;

  late chess.Chess _game;
  String _fen = '';

  late String _solverSide; // 'w' or 'b' at starting position
  List<String> _line = <String>[];
  int _plyIndex = 0;

  bool _solved = false;
  bool _autoPlaying = false;

  String? _statusText;
  bool _hintRevealed = false;

  bool _showCoordinates = true;

  // Rotation behavior:
  // true  => side-to-move at bottom
  // false => solver side stays at bottom
  bool _rotateToSideToMove = true;

  BoardArrow? _lastMoveArrow;
  final Map<String, Color> _cellHighlights = <String, Color>{};

  Puzzle get _puzzle => widget.puzzles[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, widget.puzzles.length - 1);
    _loadPuzzle();
  }

  void _loadPuzzle() {
    _game = _safeFromFen(_puzzle.fen);
    _fen = _game.fen;

    _solverSide = _sideToMoveFromFen(_puzzle.fen);

    _line = _parseSolutionTextToSanList(
      _puzzle.solutionLine,
      fallbackBestMove: _puzzle.bestMoveSan,
    );

    _plyIndex = 0;
    _solved = false;
    _autoPlaying = false;
    _statusText = null;
    _hintRevealed = false;
    _cellHighlights.clear();
    _lastMoveArrow = null;

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
    if (parts.length >= 2 && (parts[1] == 'w' || parts[1] == 'b')) return parts[1];
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
    if (t == 'O-O+' || t == 'O-O#' || t == 'O-O-O+' || t == 'O-O-O#') return true;

    final r = RegExp(
      r'^(?:[KQRBN])?(?:[a-h]|[1-8])?(?:[a-h]|[1-8])?x?[a-h][1-8](?:=[QRBN])?(?:\+{1,2}|#)?$',
    );
    return r.hasMatch(t);
  }

  List<String> _parseSolutionTextToSanList(String raw, {required String fallbackBestMove}) {
    final text = raw.trim();
    if (text.isEmpty) {
      final b = _normalizeSan(fallbackBestMove);
      return b.isEmpty ? <String>[] : <String>[b];
    }

    final words = text.replaceAll('\n', ' ').replaceAll('\r', ' ').split(RegExp(r'\s+'));
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

    if (out.isEmpty) {
      final b = _normalizeSan(fallbackBestMove);
      return b.isEmpty ? <String>[] : <String>[b];
    }

    return out;
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

      final promoOk =
          (promo == null && (mPromo == null || mPromo.isEmpty)) || (promo != null && mPromo == promo);

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
      _lastMoveArrow = BoardArrow(from: move.from.toLowerCase(), to: move.to.toLowerCase());
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

  void _resetToStart(String message) {
    _game = _safeFromFen(_puzzle.fen);
    _fen = _game.fen;
    _plyIndex = 0;

    _solved = false;
    _autoPlaying = false;

    _statusText = message;
    _hintRevealed = false;

    _cellHighlights.clear();
    _lastMoveArrow = null;

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

  void _onUserMove(ShortMove move) {
    if (_solved || _autoPlaying) return;

    if (!_isSolverTurn()) {
      setState(() => _statusText = 'Wait for the response.');
      return;
    }

    if (_plyIndex >= _line.length) {
      setState(() {
        _solved = true;
        _statusText = 'Solved.';
      });
      return;
    }

    final expected = _normalizeSan(_line[_plyIndex]);

    final verbose = _findVerboseMoveByShortMove(move);
    if (verbose == null) {
      _wrong += 1;
      _resetToStart('Illegal move.');
      return;
    }

    final playedSan = verbose['san']?.toString() ?? '';
    final played = _normalizeSan(playedSan);

    if (played != expected) {
      _wrong += 1;
      _resetToStart('Incorrect. Try again.');
      return;
    }

    final ok = _applyShortMove(move);
    if (!ok) {
      _wrong += 1;
      _resetToStart('Illegal move.');
      return;
    }

    _plyIndex += 1;
    _cellHighlights.clear();

    if (_plyIndex >= _line.length) {
      setState(() {
        _solved = true;
        _statusText = 'Solved.';
      });
      return;
    }

    setState(() => _statusText = 'Correct.');

    unawaited(_autoPlayUntilSolverTurnOrDone());
  }

  void _revealHint() {
    if (_solved) return;

    if (!_isSolverTurn()) {
      setState(() {
        _hintRevealed = true;
        _statusText = 'Wait for the response.';
      });
      return;
    }

    if (_plyIndex >= _line.length) {
      setState(() {
        _hintRevealed = true;
        _statusText = 'Solved.';
      });
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

    setState(() {
      _hintRevealed = true;
      _statusText = 'Hint: $expected';
    });
  }

  void _goNext() {
    if (_index + 1 >= widget.puzzles.length) {
      Navigator.of(context).pop();
      return;
    }
    _index += 1;
    _loadPuzzle();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.setTitle?.trim().isNotEmpty == true ? widget.setTitle!.trim() : 'Puzzle';

    final currentSide = _currentSideToMove();
    final blackAtBottom = _rotateToSideToMove ? (currentSide == 'b') : (_solverSide == 'b');

    final whiteType = _solverSide == 'w' ? PlayerType.human : PlayerType.computer;
    final blackType = _solverSide == 'b' ? PlayerType.human : PlayerType.computer;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(onPressed: _revealHint, child: const Text('Hint')),
          TextButton(
            onPressed: () => setState(() => _showCoordinates = !_showCoordinates),
            child: Text(_showCoordinates ? 'Coords: On' : 'Coords: Off'),
          ),
          TextButton(
            onPressed: () => setState(() => _rotateToSideToMove = !_rotateToSideToMove),
            child: Text(_rotateToSideToMove ? 'Rotate: Turn' : 'Rotate: Solver'),
          ),
          TextButton(
            onPressed: () => _resetToStart('Reset.'),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(_pagePadding),
          child: OrientationBuilder(
            builder: (context, orientation) {
              if (orientation == Orientation.landscape) {
                return Row(
                  children: [
                    Expanded(child: _buildBoardArea(blackAtBottom, whiteType, blackType)),
                    const SizedBox(width: 16),
                    SizedBox(width: 320, child: _buildInfoPanel()),
                  ],
                );
              }
              return Column(
                children: [
                  _buildInfoPanel(),
                  const SizedBox(height: 12),
                  Expanded(child: _buildBoardArea(blackAtBottom, whiteType, blackType)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
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
              'Book page: ${_puzzle.bookPage ?? '-'}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 8,
              children: [
                Text('Puzzle: ${_index + 1}/${widget.puzzles.length}'),
                Text('Line: $step'),
                Text('Wrong: $_wrong'),
              ],
            ),
            const SizedBox(height: 10),
            if (_statusText != null) ...[
              Text(_statusText!, textAlign: TextAlign.center),
              const SizedBox(height: 10),
            ],
            if (_autoPlaying)
              const Center(child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator())),
            if (_solved)
              FilledButton(
                onPressed: _goNext,
                child: Text((_index + 1 >= widget.puzzles.length) ? 'Back to list' : 'Next puzzle'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardArea(bool blackAtBottom, PlayerType whiteType, PlayerType blackType) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSide = math.min(constraints.maxWidth, constraints.maxHeight);
        final outer = math.max(220.0, maxSide);

        // Give the board a big virtual canvas so coordinates never clip.
        final virtual = _showCoordinates ? 820.0 : 760.0;

        return Center(
          child: SizedBox(
            width: outer,
            height: outer,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: SizedBox(
                width: virtual,
                height: virtual,
                child: SimpleChessBoard(
                  chessBoardColors: ChessBoardColors(),
                  fen: _fen,
                  engineThinking: _autoPlaying,
                  blackSideAtBottom: blackAtBottom,
                  whitePlayerType: whiteType,
                  blackPlayerType: blackType,
                  showPossibleMoves: true,
                  showCoordinatesZone: _showCoordinates,
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
            ),
          ),
        );
      },
    );
  }
}
