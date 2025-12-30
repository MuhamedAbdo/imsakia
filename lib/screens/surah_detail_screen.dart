import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/surah.dart';
import '../models/surah_data.dart';
import '../models/verse.dart';
import '../services/quran_service.dart';

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
    print('🚀 SurahDetailScreen initState started');
    print('📖 Surah: ${widget.surah.name} (${widget.surah.number})');
    
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      print('🔄 Loading surah data...');
      
      // Load surah data with verses
      _surahData = await _quranService.getSurahDataByNumber(widget.surah.number);
      
      if (_surahData != null) {
        print('✅ Loaded ${_surahData!.verses.length} verses for surah ${widget.surah.number}');
        
        // Load bookmarked verses
        await _loadBookmarkedVerses();
        
        // Restore scroll position after a short delay to ensure the widget is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 100), () {
            _restoreScrollPosition();
          });
        });
      } else {
        print('❌ Failed to load surah data');
      }
      
      // Check bookmark status
      await _checkBookmarkStatus();
      
      setState(() {
        _isLoading = false;
      });
      
      print('✅ SurahDetailScreen initialization complete');
      
    } catch (e) {
      print('❌ Error initializing SurahDetailScreen: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkBookmarkStatus() async {
    if (_surahData != null && _surahData!.verses.isNotEmpty) {
      final firstVersePage = _surahData!.verses.first.page;
      final isBookmarked = await _quranService.isPageBookmarked(firstVersePage);
      if (mounted) {
        setState(() {
          _isBookmarked = isBookmarked;
        });
      }
    }
  }

  Future<void> _loadBookmarkedVerses() async {
    // Load bookmarked verses for this surah from SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarkedVersesString = prefs.getString('bookmarked_verses_${widget.surah.number}');
      if (bookmarkedVersesString != null) {
        final List<String> versesList = bookmarkedVersesString.split(',');
        _bookmarkedVerses = versesList.map((v) => int.parse(v)).toSet();
      }
    } catch (e) {
      print('❌ Error loading bookmarked verses: $e');
    }
  }

  Future<void> _saveBookmarkedVerses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final versesString = _bookmarkedVerses.join(',');
      await prefs.setString('bookmarked_verses_${widget.surah.number}', versesString);
      print('💾 Saved ${_bookmarkedVerses.length} bookmarked verses for surah ${widget.surah.number}');
    } catch (e) {
      print('❌ Error saving bookmarked verses: $e');
    }
  }

  Future<void> _toggleVerseBookmark(int verseNumber) async {
    setState(() {
      if (_bookmarkedVerses.contains(verseNumber)) {
        _bookmarkedVerses.remove(verseNumber);
      } else {
        _bookmarkedVerses.add(verseNumber);
      }
    });
    
    await _saveBookmarkedVerses();
    
    // Save as last read ayah
    if (_surahData != null) {
      await _quranService.saveLastReadAyah(
        widget.surah.number,
        widget.surah.name,
        verseNumber,
      );
    }
  }

  void _restoreScrollPosition() {
    // Find the last read ayah and scroll to it
    if (_surahData == null) return;
    
    for (int i = 0; i < _surahData!.verses.length; i++) {
      if (_bookmarkedVerses.contains(i + 1)) {
        // Scroll to the first bookmarked verse
        final scrollPosition = (i + 1) * 200.0; // Approximate height per verse
        _scrollController.animateTo(
          scrollPosition,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        break;
      }
    }
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      if (_surahData != null && _surahData!.verses.isNotEmpty) {
        await _quranService.removeBookmark(_surahData!.verses.first.page);
      }
    } else {
      if (_surahData != null && _surahData!.verses.isNotEmpty) {
        await _quranService.saveBookmark(_surahData!.verses.first.page, surahNumber: widget.surah.number);
      }
    }
    
    // Save last read page
    if (_surahData != null && _surahData!.verses.isNotEmpty) {
      await _quranService.saveLastReadPage(_surahData!.verses.first.page, surahNumber: widget.surah.number);
    }
    
    // Update bookmark status
    await _checkBookmarkStatus();
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });

    // Auto-hide overlay after 3 seconds
    if (_showOverlay) {
      _overlayTimer?.cancel();
      _overlayTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showOverlay = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.surah.name,
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.surah.englishName,
              style: GoogleFonts.tajawal(
                fontSize: 14,
                color: Colors.grey[300],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _toggleBookmark,
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? Theme.of(context).primaryColor : null,
            ),
            tooltip: _isBookmarked ? 'إزالة الإشارة المرجعية' : 'إضافة إشارة مرجعية',
          ),
          if (_surahData != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_surahData!.verses.length} آيات',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        color: const Color(0xFFFAF7F0), // Cream paper background
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _surahData == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load surah data',
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            color: Colors.red[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : GestureDetector(
                    onTap: _toggleOverlay,
                    child: Stack(
                      children: [
                        // Quran Verses List
                        ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _surahData!.verses.length,
                          itemBuilder: (context, index) {
                            final verse = _surahData!.verses[index];
                            return _VerseCard(
                              verse: verse,
                              verseNumber: index + 1,
                              isBookmarked: _bookmarkedVerses.contains(index + 1),
                              onBookmarkTap: () => _toggleVerseBookmark(index + 1),
                              onTap: () {
                                // Handle verse tap if needed
                              },
                            );
                          },
                        ),
                        
                        // Overlay with surah info
                        if (_showOverlay)
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${_surahData!.verses.length} آيات',
                                        style: GoogleFonts.tajawal(
                                          fontSize: 14,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _surahData!.nameAr,
                                        style: GoogleFonts.tajawal(
                                          fontSize: 16,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      'سورة ${widget.surah.number}',
                                      style: GoogleFonts.tajawal(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  final Verse verse;
  final int verseNumber;
  final bool isBookmarked;
  final VoidCallback onBookmarkTap;
  final VoidCallback onTap;

  const _VerseCard({
    required this.verse,
    required this.verseNumber,
    required this.isBookmarked,
    required this.onBookmarkTap,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Header with verse number and bookmark
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'آية $verseNumber',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              
              // Bookmark button
              IconButton(
                onPressed: onBookmarkTap,
                icon: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: isBookmarked ? Colors.orange[600] : Colors.grey[400],
                  size: 20,
                ),
                tooltip: isBookmarked ? 'إزالة الإشارة المرجعية' : 'إضافة إشارة مرجعية',
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Arabic text with improved typography
          Text(
            verse.arabicText,
            textAlign: TextAlign.right,
            style: GoogleFonts.amiri(
              fontSize: 28,
              height: 2.2,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white 
                  : const Color(0xFF2C2C2C),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          
          // English translation
          Text(
            verse.englishText,
            textAlign: TextAlign.left,
            style: GoogleFonts.tajawal(
              fontSize: 16,
              height: 1.6,
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.grey[300] 
                  : Colors.grey[700],
            ),
          ),
          
          // Additional info
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'صفحة ${verse.page}',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'جزء ${verse.juz}',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              if (verse.sajda)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'سجدة',
                    style: GoogleFonts.tajawal(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
