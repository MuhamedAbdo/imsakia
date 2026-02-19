import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/db_helper.dart';
import '../providers/quran_provider.dart';

class JuzViewNew extends StatefulWidget {
  final Map<String, dynamic> juz;
  final int? initialAyahNumber;
  final DbHelper dbHelper = DbHelper();

  JuzViewNew({super.key, required this.juz, this.initialAyahNumber});

  @override
  State<JuzViewNew> createState() => _JuzViewNewState();
}

class _JuzViewNewState extends State<JuzViewNew> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _ayahKeys = {};
  Future<List<Map<String, dynamic>>>? _ayahsFuture;
  bool _hasInitialJumped = false;

  @override
  void initState() {
    super.initState();
    print('JuzViewNew: Initializing Juz ${widget.juz['id']}');
    _ayahsFuture = widget.dbHelper.getAyahsByJuz(widget.juz['id']).then((ayahs) {
      print('JuzViewNew: Loaded ${ayahs.length} ayahs for Juz ${widget.juz['id']}');
      if (ayahs.isNotEmpty) {
        print('JuzViewNew: First ayah - Surah ${ayahs.first['surah_id']}, Ayah ${ayahs.first['number_in_surah']}');
      }
      return ayahs;
    }).catchError((error) {
      print('JuzViewNew: Error loading ayahs: $error');
      throw error;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Helper method to clean ayah text by removing duplicate Basmala
  String _getCleanAyahText(Map<String, dynamic> ayah, int surahId, int ayahNum) {
    String text = ayah['text'] ?? '';
    
    // Match logic from SurahViewNew
    if (ayahNum == 1 && surahId != 1) {
      if (text.startsWith("بِسْمِ")) {
        // Use same skipLength that worked in other file
        int skipLength = 38; 
        if (text.length > skipLength) {
          String cleaned = text.substring(skipLength).trim();
          // Additional cleaning for special characters/spaces often found in the DB
          while (cleaned.isNotEmpty && (cleaned.startsWith(' ') || cleaned.startsWith('ۏ'))) {
            cleaned = cleaned.substring(1).trim();
          }
          return cleaned;
        }
      }
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final quranProvider = Provider.of<QuranProvider>(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: Text(
            'الجزء ${widget.juz['id']}',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: Icon(
                quranProvider.lastJuzId == widget.juz['id'] &&
                        quranProvider.lastAyahNumber != null &&
                        quranProvider.isJuzMode
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
              onPressed: () {
                int topAyahNumber = 1;
                double minOffset = double.infinity;

                _ayahKeys.forEach((keyString, key) {
                  final RenderBox? box =
                      key.currentContext?.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final position = box.localToGlobal(Offset.zero).dy;
                    if (position >= 0 && position < minOffset) {
                      minOffset = position;
                      // Extract ayah number from key string
                      final parts = keyString.split('_');
                      if (parts.length >= 4) {
                        topAyahNumber = int.tryParse(parts[3]) ?? 1;
                      }
                    }
                  }
                });

                quranProvider.saveBookmark(
                  surahId:
                      0, // In Juz mode, surahId might be less relevant for the label
                  ayahNumber: topAyahNumber,
                  juzId: widget.juz['id'],
                  isJuzMode: true,
                  name: 'الجزء ${widget.juz['id']}',
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم حفظ المرجعية: الجزء ${widget.juz['id']} - آية $topAyahNumber',
                      style: GoogleFonts.tajawal(),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.text_increase),
              onPressed: () => quranProvider.increaseFontSize(),
            ),
            IconButton(
              icon: const Icon(Icons.text_decrease),
              onPressed: () => quranProvider.decreaseFontSize(),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _ayahsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              print('JuzViewNew: Snapshot error: ${snapshot.error}');
              return Center(child: Text('خطأ في تحميل البيانات: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              print('JuzViewNew: No data available');
              return const Center(child: Text('لا توجد بيانات'));
            }

            if (snapshot.data!.isEmpty) {
              print('JuzViewNew: Empty data for Juz ${widget.juz['id']}');
              return Center(child: Text('لا توجد آيات في الجزء ${widget.juz['id']}'));
            }

            final ayahs = snapshot.data!;

            if (!_hasInitialJumped && widget.initialAyahNumber != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Find the key for the initial ayah
                final targetKey = _ayahKeys.entries
                    .where((entry) => entry.key.contains('_a${widget.initialAyahNumber}'))
                    .firstOrNull;
                if (targetKey != null && targetKey.value.currentContext != null) {
                  Scrollable.ensureVisible(
                    targetKey.value.currentContext!,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                  _hasInitialJumped = true;
                }
              });
            }

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(20.0),
                  sliver: SliverToBoxAdapter(
                    child: SelectionArea(
                      child: Text.rich(
                        TextSpan(
                          children: ayahs.map((ayah) {
                            final ayahNum = ayah['number_in_surah'];
                            final surahId = ayah['surah_id'];
                            final keyString = 'juz_${widget.juz['id']}_s${surahId}_a$ayahNum';
                            _ayahKeys[keyString] ??= GlobalKey();

                            return TextSpan(
                              children: [
                                WidgetSpan(
                                  child: SizedBox(
                                    key: _ayahKeys[keyString],
                                    width: 1,
                                    height: 1,
                                  ),
                                ),
                                // Surah Header for first ayah of each surah
                                if (ayahNum == 1)
                                  WidgetSpan(
                                    child: Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(top: 20.0, bottom: 8.0),
                                      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6.0),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        ayah['surah_name_ar'] ?? '',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.tajawal(
                                          fontSize: quranProvider.fontSize * 1.15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber[900] ?? Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Basmala for all surahs except Al-Fatiha (surah 1) and At-Tawbah (surah 9)
                                // Al-Fatiha keeps Basmala in its first ayah text
                                // At-Tawbah has no Basmala
                                if (ayahNum == 1 && surahId != 1 && surahId != 9)
                                  WidgetSpan(
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                                      margin: const EdgeInsets.only(bottom: 6.0),
                                      child: Text(
                                        'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'AmiriQuran',
                                          fontSize: quranProvider.fontSize * 0.9,
                                          color: Colors.grey[700],
                                          height: 1.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Remove Basmala from ayah text if it's not Surah 1 and this is ayah 1
                                TextSpan(
                                  text: _getCleanAyahText(ayah, surahId, ayahNum),
                                  style: TextStyle(
                                    fontFamily: 'AmiriQuran',
                                    fontSize: quranProvider.fontSize,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    height: 2.0,
                                  ),
                                ),
                                TextSpan(
                                  text: ' ﴿$ayahNum﴾ ',
                                  style: TextStyle(
                                    fontFamily: 'AmiriQuran',
                                    fontSize: quranProvider.fontSize * 0.8,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
