import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  final Map<int, GlobalKey> _ayahKeys = {};
  Future<List<Map<String, dynamic>>>? _ayahsFuture;
  bool _hasInitialJumped = false;

  @override
  void initState() {
    super.initState();
    _ayahsFuture = widget.dbHelper.getAyahsByJuz(widget.juz['id']);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
                int topSurahId = 1;
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
                                text:
                                    (ayahNum == 1
                                        ? '\n${ayah['surah_name_ar']}\n'
                                        : '') +
                                    (ayah['text'] ?? ''),
                                style: TextStyle(
                                  fontFamily: 'AmiriQuran',
                                  fontSize: quranProvider.fontSize,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  height: 2.0,
                                ),
                              ),
                              TextSpan(
                                text: ' ﴿${ayahNum}﴾ ',
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
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
