class PuzzleStats {
  PuzzleStats({
    required this.puzzleKey,
    required this.attempts,
    required this.solves,
    required this.bestTimeMs,
    required this.lastSolvedIso,
  });

  final String puzzleKey;
  final int attempts;
  final int solves;
  final int? bestTimeMs;
  final String? lastSolvedIso;

  factory PuzzleStats.empty(String key) => PuzzleStats(
        puzzleKey: key,
        attempts: 0,
        solves: 0,
        bestTimeMs: null,
        lastSolvedIso: null,
      );

  PuzzleStats copyWith({
    int? attempts,
    int? solves,
    int? bestTimeMs,
    String? lastSolvedIso,
  }) {
    return PuzzleStats(
      puzzleKey: puzzleKey,
      attempts: attempts ?? this.attempts,
      solves: solves ?? this.solves,
      bestTimeMs: bestTimeMs ?? this.bestTimeMs,
      lastSolvedIso: lastSolvedIso ?? this.lastSolvedIso,
    );
  }

  Map<String, dynamic> toJson() => {
        'puzzleKey': puzzleKey,
        'attempts': attempts,
        'solves': solves,
        'bestTimeMs': bestTimeMs,
        'lastSolvedIso': lastSolvedIso,
      };

  factory PuzzleStats.fromJson(Map<String, dynamic> json) {
    return PuzzleStats(
      puzzleKey: (json['puzzleKey'] ?? '').toString(),
      attempts: int.tryParse((json['attempts'] ?? '0').toString()) ?? 0,
      solves: int.tryParse((json['solves'] ?? '0').toString()) ?? 0,
      bestTimeMs: json['bestTimeMs'] == null
          ? null
          : int.tryParse(json['bestTimeMs'].toString()),
      lastSolvedIso: json['lastSolvedIso']?.toString(),
    );
  }

  DateTime? get lastSolvedAt {
    if (lastSolvedIso == null || lastSolvedIso!.isEmpty) return null;
    return DateTime.tryParse(lastSolvedIso!);
  }
}
