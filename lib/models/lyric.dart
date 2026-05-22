class LyricLine {
  final int timeMs;
  final String text;
  final String? translation;

  const LyricLine({
    required this.timeMs,
    required this.text,
    this.translation,
  });

  @override
  String toString() => '[$timeMs] $text${translation != null ? ' ($translation)' : ''}';
}

class Lyric {
  final String songId;
  final List<LyricLine> lines;
  final bool hasTranslation;

  const Lyric({
    required this.songId,
    required this.lines,
    this.hasTranslation = false,
  });

  factory Lyric.parse(String songId, String lrcContent, {String? translatedLrc}) {
    final lines = <LyricLine>[];
    final translationMap = <int, String>{};

    if (translatedLrc != null && translatedLrc.isNotEmpty) {
      _parseTranslation(translatedLrc, translationMap);
    }

    final hasTranslation = translationMap.isNotEmpty;

    final regex = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)');
    final matches = regex.allMatches(lrcContent);

    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final millisStr = match.group(3);
      final milliseconds = millisStr != null
          ? int.parse(millisStr.length == 2 ? '${millisStr}0' : millisStr)
          : 0;
      final text = match.group(4)?.trim() ?? '';
      final timeMs = (minutes * 60 + seconds) * 1000 + milliseconds;

      if (text.isEmpty) continue;

      final translation = translationMap[timeMs];

      lines.add(LyricLine(
        timeMs: timeMs,
        text: text,
        translation: translation,
      ));
    }

    lines.sort((a, b) => a.timeMs.compareTo(b.timeMs));

    return Lyric(
      songId: songId,
      lines: lines,
      hasTranslation: hasTranslation,
    );
  }

  static void _parseTranslation(
      String translatedLrc, Map<int, String> translationMap) {
    final regex = RegExp(r'\[(\d{2}):(\d{2})(?:\.(\d{2,3}))?\](.*)');
    final matches = regex.allMatches(translatedLrc);

    for (final match in matches) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      final millisStr = match.group(3);
      final milliseconds = millisStr != null
          ? int.parse(millisStr.length == 2 ? '${millisStr}0' : millisStr)
          : 0;
      final text = match.group(4)?.trim() ?? '';
      final timeMs = (minutes * 60 + seconds) * 1000 + milliseconds;

      if (text.isNotEmpty) {
        translationMap[timeMs] = text;
      }
    }
  }

  LyricLine? getLineAt(int positionMs) {
    if (lines.isEmpty) return null;

    LyricLine? currentLine;

    for (final line in lines) {
      if (line.timeMs > positionMs) break;
      currentLine = line;
    }

    return currentLine;
  }

  @override
  String toString() => 'Lyric(songId: $songId, lines: ${lines.length}, hasTranslation: $hasTranslation)';
}