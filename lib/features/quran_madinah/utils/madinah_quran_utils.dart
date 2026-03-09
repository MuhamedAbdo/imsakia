import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

  /// Absolute mapping of all 240 quarter starting pages in the Madinah Mushaf.
  static const List<int> quarterStarts = [
    1, 5, 7, 9, 11, 14, 17, 19, 22, 24, 27, 29, 32, 34, 37, 39, 42, 44, 46, 49, 
    51, 54, 56, 59, 62, 64, 67, 69, 72, 74, 77, 79, 82, 84, 87, 89, 92, 94, 97, 
    100, 102, 104, 106, 109, 112, 114, 117, 119, 121, 124, 126, 129, 132, 134, 
    137, 140, 142, 144, 146, 148, 151, 154, 156, 158, 162, 164, 167, 170, 173, 
    175, 177, 179, 182, 184, 187, 189, 192, 194, 196, 199, 201, 204, 206, 209, 
    212, 214, 217, 219, 222, 224, 226, 228, 231, 233, 236, 238, 242, 244, 247, 
    249, 252, 254, 256, 259, 262, 264, 267, 270, 272, 275, 277, 280, 282, 284, 
    287, 289, 292, 295, 297, 299, 302, 304, 306, 309, 312, 315, 317, 319, 322, 
    324, 326, 329, 332, 334, 336, 339, 342, 344, 347, 350, 352, 354, 356, 359, 
    362, 364, 367, 369, 371, 374, 377, 379, 382, 384, 386, 389, 392, 394, 396, 
    399, 402, 404, 407, 410, 413, 415, 418, 420, 422, 425, 426, 429, 431, 433, 
    436, 439, 442, 444, 446, 449, 451, 454, 456, 459, 462, 464, 467, 469, 472, 
    474, 477, 479, 482, 484, 486, 488, 491, 493, 496, 499, 502, 505, 507, 510, 
    513, 515, 517, 519, 522, 524, 526, 529, 531, 534, 536, 539, 542, 544, 547, 
    550, 553, 554, 558, 560, 562, 564, 566, 569, 572, 575, 577, 579, 582, 585, 
    587, 589, 591, 594, 596, 599
  ];

  /// Calculates the current Hizb and Quarter based on the absolute array.
  /// This guarantees 100% precision for every page in the Madinah Mushaf.
  static String getHizbInfo(int page) {
    int quarterIndex = 0;
    // Find the latest quarter that starts on or before this page
    for (int i = 0; i < quarterStarts.length; i++) {
      if (page >= quarterStarts[i]) {
        quarterIndex = i;
      } else {
        break; // Array is sorted, we can stop
      }
    }

    int quarterNumber = quarterIndex + 1; // 1 to 240
    int hizb = ((quarterNumber - 1) / 4).floor() + 1;
    int quarterInHizb = ((quarterNumber - 1) % 4) + 1;

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
    
    // Fix known Emlaey word splits to match Uthmani spacing for better 1:1 alignment
    String normalizedEmlaey = emlaey
        .replaceAll('أو لم ', 'أولم ')
        .replaceAll('يا أيها ', 'يأيها ')
        .replaceAll('يا أيتها ', 'يأيتها ')
        .replaceAll('يا ويلتى ', 'يويلتى ')
        .replaceAll('يا ليتني ', 'يليتني ');

    List<String> textWords = cleanedText
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .toList();
    List<String> emlaeyWords = normalizedEmlaey
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
          text: wordText, // Without trailing space
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
    [TapGestureRecognizer? recognizer, bool isTargetAya = false]
  ) {
    List<InlineSpan> spans = [];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Theming requirements: Red in Light Mode, Amber/Gold in Dark Mode
    final Color normalColor = isDarkMode ? Colors.white : Colors.black;

    final Color allahColor = isDarkMode ? Colors.amber : Colors.red;
    final Color highlightColor = Colors.yellow.withValues(alpha: 0.5);
    final Color targetAyaColor = isDarkMode ? Colors.blue.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.2);

    for (var parsed in parsedWords) {
      if (parsed.isAllah) {
        debugPrint("Colored Allah: ${parsed.text} using Color: $allahColor");
      }

      TextStyle baseStyle = TextStyle(
        fontFamily: 'HafsSmart',
        fontSize: fontSize,
        color: parsed.isAllah ? allahColor : normalColor,
        backgroundColor: parsed.isHighlight ? highlightColor : (isTargetAya ? targetAyaColor : null),
      );

      // We add the word without the trailing space to prevent RTL style bleeding across lines
      spans.add(TextSpan(
        text: parsed.text,
        style: baseStyle,
        recognizer: recognizer,
      ));

      // Add the trailing space as a separate TextSpan with normal color and transparent background
      spans.add(TextSpan(
        text: ' ',
        style: TextStyle(
          fontFamily: 'HafsSmart',
          fontSize: fontSize,
          color: normalColor,
          backgroundColor: isTargetAya ? targetAyaColor : null,
        ),
        recognizer: recognizer,
      ));
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
