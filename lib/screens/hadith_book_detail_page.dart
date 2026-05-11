import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hadith_book.dart';
import '../models/hadith_item.dart';
import '../services/hadith_compute_service.dart';
import 'hadith_reading_page.dart';

class HadithBookDetailPage extends StatefulWidget {
  final HadithBook book;

  const HadithBookDetailPage({super.key, required this.book});

  @override
  State<HadithBookDetailPage> createState() => _HadithBookDetailPageState();
}

class _HadithBookDetailPageState extends State<HadithBookDetailPage> {
  bool _isCoverOpen = false;
  bool _isLoading = true;
  List<HadithItem> _hadiths = [];
  List<HadithItem> _filteredHadiths = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBookContent();
  }

  Future<void> _loadBookContent() async {
    try {
      // تحميل الملف كـ String
      final jsonString = await rootBundle.loadString(widget.book.jsonPath);
      
      // معالجة البيانات في الخلفية لتجنب تجميد الواجهة
      final hadiths = await HadithComputeService.parseHadithsFromJson(jsonString);

      if (mounted) {
        setState(() {
          _hadiths = hadiths;
          _filteredHadiths = hadiths;
          _isLoading = false;
        });

        // تشغيل أنيميشن فتح الغلاف بعد تحميل البيانات بفترة وجيزة
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() => _isCoverOpen = true);
          }
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading book: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// الحصول على معاينة مختصرة من نص الحديث (أول 150 حرف)
  String _getPreviewText(String text) {
    if (text.length <= 150) return text;
    return '${text.substring(0, 150)}...';
  }

  // البحث عن الأحاديث مع تحسين الأولوية وإزالة التشكيل
  Future<void> _searchHadiths(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredHadiths = _hadiths;
      });
      return;
    }

    final results = await HadithComputeService.searchHadithsWithSmartFilter(_hadiths, query);
    if (mounted) {
      setState(() {
        _filteredHadiths = results;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // بناء المحتوى الرئيسي مع معالجة الـ Overflow
  Widget _buildContent(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredHadiths.isEmpty
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
                                'عذراً، لم يتم العثور على أحاديث تطابق بحثك',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'جرب كلمات مفتاحية أخرى أو رقم حديث مختلف',
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
                                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: widget.book.coverColor.withAlpha(32),
                                  ),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.amiri(
                                    fontSize: 16,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'ابحث في الأحاديث...',
                                    hintStyle: GoogleFonts.tajawal(
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search_rounded,
                                      color: widget.book.coverColor,
                                    ),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              _searchController.clear();
                                              _searchHadiths('');
                                            },
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                  onChanged: _searchHadiths,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // قائمة الأحاديث
                            SizedBox(
                              height: constraints.maxHeight - 150, // حساب الارتفاع المتاح
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                itemCount: _filteredHadiths.length,
                                itemBuilder: (context, index) {
                                  final hadith = _filteredHadiths[index];
                                  return _buildHadithCard(hadith, isDark);
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
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: style,
        ));
      }
      
      // النص المظلل
      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(
          backgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.3),
          color: Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ));
      
      start = index + query.length;
    }
    
    // النص المتبقي
    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: style,
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.right,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildHadithCard(HadithItem hadith, bool isDark) {
    final searchQuery = _searchController.text.trim();
    
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
                builder: (context) => HadithReadingPage(
                  hadith: hadith,
                  bookTitle: widget.book.title,
                  coverColor: widget.book.coverColor,
                  allHadiths: _hadiths,
                  currentIndex: _filteredHadiths.indexOf(hadith),
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CircleAvatar لرقم الحديث مع تظليل إذا تطابق
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: searchQuery == hadith.number.toString() 
                        ? const Color(0xFFFFD700).withValues(alpha: 0.3)
                        : widget.book.coverColor,
                    borderRadius: BorderRadius.circular(22),
                    border: searchQuery == hadith.number.toString()
                        ? Border.all(color: const Color(0xFFFFD700), width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${hadith.number}',
                      style: GoogleFonts.tajawal(
                        color: searchQuery == hadith.number.toString() 
                            ? Colors.black87 
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // نص الحديث مع التظليل
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _highlightText(
                        _getPreviewText(hadith.hadith),
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
                            'اقرأ الحديث كاملاً',
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
            const SizedBox(width: 8), // مسافة بادئة من اليمين
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: _buildContent(isDark),
                ),
              ),
            ),

            // Animated Book Cover (الغلاف المتحرك)
            // تعديل الأنميشن لفتح الكتاب من جهة اليمين (كعب الكتاب العربي)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeInOutQuart,
              top: _isCoverOpen ? -MediaQuery.of(context).size.height : 20,
              left: _isCoverOpen ? 0 : 0,
              right: _isCoverOpen ? 0 : 0,
              child: AnimatedRotation(
                turns: _isCoverOpen ? -0.05 : 0.0, // دوران خفيف لمحاكاة فتح الكتاب من اليمين
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
                        height: (MediaQuery.of(context).size.width * 0.75) * (3 / 2),
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
                                  colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent],
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
                            child: Container(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          // المحتوى (الأيقونة والنصوص) - محاذاة صريحة لليسار
                          Padding(
                            padding: const EdgeInsets.fromLTRB(15, 20, 40, 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Icon(Icons.auto_stories_rounded, color: Color(0xFFFFD700), size: 50),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    widget.book.title,
                                    textAlign: TextAlign.left,
                                    style: GoogleFonts.amiri(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: 50,
                                    height: 2,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(height: 15),
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    widget.book.author,
                                    textAlign: TextAlign.left,
                                    style: GoogleFonts.tajawal(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // أيقونة التزيين
                          Positioned(
                            right: 12,
                            top: 15,
                            child: Opacity(
                              opacity: 0.3,
                              child: Icon(Icons.star_border_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ),],
        ),
      ),
    );
  }
}
