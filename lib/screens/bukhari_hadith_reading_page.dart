import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bukhari_model.dart';
import '../providers/quran_provider.dart';
import 'package:provider/provider.dart';

class BukhariHadithReadingPage extends StatelessWidget {
  final BukhariHadith hadith;
  final String bookTitle;

  const BukhariHadithReadingPage({
    super.key,
    required this.hadith,
    required this.bookTitle,
  });

  /// مشاركة الحديث كنص منسق
  Future<void> _shareHadith(BuildContext context) async {
    final shareText =
        '''
📖 ${hadith.text}

📚 الكتاب: $bookTitle
🔢 رقم الحديث: ${hadith.id}

_________________________
تمت المشاركة من تطبيق زاد
    ''';

    try {
      final result = await Share.share(
        shareText,
        subject: 'حديث من $bookTitle - رقم ${hadith.id}',
      );

      // التحقق من نتيجة المشاركة
      if (result.status == ShareResultStatus.success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم مشاركة الحديث بنجاح'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        String errorMessage = 'حدث خطأ أثناء المشاركة';

        // تحديد نوع الخطأ بدقة أكبر
        if (e.toString().contains('PlatformException')) {
          errorMessage = 'لا يوجد تطبيقات مشاركة متاحة';
        } else if (e.toString().contains('Timeout')) {
          errorMessage = 'انتهت مهلة المشاركة، حاول مرة أخرى';
        } else if (e.toString().contains('Permission')) {
          errorMessage = 'يجب السماح بالوصول لتطبيقات المشاركة';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'حاول مرة أخرى',
              textColor: Colors.white,
              onPressed: () => _shareHadith(context),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final appBarColor = isDarkMode ? Colors.black87 : Colors.blue;
    const appBarContentColor = Colors.white;
    final fontSize = Provider.of<QuranProvider>(context).fontSize;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF121212)
            : const Color(0xFFF5F5F0),
        appBar: AppBar(
          backgroundColor: appBarColor,
          elevation: 2,
          title: Text(
            '$bookTitle - حديث رقم ${hadith.id}',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: appBarContentColor,
              fontSize: 16,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: appBarContentColor),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded, color: appBarContentColor),
              onPressed: () => _shareHadith(context),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: appBarContentColor),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: hadith.text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ الحديث')),
                  );
                }
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with hadith number
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'حديث رقم: ${hadith.id}',
                    style: GoogleFonts.tajawal(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Hadith text
                Text(
                  hadith.text,
                  style: GoogleFonts.amiri(
                    fontSize: fontSize,
                    height: 1.8,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.justify,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 30),
                // Footer
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'صحيح البخاري',
                    style: GoogleFonts.tajawal(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
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
