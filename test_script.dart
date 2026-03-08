import 'dart:convert';
import 'dart:io';

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

String _removeDiacritics(String text) {
  final diacritics = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC\u06DF-\u06E8\u06EA-\u06ED]',
  );
  return text.replaceAll(diacritics, '');
}

List<ParsedSpanData> parseVerse(String text, String? searchQuery) {
  List<ParsedSpanData> parsedWords = [];
  String cleanedText = text.replaceFirst(RegExp(r'\s*\d+\s*(?=﴿|$)'), ' ');
  List<String> words = cleanedText.split(' ');
  String normalizedQuery = searchQuery != null
      ? _removeDiacritics(searchQuery).trim()
      : "";

  for (var word in words) {
    if (word.isEmpty) continue;

    String noDiacritics = _removeDiacritics(word);
    String cleanWord = noDiacritics
        .replaceAll(RegExp(r'[^\u0621-\u064A]'), '')
        .trim();

    bool isAllah =
        ['الله', 'لله', 'بالله', 'تالله', 'فالله'].contains(cleanWord) ||
        word.contains('\uFDF2');
    bool isHighlighted =
        normalizedQuery.isNotEmpty && noDiacritics.contains(normalizedQuery);

    parsedWords.add(
      ParsedSpanData(
        text: '$word ',
        isAllah: isAllah,
        isHighlight: isHighlighted,
      ),
    );

    // DEBUG:
    if (cleanWord.contains('لل')) {
      print(
        "WORD: $word -> NO DIACRITICS: $noDiacritics -> CLEAN: $cleanWord -> isAllah: $isAllah",
      );
    }
  }
  return parsedWords;
}

void main() async {
  final file = File('assets/data/hafs_smart_v8.json');
  final jsonStr = await file.readAsString();
  final List<dynamic> jsonList = jsonDecode(jsonStr);

  int mismatchCount = 0;
  for (var item in jsonList) {
    int ayaNo = item['aya_no'];
    int suraNo = item['sura_no'];
    // Removed the skip condition to test ALL ayahs

    final text = item['aya_text'] as String;
    final emlaey = item['aya_text_emlaey'] as String;

    final textWords = text
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .toList();
    final emlaeyWords = emlaey
        .split(' ')
        .where((w) => w.trim().isNotEmpty)
        .toList();

    if (textWords.length != emlaeyWords.length + 1) {
      if (textWords.length == emlaeyWords.length) {
        // sometimes no end marker?
      } else {
        mismatchCount++;
        // print("Mismatch Sura $suraNo Aya $ayaNo: Text(${textWords.length}) Emlaey(${emlaeyWords.length})");
      }
    }
  }
  print("Total mismatches (excluding Basmalah): $mismatchCount");
}
