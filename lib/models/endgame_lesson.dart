class EndgameLesson {
  EndgameLesson({
    required this.id,
    required this.title,
    required this.header,
    required this.cue,
    required this.solutionText,
    required this.imageAsset,
    required this.sourcePdfPage,
  });

  final int id;
  final String title;
  final String header;
  final String cue;
  final String solutionText;
  final String imageAsset;
  final int sourcePdfPage;

  static String _cleanSolutionText(String raw) {
    var t = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Remove stray board coordinate labels (common in PDF extracts).
    final lines = t.split('\n');
    final cleaned = <String>[];
    for (final line in lines) {
      final s = line.trimRight();
      final trimmed = s.trim();

      // Drop standalone file/rank labels like: a b c d e f g h or 1..8
      final isSingleFile = trimmed.length == 1 && 'abcdefgh'.contains(trimmed);
      final isSingleRank = trimmed.length == 1 && '12345678'.contains(trimmed);
      if (isSingleFile || isSingleRank) {
        continue;
      }

      cleaned.add(s);
    }

    t = cleaned.join('\n');

    // Join words that the PDF extraction split with a space, e.g. "R ook" -> "Rook".
    // This is common when ligatures or embedded fonts are used.
    t = t.replaceAllMapped(
      RegExp(r'\b([A-Z])\s+([a-z]{2,})\b'),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    // Join short lowercase fragments that are almost certainly mid-word splits,
    // e.g. "obv ious" -> "obvious", "stal e" -> "stale".
    const dontJoin = <String>{
      'a',
      'an',
      'and',
      'are',
      'as',
      'at',
      'be',
      'by',
      'do',
      'for',
      'from',
      'go',
      'had',
      'has',
      'have',
      'he',
      'her',
      'him',
      'his',
      'i',
      'if',
      'in',
      'is',
      'it',
      'its',
      'me',
      'my',
      'no',
      'not',
      'of',
      'on',
      'or',
      'our',
      'out',
      'she',
      'so',
      'than',
      'that',
      'the',
      'their',
      'then',
      'there',
      'these',
      'they',
      'this',
      'to',
      'up',
      'was',
      'we',
      'were',
      'with',
      'you',
      'your',
    };

    t = t.replaceAllMapped(
      RegExp(r'\b([a-z]{1,3})\s+([a-z]{3,})\b'),
      (m) {
        final left = (m.group(1) ?? '').toLowerCase();
        if (dontJoin.contains(left)) {
          return m.group(0) ?? '';
        }
        return '${m.group(1)}${m.group(2)}';
      },
    );

    // Fix hyphenation across line breaks: "imme-\ndi ately" -> "immediately".
    t = t.replaceAll(RegExp(r'-\n\s*'), '');

    // Fix mid-word line breaks that split a word without a hyphen.
    // Heuristic: if a line ends with 2-6 letters and next line starts with a-z,
    // join without space.
    t = t.replaceAllMapped(
      RegExp(r'([A-Za-z]{2,6})\n([a-z]{2,})'),
      (m) => '${m.group(1)}${m.group(2)}',
    );

    // Now normalize remaining line breaks to be readable, but keep paragraph breaks.
    // Convert single newlines to spaces, preserve double newlines.
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    t = t.replaceAllMapped(
      RegExp(r'(?<!\n)\n(?!\n)'),
      (_) => ' ',
    );

    // Collapse whitespace.
    t = t.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    t = t.replaceAll(RegExp(r'\n[ \t]+'), '\n');
    t = t.trim();

    // Drop trailing extraction junk like "1 1 _" or stray underscores/digits.
    t = t.replaceAll(RegExp(r'[\s_]*([0-9]\s*){1,8}[_\s]*$'), '');
    t = t.replaceAll(RegExp(r'[_\s]+$'), '');
    t = t.trim();

    return t;
  }

  factory EndgameLesson.fromJson(Map<String, dynamic> json) {
    return EndgameLesson(
      id: (json['id'] as num).toInt(),
      title: (json['title'] ?? '').toString(),
      header: (json['header'] ?? '').toString(),
      cue: (json['cue'] ?? '').toString(),
      solutionText: _cleanSolutionText((json['solutionText'] ?? '').toString()),
      imageAsset: (json['image'] ?? '').toString(),
      sourcePdfPage: (json['sourcePdfPage'] as num?)?.toInt() ?? 0,
    );
  }
}
