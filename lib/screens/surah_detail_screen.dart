import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage ?? widget.surah.startPage;
    _pageController = PageController(initialPage: _currentPage - 1);
    _checkBookmarkStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkBookmarkStatus() async {
    final isBookmarked = await _quranService.isPageBookmarked(_currentPage);
    if (mounted) {
      setState(() {
        _isBookmarked = isBookmarked;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (_isBookmarked) {
      await _quranService.removeBookmark(_currentPage);
    } else {
      await _quranService.saveBookmark(_currentPage, surahNumber: widget.surah.number);
    }
    
    // Save last read page
    await _quranService.saveLastReadPage(_currentPage, surahNumber: widget.surah.number);
    
    // Update bookmark status
    await _checkBookmarkStatus();
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
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) async {
          setState(() {
            _currentPage = page + 1;
          });
          
          // Save last read page
          await _quranService.saveLastReadPage(_currentPage, surahNumber: widget.surah.number);
          
          // Check bookmark status for new page
          await _checkBookmarkStatus();
        },
        itemCount: _totalPages,
        itemBuilder: (context, index) {
          return _buildQuranPage(index + 1);
        },
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

  Widget _buildQuranPage(int pageNumber) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.largePadding),
      child: Column(
        children: [
          // Page Header
          Container(
            padding: const EdgeInsets.all(AppConstants.mediumPadding),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'صفحة $pageNumber',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                Icon(
                  Icons.book,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppConstants.largePadding),
          
          // Quran Content (Placeholder for now)
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.largePadding),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_stories,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'محتوى صفحة القرآن',
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'سيتم عرض نصوص القرآن هنا',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (pageNumber == widget.surah.startPage)
                    Container(
                      padding: const EdgeInsets.all(AppConstants.mediumPadding),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
                      ),
                      child: Text(
                        'بداية سورة ${widget.surah.name}',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
