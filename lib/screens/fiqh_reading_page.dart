import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../models/fiqh_model.dart';
import '../providers/settings_provider.dart';
import '../services/bookmark_service.dart';

class FiqhReadingPage extends StatefulWidget {
  final FiqhQuestion question;
  final String bookTitle;
  final String jsonPath;
  final List<FiqhQuestion> allQuestions;
  final int currentIndex;
  final VoidCallback? onBookmarkChanged;

  const FiqhReadingPage({
    super.key,
    required this.question,
    required this.bookTitle,
    required this.jsonPath,
    required this.allQuestions,
    required this.currentIndex,
    this.onBookmarkChanged,
  });

  @override
  State<FiqhReadingPage> createState() => _FiqhReadingPageState();
}

class _FiqhReadingPageState extends State<FiqhReadingPage> {
  double _fontSize = 16.0;
  bool _isBookmarked = false;

  @override
  void initState() {
    super.initState();
    _loadFontSize();
    _checkBookmarkStatus();
  }

  Future<void> _loadFontSize() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    setState(() {
      _fontSize = settings.fontSize;
    });
  }

  Future<void> _checkBookmarkStatus() async {
    final isBookmarked = await BookmarkService.isBookmarked(
      widget.jsonPath,
      widget.question.id,
    );

    setState(() {
      _isBookmarked = isBookmarked;
    });
  }

  Future<void> _toggleBookmark() async {
    final isBookmarked = await BookmarkService.toggleBookmark(
      widget.jsonPath,
      widget.question.id,
    );

    setState(() {
      _isBookmarked = isBookmarked;
    });

    // Notify parent to refresh bookmark dashboard
    widget.onBookmarkChanged?.call();

    _showSnackBar(
      isBookmarked
          ? 'تمت الإضافة إلى العلامات المرجعية'
          : 'تمت الإزالة من العلامات المرجعية',
    );
  }

  void _showSnackBar(String message) {
    // Hide any current snackbars before showing a new one
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.tajawal()),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareContent() async {
    final String content =
        '''
📚 ${widget.bookTitle}

❓ السؤال:
${widget.question}

💡 الإجابة:
${widget.question.answer}

🔖 ${widget.question.tags.join(' • ')}

📱 تمت المشاركة من تطبيق إمساكية
    ''';

    try {
      await Share.share(content, subject: 'سؤال وجواب من ${widget.bookTitle}');
    } catch (e) {
      _showSnackBar('حدث خطأ أثناء المشاركة');
    }
  }

  void _increaseFontSize() {
    if (_fontSize < 24.0) {
      setState(() {
        _fontSize += 2.0;
      });
      _saveFontSize();
    }
  }

  void _decreaseFontSize() {
    if (_fontSize > 12.0) {
      setState(() {
        _fontSize -= 2.0;
      });
      _saveFontSize();
    }
  }

  Future<void> _saveFontSize() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.setFontSize(_fontSize);
  }

  void _navigateToQuestion(int index) {
    if (index >= 0 && index < widget.allQuestions.length) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              FiqhReadingPage(
                question: widget.allQuestions[index],
                bookTitle: widget.bookTitle,
                jsonPath: widget.jsonPath,
                allQuestions: widget.allQuestions,
                currentIndex: index,
              ),
        ),
      );
    }
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
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.bookTitle,
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF263238),
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            // Bookmark Button
            IconButton(
              icon: Icon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed: _toggleBookmark,
            ),
            // Share Button
            IconButton(
              icon: Icon(
                Icons.share,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed: _shareContent,
            ),
          ],
        ),
        body: Column(
          children: [
            // Font Size Controls
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2428) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.1),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'حجم الخط:',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _decreaseFontSize,
                    icon: Icon(
                      Icons.remove,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 20,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_fontSize.toInt()}',
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _increaseFontSize,
                    icon: Icon(
                      Icons.add,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 20,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),

            // Question and Answer Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Number
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'السؤال رقم ${widget.question.id}',
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Question
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.22 : 0.06,
                            ),
                            blurRadius: 15,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.help_outline,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'السؤال:',
                                style: GoogleFonts.tajawal(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.question.question,
                            style: GoogleFonts.tajawal(
                              fontSize: _fontSize,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Answer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.22 : 0.06,
                            ),
                            blurRadius: 15,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.green[600],
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'الإجابة:',
                                style: GoogleFonts.tajawal(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.question.answer,
                            style: GoogleFonts.tajawal(
                              fontSize: _fontSize,
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tags
                    if (widget.question.tags.isNotEmpty) ...[
                      Text(
                        'الوسوم:',
                        style: GoogleFonts.tajawal(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.question.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.tajawal(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(
                      height: 100,
                    ), // Extra space for navigation buttons
                  ],
                ),
              ),
            ),
          ],
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
                    onPressed: widget.currentIndex > 0
                        ? () => _navigateToQuestion(widget.currentIndex - 1)
                        : null,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(
                      'السابق',
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Question Counter
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
                    '${widget.currentIndex + 1} / ${widget.allQuestions.length}',
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
                    onPressed:
                        widget.currentIndex < widget.allQuestions.length - 1
                        ? () => _navigateToQuestion(widget.currentIndex + 1)
                        : null,
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(
                      'التالي',
                      style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
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
