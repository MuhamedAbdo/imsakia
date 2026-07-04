import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hadith_book.dart';
import 'hadith_book_detail_page.dart';

class HadithLibraryPage extends StatelessWidget {
  const HadithLibraryPage({super.key});

  static const List<HadithBook> books = [
    HadithBook(
      title: 'صحيح البخاري',
      bookKey: 'bukhari',
      coverColor: Color(0xFF1B5E20), // Deep Green
      author: 'الإمام البخاري',
    ),
    HadithBook(
      title: 'صحيح مسلم',
      bookKey: 'muslim',
      coverColor: Color(0xFF0D47A1), // Deep Blue
      author: 'الإمام مسلم',
    ),
    HadithBook(
      title: 'سنن أبي داود',
      bookKey: 'abi_daud',
      coverColor: Color(0xFF4E342E), // Brown
      author: 'الإمام أبو داود',
    ),
    HadithBook(
      title: 'مسند أحمد',
      bookKey: 'ahmed',
      coverColor: Color(0xFF37474F), // Blue Grey
      author: 'الإمام أحمد بن حنبل',
    ),
    HadithBook(
      title: 'سنن الدارمي',
      bookKey: 'darimi',
      coverColor: Color(0xFF004D40), // Teal
      author: 'الإمام الدارمي',
    ),
    HadithBook(
      title: 'سنن ابن ماجه',
      bookKey: 'ibn_maja',
      coverColor: Color(0xFFBF360C), // Deep Orange
      author: 'الإمام ابن ماجه',
    ),
    HadithBook(
      title: 'موطأ مالك',
      bookKey: 'malik',
      coverColor: Color(0xFF311B92), // Deep Purple
      author: 'الإمام مالك بن أنس',
    ),
    HadithBook(
      title: 'سنن النسائي',
      bookKey: 'nasai',
      coverColor: Color(0xFF880E4F), // Maroon
      author: 'الإمام النسائي',
    ),
    HadithBook(
      title: 'جامع الترمذي',
      bookKey: 'trmizi',
      coverColor: Color(0xFFE65100), // Orange
      author: 'الإمام الترمذي',
    ),
  ];

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
            'مكتبة الحديث الشريف',
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
        body: GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 25,
            childAspectRatio: 2 / 3,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            return BookCard(book: books[index]);
          },
        ),
      ),
    );
  }
}

class BookCard extends StatelessWidget {
  final HadithBook book;
  const BookCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            reverseTransitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (context, animation, secondaryAnimation) => HadithBookDetailPage(book: book),
          ),
        );
      },
      child: Hero(
        tag: book.bookKey,
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
                        colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent],
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
                        child: Icon(Icons.auto_stories_rounded, color: Color(0xFFFFD700), size: 28),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          book.title,
                          textAlign: TextAlign.left,
                          style: GoogleFonts.amiri(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, height: 1.3),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          book.author,
                          textAlign: TextAlign.left,
                          style: GoogleFonts.tajawal(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
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
                    child: Icon(Icons.star_border_rounded, color: Colors.white, size: 16),
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
