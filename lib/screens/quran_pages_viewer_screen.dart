import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/quran_pages_service.dart';

class QuranPagesViewerScreen extends StatefulWidget {
  final int initialPage;
  final String surahName;

  const QuranPagesViewerScreen({
    super.key,
    this.initialPage = 1,
    this.surahName = '',
  });

  @override
  State<QuranPagesViewerScreen> createState() => _QuranPagesViewerScreenState();
}

class _QuranPagesViewerScreenState extends State<QuranPagesViewerScreen> {
  late PageController _pageController;
  int _currentPage = 1;
  String _currentQuarterDisplay = '';
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: _currentPage - 1);
    _updateQuarterName(_currentPage);
    _checkBookmarkStatus();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Theme.of(context).primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          _currentQuarterDisplay,
          style: GoogleFonts.tajawal(
            color: QuranPagesService.isQuarterStart(_currentPage) ? Colors.amber : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _toggleBookmark,
            icon: Icon(
              _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _isBookmarked ? Colors.amber : Colors.white,
            ),
          ),
        ],
      ),
      body: _buildPortraitPages(isDarkMode),
    );
  }

  Widget _buildPortraitPages(bool isDarkMode) {
    return PageView.builder(
      controller: _pageController,
      reverse: true,
      itemCount: 604,
      onPageChanged: (index) {
        if (mounted) {
          setState(() => _currentPage = index + 1);
          _updateQuarterName(_currentPage);
        }
      },
      itemBuilder: (context, index) {
        return _QuranImageItem(
          pageNumber: index + 1,
          isDarkMode: isDarkMode,
        );
      },
    );
  }

  static ColorFilter _getMatrix(bool isDarkMode) {
    return ColorFilter.matrix(isDarkMode
        ? const [-1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0]
        : const [2.0, 0, 0, 0, -100, 0, 2.0, 0, 0, -100, 0, 0, 2.0, 0, -100, 0, 0, 0, 1, 0]);
  }

  void _updateQuarterName(int pageNumber) {
    try {
      final rawName = QuranPagesService.getCurrentQuarter(pageNumber);
      String cleaned = rawName.replaceAll('الربع:', '').replaceAll('الربع', '').trim();
      if (cleaned.contains('-')) cleaned = cleaned.split('-').last.trim();
      if (mounted) setState(() => _currentQuarterDisplay = 'الربع $cleaned');
    } catch (_) {}
  }

  void _checkBookmarkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _isBookmarked = (prefs.getInt('quran_bookmark_page') == _currentPage));
  }

  void _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    _isBookmarked ? await prefs.remove('quran_bookmark_page') : await prefs.setInt('quran_bookmark_page', _currentPage);
    _checkBookmarkStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _QuranImageItem extends StatelessWidget {
  final int pageNumber;
  final bool isDarkMode;

  const _QuranImageItem({
    required this.pageNumber,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: isDarkMode ? Colors.black : Colors.white,
      child: ColorFiltered(
        colorFilter: _QuranPagesViewerScreenState._getMatrix(isDarkMode),
        child: Image.asset(
          QuranPagesService.instance.getLocalAssetPath(pageNumber),
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}