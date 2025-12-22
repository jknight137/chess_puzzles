class RunResult {
  RunResult({
    required this.id,
    required this.setId,
    required this.setTitle,
    required this.startedIso,
    required this.finishedIso,
    required this.durationMs,
    required this.puzzlesTotal,
    required this.puzzlesSolved,
    required this.wrongMoves,
    required this.hintsUsed,
    required this.score,
  });

  final String id;
  final String setId;
  final String setTitle;

  final String startedIso;
  final String finishedIso;

  final int durationMs;
  final int puzzlesTotal;
  final int puzzlesSolved;
  final int wrongMoves;
  final int hintsUsed;
  final int score;

  DateTime get startedAt => DateTime.parse(startedIso);
  DateTime get finishedAt => DateTime.parse(finishedIso);

  Map<String, dynamic> toJson() => {
        'id': id,
        'setId': setId,
        'setTitle': setTitle,
        'startedIso': startedIso,
        'finishedIso': finishedIso,
        'durationMs': durationMs,
        'puzzlesTotal': puzzlesTotal,
        'puzzlesSolved': puzzlesSolved,
        'wrongMoves': wrongMoves,
        'hintsUsed': hintsUsed,
        'score': score,
      };

  factory RunResult.fromJson(Map<String, dynamic> json) {
    return RunResult(
      id: (json['id'] ?? '').toString(),
      setId: (json['setId'] ?? '').toString(),
      setTitle: (json['setTitle'] ?? '').toString(),
      startedIso:
          (json['startedIso'] ?? DateTime.now().toIso8601String()).toString(),
      finishedIso:
          (json['finishedIso'] ?? DateTime.now().toIso8601String()).toString(),
      durationMs: int.tryParse((json['durationMs'] ?? '0').toString()) ?? 0,
      puzzlesTotal: int.tryParse((json['puzzlesTotal'] ?? '0').toString()) ?? 0,
      puzzlesSolved:
          int.tryParse((json['puzzlesSolved'] ?? '0').toString()) ?? 0,
      wrongMoves: int.tryParse((json['wrongMoves'] ?? '0').toString()) ?? 0,
      hintsUsed: int.tryParse((json['hintsUsed'] ?? '0').toString()) ?? 0,
      score: int.tryParse((json['score'] ?? '0').toString()) ?? 0,
    );
  }
}
