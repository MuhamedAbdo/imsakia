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
  late ScrollController _scrollController;
  int _currentPage = 1;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isBookmarked = false;
  String _currentSurahName = '';
  String _currentJuzName = '';
  String _currentQuarterName = '';
  bool _isLandscape = false;
  bool _isScrolling = false;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _currentSurahName = widget.surahName;
    _pageController = PageController(initialPage: _currentPage - 1);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollChanged);

    // الاستماع لتغيرات الاتجاه
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateOrientation();
    });

    _updateSurahName(_currentPage);
    _updateJuzName(_currentPage);
    _updateQuarterName(_currentPage);
    _checkBookmarkStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // تحديد الوضع الليلي/النهاري هنا بعد اكتمال بناء الـ widget
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
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

  void _updateOrientation() {
    final orientation = MediaQuery.of(context).orientation;
    final newIsLandscape = orientation == Orientation.landscape;

    if (newIsLandscape != _isLandscape) {
      setState(() {
        _isLandscape = newIsLandscape;
      });

      // في الوضع الأفقي، ابدأ من الأعلى
      if (_isLandscape && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  void _onScrollChanged() {
    if (!_isLandscape || _isScrolling) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    // إذا وصلنا لنهاية الصفحة وسحب للأعلى
    if (currentScroll >= maxScroll - 50 && _currentPage < QuranPagesService.totalPages) {
      _navigateToNextPage();
    }
    // إذا كنا في بداية الصفحة وسحب للأسفل
    else if (currentScroll <= 50 && _currentPage > 1) {
      _navigateToPreviousPage();
    }
  }

  void _navigateToNextPage() {
    if (_isScrolling) return;

    setState(() {
      _isScrolling = true;
      _currentPage++;
    });

    _updateSurahName(_currentPage);
    _updateJuzName(_currentPage);
    _updateQuarterName(_currentPage);
    _checkBookmarkStatus();

    // العودة للأعلى في الصفحة الجديدة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      setState(() {
        _isScrolling = false;
      });
    });

    Logger.debug('Navigated to next page: $_currentPage');
  }

  void _navigateToPreviousPage() {
    if (_isScrolling) return;

    setState(() {
      _isScrolling = true;
      _currentPage--;
    });

    _updateSurahName(_currentPage);
    _updateJuzName(_currentPage);
    _updateQuarterName(_currentPage);
    _checkBookmarkStatus();

    // الانتقال للأسفل في الصفحة الجديدة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
      setState(() {
        _isScrolling = false;
      });
    });

    Logger.debug('Navigated to previous page: $_currentPage');
  }

  void _onPageChanged(int index) {
    if (_isLandscape) return; // لا تستخدم في الوضع الأفقي

    final newPage = index + 1;
    setState(() {
      _currentPage = newPage;
    });
    _updateSurahName(_currentPage);
    _updateJuzName(_currentPage);
    _updateQuarterName(_currentPage);
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
        Logger.debug('Updated surah name to: ${currentSurah.name} for page $pageNumber');
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

  void _updateQuarterName(int pageNumber) {
    try {
      final quarterName = QuranPagesService.getCurrentQuarter(pageNumber);

      if (mounted) {
        setState(() {
          _currentQuarterName = quarterName;
        });
        Logger.debug('Updated quarter name to: $quarterName for page $pageNumber');
      }
    } catch (e) {
      Logger.error('Error updating quarter name: $e');
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
    // تحديث الاتجاه عند كل بناء
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateOrientation();
    });

    // تحديث الوضع الليلي/النهاري
    _isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // ألوان حسب الوضع
    final scaffoldBgColor = _isDarkMode ? Colors.black : Colors.white;
    final controlsColor = _isDarkMode ? Colors.white : Colors.black;
    final appBarColor = _isDarkMode ? Colors.black : Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: scaffoldBgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        titleSpacing: 0,
        title: _buildTopControls(controlsColor),
        actions: [
          // رقم الصفحة في الـ AppBar
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.white.withOpacity(0.2) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: _isDarkMode ? Border.all(color: Colors.white.withOpacity(0.3)) : null,
              ),
              child: Text(
                '$_currentPage',
                style: GoogleFonts.tajawal(
                  color: _isDarkMode ? Colors.white : Theme.of(context).primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: _isDarkMode ? Colors.black : Colors.white,
        child: _isLandscape
            ? _buildLandscapeView()
            : _buildPortraitView(),
      ),
    );
  }

  Widget _buildPortraitView() {
    final controlsColor = _isDarkMode ? Colors.white : Colors.black;
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: QuranPagesService.totalPages,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final pageNumber = index + 1;
        return Container(
          color: _isDarkMode ? Colors.black : Colors.white,
          padding: const EdgeInsets.all(8),
          child: _buildQuranPage(pageNumber, false),
        );
      },
    );
  }

  Widget _buildLandscapeView() {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      child: Container(
        color: _isDarkMode ? Colors.black : Colors.white,
        padding: const EdgeInsets.all(8),
        child: _buildQuranPage(_currentPage, true),
      ),
    );
  }

  Widget _buildTopControls(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        children: [
          // الربع على اليسار
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentQuarterName.split(' - ')[1], // فقط اسم الربع
                style: GoogleFonts.tajawal(
                  color: QuranPagesService.isQuarterStart(_currentPage)
                      ? Colors.amber // لون ذهبي لبداية الربع
                      : textColor.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: QuranPagesService.isQuarterStart(_currentPage)
                      ? FontWeight.bold // خط عريض لبداية الربع
                      : FontWeight.w400,
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
    );
  }

  Widget _buildQuranPage(int pageNumber, bool isLandscape) {
    final assetPath = QuranPagesService.instance.getLocalAssetPath(pageNumber);

    Widget image = Image.asset(
      assetPath,
      fit: BoxFit.cover, // cover لملء الشاشة بالكامل
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) =>
          _buildErrorWidget(pageNumber),
    );

    // مصفوفة ألوان "سحق الحواف" - تحويل كل شيء غير الأبيض إلى أسود صريح
    Widget filteredImage = ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -1.0,  0.0,  0.0, 0.0, 255.0, // عكس الأحمر
         0.0, -1.0,  0.0, 0.0, 255.0, // عكس الأخضر
         0.0,  0.0, -1.0, 0.0, 255.0, // عكس الأزرق
         0.0,  0.0,  0.0, 1.0,   0.0, // الشفافية
      ]),
      child: image,
    );

    // فلتر إضافي للوضع النهاري - سحق الحواف الرمادية وجعلها سوداء تماماً
    if (!_isDarkMode) {
      filteredImage = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          3.0,  0.0,  0.0, 0.0, -80.0, // تباين شديد للأحمر
          0.0,  3.0,  0.0, 0.0, -80.0, // تباين شديد للأخضر
          0.0,  0.0,  3.0, 0.0, -80.0, // تباين شديد للأزرق
          0.0,  0.0,  0.0, 1.0,   0.0, // الشفافية تبقى كما هي
        ]),
        child: filteredImage,
      );
    }

    return filteredImage;
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