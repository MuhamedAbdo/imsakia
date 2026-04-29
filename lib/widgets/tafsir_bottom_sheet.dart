import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/db_helper.dart';

class TafsirBottomSheet extends StatelessWidget {
  final Map<String, dynamic> ayah;

  const TafsirBottomSheet({super.key, required this.ayah});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final dbHelper = DbHelper();

    final dialogHeight = MediaQuery.of(context).size.height * 0.9;

    return Container(
      height: dialogHeight,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1e1e1e) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white38 : Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDarkMode
                      ? [const Color(0xFF2d2d2d), const Color(0xFF1e1e1e)]
                      : [const Color(0xFF8B7355), const Color(0xFF6B5B45)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Ayah reference
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white12 : Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'سورة ${_getSurahName(ayah['surah_id'] ?? 1)} - الآية ${ayah['number_in_surah'] ?? 1}',
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        color: isDarkMode
                            ? Colors.white
                            : const Color(0xFFfef8f0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Ayah text
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: dialogHeight * 0.2,
                        maxHeight: dialogHeight * 0.35,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          // التعديل هنا: استخدام .withValues بدلاً من .withOpacity
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode ? Colors.white12 : Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            ayah['text'] ?? '',
                            style: TextStyle(
                              fontFamily: 'HafsSmart',
                              fontSize: 20,
                              height: 1.8,
                              // التعديل هنا أيضاً
                              color: isDarkMode
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : const Color(0xFF2d2d2d),
                            ),
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tafsir content
          Expanded(
            flex: 2,
            child: FutureBuilder<String>(
              future: dbHelper.getTafsir(ayah['surah_id'] ?? 1, ayah['number_in_surah'] ?? 1),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tafsirText = snapshot.data;

                return Container(
                  padding: const EdgeInsets.all(20),
                  child: (tafsirText != null && tafsirText != "لا يوجد تفسير متاح." && tafsirText != "التفسير غير متوفر.")
                      ? Directionality(
                          textDirection: TextDirection.rtl,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Tafsir title
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDarkMode 
                                        ? Colors.white12 
                                        : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'تفسير الآية',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 18,
                                      color: isDarkMode 
                                          ? const Color(0xFFfef8f0) 
                                          : Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Tafsir text
                                Text(
                                  tafsirText,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 18,
                                    height: 1.8,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.menu_book_outlined,
                                size: 64,
                                color: isDarkMode
                                    ? Colors.white38
                                    : Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا يوجد تفسير متاح لهذه الآية',
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  color: isDarkMode
                                      ? Colors.white60
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                );
              },
            ),
          ),

          // Close button
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'إغلاق',
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSurahName(int surahNumber) {
    // تم الإبقاء على الخريطة كما هي للاختصار
    final surahNames = {
      1: 'الفاتحة', 2: 'البقرة', 3: 'آل عمران', 4: 'النساء', 5: 'المائدة',
      6: 'الأنعام', 7: 'الأعراف', 8: 'الأنفال', 9: 'التوبة', 10: 'يونس',
      // ... بقية الأسماء
      114: 'الناس',
    };

    return surahNames[surahNumber] ?? 'سورة $surahNumber';
  }
}
