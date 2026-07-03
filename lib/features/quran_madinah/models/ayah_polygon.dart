import 'dart:ui';

/// Represents a single Ayah's hit-test region on a Mushaf page.
/// The polygon coordinates match the original SVG viewBox coordinate space.
class AyahPolygon {
  final int ayahNumber;
  final int surahNumber;
  final List<Offset> points;

  const AyahPolygon({
    required this.ayahNumber,
    required this.surahNumber,
    required this.points,
  });

  /// Parses a raw polygon string from the JSON file.
  ///
  /// Handles two formats found in the KFQC data:
  ///   • SVG path: "M 181.08 18.31 L 57.54 18.31 L 57.54 48.94 L 181.08 48.94 Z"
  ///   • Simple pairs: "181.08,18.31 57.54,18.31 57.54,48.94 181.08,48.94"
  ///
  /// Multiple sub-polygons separated by "M" are also handled correctly
  /// (e.g. "M 0 5.75 L 345 5.75 ... Z M 253.3 43.93 L 345 43.93 ... Z").
  static List<Offset> parsePolygon(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return [];

    // ── SVG path format (starts with "M") ──────────────────────────────────
    if (cleaned.startsWith('M') || cleaned.startsWith('m')) {
      return _parseSvgPath(cleaned);
    }

    // ── Simple "x,y" space-separated format ────────────────────────────────
    return _parseSimplePairs(cleaned);
  }

  /// Parses SVG path data that may contain multiple sub-paths.
  /// Only processes M / L / Z commands (sufficient for these rectangle polygons).
  static List<Offset> _parseSvgPath(String path) {
    // Tokenise: split on whitespace and commas, keeping letters
    final tokens = path
        .replaceAllMapped(RegExp(r'([MLZmlz])'), (m) => ' ${m.group(0)} ')
        .split(RegExp(r'[\s,]+'))
        .where((s) => s.isNotEmpty)
        .toList();

    final points = <Offset>[];
    int i = 0;
    while (i < tokens.length) {
      final cmd = tokens[i];
      switch (cmd.toUpperCase()) {
        case 'M':
        case 'L':
          i++;
          if (i + 1 < tokens.length) {
            final x = double.tryParse(tokens[i]) ?? 0.0;
            final y = double.tryParse(tokens[i + 1]) ?? 0.0;
            points.add(Offset(x, y));
            i += 2;
          }
        case 'Z':
          i++;
        default:
          // Numeric token without command – treat as implicit L
          if (double.tryParse(cmd) != null && i + 1 < tokens.length) {
            final x = double.parse(cmd);
            final y = double.tryParse(tokens[i + 1]) ?? 0.0;
            points.add(Offset(x, y));
            i += 2;
          } else {
            i++;
          }
      }
    }
    return points;
  }

  /// Parses simple "x1,y1 x2,y2 ..." pairs.
  static List<Offset> _parseSimplePairs(String raw) {
    final points = <Offset>[];
    for (final pair in raw.trim().split(RegExp(r'\s+'))) {
      final parts = pair.split(',');
      if (parts.length == 2) {
        final x = double.tryParse(parts[0].trim());
        final y = double.tryParse(parts[1].trim());
        if (x != null && y != null) {
          points.add(Offset(x, y));
        }
      }
    }
    return points;
  }

  /// Constructs an [AyahPolygon] from a JSON map entry.
  factory AyahPolygon.fromJson(Map<String, dynamic> json) {
    final rawPolygon = (json['polygon'] as String? ?? '').trim();
    return AyahPolygon(
      ayahNumber: (json['ayahNumber'] as num).toInt(),
      surahNumber: (json['surahNumber'] as num).toInt(),
      points: parsePolygon(rawPolygon),
    );
  }

  @override
  String toString() =>
      'AyahPolygon(surah=$surahNumber, ayah=$ayahNumber, pts=${points.length})';
}
