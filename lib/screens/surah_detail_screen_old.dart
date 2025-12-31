import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../models/surah.dart';
import '../services/quran_service.dart';
import '../utils/app_constants.dart';

class SurahDetailScreen extends StatefulWidget {
  final Surah surah;
  final int? initialPage;

  const SurahDetailScreen({
    super.key,
    required this.surah,
    this.initialPage,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  late PageController _pageController;
  int _currentPage = 1;
  final int _totalPages = 604; // Madina Mushaf total pages
  final QuranService _quranService = QuranService();
  bool _isBookmarked = false;
  bool _showOverlay = false;
  Timer? _overlayTimer;

  @override
  void initState() {
    super.initState();
    print('🚀 SurahDetailScreen initState started');
    print('📖 Surah: ${widget.surah.name} (${widget.surah.number})');
    print('📄 Initial page: ${widget.initialPage ?? widget.surah.startPage}');
    
    _currentPage = widget.initialPage ?? widget.surah.startPage;
    
    // Calculate initial index for RTL reading
    // Page 1 should be at index 603, Page 604 should be at index 0
    final initialIndex = 604 - _currentPage;
    print('📍 Initial index: $initialIndex for page $_currentPage');
    
    _pageController = PageController(initialPage: initialIndex);
    
    print('🔄 Loading QuranService data...');
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      // Ensure QuranService is loaded
      if (!_quranService.isLoaded) {
        print('⏳ QuranService not loaded, loading now...');
        await _quranService.loadSurahs();
        print('✅ QuranService loaded successfully');
      } else {
        print('✅ QuranService already loaded');
      }
      
      // Check bookmark status
      await _checkBookmarkStatus();
      print('✅ SurahDetailScreen initialization complete');
      
    } catch (e) {
      print('❌ Error initializing SurahDetailScreen: $e');
      if (mounted) {
        setState(() {
          // Handle error state if needed
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _overlayTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkBookmarkStatus() async {
    final isBookmarked = await _quranService.isSurahBookmarked(widget.surah.number);
    if (mounted) {
      setState(() {
        _isBookmarked = isBookmarked;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await _quranService.removeBookmark(widget.surah.number);
    } else {
      // Save bookmark with current page info
      await _quranService.saveBookmark(widget.surah.number, _currentPage, 0.0);
    }
    
    // Save last read page
    await _quranService.saveLastReadPage(_currentPage, surahNumber: widget.surah.number);
    
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

  void _hideOverlay() {
    if (_showOverlay) {
      setState(() {
        _showOverlay = false;
      });
      _overlayTimer?.cancel();
    }
  }

  String _getCurrentSurahName() {
    print('🔍 Getting surah name for page $_currentPage');
    
    final currentSurah = _quranService.getSurahByPage(_currentPage);
    if (currentSurah != null) {
      print('✅ Found surah: ${currentSurah.name} for page $_currentPage');
      return currentSurah.name;
    }
    
    print('⚠️ No surah found for page $_currentPage, using fallback: ${widget.surah.name}');
    return widget.surah.name; // Fallback to the original surah
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$_currentPage/$_totalPages',
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
        color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1A1A1A) // Dark mode background
            : const Color(0xFFF5F1E8), // Light cream background for reading
        child: GestureDetector(
          onTap: _toggleOverlay,
          child: Stack(
            children: [
              // Quran Pages with InteractiveViewer
              PageView.builder(
                controller: _pageController,
                reverse: true, // Arabic is read from right to left
                onPageChanged: (index) async {
                  // Calculate current page number for RTL reading
                  final currentPageNumber = 604 - index;
                  setState(() {
                    _currentPage = currentPageNumber;
                  });
                  
                  print('📄 Changed to page $_currentPage (index $index)');
                  
                  // Save last read page
                  await _quranService.saveLastReadPage(_currentPage, surahNumber: widget.surah.number);
                  
                  // Check bookmark status for new page
                  await _checkBookmarkStatus();
                  
                  // Hide overlay when changing pages
                  _hideOverlay();
                },
                itemCount: _totalPages,
                itemBuilder: (context, index) {
                  // Calculate page number for RTL reading (Madina Mushaf)
                  // Page 1 is at the rightmost (last index), Page 604 is at the leftmost (first index)
                  final pageNumber = 604 - index;
                  
                  // Get local asset path
                  final assetPath = 'assets/quran/pages/$pageNumber.png';
                  
                  print('📄 Building page $pageNumber for index $index');
                  print('� Asset path: $assetPath');
                  
                  return InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: _QuranPageImage(
                      pageNumber: pageNumber,
                      assetPath: assetPath,
                    ),
                  );
                },
              ),
              
              // Overlay with page info and surah name
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
                              'صفحة $_currentPage',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getCurrentSurahName(),
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
                            '$_currentPage/$_totalPages',
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppConstants.mediumPadding),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_currentPage > 1) {
                    _pageController.animateToPage(
                      _currentPage - 2,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                icon: const Icon(Icons.keyboard_arrow_left),
                label: Text(
                  'السابق',
                  style: GoogleFonts.tajawal(),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_currentPage < _totalPages) {
                    _pageController.animateToPage(
                      _currentPage,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                icon: const Icon(Icons.keyboard_arrow_right),
                label: Text(
                  'التالي',
                  style: GoogleFonts.tajawal(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuranPageImage extends StatefulWidget {
  final int pageNumber;
  final String assetPath;

  const _QuranPageImage({
    required this.pageNumber,
    required this.assetPath,
  });

  @override
  State<_QuranPageImage> createState() => _QuranPageImageState();
}

class _QuranPageImageState extends State<_QuranPageImage> {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      widget.assetPath,
      errorBuilder: (context, error, stackTrace) {
        print('❌ ERROR LOADING PAGE ${widget.pageNumber}:');
        print('❌ Error Type: ${error.runtimeType}');
        print('❌ Error Message: ${error.toString()}');
        print('❌ Failed Asset Path: ${widget.assetPath}');
        print('❌ Stack Trace: $stackTrace');
        
        return Center(
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
                'Image Not Found',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  color: Colors.red[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Page: ${widget.pageNumber}\nPath: ${widget.assetPath}',
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
      fit: BoxFit.contain,
    );
  }
}
