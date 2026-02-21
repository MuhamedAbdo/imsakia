import 'package:flutter/gestures.dart';
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
  late PageController _pageController;
  late int _currentJuzId;
  ScrollPhysics _pagePhysics = const NeverScrollableScrollPhysics();
  bool _hasShownNotification = false;

  @override
  void initState() {
    super.initState();
    _currentJuzId = widget.juz['id'] ?? 1;
    _pageController = PageController(initialPage: _currentJuzId - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _updatePhysics(bool isAtTop, bool isAtBottom, bool isShort, int id) {
    if (!mounted) return;
    ScrollPhysics newPhysics;
    if (id == 1) {
      newPhysics = (isAtBottom || isShort) ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics();
    } else if (id == 30) {
      newPhysics = (isAtTop || isShort) ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics();
    } else {
      newPhysics = (isAtTop || isAtBottom || isShort) ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics();
    }

    if (_pagePhysics != newPhysics) {
      setState(() => _pagePhysics = newPhysics);
    }

    if (isAtBottom && !_hasShownNotification && id < 30 && !isShort) {
      _hasShownNotification = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم الجزء.. اسحب لليسار للانتقال للتالي', 
                style: GoogleFonts.tajawal(color: Colors.white), textAlign: TextAlign.center),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.9),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: PageView.builder(
          controller: _pageController,
          itemCount: 30,
          physics: _pagePhysics,
          onPageChanged: (index) {
            setState(() {
              _currentJuzId = index + 1;
              _hasShownNotification = false;
              _pagePhysics = const NeverScrollableScrollPhysics();
            });
          },
          itemBuilder: (context, index) {
            return JuzPageItem(
              juzId: index + 1,
              dbHelper: widget.dbHelper,
              initialAyah: (index + 1 == (widget.juz['id'] ?? 1)) ? widget.initialAyahNumber : null,
              onScroll: (top, bottom, short) => _updatePhysics(top, bottom, short, index + 1),
            );
          },
        ),
      ),
    );
  }
}

class JuzPageItem extends StatefulWidget {
  final int juzId;
  final DbHelper dbHelper;
  final int? initialAyah;
  final Function(bool, bool, bool) onScroll;

  const JuzPageItem({super.key, required this.juzId, required this.dbHelper, required this.onScroll, this.initialAyah});

  @override
  State<JuzPageItem> createState() => _JuzPageItemState();
}

class _JuzPageItemState extends State<JuzPageItem> {
  late ScrollController _scrollController;
  List<Map<String, dynamic>> _ayahItems = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _prepareAyahItems();
  }

  void _prepareAyahItems() async {
    final ayahs = await widget.dbHelper.getAyahsByJuz(widget.juzId);
    if (!mounted) return;
    setState(() {
      _ayahItems = ayahs;
    });

    if (widget.initialAyah != null && widget.initialAyah! > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _scrollToAyah(widget.initialAyah!);
        });
      });
    }
  }

  void _scrollToAyah(int ayahNum) {
    if (_ayahItems.isEmpty || !_scrollController.hasClients) return;
    
    int targetIndex = _ayahItems.indexWhere((ayah) => ayah['number_in_surah'] == ayahNum);
    if (targetIndex != -1) {
      double progress = targetIndex / _ayahItems.length;
      double targetScroll = progress * _scrollController.position.maxScrollExtent;
      
      _scrollController.animateTo(
        targetScroll,
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      widget.onScroll(pos.pixels <= 20, pos.pixels >= pos.maxScrollExtent - 20, pos.maxScrollExtent < 10);
    }
  }

  void _showTafsirDialog(Map<String, dynamic> ayah) async {
    String tafsir = await widget.dbHelper.getTafsir(ayah['surah_id'], ayah['number_in_surah']);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.45,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25))
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("${ayah['surah_name_ar'] ?? ''} - آية ${ayah['number_in_surah']}", 
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                    ),
                    child: Text(_cleanAyahText(ayah['text'] ?? '', ayah['surah_id'], ayah['number_in_surah']), textAlign: TextAlign.center, 
                      style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 20)),
                  ),
                  const SizedBox(height: 15),
                  Text(tafsir, textAlign: TextAlign.justify, style: GoogleFonts.tajawal(fontSize: 16)),
                ])
              )
            )
          ],
        ),
      ),
    );
  }

  // الدالة المصححة والنهائية لحذف البسملة والرموز الزائدة
  String _cleanAyahText(String text, int surahId, int ayahNum) {
    String cleaned = text.trim();

    // 1. حذف البسملة المدمجة في بداية السورة (باستثناء الفاتحة)
    // نستخدم منطق القص (38 حرفاً) المعتمد في الكود الناجح الأول
    if (ayahNum == 1 && surahId != 1) {
      if (cleaned.startsWith("بِسْمِ")) {
        int skipLength = 38; 
        if (cleaned.length > skipLength) {
          cleaned = cleaned.substring(skipLength).trim();
          
          // إزالة أي رموز غريبة أو مسافات قد تتبقى بعد القص مباشرة
          while (cleaned.isNotEmpty && (cleaned.startsWith(' ') || cleaned.startsWith('ۏ'))) {
            cleaned = cleaned.substring(1).trim();
          }
        }
      }
    }

    // 2. حذف رموز التجويد التي تظهر كـ ميم زائدة (مع الحفاظ على علامات الوقف ج، صلے، قلے)
    cleaned = cleaned.replaceAll('\u06E2', ''); // ميم الإقلاب الصغيرة (ۢ)
    cleaned = cleaned.replaceAll('\u06ED', ''); // ميم الإخفاء الصغيرة (ۭ)
    cleaned = cleaned.replaceAll('ۏ', '');     // الرمز الذي يظهر كـ ميم في بعض الخطوط

    return cleaned.trim();
  }

  List<TextSpan> _buildContinuousAyahText(QuranProvider quranProvider) {
    List<TextSpan> spans = [];
    for (var ayah in _ayahItems) {
      final ayahNum = ayah['number_in_surah'];
      final surahId = ayah['surah_id'];
      
      TapGestureRecognizer tapRecognizer = TapGestureRecognizer()
        ..onTap = () => _showTafsirDialog(ayah);

      if (ayahNum == 1) {
        spans.add(TextSpan(children: [
          WidgetSpan(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 25, bottom: 10),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
              ),
              child: Text(
                ayah['surah_name_ar'] ?? '',
                textAlign: TextAlign.center,
                style: GoogleFonts.tajawal(fontSize: quranProvider.fontSize * 1.1, fontWeight: FontWeight.bold, color: Colors.amber[900]),
              ),
            ),
          ),
        ]));
        
        if (surahId != 1 && surahId != 9) {
          spans.add(TextSpan(children: [
            WidgetSpan(
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: const EdgeInsets.only(bottom: 15, top: 10),
                child: Text('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ',
                  style: TextStyle(fontFamily: 'AmiriQuran', fontSize: quranProvider.fontSize + 4, color: Colors.blue[800], fontWeight: FontWeight.bold)),
              ),
            ),
          ]));
        }
      }

      spans.add(TextSpan(children: [
        TextSpan(
          text: _cleanAyahText(ayah['text'] ?? '', surahId, ayahNum),
          recognizer: tapRecognizer,
          style: TextStyle(fontFamily: 'AmiriQuran', fontSize: quranProvider.fontSize, height: 2.2, color: Theme.of(context).colorScheme.onSurface),
        ),
        TextSpan(
          text: ' ﴿$ayahNum﴾ ',
          recognizer: tapRecognizer,
          style: TextStyle(fontFamily: 'AmiriQuran', fontSize: quranProvider.fontSize * 0.8, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
        ),
      ]));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final quranProvider = Provider.of<QuranProvider>(context);

    if (_ayahItems.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text('الجزء ${widget.juzId}', style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(quranProvider.lastJuzId == widget.juzId && quranProvider.isJuzMode ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () {
              int estimatedAyah = 1;
              String surahName = "";
              int surahId = _ayahItems[0]['surah_id'];

              if (_scrollController.hasClients && _ayahItems.isNotEmpty) {
                double progress = (_scrollController.offset / _scrollController.position.maxScrollExtent).clamp(0.0, 1.0);
                int index = (progress * (_ayahItems.length - 1)).round();
                estimatedAyah = _ayahItems[index]['number_in_surah'];
                surahName = _ayahItems[index]['surah_name_ar'] ?? '';
                surahId = _ayahItems[index]['surah_id'];
              }

              quranProvider.saveBookmark(
                surahId: surahId,
                ayahNumber: estimatedAyah,
                isJuzMode: true,
                juzId: widget.juzId,
                name: 'الجزء ${widget.juzId}',
              );

              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حفظ المرجعية: $surahName آية $estimatedAyah', style: GoogleFonts.tajawal()),
                  behavior: SnackBarBehavior.floating,
                )
              );
            },
          ),
          IconButton(icon: const Icon(Icons.text_increase), onPressed: () => quranProvider.increaseFontSize()),
          IconButton(icon: const Icon(Icons.text_decrease), onPressed: () => quranProvider.decreaseFontSize()),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            sliver: SliverToBoxAdapter(
              child: SelectionArea(
                child: Text.rich(
                  TextSpan(children: _buildContinuousAyahText(quranProvider)),
                  textAlign: TextAlign.justify,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
}