import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/quran_service.dart';
import '../utils/logger.dart';
import '../models/surah.dart';
import 'quran_reader_screen.dart';

class JuzIndexScreen extends StatelessWidget {
  const JuzIndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final quranService = QuranService();
    final juzStartPages = quranService.juzStartPages;
    // التحقق من الوضع الحالي
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // لون الخلفية في الوضع المظلم يجب أن يكون رمادي عميق جداً وليس أسود مطفأ تماماً لرؤية الظلال
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            'فهرس الأجزاء',
            style: GoogleFonts.tajawal(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color:
                  Colors.white, // أبيض دائماً لأن الخلفية ملونة (primaryColor)
            ),
          ),
          centerTitle: true,
          backgroundColor: primaryColor,
          elevation: 0,
          // ضمان ظهور أيقونة الرجوع باللون الأبيض
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: juzStartPages.length,
          itemBuilder: (context, index) {
            final juzNumber = index + 1;
            final startPage = juzStartPages[index];
            final juzName = quranService.getJuzName(juzNumber);

            return _buildJuzCard(
              context,
              juzNumber,
              juzName,
              startPage,
              isDark,
              primaryColor,
              quranService,
            );
          },
        ),
      ),
    );
  }

  Widget _buildJuzCard(
    BuildContext context,
    int juzNumber,
    String juzName,
    int startPage,
    bool isDark,
    Color primaryColor,
    QuranService quranService,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // في الوضع المظلم نستخدم لوناً أفتح قليلاً من الخلفية للتمييز
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            // تحسين رؤية الدائرة في الوضع المظلم عبر زيادة الشفافية قليلاً
            color: isDark
                ? primaryColor.withOpacity(0.2)
                : primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: primaryColor.withOpacity(isDark ? 0.5 : 0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              '$juzNumber',
              style: GoogleFonts.tajawal(
                color: isDark ? Colors.white : primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          juzName,
          style: GoogleFonts.tajawal(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            // التأكد من أن النص يميل للأبيض في الوضع المظلم
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'تبدأ من صفحة $startPage',
            style: GoogleFonts.tajawal(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_back_ios_new_rounded, // أيقونة أنعم
          color: isDark ? Colors.white54 : primaryColor.withOpacity(0.7),
          size: 20,
        ),
        onTap: () {
          // ... نفس منطق الانتقال السابق ...
          final juzInfo = quranService.getJuzInfo(juzNumber);
          if (juzInfo != null) {
            final surah = juzInfo['surah'] as Surah;
            final ayahInSurah = juzInfo['ayahInSurah'] as int;

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuranReaderScreen(
                  initialSurah: surah.number,
                  initialAyah: ayahInSurah,
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
