import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hadith_item.dart';
import '../services/bookmark_service.dart';

class HadithReadingPage extends StatefulWidget {
  final HadithItem hadith;
  final String bookTitle;
  final Color coverColor;
  final List<HadithItem> allHadiths;
  final int currentIndex;
  final String jsonPath;

  const HadithReadingPage({
    super.key,
    required this.hadith,
    required this.bookTitle,
    required this.coverColor,
    required this.allHadiths,
    required this.currentIndex,
    required this.jsonPath,
  });

  @override
  State<HadithReadingPage> createState() => _HadithReadingPageState();
}

class _HadithReadingPageState extends State<HadithReadingPage> {
  late PageController _pageController;
  late int _currentIndex;
  double _currentFontSize = 18.0; // حجم الخط الحالي
  double _currentLineHeight = 1.6; // التباعد بين الأسطر الحالي
  Set<int> _bookmarkedHadiths = <int>{};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadSettings();
    _loadBookmarks();
  }

  /// تحميل العلامات المرجعية المحفوظة
  Future<void> _loadBookmarks() async {
    final bookmarks = await BookmarkService.getBookmarks(widget.jsonPath);
    setState(() {
      _bookmarkedHadiths = bookmarks;
    });
  }

  /// تبديل حالة العلامة المرجعية للحديث الحالي
  Future<bool> _toggleBookmark() async {
    final currentHadithNumber = _currentIndex + 1;
    final isBookmarked = await BookmarkService.toggleBookmark(
      widget.jsonPath,
      currentHadithNumber,
    );

    setState(() {
      if (isBookmarked) {
        _bookmarkedHadiths.add(currentHadithNumber);
      } else {
        _bookmarkedHadiths.remove(currentHadithNumber);
      }
    });

    // عرض رسالة تأكيد
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBookmarked
                ? 'تمت إضافة الحديث إلى العلامات المرجعية'
                : 'تمت إزالة الحديث من العلامات المرجعية',
            style: GoogleFonts.tajawal(),
          ),
          backgroundColor: isBookmarked ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return true; // Return true to indicate bookmark was toggled
  }

  /// تحميل إعدادات الخط والتباعد المحفوظة
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentFontSize = prefs.getDouble('hadith_font_size') ?? 18.0;
      _currentLineHeight = prefs.getDouble('hadith_line_height') ?? 1.6;
    });
  }

  /// حفظ إعدادات الخط والتباعد
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('hadith_font_size', _currentFontSize);
    await prefs.setDouble('hadith_line_height', _currentLineHeight);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _saveSettings(); // حفظ الإعدادات عند الخروج
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        appBar: AppBar(
          backgroundColor: widget.coverColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            '${widget.bookTitle} - ${_currentIndex + 1}/${widget.allHadiths.length}',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.text_fields, color: Colors.white),
              onPressed: () => _showFontSettingsSheet(context),
              tooltip: 'حجم الخط',
            ),
            IconButton(
              icon: Icon(
                _bookmarkedHadiths.contains(_currentIndex + 1)
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                final currentContext = context;
                _toggleBookmark().then((result) {
                  if (result && mounted) {
                    Navigator.pop(
                      currentContext,
                      true,
                    ); // Return true to parent
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: () => _shareHadith(),
            ),
            const SizedBox(width: 8),
          ],
          centerTitle: true,
        ),
        body: PageView.builder(
          controller: _pageController,
          reverse:
              true, // السحب من اليمين لليسار للحديث التالي (الاتجاه العربي)
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemCount: widget.allHadiths.length,
          itemBuilder: (context, index) {
            final currentHadith = widget.allHadiths[index];
            return _buildHadithContent(currentHadith, isDark);
          },
        ),
      ),
    );
  }

  /// عرض صفحة الشرح كـ BottomSheet
  void _showExplanationSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentHadith = widget.allHadiths[_currentIndex];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        builder: (_, _) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: widget.coverColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'شرح الحديث رقم ${currentHadith.number}',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    currentHadith.description,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.amiri(
                      fontSize: 18,
                      height: 1.6,
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              // Bottom padding
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showFontSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        builder: (_, _) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: widget.coverColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إعدادات الخط',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Font size slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'حجم الخط',
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Slider(
                            value: _currentFontSize,
                            min: 12,
                            max: 24,
                            divisions: 12,
                            label: _currentFontSize.round().toString(),
                            onChanged: (value) {
                              setState(() {
                                _currentFontSize = value;
                              });
                            },
                          ),
                        ],
                      ),
                      // Line height slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'التباعد بين الأسطر',
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Slider(
                            value: _currentLineHeight,
                            min: 1.0,
                            max: 2.0,
                            divisions: 10,
                            label: _currentLineHeight.toStringAsFixed(1),
                            onChanged: (value) {
                              setState(() {
                                _currentLineHeight = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom padding
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// مشاركة الحديث كنص منسق
  Future<void> _shareHadith() async {
    final currentHadith = widget.allHadiths[_currentIndex];

    // التحقق من صحة البيانات قبل المشاركة
    if (currentHadith.hadith.isEmpty) {
      _showErrorSnackBar('نص الحديث فارغ');
      return;
    }

    // إنشاء نص المشاركة مع التحقق من الطول
    var shareText =
        '''
📖 ${currentHadith.hadith.trim()}

📚 الكتاب: ${widget.bookTitle.trim()}
🔢 رقم الحديث: ${currentHadith.number}

_________________________
تمت المشاركة من تطبيق زاد
    ''';

    // التحقق من طول النص (بعض التطبيقات لها حدود)
    if (shareText.length > 8000) {
      shareText = shareText.substring(0, 7900) + '...';
    }

    try {
      debugPrint('=== Attempting to share ===');
      debugPrint('Text length: ${shareText.length}');
      debugPrint(
        'Subject: حديث من ${widget.bookTitle} - رقم ${currentHadith.number}',
      );

      final result = await Share.share(
        shareText,
        subject: 'حديث من ${widget.bookTitle} - رقم ${currentHadith.number}',
      );

      debugPrint('Share result: ${result.status}');

      // التحقق من نتيجة المشاركة
      if (result.status == ShareResultStatus.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تم مشاركة الحديث بنجاح',
                style: GoogleFonts.tajawal(),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (result.status == ShareResultStatus.dismissed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم إلغاء المشاركة', style: GoogleFonts.tajawal()),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // طباعة الخطأ في الـ console للتشخيص
        debugPrint('=== Share Error Details ===');
        debugPrint('Error type: ${e.runtimeType}');
        debugPrint('Error message: ${e.toString()}');
        debugPrint('Error stack trace: ${StackTrace.current}');

        String errorMessage = 'حدث خطأ أثناء المشاركة';

        // تحديد نوع الخطأ بدقة أكبر
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('platform') ||
            errorString.contains('activitynotfound')) {
          errorMessage = 'لا يوجد تطبيقات مشاركة متاحة على الجهاز';
        } else if (errorString.contains('timeout') ||
            errorString.contains('cancelled')) {
          errorMessage = 'تم إلغاء المشاركة أو انتهت المهلة';
        } else if (errorString.contains('permission') ||
            errorString.contains('access')) {
          errorMessage = 'يجب السماح بالوصول لتطبيقات المشاركة';
        } else if (errorString.contains('argument') ||
            errorString.contains('null')) {
          errorMessage = 'خطأ في بيانات المشاركة، يرجى المحاولة مرة أخرى';
        } else {
          // عرض الخطأ الأصلي للتشخيص
          errorMessage =
              'خطأ: ${e.toString().length > 50 ? '${e.toString().substring(0, 50)}...' : e.toString()}';
        }

        _showErrorSnackBar(errorMessage);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.tajawal()),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'حاول مرة أخرى',
          textColor: Colors.white,
          onPressed: () => _shareHadith(),
        ),
      ),
    );
  }

  Widget _buildHadithContent(HadithItem hadith, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // رقم الحديث
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: widget.coverColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.coverColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              'الحديث رقم ${hadith.number}',
              style: GoogleFonts.tajawal(
                color: widget.coverColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // نص الحديث
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: widget.coverColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  hadith.hadith,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.amiri(
                    fontSize: _currentFontSize,
                    height: _currentLineHeight,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // زر شرح الحديث
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              onPressed: () => _showExplanationSheet(context),
              icon: const Icon(Icons.lightbulb_outline_rounded),
              label: Text(
                'شرح الحديث',
                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.coverColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // أزرار المشاركة والحفظ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // Copy hadith to clipboard
                  Clipboard.setData(ClipboardData(text: hadith.hadith));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم نسخ الحديث',
                        style: GoogleFonts.tajawal(),
                      ),
                      backgroundColor: widget.coverColor,
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
                label: Text(
                  'نسخ الحديث',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.coverColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Copy hadith with explanation to clipboard
                  final fullText =
                      '${hadith.hadith}\n\n--- شرح الحديث ---\n${hadith.description}';
                  Clipboard.setData(ClipboardData(text: fullText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم نسخ الحديث مع الشرح',
                        style: GoogleFonts.tajawal(),
                      ),
                      backgroundColor: widget.coverColor,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_all),
                label: Text(
                  'نسخ الكل',
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.coverColor.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
