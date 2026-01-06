import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../models/surah.dart';
import '../models/surah_data.dart';
import '../models/verse.dart';
import '../services/quran_service.dart';
import '../providers/quran_provider.dart';

class SurahDetailScreen extends StatefulWidget {
  final Surah surah;
  final int? initialVerse;

  const SurahDetailScreen({
    super.key,
    required this.surah,
    this.initialVerse,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final QuranService _quranService = QuranService();
  late QuranProvider _quranProvider;
  SurahData? _surahData;
  bool _isBookmarked = false;
  bool _showOverlay = false;
  Timer? _overlayTimer;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  Set<int> _bookmarkedVerses = <int>{};

  @override
  void initState() {
    super.initState();
    _quranProvider = Provider.of<QuranProvider>(context, listen: false);
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      _surahData = await _quranService.getSurahDataByNumber(widget.surah.number);
      if (_surahData != null) {
        await _loadBookmarkedVerses();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            _restoreScrollPosition();
          });
        });
      }
      await _checkBookmarkStatus();
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkBookmarkStatus() async {
    if (_surahData != null && _surahData!.verses.isNotEmpty) {
      await _quranProvider.loadBookmarkForSurah(widget.surah.number);
      if (mounted) {
        setState(() {
          _isBookmarked = _quranProvider.hasBookmark;
        });
      }
    }
  }

  Future<void> _loadBookmarkedVerses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarkedVersesString = prefs.getString('bookmarked_verses_${widget.surah.number}');
      if (bookmarkedVersesString != null) {
        final List<String> versesList = bookmarkedVersesString.split(',');
        _bookmarkedVerses = versesList.map((v) => int.parse(v)).toSet();
      }
    } catch (e) {}
  }

  Future<void> _saveBookmarkedVerses() async {
    final prefs = await SharedPreferences.getInstance();
    final versesString = _bookmarkedVerses.join(',');
    await prefs.setString('bookmarked_verses_${widget.surah.number}', versesString);
  }

  Future<void> _toggleVerseBookmark(int verseNumber) async {
    final scrollPosition = _scrollController.hasClients ? _scrollController.offset : 0.0;
    setState(() {
      if (_bookmarkedVerses.contains(verseNumber)) {
        _bookmarkedVerses.remove(verseNumber);
      } else {
        _bookmarkedVerses.add(verseNumber);
      }
    });
    await _saveBookmarkedVerses();
    await _quranProvider.saveBookmark(widget.surah.number, verseNumber, scrollPosition);
    _showBookmarkSnackBar('تم تحديث علامة الحفظ: ${widget.surah.name} آية $verseNumber');
    await _checkBookmarkStatus();
  }

  void _restoreScrollPosition() {
    if (_surahData == null) return;
    for (int i = 0; i < _surahData!.verses.length; i++) {
      if (_bookmarkedVerses.contains(i + 1)) {
        final scrollPosition = (i + 1) * 200.0;
        _scrollController.animateTo(scrollPosition, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
        break;
      }
    }
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await _quranProvider.removeBookmark(widget.surah.number);
      _showBookmarkSnackBar('تم إزالة علامة الحفظ');
    } else {
      final scrollPosition = _scrollController.hasClients ? _scrollController.offset : 0.0;
      await _quranProvider.saveBookmark(widget.surah.number, 1, scrollPosition);
      _showBookmarkSnackBar('تم تحديث علامة الحفظ: ${widget.surah.name} آية 1');
    }
    await _checkBookmarkStatus();
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
    if (_showOverlay) {
      _overlayTimer?.cancel();
      _overlayTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showOverlay = false);
      });
    }
  }

  void _showBookmarkSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message, style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w500)),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).primaryColor,
      ));
    }
  }

  Future<void> _goToBookmark() async {
    await _quranProvider.loadBookmarkForSurah(widget.surah.number);
    final bookmark = _quranProvider.currentBookmark;
    if (bookmark != null && _scrollController.hasClients) {
      _scrollController.animateTo(bookmark['scrollPosition'] ?? 0.0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      _showBookmarkSnackBar('تم الرجوع لعلامة الحفظ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.surah.name, style: GoogleFonts.tajawal(fontSize: 20, fontWeight: FontWeight.w600)),
          Text(widget.surah.englishName, style: GoogleFonts.tajawal(fontSize: 14, color: Colors.grey[300])),
        ]),
        actions: [
          IconButton(onPressed: _goToBookmark, icon: const Icon(Icons.bookmark, color: Colors.green)),
          IconButton(onPressed: _toggleBookmark, icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: _isBookmarked ? Theme.of(context).primaryColor : null)),
        ],
      ),
      body: Container(
        color: const Color(0xFFFAF7F0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : GestureDetector(
                onTap: _toggleOverlay,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _surahData?.verses.length ?? 0,
                  itemBuilder: (context, index) {
                    final verse = _surahData!.verses[index];
                    return _ContinuousVerse(
                      verse: verse,
                      verseNumber: index + 1,
                      isBookmarked: _bookmarkedVerses.contains(index + 1),
                      onBookmarkTap: () => _toggleVerseBookmark(index + 1),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _ContinuousVerse extends StatelessWidget {
  final Verse verse;
  final int verseNumber;
  final bool isBookmarked;
  final VoidCallback onBookmarkTap;

  const _ContinuousVerse({required this.verse, required this.verseNumber, required this.isBookmarked, required this.onBookmarkTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text('﴿$verseNumber﴾', style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
          ),
          GestureDetector(onTap: onBookmarkTap, child: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border, color: isBookmarked ? Colors.orange[600] : Colors.grey[400], size: 22)),
        ]),
        const SizedBox(height: 8),
        Text(verse.arabicText, textAlign: TextAlign.right, style: GoogleFonts.amiri(fontSize: 24, height: 2.0, fontWeight: FontWeight.w600)),
        if (verse.englishText.isNotEmpty)
          Text(verse.englishText, textAlign: TextAlign.left, style: GoogleFonts.tajawal(fontSize: 14, color: Colors.grey[600])),
      ]),
    );
  }
}