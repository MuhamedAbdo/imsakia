import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/quran_pages_service.dart';
import '../services/quran_service.dart';
import '../models/surah.dart';
import '../utils/logger.dart';

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
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isBookmarked = false;
  String _currentSurahName = '';
  String _currentJuzName = '';

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _currentSurahName = widget.surahName; // القيمة الابتدائية
    _pageController = PageController(initialPage: _currentPage - 1);
    _updateSurahName(_currentPage);
    _updateJuzName(_currentPage);
    _checkBookmarkStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _onPageChanged(int index) {
    final newPage = index + 1;
    setState(() {
      _currentPage = newPage;
    });
    _updateSurahName(_currentPage);
    _updateJuzName(_currentPage);
    _checkBookmarkStatus();
    Logger.debug('Changed to Quran page $_currentPage');
  }

  void _updateSurahName(int pageNumber) {
    try {
      final surahs = QuranService().surahs;
      
      // البحث عن السورة التي تحتوي على هذه الصفحة
      Surah? currentSurah;
      
      for (int i = surahs.length - 1; i >= 0; i--) {
        if (pageNumber >= surahs[i].startPage) {
          currentSurah = surahs[i];
          break;
        }
      }
      
      if (currentSurah != null && mounted) {
        setState(() {
          _currentSurahName = currentSurah!.name;
        });
        Logger.debug('Updated surah name to: ${currentSurah!.name} for page $pageNumber');
      }
    } catch (e) {
      Logger.error('Error updating surah name: $e');
    }
  }

  void _updateJuzName(int pageNumber) {
    try {
      final quranService = QuranService();
      final juzNumber = quranService.getJuzNumber(pageNumber);
      final juzName = quranService.getJuzName(juzNumber);
      
      if (mounted) {
        setState(() {
          _currentJuzName = juzName;
        });
        Logger.debug('Updated juz name to: $juzName for page $pageNumber');
      }
    } catch (e) {
      Logger.error('Error updating juz name: $e');
    }
  }

  void _checkBookmarkStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarkedPage = prefs.getInt('quran_bookmark_page');
      setState(() {
        _isBookmarked = (bookmarkedPage == _currentPage);
      });
      Logger.debug('Bookmark status checked: $_isBookmarked for page $_currentPage');
    } catch (e) {
      Logger.error('Error checking bookmark status: $e');
    }
  }

  void _toggleBookmark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_isBookmarked) {
        // إزالة العلامة
        await prefs.remove('quran_bookmark_page');
        await prefs.remove('quran_bookmark_surah');
        setState(() {
          _isBookmarked = false;
        });
        Logger.info('Bookmark removed from page $_currentPage');
      } else {
        // حفظ العلامة
        await prefs.setInt('quran_bookmark_page', _currentPage);
        await prefs.setString('quran_bookmark_surah', _currentSurahName);
        setState(() {
          _isBookmarked = true;
        });
        Logger.info('Bookmark saved: page $_currentPage, surah $_currentSurahName');
      }
    } catch (e) {
      Logger.error('Error toggling bookmark: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // خلفية سوداء دائماً مع فلتر عكس الألوان
    const scaffoldBgColor = Colors.black;
    const controlsColor = Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      body: Stack(
        children: [
          // عرض صفحات القرآن مع دعم السحب
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: QuranPagesService.totalPages,
            // السحب من اليمين لليسار (الاتجاه العربي)
            reverse: true, 
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final pageNumber = index + 1;
              return GestureDetector(
                onTap: _toggleControls,
                child: Stack(
                  children: [
                    Center(child: _buildQuranPage(pageNumber)),
                    _buildPageNumber(controlsColor),
                  ],
                ),
              );
            },
          ),
          
          // شريط التحكم العلوي - يظل ظاهراً دائماً
          _buildTopControls(controlsColor, scaffoldBgColor),
        ],
      ),
    );
  }

  Widget _buildTopControls(Color textColor, Color bgColor) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.9),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Row(
          children: [
            // الربع على اليسار
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الربع ${_getRubNumber(_currentPage)}',
                  style: GoogleFonts.tajawal(
                    color: textColor.withOpacity(0.7), 
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // اسم السورة في المنتصف
            Expanded(
              child: Text(
                _currentSurahName,
                style: GoogleFonts.tajawal(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const Spacer(),
            // الجزء على اليمين
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currentJuzName,
                  style: GoogleFonts.tajawal(
                    color: textColor.withOpacity(0.8), 
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _toggleBookmark,
              icon: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _isBookmarked ? Colors.amber : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getRubNumber(int pageNumber) {
    // حساب رقم الربع بناءً على الصفحة (كل ربع حوالي 2.5 صفحة)
    // 604 صفحة / 240 ربع = 2.517 صفحة للربع الواحد
    final rubNumber = ((pageNumber - 1) / 2.517).floor() + 1;
    return rubNumber > 240 ? '240' : rubNumber.toString();
  }

  Widget _buildPageNumber(Color textColor) {
    return Positioned(
      bottom: 10,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$_currentPage',
            style: GoogleFonts.tajawal(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuranPage(int pageNumber) {
    final assetPath = QuranPagesService.instance.getLocalAssetPath(pageNumber);
    
    Widget image = Image.asset(
      assetPath,
      fit: pageNumber <= 2 ? BoxFit.contain : BoxFit.fitWidth,
      width: pageNumber <= 2 ? null : double.infinity,
      alignment: Alignment.center,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => 
          _buildErrorWidget(pageNumber),
    );

    // تطبيق فلتر عكس الألوان دائماً لجعل النص أبيض على خلفية سوداء
    Widget filteredImage = ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -1,  0,  0, 0, 255, // عكس اللون الأحمر
         0, -1,  0, 0, 255, // عكس اللون الأخضر
         0,  0, -1, 0, 255, // عكس اللون الأزرق
         0,  0,  0, 1,   0, // الشفافية تبقى كما هي
      ]),
      child: image,
    );

    // إضافة InteractiveViewer للسماح بالتكبير والتصغير
    return InteractiveViewer(
      panEnabled: true,
      boundaryMargin: const EdgeInsets.all(20),
      minScale: 0.5,
      maxScale: 4.0,
      child: filteredImage,
    );
  }

  Widget _buildErrorWidget(int pageNumber) {
    return Center(
      child: Text(
        'ملف الصورة $pageNumber.png غير موجود',
        style: GoogleFonts.tajawal(color: Colors.red[400]),
      ),
    );
  }
}