import 'package:flutter/material.dart';

class QuranUtils {
  /// Regular expression to match God's names with optional Arabic diacritics.
  /// Handles prefixes: ب، ف، ت، ل and variations of Allah.
  static final RegExp allahRegex = RegExp(
    r'([بفت]?لله|[بفت]?اللَّه|بالله|تالله|فالله)[\u064B-\u0652\u0670]*',
    unicode: true,
  );

  /// Precise mapping for Juz' starts (Madinah Mushaf standard).
  static final Map<int, int> juzStarts = {
    1: 1,
    2: 22,
    3: 42,
    4: 62,
    5: 82,
    6: 102,
    7: 122,
    8: 142,
    9: 162,
    10: 182,
    11: 202,
    12: 222,
    13: 242,
    14: 262,
    15: 282,
    16: 302,
    17: 322,
    18: 342,
    19: 362,
    20: 382,
    21: 402,
    22: 422,
    23: 442,
    24: 462,
    25: 482,
    26: 502,
    27: 522,
    28: 542,
    29: 562,
    30: 582,
  };

  /// Calculates the current Juz based on the page number.
  static int getJuzNumber(int page) {
    for (int i = 30; i >= 1; i--) {
      if (page >= juzStarts[i]!) return i;
    }
    return 1;
  }

  /// Calculates the current Hizb and Quarter based on the page number.
  /// This is an approximation based on the standard 20 pages per Juz (8 quarters per Juz).
  /// For absolute precision in Quran apps, a per-ayah database mapping is usually used.
  static String getHizbInfo(int page) {
    int juz = getJuzNumber(page);
    int pagesInJuz = page - juzStarts[juz]! + 1;

    // Each Juz has 2 Hizbs (10 pages each), each Hizb has 4 Quarters (2.5 pages each)
    int quarter = ((pagesInJuz - 1) / 2.5).floor() + 1;
    int hizb = ((juz - 1) * 2) + ((quarter > 4) ? 2 : 1);
    int quarterInHizb = (quarter > 4) ? (quarter - 4) : quarter;

    String quarterText = "";
    switch (quarterInHizb) {
      case 1:
        quarterText = "الحزب $hizb";
        break;
      case 2:
        quarterText = "رُبع الحزب $hizb";
        break;
      case 3:
        quarterText = "نصف الحزب $hizb";
        break;
      case 4:
        quarterText = "ثلاثة أرباع الحزب $hizb";
        break;
    }
    return quarterText;
  }

  /// Optimizes text parsing to run once, separating logic from rendering
  static List<ParsedSpanData> parseVerse(
    String text,
    String emlaey,
    String? searchQuery,
  ) {
    List<ParsedSpanData> parsedWords = [];

    // Clean text and split into words
    String cleanedText = text.replaceFirst(RegExp(r'\s*\d+\s*(?=﴿|$)'), ' ');
    List<String> textWords = cleanedText
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .toList();
    List<String> emlaeyWords = emlaey
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .toList();

    // Normalize search query for matching
    String normalizedQuery = searchQuery != null
        ? _removeDiacritics(searchQuery).trim()
        : "";

    for (int i = 0; i < textWords.length; i++) {
      String wordText = textWords[i];
      String wordEmlaey = i < emlaeyWords.length ? emlaeyWords[i] : "";

      // Clean the standard Emlaey word for accurate detection
      String cleanWordEmlaey = _removeDiacritics(wordEmlaey)
          .replaceAll(
            RegExp(r'[^\u0621-\u064A]'),
            '',
          ) // Keep only basic Arabic letters
          .trim();

      bool isAllah = [
        'الله',
        'لله',
        'بالله',
        'تالله',
        'فالله',
      ].contains(cleanWordEmlaey);

      bool isHighlighted =
          normalizedQuery.isNotEmpty &&
          _removeDiacritics(wordEmlaey).contains(normalizedQuery);

      parsedWords.add(
        ParsedSpanData(
          text: '$wordText ',
          isAllah: isAllah,
          isHighlight: isHighlighted,
        ),
      );
    }

    return parsedWords;
  }

  /// Extremely fast renderer that takes pre-parsed words and builds InlineSpans
  static List<InlineSpan> buildSpansFromParsed(
    List<ParsedSpanData> parsedWords,
    BuildContext context,
    double fontSize,
  ) {
    List<InlineSpan> spans = [];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Theming requirements: Red in Light Mode, Amber/Gold in Dark Mode
    final Color normalColor =
        Theme.of(context).textTheme.bodyMedium?.color ??
        (isDarkMode ? Colors.white : Colors.black);

    final Color allahColor = isDarkMode ? Colors.amber : Colors.red;
    final Color highlightColor = Colors.yellow.withValues(alpha: 0.5);

    for (var parsed in parsedWords) {
      if (parsed.isAllah) {
        debugPrint("Colored Allah: ${parsed.text} using Color: $allahColor");
      }

      TextStyle baseStyle = TextStyle(
        fontFamily: 'HafsSmart',
        fontSize: fontSize,
        color: parsed.isAllah ? allahColor : normalColor,
        backgroundColor: parsed.isHighlight ? highlightColor : null,
      );

      spans.add(TextSpan(text: parsed.text, style: baseStyle));
    }

    return spans;
  }

  static String _removeDiacritics(String text) {
    // Comprehensive regex for Arabic diacritics and Quranic marks
    final diacritics = RegExp(
      r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED]',
    );
    return text.replaceAll(diacritics, '');
  }
}

/// Holds pre-calculated word information to prevent regex/splitting during build()
class ParsedSpanData {
  final String text;
  final bool isAllah;
  final bool isHighlight;

  ParsedSpanData({
    required this.text,
    this.isAllah = false,
    this.isHighlight = false,
  });
}
