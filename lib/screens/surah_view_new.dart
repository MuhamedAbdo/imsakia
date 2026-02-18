import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/db_helper.dart';
import '../providers/quran_provider.dart';

class SurahViewNew extends StatefulWidget {
  final Map<String, dynamic> surah;
  final int? initialAyahNumber;
  final DbHelper dbHelper = DbHelper();

  SurahViewNew({super.key, required this.surah, this.initialAyahNumber});

  @override
  State<SurahViewNew> createState() => _SurahViewNewState();
}

class _SurahViewNewState extends State<SurahViewNew> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};
  Future<List<Map<String, dynamic>>>? _ayahsFuture;
  bool _hasInitialJumped = false;

  @override
  void initState() {
    super.initState();
    _ayahsFuture = widget.dbHelper.getAyahsBySurah(widget.surah['id']);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _cleanAyahText(String text, int numberInSurah, int surahId) {
    if (numberInSurah == 1 && surahId != 1) {
      if (text.startsWith("بِسْمِ")) {
        int skipLength = 38;
        if (text.length > skipLength) {
          String cleaned = text.substring(skipLength).trim();
          while (cleaned.isNotEmpty &&
              (cleaned.startsWith(' ') || cleaned.startsWith('ۏ'))) {
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
            widget.surah['name_ar'] ?? "سورة",
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: Icon(
                quranProvider.lastSurahId == widget.surah['id'] &&
                        quranProvider.lastAyahNumber != null &&
                        !quranProvider.isJuzMode
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
              onPressed: () {
                int topAyahNumber = 1;
                double minOffset = double.infinity;

                _ayahKeys.forEach((ayahNumber, key) {
                  final RenderBox? box =
                      key.currentContext?.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final position = box.localToGlobal(Offset.zero).dy;
                    if (position >= 0 && position < minOffset) {
                      minOffset = position;
                      topAyahNumber = ayahNumber;
                    }
                  }
                });

                quranProvider.saveBookmark(
                  surahId: widget.surah['id'] ?? 0,
                  ayahNumber: topAyahNumber,
                  isJuzMode: false,
                  name: 'سورة ${widget.surah['name_ar'] ?? ''}',
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'تم حفظ المرجعية: ${widget.surah['name_ar']} - آية $topAyahNumber',
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

            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Center(child: Text('خطأ في تحميل البيانات'));
            }

            final ayahs = snapshot.data!;

            if (!_hasInitialJumped && widget.initialAyahNumber != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final key = _ayahKeys[widget.initialAyahNumber];
                if (key != null && key.currentContext != null) {
                  Scrollable.ensureVisible(
                    key.currentContext!,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  );
                  _hasInitialJumped = true;
                }
              });
            }

            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  if (widget.surah['id'] != 9 && widget.surah['id'] != 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Text(
                        'بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                        style: TextStyle(
                          fontFamily: 'AmiriQuran',
                          fontSize: quranProvider.fontSize + 4,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SelectionArea(
                    child: Text.rich(
                      TextSpan(
                        children: ayahs.map((ayah) {
                          final ayahNum = ayah['number_in_surah'];
                          _ayahKeys[ayahNum] ??= GlobalKey();

                          return TextSpan(
                            children: [
                              WidgetSpan(
                                child: SizedBox.shrink(key: _ayahKeys[ayahNum]),
                              ),
                              TextSpan(
                                text: _cleanAyahText(
                                  ayah['text'] ?? '',
                                  ayahNum,
                                  widget.surah['id'],
                                ),
                                style: TextStyle(
                                  fontFamily: 'AmiriQuran',
                                  fontSize: quranProvider.fontSize,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  height: 2.0,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _showTafsir(context, ayah),
                              ),
                              TextSpan(
                                text: ' ﴿${ayahNum}﴾ ',
                                style: TextStyle(
                                  fontFamily: 'AmiriQuran',
                                  fontSize: quranProvider.fontSize * 0.8,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => _showTafsir(context, ayah),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                      textAlign: TextAlign.justify,
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showTafsir(BuildContext context, Map<String, dynamic> ayah) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'التفسير الميسر',
                      style: GoogleFonts.tajawal(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: widget.dbHelper.getTafsirByAyah(ayah['id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    final tafsir = snapshot.data;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        tafsir?['data'] ?? 'لا يوجد تفسير متاح',
                        style: GoogleFonts.tajawal(fontSize: 18, height: 1.6),
                        textAlign: TextAlign.justify,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
