import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/db_helper.dart';
import '../providers/quran_provider.dart';

class SurahViewNew extends StatefulWidget {
  final Map<String, dynamic> surah;
  final int? initialAyahNumber;
  final String? searchText;
  final DbHelper dbHelper = DbHelper();

  SurahViewNew({super.key, required this.surah, this.initialAyahNumber, this.searchText});

  @override
  State<SurahViewNew> createState() => _SurahViewNewState();
}

class _SurahViewNewState extends State<SurahViewNew> {
  late PageController _pageController;
  late int _currentSurahId;
  List<Map<String, dynamic>> _allSurahs = [];

  @override
  void initState() {
    super.initState();
    _currentSurahId = widget.surah['id'] ?? 1;
    _pageController = PageController(initialPage: _currentSurahId - 1);
    _loadSurahNames();
  }

  Future<void> _loadSurahNames() async {
    final surahs = await widget.dbHelper.getSurahs();
    if (mounted) setState(() => _allSurahs = surahs);
  }

  String _getSurahName(int id) {
    if (_allSurahs.isEmpty) return "سورة ...";
    final s = _allSurahs.firstWhere((element) => element['id'] == id, orElse: () => {});
    return s['name_ar'] ?? "سورة";
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: PageView.builder(
          controller: _pageController,
          itemCount: 114,
          onPageChanged: (index) => setState(() => _currentSurahId = index + 1),
          itemBuilder: (context, index) {
            return SurahPageContent(
              surahId: index + 1,
              surahName: _getSurahName(index + 1),
              dbHelper: widget.dbHelper,
              initialAyah: (index + 1 == widget.surah['id']) ? widget.initialAyahNumber : null,
              searchText: (index + 1 == widget.surah['id']) ? widget.searchText : null,
            );
          },
        ),
      ),
    );
  }
}

class SurahPageContent extends StatefulWidget {
  final int surahId;
  final String surahName;
  final DbHelper dbHelper;
  final int? initialAyah;
  final String? searchText;

  const SurahPageContent({super.key, required this.surahId, required this.surahName, required this.dbHelper, this.initialAyah, this.searchText});

  @override
  State<SurahPageContent> createState() => _SurahPageContentState();
}

class _SurahPageContentState extends State<SurahPageContent> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _ayahItems = [];
  final Map<int, GlobalKey> _ayahKeys = {};

  @override
  void initState() {
    super.initState();
    _loadAyahs();
  }

  // الدالة السحرية لحل مشكلة الميم الزائدة ورموز التجويد المزعجة
  String _cleanAyahText(String text, int numberInSurah, int surahId) {
    String cleaned = text;

    // 1. معالجة البسملة الملتصقة في الآية الأولى
    if (numberInSurah == 1 && surahId != 1) {
      if (cleaned.startsWith("بِسْمِ")) {
        int skipLength = 38; 
        if (cleaned.length > skipLength) {
          cleaned = cleaned.substring(skipLength).trim();
        }
      }
    }

    // 2. حذف رموز الميم الزائدة (رموز الإقلاب والإخفاء التي تظهر كحروف مستقلة)
    // نستخدم الـ Unicode الخاص بكل أشكال الميم الصغيرة في المصحف
    cleaned = cleaned.replaceAll('\u06E2', ''); // ميم الإقلاب الصغيرة فوق الكلمة
    cleaned = cleaned.replaceAll('\u06ED', ''); // ميم الإخفاء الصغيرة
    cleaned = cleaned.replaceAll('ۭ', '');      // ميم صغيرة أخرى
    cleaned = cleaned.replaceAll('ۢ', '');      // علامة إقلاب
    cleaned = cleaned.replaceAll('ۏ', '');      // الرمز الغريب الذي يظهر أحياناً

    // تنظيف المسافات الزائدة الناتجة عن الحذف
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    return cleaned.trim();
  }

  void _loadAyahs() async {
    final ayahs = await widget.dbHelper.getAyahsBySurah(widget.surahId);
    if (!mounted) return;
    
    final processedAyahs = ayahs.map((ayah) {
      final Map<String, dynamic> mutableAyah = Map.from(ayah);
      mutableAyah['text'] = _cleanAyahText(
        ayah['text'] ?? '', 
        ayah['number_in_surah'], 
        widget.surahId
      );
      return mutableAyah;
    }).toList();

    for (var ayah in processedAyahs) { 
      _ayahKeys[ayah['number_in_surah']] = GlobalKey(); 
    }
    
    setState(() => _ayahItems = processedAyahs);
    
    if (widget.initialAyah != null && widget.initialAyah! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToAyah(widget.initialAyah!));
    }
  }

  void _scrollToAyah(int ayahNum) {
    final key = _ayahKeys[ayahNum];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(seconds: 1), curve: Curves.easeInOut);
    }
  }

  int _calculateCurrentAyah() {
    int currentAyah = 1;
    double minDistance = double.infinity;
    _ayahKeys.forEach((ayahNum, key) {
      final RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        final position = box.localToGlobal(Offset.zero).dy;
        if (position >= 0 && position < minDistance) {
          minDistance = position;
          currentAyah = ayahNum;
        }
      }
    });
    return currentAyah;
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
            Text("${widget.surahName} - آية ${ayah['number_in_surah']}", 
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                    ),
                    child: Text(ayah['text'] ?? '', textAlign: TextAlign.center, 
                      style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 22)),
                  ),
                  const SizedBox(height: 15),
                  Text(tafsir, textAlign: TextAlign.justify, style: GoogleFonts.tajawal(fontSize: 17, height: 1.6)),
                ])
              )
            )
          ],
        ),
      ),
    );
  }

  List<TextSpan> _buildHighlightedSpans(String text, String? query, TextStyle style, Map<String, dynamic> ayah) {
    if (query == null || query.trim().isEmpty) {
      return [TextSpan(text: text, style: style, recognizer: TapGestureRecognizer()..onTap = () => _showTafsirDialog(ayah))];
    }
    String normalize(String s) => s.replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '').replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');
    String normQuery = normalize(query.trim()).replaceFirst('ال', '');
    List<TextSpan> spans = [];
    List<String> words = text.split(' ');
    for (int i = 0; i < words.length; i++) {
      String word = words[i];
      bool isMatch = normalize(word).replaceFirst('ال', '').contains(normQuery);
      spans.add(TextSpan(
        text: word,
        style: isMatch ? style.copyWith(backgroundColor: Colors.yellow.withOpacity(0.5), color: Colors.red[900], fontWeight: FontWeight.bold) : style,
        recognizer: TapGestureRecognizer()..onTap = () => _showTafsirDialog(ayah),
      ));
      if (i < words.length - 1) spans.add(TextSpan(text: ' ', style: style));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final quranProvider = Provider.of<QuranProvider>(context);
    if (_ayahItems.isEmpty) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white), 
        title: Text(widget.surahName, style: GoogleFonts.tajawal(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(quranProvider.lastSurahId == widget.surahId ? Icons.bookmark : Icons.bookmark_border, color: Colors.white),
            onPressed: () {
              int currentAyah = _calculateCurrentAyah();
              quranProvider.saveBookmark(surahId: widget.surahId, ayahNumber: currentAyah, isJuzMode: false, name: widget.surahName);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ المرجعية عند الآية $currentAyah', style: GoogleFonts.tajawal())));
            },
          ),
          IconButton(icon: const Icon(Icons.text_increase, color: Colors.white), onPressed: () => quranProvider.increaseFontSize()),
          IconButton(icon: const Icon(Icons.text_decrease, color: Colors.white), onPressed: () => quranProvider.decreaseFontSize()),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          children: [
            if (widget.surahId != 1 && widget.surahId != 9)
              Padding(
                padding: const EdgeInsets.only(bottom: 25),
                child: Text('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ', 
                  style: TextStyle(fontFamily: 'AmiriQuran', fontSize: quranProvider.fontSize + 6, color: Colors.blue[800], fontWeight: FontWeight.bold)),
              ),
            SelectionArea(
              child: Text.rich(
                TextSpan(
                  children: _ayahItems.map((ayah) {
                    int num = ayah['number_in_surah'];
                    return TextSpan(
                      children: [
                        WidgetSpan(child: SizedBox.fromSize(size: Size.zero, key: _ayahKeys[num])),
                        ..._buildHighlightedSpans(ayah['text'], widget.searchText, TextStyle(fontFamily: 'AmiriQuran', fontSize: quranProvider.fontSize, height: 2.2, color: Theme.of(context).colorScheme.onSurface), ayah),
                        TextSpan(
                          text: ' ﴿$num﴾ ',
                          style: TextStyle(fontFamily: 'AmiriQuran', fontSize: quranProvider.fontSize * 0.8, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()..onTap = () => _showTafsirDialog(ayah),
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
      ),
    );
  }

  @override
  void dispose() { _scrollController.dispose(); super.dispose(); }
}