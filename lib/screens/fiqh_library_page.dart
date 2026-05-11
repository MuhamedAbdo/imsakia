import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/fiqh_model.dart';
import 'fiqh_book_detail_page.dart';

class FiqhLibraryPage extends StatefulWidget {
  const FiqhLibraryPage({super.key});

  @override
  State<FiqhLibraryPage> createState() => _FiqhLibraryPageState();
}

class _FiqhLibraryPageState extends State<FiqhLibraryPage> {
  List<FiqhBook> books = [];
  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();
    _loadFiqhBooks();
  }

  Future<void> _loadFiqhBooks() async {
    try {
      debugPrint('🔍 Loading Fiqh books from assets/data/fiqh/index.json');

      final String response = await rootBundle.loadString(
        'assets/data/fiqh/index.json',
      );

      debugPrint(
        '📄 JSON response loaded successfully, length: ${response.length}',
      );

      final List<dynamic> data = json.decode(response);
      debugPrint('📊 Parsed ${data.length} books from JSON');

      List<FiqhBook> loadedBooks = data
          .map((json) => FiqhBook.fromJson(json))
          .toList();

      // Sort by ID (ascending) to ensure correct Islamic ordering
      // The index.json file is already ordered Islamically (1: الطهارة, 2: الصلاة, 3: الجنائز, etc.)
      loadedBooks.sort((a, b) => a.id.compareTo(b.id));

      debugPrint(
        '✅ Successfully loaded and sorted ${loadedBooks.length} Fiqh books',
      );

      setState(() {
        books = loadedBooks;
        isLoading = false;
        hasError = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading Fiqh books: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      debugPrint('🔍 Error type: ${e.runtimeType}');

      setState(() {
        isLoading = false;
        hasError = true;
      });
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
            'مكتبة الفقه الإسلامي',
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
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : hasError
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'خطأ في تحميل مكتبة الفقه',
                      style: GoogleFonts.tajawal(
                        fontSize: 18,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى',
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          isLoading = true;
                          hasError = false;
                        });
                        _loadFiqhBooks();
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(
                        'إعادة المحاولة',
                        style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 25,
                  childAspectRatio: 2 / 3,
                ),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  return FiqhBookCard(book: books[index]);
                },
              ),
      ),
    );
  }
}

class FiqhBookCard extends StatelessWidget {
  final FiqhBook book;
  const FiqhBookCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            reverseTransitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (context, animation, secondaryAnimation) =>
                FiqhBookDetailPage(book: book),
          ),
        );
      },
      child: Hero(
        tag: book.fileName,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Container(
            decoration: BoxDecoration(
              color: book.coverColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                topRight: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(4, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                // 1. كعب الكتاب (Spine) - اليمين
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 25,
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
                // 2. الخط الفاصل الذهبي
                Positioned(
                  right: 22,
                  top: 0,
                  bottom: 0,
                  width: 1.5,
                  child: Container(color: Colors.white.withValues(alpha: 0.15)),
                ),
                // 3. المحتوى (الأيقونة والنصوص) - محاذاة صريحة لليسار
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 25, 40, 25),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.gavel,
                          color: Color(0xFFFFD700),
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          book.title,
                          textAlign: TextAlign.left,
                          style: GoogleFonts.amiri(
                            fontSize: 18,
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
                            fontSize: 13,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 4. أيقونة التزيين
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
    );
  }
}
