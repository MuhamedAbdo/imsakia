import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/quran_text_service.dart';
import '../services/tafsir_service.dart';
import '../models/quran_models.dart';
import '../widgets/surah_header_widget.dart';
import '../widgets/tafsir_bottom_sheet.dart';

class QuranReaderScreen extends StatefulWidget {
  final int? initialSurah;
  final int? initialAyah;

  const QuranReaderScreen({super.key, this.initialSurah, this.initialAyah});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final QuranTextService _quranService = QuranTextService();
  final TafsirService _tafsirService = TafsirService();
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  List<QuranSurah> _surahs = [];
  bool _isLoading = true;
  bool _isInitialMount = true;
  double _fontSize = 24.0;
  String _currentTitle = "";

  // Store gesture recognizers for proper disposal
  final List<TapGestureRecognizer> _gestureRecognizers = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    // Dispose all gesture recognizers
    for (final recognizer in _gestureRecognizers) {
      recognizer.dispose();
    }
    _gestureRecognizers.clear();

    super.dispose();
  }

  Future<void> _init() async {
    await _quranService.loadQuranData();
    await _tafsirService.loadTafsirData();
    double savedFontSize = await _quranService.getFontSize();

    // تحديد السورة الابتدائية لضبط العنوان فوراً
    int initialSIdx = 0;
    if (widget.initialSurah != null) {
      initialSIdx = widget.initialSurah! - 1;
    }

    setState(() {
      _surahs = _quranService.surahs;
      _isLoading = false;
      _fontSize = savedFontSize.clamp(18.0, 38.0);
      // ضبط العنوان الابتدائي لتجنب الفراغ في البداية
      if (_surahs.isNotEmpty && initialSIdx < _surahs.length) {
        _currentTitle = _surahs[initialSIdx].name;
      }
    });

    _positionsListener.itemPositions.addListener(_onScroll);

    final progress = await _quranService.getProgress();
    final bookmark = await _quranService.getBookmark();

    int targetIndex = 0;
    double targetOffset = 0.0;

    if (widget.initialSurah != null) {
      targetIndex = (widget.initialSurah! - 1) * 2;
    } else if (bookmark != null) {
      targetIndex = bookmark['index'];
      targetOffset = bookmark['offset'];
      // Update title immediately when using bookmark
      _updateTitleFromIndex(targetIndex);
    } else if (progress != null) {
      targetIndex = progress['index'];
      targetOffset = progress['offset'];
      // Update title immediately when using progress
      _updateTitleFromIndex(targetIndex);
    }

    Future.delayed(const Duration(milliseconds: 400), () {
      if (_scrollController.isAttached) {
        _scrollController.jumpTo(index: targetIndex, alignment: targetOffset);
      }
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _isInitialMount = false;
      });
    });
  }

  void _updateTitleFromIndex(int index) {
    int sIdx = index ~/ 2;
    if (sIdx >= 0 && sIdx < _surahs.length) {
      final surah = _surahs[sIdx];
      if (_currentTitle != surah.name) {
        setState(() => _currentTitle = surah.name);
      }
    }
  }

  void _onScroll() {
    if (_isInitialMount) return;

    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final topItem = positions.reduce(
      (a, b) => a.itemLeadingEdge.abs() < b.itemLeadingEdge.abs() ? a : b,
    );
    _quranService.saveProgress(topItem.index, topItem.itemLeadingEdge);

    int sIdx = topItem.index ~/ 2;
    if (sIdx < _surahs.length) {
      final surah = _surahs[sIdx];

      // تحديث العنوان عند التمرير
      if (_currentTitle != surah.name) {
        setState(() => _currentTitle = surah.name);
      }
    }
  }

  void _showFontSizeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 150,
        child: Column(
          children: [
            Text(
              "حجم خط القراءة",
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
            StatefulBuilder(
              builder: (context, setSheetState) => Slider(
                value: _fontSize.clamp(18.0, 38.0),
                min: 18,
                max: 38,
                onChanged: (val) {
                  setSheetState(() => _fontSize = val);
                  setState(() {});
                  _quranService.saveFontSize(val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // تعديلات الألوان والخط لضمان الوضوح التام
        backgroundColor: Theme.of(context).primaryColor,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _currentTitle,
          style: GoogleFonts.amiriQuran(
            fontSize: 26,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined, color: Colors.white),
            onPressed: () async {
              final pos = _positionsListener.itemPositions.value;
              if (pos.isNotEmpty) {
                final top = pos.reduce(
                  (a, b) =>
                      a.itemLeadingEdge.abs() < b.itemLeadingEdge.abs() ? a : b,
                );
                await _quranService.saveBookmark(
                  top.index,
                  top.itemLeadingEdge,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "تم حفظ موضع القراءة",
                      style: GoogleFonts.tajawal(),
                    ),
                    backgroundColor: Colors.green[700],
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.format_size, color: Colors.white),
            onPressed: _showFontSizeSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ScrollablePositionedList.builder(
              itemScrollController: _scrollController,
              itemPositionsListener: _positionsListener,
              itemCount: _surahs.length * 2,
              itemBuilder: (context, index) {
                int sIdx = index ~/ 2;
                return index % 2 == 0
                    ? SurahHeaderWidget(surah: _surahs[sIdx])
                    : _buildContent(_surahs[sIdx]);
              },
            ),
    );
  }

  Widget _buildContent(QuranSurah surah) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Basmalah as separate centered widget
        if (_shouldShowBasmalah(surah))
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Center(
              child: Text(
                "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                textAlign: TextAlign.center,
                style: GoogleFonts.amiriQuran(
                  fontSize: _fontSize + 2,
                  color: isDark ? Colors.amber[200] : Colors.brown[600],
                  height: 2.1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        // Verses as justified paragraph
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 15, 24, 40),
          child: RichText(
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.justify,
            text: TextSpan(children: _buildTextSpans(surah, isDark)),
          ),
        ),
      ],
    );
  }

  List<TextSpan> _buildTextSpans(QuranSurah surah, bool isDark) {
    List<TextSpan> spans = [];

    // Add all ayahs as a continuous paragraph
    for (int i = 0; i < surah.ayahs.length; i++) {
      final ayah = surah.ayahs[i];

      // Create and store gesture recognizer for ayah text
      final ayahTextRecognizer = TapGestureRecognizer()
        ..onTap = () => _showTafsirModal(surah, ayah);
      _gestureRecognizers.add(ayahTextRecognizer);

      // Create tappable ayah text
      spans.add(
        TextSpan(
          text: ayah.arabicText,
          style: GoogleFonts.amiriQuran(
            fontSize: _fontSize,
            color: isDark ? Colors.white : Colors.black,
            height: 2.1,
          ),
          recognizer: ayahTextRecognizer,
        ),
      );

      // Create and store gesture recognizer for ayah symbol
      final ayahSymbolRecognizer = TapGestureRecognizer()
        ..onTap = () => _showTafsirModal(surah, ayah);
      _gestureRecognizers.add(ayahSymbolRecognizer);

      // Add ayah number in decorative circle
      spans.add(
        TextSpan(
          text: " ${_getAyahSymbol(ayah.ayahNumber)} ",
          style: GoogleFonts.tajawal(
            fontSize: _fontSize * 0.8,
            color: isDark ? Colors.amber[200] : Colors.brown[600],
            fontWeight: FontWeight.bold,
          ),
          recognizer: ayahSymbolRecognizer,
        ),
      );

      // Add space between ayahs (but not line break)
      if (i < surah.ayahs.length - 1) {
        spans.add(
          TextSpan(
            text: " ",
            style: GoogleFonts.amiriQuran(
              fontSize: _fontSize,
              color: isDark ? Colors.white : Colors.black,
              height: 2.1,
            ),
          ),
        );
      }
    }

    return spans;
  }

  String _getAyahSymbol(int ayahNumber) {
    // Create decorative circle with ayah number
    return "﴿$ayahNumber﴾";
  }

  void _showTafsirModal(QuranSurah surah, QuranAyah ayah) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TafsirBottomSheet(ayah: ayah),
    );
  }

  bool _shouldShowBasmalah(QuranSurah surah) {
    // Al-Fatihah: Basmalah is treated as first ayah (Ayah 1)
    if (surah.number == 1) {
      return false; // Basmalah is already included as ayah 1
    }

    // Surah At-Tawbah: NO Basmalah
    if (surah.number == 9) {
      return false;
    }

    // All other Surahs: Display Basmalah as Header/Title
    return true;
  }
}
