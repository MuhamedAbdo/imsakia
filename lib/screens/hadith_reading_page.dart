import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/hadith_item.dart';
import '../services/bookmark_service.dart';
import '../providers/font_settings_provider.dart';

class HadithReadingPage extends StatefulWidget {
  final List<HadithItem> allHadiths;
  final String bookTitle;
  final Color coverColor;
  final HadithItem? hadith;
  final int? currentIndex;
  final String? bookKey;

  const HadithReadingPage({
    super.key,
    required this.allHadiths,
    required this.bookTitle,
    required this.coverColor,
    this.hadith,
    this.currentIndex,
    this.bookKey,
  });

  @override
  State<HadithReadingPage> createState() => _HadithReadingPageState();
}

class _HadithReadingPageState extends State<HadithReadingPage> {
  late PageController _pageController;
  late int _currentIndex;
  final Set<int> _bookmarkedHadiths = <int>{};

  @override
  void initState() {
    super.initState();
    int idx = widget.currentIndex ?? 0;
    if (widget.hadith != null && widget.allHadiths.isNotEmpty) {
      final foundIdx = widget.allHadiths.indexWhere((h) => h.number == widget.hadith!.number);
      if (foundIdx != -1) {
        idx = foundIdx;
      }
    }
    if (idx < 0 || idx >= widget.allHadiths.length) {
      idx = 0;
    }
    _currentIndex = idx;
    _pageController = PageController(initialPage: _currentIndex);
    _loadBookmarks();
  }

  int get _currentHadithNumber {
    if (widget.allHadiths.isNotEmpty && _currentIndex >= 0 && _currentIndex < widget.allHadiths.length) {
      return widget.allHadiths[_currentIndex].number;
    }
    return widget.hadith?.number ?? (_currentIndex + 1);
  }

  Future<void> _loadBookmarks() async {
    final bookKey = widget.bookKey ?? 'hadith_bookmarks';
    final bookmarks = await BookmarkService.getBookmarks(bookKey);
    if (mounted) {
      setState(() {
        _bookmarkedHadiths.clear();
        _bookmarkedHadiths.addAll(bookmarks);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleBookmark() async {
    final hadithNumber = _currentHadithNumber;
    final bookKey = widget.bookKey ?? 'hadith_bookmarks';

    await BookmarkService.toggleBookmark(bookKey, hadithNumber);

    if (mounted) {
      setState(() {
        if (_bookmarkedHadiths.contains(hadithNumber)) {
          _bookmarkedHadiths.remove(hadithNumber);
        } else {
          _bookmarkedHadiths.add(hadithNumber);
        }
      });

      final isNowBookmarked = _bookmarkedHadiths.contains(hadithNumber);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isNowBookmarked
                ? 'تمت الإضافة إلى الأحاديث المحفوظة'
                : 'تمت الإزالة من الأحاديث المحفوظة',
            style: GoogleFonts.tajawal(),
          ),
          backgroundColor: widget.coverColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _shareHadith() async {
    final currentHadith = widget.allHadiths[_currentIndex];

    final content =
        '''
❓ الحديث رقم ${currentHadith.number}

✒️ ${currentHadith.hadith}

📖 شرح الحديث:
${currentHadith.description}

📚 المصدر: ${widget.bookTitle}

📱 تمت المشاركة من تطبيق زاد
    ''';

    try {
      await Share.share(content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء المشاركة',
              style: GoogleFonts.tajawal(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildHadithContent(HadithItem hadith, bool isDark) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2428) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hadith number
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: widget.coverColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'الحديث رقم ${hadith.number}',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Hadith text
              Text(
                hadith.hadith,
                textAlign: TextAlign.right,
                style: GoogleFonts.amiri(
                  fontSize: 18,
                  height: Provider.of<FontSettingsProvider>(context).lineHeight,
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),

              // Explanation button (only show if description exists)
              if (hadith.description.isNotEmpty) ...[
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _showExplanationDialog(hadith, isDark),
                    icon: Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: Text(
                      'شرح الحديث',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                ),
                const SizedBox(height: 20),
              ],

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
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
                  ),
                  const SizedBox(width: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToHadith(int index) {
    if (index >= 0 && index < widget.allHadiths.length) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// عرض شرح الحديث في نافذة حوارية قابلة للسحب
  void _showExplanationDialog(HadithItem hadith, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E2428) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.all(20),
          contentPadding: const EdgeInsets.all(20),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: widget.coverColor, size: 24),
              const SizedBox(width: 12),
              Text(
                'شرح الحديث رقم ${hadith.number}',
                style: GoogleFonts.tajawal(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              hadith.description,
              textAlign: TextAlign.right,
              style: GoogleFonts.tajawal(
                fontSize: 16,
                height: Provider.of<FontSettingsProvider>(context, listen: false).lineHeight,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: hadith.description));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم نسخ الشرح', style: GoogleFonts.tajawal()),
                    backgroundColor: widget.coverColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(Icons.copy, color: widget.coverColor),
              label: Text(
                'نسخ الشرح',
                style: GoogleFonts.tajawal(
                  color: widget.coverColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إغلاق',
                style: GoogleFonts.tajawal(
                  color: widget.coverColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF7F8FA),
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
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _bookmarkedHadiths.contains(_currentHadithNumber)
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                color: Colors.white,
              ),
              onPressed: _toggleBookmark,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: () => _shareHadith(),
            ),
          ],
        ),
        body: StatefulBuilder(
          builder: (context, setState) {
            return PageView.builder(
              controller: _pageController,
              reverse:
                  true, // السحب من اليمين لليسار للحديث التالي (الاتجاه العربي)
              onPageChanged: (index) {
                this.setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: widget.allHadiths.length,
              itemBuilder: (context, index) {
                final currentHadith = widget.allHadiths[index];
                return _buildHadithContent(currentHadith, isDark);
              },
            );
          },
        ),

        // Navigation Buttons
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2428) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _currentIndex > 0
                        ? () => _navigateToHadith(_currentIndex - 1)
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(
                      'السابق',
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.coverColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Hadith Counter
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.allHadiths.length}',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Next Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _currentIndex < widget.allHadiths.length - 1
                        ? () => _navigateToHadith(_currentIndex + 1)
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(
                      'التالي',
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.coverColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
