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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'فهرس الأجزاء',
          style: GoogleFonts.tajawal(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: juzStartPages.length,
        itemBuilder: (context, index) {
          final juzNumber = index + 1;
          final startPage = juzStartPages[index];
          final juzName = quranService.getJuzName(juzNumber);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.amber[700],
                child: Text(
                  '$juzNumber',
                  style: GoogleFonts.tajawal(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                juzName,
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'تبدأ من صفحة $startPage',
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Logger.info('Navigating to $juzName, page $startPage');
                // Get precise juz information with exact ayah
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
        },
      ),
    );
  }
}
