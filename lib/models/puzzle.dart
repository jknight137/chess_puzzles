class Puzzle {
  Puzzle({
    required this.id,
    required this.chapter,
    required this.difficulty,
    required this.title,
    required this.sourceTitle,
    required this.fen,
    required this.bestMoveSan,
    required this.solutionLine,
    required this.bookPage,
  });

  final String id;
  final int chapter;
  final String difficulty;
  final String title;
  final String sourceTitle;
  final String fen;
  final String bestMoveSan;

  // Raw text from JSON. This may contain move numbers and commentary.
  final String solutionLine;

  final int? bookPage;

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    final chapter = int.tryParse((json['chapter'] ?? '').toString()) ?? 0;
    final difficulty = (json['difficulty'] ?? '').toString().trim();
    final title = (json['title'] ?? 'Puzzle').toString().trim();
    final sourceTitle = (json['sourceTitle'] ?? '').toString().trim();
    final fen = (json['fen'] ?? '').toString().trim();
    final bestMoveSan = (json['bestMoveSan'] ?? '').toString().trim();
    final solutionLine = (json['solutionLine'] ?? '').toString().trim();

    final bookPageRaw = json['bookPage'];
    final bookPage = bookPageRaw is int ? bookPageRaw : int.tryParse(bookPageRaw?.toString() ?? '');

    return Puzzle(
      id: id,
      chapter: chapter,
      difficulty: difficulty,
      title: title,
      sourceTitle: sourceTitle,
      fen: fen,
      bestMoveSan: bestMoveSan,
      solutionLine: solutionLine,
      bookPage: bookPage,
    );
  }
}
