import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/hadith_item.dart';

class HadithReadingPage extends StatefulWidget {
  final HadithItem hadith;
  final String bookTitle;
  final Color coverColor;
  final List<HadithItem> allHadiths;
  final int currentIndex;

  const HadithReadingPage({
    super.key,
    required this.hadith,
    required this.bookTitle,
    required this.coverColor,
    required this.allHadiths,
    required this.currentIndex,
  });

  @override
  State<HadithReadingPage> createState() => _HadithReadingPageState();
}

class _HadithReadingPageState extends State<HadithReadingPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
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
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark_border_rounded, color: Colors.white),
              onPressed: () {
                // Future bookmark implementation
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              onPressed: () {
                // Future share implementation
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: PageView.builder(
          controller: _pageController,
          reverse: true, // السحب من اليمين لليسار للحديث التالي (الاتجاه العربي)
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
                    fontSize: 18,
                    height: 1.6,
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // عنوان الشرح
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.coverColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(15),
                topLeft: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'شرح الحديث',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
          
          // نص الشرح
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
              border: Border.all(
                color: widget.coverColor.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              hadith.description,
              textAlign: TextAlign.right,
              style: GoogleFonts.amiri(
                fontSize: 16,
                height: 1.6,
                color: isDark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w400,
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // Copy hadith with explanation to clipboard
                  final fullText = '${hadith.hadith}\n\n--- شرح الحديث ---\n${hadith.description}';
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
