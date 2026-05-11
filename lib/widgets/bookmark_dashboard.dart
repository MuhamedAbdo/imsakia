import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/fiqh_model.dart';
import '../services/bookmark_service.dart';

class BookmarkDashboard extends StatefulWidget {
  final FiqhBook book;
  final List<FiqhQuestion> bookmarkedQuestions;
  final Function(FiqhQuestion) onQuestionTap;
  final VoidCallback onBookmarkRemoved;

  const BookmarkDashboard({
    super.key,
    required this.book,
    required this.bookmarkedQuestions,
    required this.onQuestionTap,
    required this.onBookmarkRemoved,
  });

  @override
  State<BookmarkDashboard> createState() => _BookmarkDashboardState();
}

class _BookmarkDashboardState extends State<BookmarkDashboard> {
  List<FiqhQuestion> _localBookmarkedQuestions = [];

  @override
  void initState() {
    super.initState();
    _localBookmarkedQuestions = List.from(widget.bookmarkedQuestions);
  }

  @override
  void didUpdateWidget(BookmarkDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookmarkedQuestions != widget.bookmarkedQuestions) {
      _localBookmarkedQuestions = List.from(widget.bookmarkedQuestions);
    }
  }

  void _removeQuestionLocally(FiqhQuestion question) {
    setState(() {
      _localBookmarkedQuestions.removeWhere((q) => q.id == question.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final height = MediaQuery.of(context).size.height;

    return Container(
      height: height * 0.8,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2428) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.book.coverColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.bookmark,
                    color: widget.book.coverColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الأسئلة المحفوظة',
                        style: GoogleFonts.tajawal(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        widget.book.title,
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: widget.book.coverColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_localBookmarkedQuestions.length}',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: widget.book.coverColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: _localBookmarkedQuestions.isEmpty
                ? _buildEmptyState(isDark)
                : _buildBookmarksList(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 80,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لم تقم بحفظ أي أسئلة في هذا الباب بعد',
            style: GoogleFonts.tajawal(
              fontSize: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'اضغط على أيقونة العلامة المرجعية في صفحة القراءة لحفظ السؤال',
            style: GoogleFonts.tajawal(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _localBookmarkedQuestions.length,
      itemBuilder: (context, index) {
        final question = _localBookmarkedQuestions[index];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: BookmarkQuestionCard(
            question: question,
            book: widget.book,
            onTap: () => widget.onQuestionTap(question),
            onRemove: () => _removeBookmark(question),
          ),
        );
      },
    );
  }

  Future<void> _removeBookmark(FiqhQuestion question) async {
    try {
      // Remove from local state immediately for instant UI feedback
      _removeQuestionLocally(question);

      // Update the database in background
      await BookmarkService.toggleBookmark(widget.book.jsonPath, question.id);

      // Notify parent to update the counter in AppBar
      widget.onBookmarkRemoved();

      // Hide any current snackbars before showing a new one
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حذف السؤال من المحفوظات',
            style: GoogleFonts.tajawal(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // If database operation fails, add the question back to local state
      setState(() {
        _localBookmarkedQuestions.add(question);
        _localBookmarkedQuestions.sort((a, b) => a.id.compareTo(b.id));
      });

      // Hide any current snackbars before showing error message
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء حذف العلامة المرجعية',
            style: GoogleFonts.tajawal(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class BookmarkQuestionCard extends StatelessWidget {
  final FiqhQuestion question;
  final FiqhBook book;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const BookmarkQuestionCard({
    super.key,
    required this.question,
    required this.book,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2F33) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: book.coverColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question Header
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: book.coverColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${question.id}',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: book.coverColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'السؤال رقم ${question.id}',
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onRemove,
                      icon: Icon(
                        Icons.bookmark_remove,
                        color: Colors.red[400],
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Question Text
                Text(
                  question.question,
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Tags
                if (question.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: question.tags.take(3).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getTagColor(tag).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getTagColor(tag).withValues(alpha: 0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            color: _getTagColor(tag),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],

                // Navigation Hint
                Row(
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'اضغط للقراءة',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getTagColor(String tag) {
    // Assign colors to common tags
    final tagColors = {
      'الصلاة': Colors.blue,
      'صلاة': Colors.blue,
      'الزكاة': Colors.green,
      'زكاة': Colors.green,
      'الصوم': Colors.orange,
      'صوم': Colors.orange,
      'الحج': Colors.purple,
      'حج': Colors.purple,
      'الطهارة': Colors.cyan,
      'طهارة': Colors.cyan,
      'الجنائز': Colors.brown,
      'جنائز': Colors.brown,
      'النكاح': Colors.pink,
      'نكاح': Colors.pink,
      'البيوع': Colors.teal,
      'بيوع': Colors.teal,
      'الأطعمة': Colors.indigo,
      'أطعمة': Colors.indigo,
      'اللباس': Colors.red,
      'لباس': Colors.red,
    };

    return tagColors[tag] ?? Colors.grey;
  }
}
