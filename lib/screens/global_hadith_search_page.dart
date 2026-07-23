import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hadith_book.dart';
import '../models/hadith_item.dart';
import '../services/hadith_database_service.dart';
import 'hadith_library_page.dart';
import 'hadith_reading_page.dart';

class GlobalHadithSearchPage extends StatefulWidget {
  const GlobalHadithSearchPage({super.key});

  @override
  State<GlobalHadithSearchPage> createState() => _GlobalHadithSearchPageState();
}

class _GlobalHadithSearchPageState extends State<GlobalHadithSearchPage> {
  bool _isLoading = false;
  List<HadithItem> _results = [];
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _results = [];
    });

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final results = await HadithDatabaseService.instance.searchAllHadiths(query, limit: 100);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// الحصول على معاينة مختصرة من نص الحديث
  String _getPreviewText(String text) {
    if (text.length <= 150) return text;
    return '${text.substring(0, 150)}...';
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

  // الحصول على معلومات الكتاب
  HadithBook _getBookInfo(String? bookKey) {
    if (bookKey == null) return HadithLibraryPage.books.first;
    return HadithLibraryPage.books.firstWhere(
      (b) => b.bookKey == bookKey,
      orElse: () => HadithLibraryPage.books.first,
    );
  }

  Widget _buildHadithCard(HadithItem hadith, bool isDark) {
    final searchQuery = _searchController.text.trim();
    final bookInfo = _getBookInfo(hadith.bookKey);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 2,
        shadowColor: bookInfo.coverColor.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
            color: bookInfo.coverColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () async {
            // Because reading page requires the full book's hadiths for swiping,
            // we need to fetch them. Or we could pass just the single hadith 
            // if we update reading page to handle single hadith.
            // But reading page needs `allHadiths` list. 
            // We can fetch the book's hadiths first.
            
            // Show loading dialog if fetching takes time
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(child: CircularProgressIndicator()),
            );
            
            final bookHadiths = await HadithDatabaseService.instance.getHadiths(bookInfo.bookKey);
            final idx = bookHadiths.indexWhere((h) => h.number == hadith.number);
            
            if (context.mounted) {
              Navigator.pop(context); // close dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HadithReadingPage(
                    hadith: hadith,
                    bookTitle: bookInfo.title,
                    coverColor: bookInfo.coverColor,
                    allHadiths: bookHadiths,
                    currentIndex: idx != -1 ? idx : 0,
                    bookKey: bookInfo.bookKey,
                  ),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رأس البطاقة (اسم الكتاب + رقم الحديث)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: bookInfo.coverColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: bookInfo.coverColor.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 14, color: bookInfo.coverColor),
                          const SizedBox(width: 6),
                          Text(
                            bookInfo.title,
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: bookInfo.coverColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'رقم: ${hadith.number}',
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // نص الحديث
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _highlightText(
                        _getPreviewText(hadith.hadith),
                        searchQuery,
                        GoogleFonts.amiri(
                          fontSize: 16,
                          height: 1.4,
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'البحث الشامل في الأحاديث',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF263238),
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 10),
            // شريط البحث
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textAlign: TextAlign.right,
                  autofocus: true,
                  style: GoogleFonts.amiri(
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ابحث في أكثر من 60,000 حديث...',
                    hintStyle: GoogleFonts.tajawal(
                      color: isDark ? Colors.white54 : Colors.black38,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.grey,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (!_isLoading && _results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'تم العثور على ${_results.length} نتيجة',
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ),
            // النتائج
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty && _searchController.text.trim().isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 64,
                                color: isDark ? Colors.white38 : Colors.black26,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لم يتم العثور على نتائج',
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _results.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.library_books_rounded,
                                    size: 64,
                                    color: isDark ? Colors.white12 : Colors.black12,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'اكتب كلمة للبحث في جميع الكتب',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 16,
                                      color: isDark ? Colors.white54 : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 20),
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                return _buildHadithCard(_results[index], isDark);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
