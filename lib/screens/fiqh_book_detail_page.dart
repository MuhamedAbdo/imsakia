import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' as root_bundle;
import 'package:google_fonts/google_fonts.dart';
import '../models/fiqh_model.dart';
import '../services/bookmark_service.dart';
import 'fiqh_reading_page.dart';

class FiqhBookDetailPage extends StatefulWidget {
  final FiqhBook book;
  const FiqhBookDetailPage({super.key, required this.book});

  @override
  State<FiqhBookDetailPage> createState() => _FiqhBookDetailPageState();
}

class _FiqhBookDetailPageState extends State<FiqhBookDetailPage> {
  bool _isCoverOpen = false;
  List<FiqhQuestion> questions = [];
  List<FiqhQuestion> filteredQuestions = [];
  List<FiqhQuestion> bookmarkedQuestions = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  int _bookmarkCount = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    searchController.addListener(_filterQuestions);
    _loadBookmarkCount();
  }

  @override
  void dispose() {
    searchController.removeListener(_filterQuestions);
    searchController.dispose();
    super.dispose();
  }

  /// تحميل عدد العلامات المرجعية
  Future<void> _loadBookmarkCount() async {
    final count = await BookmarkService.getBookmarksCount(widget.book.jsonPath);
    if (mounted) {
      setState(() {
        _bookmarkCount = count;
      });
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final String response = await root_bundle.rootBundle.loadString(
        'assets/data/fiqh/${widget.book.fileName}',
      );
      final Map<String, dynamic> data = json.decode(response);
      final FiqhBookData bookData = FiqhBookData.fromJson(data);

      setState(() {
        questions = bookData.data;
        filteredQuestions = questions;
        isLoading = false;
      });
      _loadBookmarkedQuestions();

      // تشغيل أنيميشن فتح الغلاف بعد تحميل البيانات بفترة وجيزة
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() => _isCoverOpen = true);
        }
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadBookmarkedQuestions() async {
    final bookmarkedIds = await BookmarkService.getBookmarks(
      widget.book.jsonPath,
    );

    setState(() {
      bookmarkedQuestions = questions
          .where((q) => bookmarkedIds.contains(q.id))
          .toList();
      _bookmarkCount = bookmarkedIds.length;
    });
  }

  void _filterQuestions() {
    final query = searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        filteredQuestions = questions;
      } else {
        filteredQuestions = questions.where((question) {
          return question.question.toLowerCase().contains(query) ||
              question.answer.toLowerCase().contains(query) ||
              question.tags.any((tag) => tag.toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  void _showBookmarkDashboard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: widget.book.coverColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'العلامات المرجعية',
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
              // Bookmarks List
              Expanded(
                child: FutureBuilder<List<int>>(
                  future: BookmarkService.getBookmarkedHadithNumbers(
                    widget.book.jsonPath,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final bookmarkedNumbers = snapshot.data ?? [];

                    if (bookmarkedNumbers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bookmark_border_rounded,
                              size: 64,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد علامات مرجعية بعد',
                              style: GoogleFonts.tajawal(
                                fontSize: 16,
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ابدأ بإضافة الأسئلة المفضلة لديك',
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                color: isDark ? Colors.white54 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Filter questions to show only bookmarked ones
                    final bookmarkedQuestions = questions
                        .where(
                          (question) => bookmarkedNumbers.contains(question.id),
                        )
                        .toList();

                    return ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: bookmarkedQuestions.length,
                      itemBuilder: (context, index) {
                        final question = bookmarkedQuestions[index];
                        return _buildBookmarkedQuestionCard(question, isDark);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // بناء المحتوى الرئيسي مع معالجة الـ Overflow
  Widget _buildContent(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredQuestions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 64,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'عذراً، لم يتم العثور على أسئلة تطابق بحثك',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 16,
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'جرب كلمات مفتاحية أخرى',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.tajawal(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 20),
                        const SizedBox(height: 15),
                        // شريط البحث
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: widget.book.coverColor.withAlpha(32),
                              ),
                            ),
                            child: TextField(
                              controller: searchController,
                              textAlign: TextAlign.right,
                              style: GoogleFonts.amiri(
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'ابحث في الأسئلة...',
                                hintStyle: GoogleFonts.tajawal(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: widget.book.coverColor,
                                ),
                                suffixIcon: searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          searchController.clear();
                                          _filterQuestions();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (value) => _filterQuestions(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // قائمة الأسئلة
                        SizedBox(
                          height:
                              constraints.maxHeight -
                              150, // حساب الارتفاع المتاح
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            itemCount: filteredQuestions.length,
                            itemBuilder: (context, index) {
                              final question = filteredQuestions[index];
                              return _buildQuestionCard(question, isDark);
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  /// الحصول على معاينة مختصرة من نص السؤال (أول 150 حرف)
  String _getPreviewText(String text) {
    if (text.length <= 150) return text;
    return '${text.substring(0, 150)}...';
  }

  Widget _buildQuestionCard(FiqhQuestion question, bool isDark) {
    final searchQuery = searchController.text.trim();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        elevation: 2,
        shadowColor: widget.book.coverColor.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: widget.book.coverColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FiqhReadingPage(
                  question: question,
                  bookTitle: widget.book.title,
                  jsonPath: widget.book.jsonPath,
                  allQuestions: questions,
                  currentIndex: questions.indexOf(question),
                  onBookmarkChanged: () {
                    _loadBookmarkedQuestions();
                    _loadBookmarkCount();
                  },
                ),
              ),
            ).then((_) {
              // Refresh bookmark count when returning from reading page
              if (mounted) {
                _loadBookmarkCount();
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CircleAvatar لرقم السؤال مع تظليل إذا تطابق
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: searchQuery == question.id.toString()
                        ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                        : widget.book.coverColor,
                    borderRadius: BorderRadius.circular(22),
                    border: searchQuery == question.id.toString()
                        ? Border.all(color: const Color(0xFFFFD700), width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${question.id}',
                      style: GoogleFonts.tajawal(
                        color: searchQuery == question.id.toString()
                            ? Colors.black87
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // نص السؤال مع التظليل
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _highlightText(
                        _getPreviewText(question.question),
                        searchQuery,
                        GoogleFonts.amiri(
                          fontSize: 16,
                          height: 1.4,
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.arrow_back_ios,
                            size: 12,
                            color: widget.book.coverColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'اقرأ السؤال كاملاً',
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              color: widget.book.coverColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarkedQuestionCard(FiqhQuestion question, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        elevation: 2,
        shadowColor: widget.book.coverColor.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: widget.book.coverColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () async {
            Navigator.pop(context); // Close the bookmarks sheet
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FiqhReadingPage(
                  question: question,
                  bookTitle: widget.book.title,
                  jsonPath: widget.book.jsonPath,
                  allQuestions: questions,
                  currentIndex: questions.indexOf(question),
                  onBookmarkChanged: () {
                    _loadBookmarkedQuestions();
                    _loadBookmarkCount();
                  },
                ),
              ),
            );

            // Refresh bookmark count when returning from reading page
            if (mounted) {
              _loadBookmarkCount();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CircleAvatar لرقم السؤال
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: widget.book.coverColor,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Text(
                      '${question.id}',
                      style: GoogleFonts.tajawal(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // نص السؤال
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _getPreviewText(question.question),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.amiri(
                          fontSize: 16,
                          height: 1.4,
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.arrow_back_ios,
                            size: 12,
                            color: widget.book.coverColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'اقرأ السؤال كاملاً',
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              color: widget.book.coverColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// تظليل نص البحث داخل النص المعروض
  Widget _highlightText(String text, String query, TextStyle style) {
    if (query.isEmpty) return Text(text, style: style);

    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;

      // النص قبل التظليل
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }

      // النص المظلل
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: style.copyWith(
            backgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.3),
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    // النص المتبقي
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.right,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: widget.book.coverColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'فهرس ${widget.book.title}',
            style: GoogleFonts.tajawal(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              onPressed: _showBookmarkDashboard,
              tooltip: 'العلامات المرجعية',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.bookmark_rounded, color: Colors.white),
                  if (_bookmarkCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _bookmarkCount > 99 ? '99+' : '$_bookmarkCount',
                            style: GoogleFonts.tajawal(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            // Table of Contents (الفهرس)
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 800),
                opacity: _isCoverOpen ? 1.0 : 0.0,
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: _buildContent(isDark),
                ),
              ),
            ),

            // Animated Book Cover (الغلاف المتحرك)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOutQuart,
              top: _isCoverOpen ? -MediaQuery.of(context).size.height : 20,
              left: _isCoverOpen ? 0 : 0,
              right: _isCoverOpen ? 0 : 0,
              child: AnimatedRotation(
                turns: _isCoverOpen
                    ? -0.05
                    : 0.0, // دوران خفيف لمحاكاة فتح الكتاب من اليمين
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeInOutQuart,
                alignment: Alignment.centerRight, // محور الدوران من جهة اليمين
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: _isCoverOpen ? 0.0 : 1.0,
                  child: Center(
                    child: Hero(
                      tag: widget.book.jsonPath,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.75,
                        height:
                            (MediaQuery.of(context).size.width * 0.75) *
                            (3 / 2),
                        decoration: BoxDecoration(
                          color: widget.book.coverColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                            topRight: Radius.circular(6),
                            bottomRight: Radius.circular(6),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                              offset: const Offset(4, 15),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // كعب الكتاب (Spine) - اليمين
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerRight,
                                    end: Alignment.centerLeft,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.35),
                                      Colors.transparent,
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(6),
                                    bottomRight: Radius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            // الخط الفاصل الذهبي
                            Positioned(
                              right: 37,
                              top: 0,
                              bottom: 0,
                              width: 2,
                              child: Container(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            // المحتوى (الأيقونة والنصوص)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                15,
                                20,
                                40,
                                20,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Icon(
                                      Icons.gavel,
                                      color: Color(0xFFFFD700),
                                      size: 50,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      widget.book.title,
                                      textAlign: TextAlign.left,
                                      style: GoogleFonts.amiri(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      'فقه إسلامي',
                                      textAlign: TextAlign.left,
                                      style: GoogleFonts.tajawal(
                                        fontSize: 16,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // أيقونة التزيين
                            Positioned(
                              right: 8,
                              top: 12,
                              child: Opacity(
                                opacity: 0.3,
                                child: Icon(
                                  Icons.star_border_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuestionCard extends StatelessWidget {
  final FiqhQuestion question;
  final FiqhBook book;
  final VoidCallback onTap;

  const QuestionCard({
    super.key,
    required this.question,
    required this.book,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: book.coverColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${question.id}',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: book.coverColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    question.question,
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
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
                          color: book.coverColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.tajawal(
                            fontSize: 10,
                            color: book.coverColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios_new,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
