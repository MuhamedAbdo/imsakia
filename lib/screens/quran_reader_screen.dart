import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../services/quran_text_service.dart';
import '../models/quran_models.dart';
import '../widgets/surah_header_widget.dart';

class QuranReaderScreen extends StatefulWidget {
  final int? initialSurah;
  final int? initialAyah;

  const QuranReaderScreen({super.key, this.initialSurah, this.initialAyah});

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  final QuranTextService _quranService = QuranTextService();
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener = ItemPositionsListener.create();
  
  List<QuranSurah> _surahs = [];
  bool _isLoading = true;
  bool _isInitialMount = true; 
  double _fontSize = 24.0;
  int? _lastQuarterNotified; 
  String _currentTitle = "";

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _quranService.loadQuranData();
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
    } else if (progress != null) {
      targetIndex = progress['index'];
      targetOffset = progress['offset'];
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

  void _onScroll() {
    if (_isInitialMount) return; 

    final positions = _positionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final topItem = positions.reduce((a, b) => a.itemLeadingEdge.abs() < b.itemLeadingEdge.abs() ? a : b);
    _quranService.saveProgress(topItem.index, topItem.itemLeadingEdge);

    int sIdx = topItem.index ~/ 2;
    if (sIdx < _surahs.length) {
      final surah = _surahs[sIdx];
      
      // تحديث العنوان عند التمرير
      if (_currentTitle != surah.name) {
        setState(() => _currentTitle = surah.name);
      }

      for (var ayah in surah.ayahs) {
        final details = _quranService.getHizbDetails(surah.number, ayah.ayahNumber);
        
        if (details != null && details['q'] != _lastQuarterNotified) {
          if (topItem.itemLeadingEdge.abs() < 0.15) { 
            _lastQuarterNotified = details['q'];
            _showNotification("الجزء ${details['j']} - الربع ${details['q']} (سورة ${surah.name})");
            break;
          }
        }
      }
    }
  }

  void _showNotification(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.teal[800],
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  void _showFontSizeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 150,
        child: Column(
          children: [
            Text("حجم خط القراءة", style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            StatefulBuilder(builder: (context, setSheetState) => Slider(
              value: _fontSize.clamp(18.0, 38.0),
              min: 18, max: 38,
              onChanged: (val) {
                setSheetState(() => _fontSize = val);
                setState(() {});
                _quranService.saveFontSize(val);
              },
            )),
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
                final top = pos.reduce((a, b) => a.itemLeadingEdge.abs() < b.itemLeadingEdge.abs() ? a : b);
                await _quranService.saveBookmark(top.index, top.itemLeadingEdge);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("تم حفظ موضع القراءة", style: GoogleFonts.tajawal()),
                    backgroundColor: Colors.green[700],
                  )
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.format_size, color: Colors.white), 
            onPressed: _showFontSizeSheet
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 15, 24, 40),
      child: RichText(
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
        text: TextSpan(
          children: surah.ayahs.map((a) => TextSpan(
            children: [
              TextSpan(
                text: "${a.arabicText} ", 
                style: GoogleFonts.amiriQuran(
                  fontSize: _fontSize, 
                  color: isDark ? Colors.white : Colors.black, 
                  height: 2.1
                )
              ),
              TextSpan(
                text: "﴿${a.ayahNumber}﴾ ", 
                style: TextStyle(
                  color: isDark ? Colors.amber[200] : Colors.brown[400], 
                  fontSize: _fontSize * 0.7, 
                  fontWeight: FontWeight.bold
                )
              ),
            ],
          )).toList(),
        ),
      ),
    );
  }
}