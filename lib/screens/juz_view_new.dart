import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; 
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
      newPhysics = (isAtBottom || isShort)
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics();
    } else if (id == 30) {
      newPhysics = (isAtTop || isShort)
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics();
    } else {
      newPhysics = (isAtTop || isAtBottom || isShort)
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics();
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
              content: Text(
                'تم الجزء.. اسحب لليسار للانتقال للتالي',
                style: GoogleFonts.tajawal(color: Colors.white),
                textAlign: TextAlign.center,
              ),
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
            final qProvider = Provider.of<QuranProvider>(context, listen: false);
            return JuzPageItem(
              juzId: index + 1,
              dbHelper: widget.dbHelper,
              initialAyah: (index + 1 == (widget.juz['id'] ?? 1))
                  ? widget.initialAyahNumber
                  : null,
              initialSurahId: (index + 1 == (widget.juz['id'] ?? 1))
                  ? qProvider.lastSurahId
                  : null,
              onScroll: (top, bottom, short) =>
                  _updatePhysics(top, bottom, short, index + 1),
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
  final int? initialSurahId;
  final Function(bool, bool, bool) onScroll;

  const JuzPageItem({
    super.key,
    required this.juzId,
    required this.dbHelper,
    required this.onScroll,
    this.initialAyah,
    this.initialSurahId,
  });

  @override
  State<JuzPageItem> createState() => _JuzPageItemState();
}

class _JuzPageItemState extends State<JuzPageItem> {
  late ScrollController _scrollController;
  List<Map<String, dynamic>> _ayahItems = [];
  final Map<String, GlobalKey> _ayahKeys = {};
  bool _isAutoScrolling = false;
  bool _showSpeedSlider = false; 
  double _scrollSpeed = 1.0;
  Timer? _scrollTimer;
  String _currentVisibleSurah = "";

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

    for (var ayah in ayahs) {
      _ayahKeys['${ayah['surah_id']}_${ayah['number_in_surah']}'] = GlobalKey();
    }

    setState(() {
      _ayahItems = ayahs;
      if (_ayahItems.isNotEmpty) {
        _currentVisibleSurah = _ayahItems[0]['surah_name_ar'] ?? '';
      }
    });

    if (widget.initialAyah != null && widget.initialAyah! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _scrollToInitialLocation();
        });
      });
    }
  }

  void _scrollToInitialLocation() {
    if (_ayahItems.isEmpty || widget.initialAyah == null) return;
    Map<String, dynamic>? targetAyahData;
    String targetKey = "";
    if (widget.initialSurahId != null) {
      targetKey = '${widget.initialSurahId}_${widget.initialAyah}';
      try {
        targetAyahData = _ayahItems.firstWhere(
            (a) => a['surah_id'] == widget.initialSurahId && a['number_in_surah'] == widget.initialAyah);
      } catch (_) {}
    } else {
      try {
        targetAyahData = _ayahItems.firstWhere((a) => a['number_in_surah'] == widget.initialAyah);
        targetKey = '${targetAyahData['surah_id']}_${targetAyahData['number_in_surah']}';
      } catch (_) {}
    }
    if (targetAyahData != null && targetAyahData['surah_name_ar'] != null) {
      setState(() => _currentVisibleSurah = targetAyahData!['surah_name_ar']);
    }
    final key = _ayahKeys[targetKey];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(seconds: 1), curve: Curves.easeInOut);
    }
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      widget.onScroll(pos.pixels <= 20, pos.pixels >= pos.maxScrollExtent - 20, pos.maxScrollExtent < 10);
    }
  }

  void _saveCurrentLocation() {
    final quranProvider = Provider.of<QuranProvider>(context, listen: false);
    int currentSurahId = _ayahItems.first['surah_id'];
    int currentAyahNum = _ayahItems.first['number_in_surah'];
    String currentSurahName = _ayahItems.first['surah_name_ar'] ?? '';
    if (_scrollController.hasClients && _ayahItems.isNotEmpty) {
      for (var ayah in _ayahItems) {
        final key = _ayahKeys['${ayah['surah_id']}_${ayah['number_in_surah']}'];
        final RenderBox? box = key?.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final position = box.localToGlobal(Offset.zero).dy;
          if (position >= 0 && position < MediaQuery.of(context).size.height * 0.5) {
            currentSurahId = ayah['surah_id'];
            currentAyahNum = ayah['number_in_surah'];
            currentSurahName = ayah['surah_name_ar'] ?? '';
            break;
          }
        }
      }
    }
    quranProvider.saveBookmark(surahId: currentSurahId, ayahNumber: currentAyahNum, isJuzMode: true, juzId: widget.juzId, name: 'الجزء ${widget.juzId} ($currentSurahName)');
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ المرجعية: $currentSurahName آية $currentAyahNum', style: GoogleFonts.tajawal()), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
      if (!_isAutoScrolling) {
        _showSpeedSlider = false;
        try { WakelockPlus.disable(); } catch (e) { print("Wakelock Error: $e"); }
      } else {
        try { WakelockPlus.enable(); } catch (e) { print("Wakelock Error: $e"); }
      }
    });
    
    if (_isAutoScrolling) {
      _startScrolling();
    } else {
      _scrollTimer?.cancel();
    }
  }

  void _startScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_scrollController.hasClients) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.offset;
        if (currentScroll < maxScroll) {
          _scrollController.jumpTo(currentScroll + _scrollSpeed);
        } else {
          _toggleAutoScroll();
        }
      }
    });
  }

  String _cleanAyahText(String text, int surahId, int ayahNum) {
    String cleaned = text.trim();
    if (ayahNum == 1 && surahId != 1) {
      if (cleaned.startsWith("بِسْمِ")) {
        int skipLength = 38;
        if (cleaned.length > skipLength) {
          cleaned = cleaned.substring(skipLength).trim();
          while (cleaned.isNotEmpty && (cleaned.startsWith(' ') || cleaned.startsWith('ۏ'))) {
            cleaned = cleaned.substring(1).trim();
          }
        }
      }
    }
    cleaned = cleaned.replaceAll('\u06E2', '').replaceAll('\u06ED', '').replaceAll('ۏ', '');
    return cleaned.trim();
  }

  List<TextSpan> _buildContinuousAyahText(QuranProvider quranProvider) {
    List<TextSpan> spans = [];
    for (var ayah in _ayahItems) {
      final ayahNum = ayah['number_in_surah'];
      final surahId = ayah['surah_id'];
      final surahNameAr = ayah['surah_name_ar'] ?? '';
      final keyStr = '${surahId}_$ayahNum';
      TapGestureRecognizer tapRecognizer = TapGestureRecognizer()..onTap = () => _showTafsirDialog(ayah);

      if (ayahNum == 1) {
        spans.add(TextSpan(children: [WidgetSpan(child: VisibilityDetector(key: Key('header_${surahId}_${widget.juzId}'), onVisibilityChanged: (info) {
          if (info.visibleFraction > 0.1 && mounted && _currentVisibleSurah != surahNameAr) {
            setState(() => _currentVisibleSurah = surahNameAr);
          }
        }, child: Container(width: double.infinity, margin: const EdgeInsets.only(top: 25, bottom: 10), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3))), child: Text(surahNameAr, textAlign: TextAlign.center, style: GoogleFonts.tajawal(fontSize: quranProvider.fontSize * 1.1, fontWeight: FontWeight.bold, color: Colors.amber[900])))))]));
        if (surahId != 1 && surahId != 9) {
          spans.add(TextSpan(children: [WidgetSpan(child: Container(width: double.infinity, alignment: Alignment.center, padding: const EdgeInsets.only(bottom: 15, top: 10), child: Text('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ', style: TextStyle(fontFamily: 'AmiriQuran', fontSize: quranProvider.fontSize + 4, color: Colors.blue[800], fontWeight: FontWeight.bold))))]));
        }
      }
      spans.add(TextSpan(children: [
        WidgetSpan(child: SizedBox(width: 0, height: 0, key: _ayahKeys[keyStr])),
        TextSpan(text: _cleanAyahText(ayah['text'] ?? '', surahId, ayahNum), recognizer: tapRecognizer, style: TextStyle(fontFamily: 'AmiriQuran', fontSize: quranProvider.fontSize, height: 2.2, color: Theme.of(context).colorScheme.onSurface)),
        TextSpan(text: ' ﴿$ayahNum﴾ ', recognizer: tapRecognizer, style: TextStyle(fontFamily: 'AmiriQuran', fontSize: quranProvider.fontSize * 0.8, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
      ]));
    }
    return spans;
  }

  void _showTafsirDialog(Map<String, dynamic> ayah) async {
    String tafsir = await widget.dbHelper.getTafsir(ayah['surah_id'], ayah['number_in_surah']);
    if (!mounted) return;
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => Container(height: MediaQuery.of(context).size.height * 0.45, decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))), padding: const EdgeInsets.all(20), child: Column(children: [Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))), const SizedBox(height: 20), Text("${ayah['surah_name_ar'] ?? ''} - آية ${ayah['number_in_surah']}", style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)), const Divider(), Expanded(child: SingleChildScrollView(child: Column(children: [Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3))), child: Text(_cleanAyahText(ayah['text'] ?? '', ayah['surah_id'], ayah['number_in_surah']), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 20))), const SizedBox(height: 15), Text(tafsir, textAlign: TextAlign.justify, style: GoogleFonts.tajawal(fontSize: 16))])))])));
  }

  // الدالة الجديدة لتغيير حجم الخط
  void _showFontSizeDialog() {
    final quranProvider = Provider.of<QuranProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('حجم خط القرآن', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
          content: StatefulBuilder(
            builder: (context, dialogSetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${quranProvider.fontSize.toInt()}',
                      style: GoogleFonts.tajawal(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold, 
                        color: Theme.of(context).colorScheme.primary
                      )),
                  Slider(
                    value: quranProvider.fontSize,
                    min: 16.0, 
                    max: 45.0, 
                    divisions: 29,
                    onChanged: (value) {
                      quranProvider.setFontSize(value);
                      dialogSetState(() {});
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text('تم', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold))
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qProvider = Provider.of<QuranProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_ayahItems.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? null : colorScheme.primary,
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الجزء ${widget.juzId}', style: GoogleFonts.tajawal(color: isDarkMode ? colorScheme.onSurface : Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            if (_currentVisibleSurah.isNotEmpty)
              Text(_currentVisibleSurah, style: GoogleFonts.tajawal(color: isDarkMode ? colorScheme.onSurface.withOpacity(0.7) : Colors.white.withOpacity(0.8), fontWeight: FontWeight.normal, fontSize: 13)),
          ],
        ),
        iconTheme: IconThemeData(color: isDarkMode ? colorScheme.onSurface : Colors.white),
        actions: [
          if (_isAutoScrolling) 
            IconButton(
              icon: const Icon(Icons.speed),
              onPressed: () => setState(() => _showSpeedSlider = !_showSpeedSlider),
            ),
          IconButton(icon: Icon(qProvider.lastJuzId == widget.juzId && qProvider.isJuzMode ? Icons.bookmark : Icons.bookmark_border), onPressed: _saveCurrentLocation),
          // تم تغيير استدعاء الدالة هنا
          IconButton(icon: const Icon(Icons.text_fields), onPressed: _showFontSizeDialog),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isAutoScrolling && _showSpeedSlider)
            Container(
              margin: const EdgeInsets.only(bottom: 15, right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor.withOpacity(0.95),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 10),
                  Text("${_scrollSpeed.toStringAsFixed(1)}x", style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.45,
                    child: Slider(
                      value: _scrollSpeed,
                      min: 0.2,
                      max: 6.0,
                      divisions: 29,
                      onChanged: (val) => setState(() => _scrollSpeed = val),
                    ),
                  ),
                ],
              ),
            ),
          FloatingActionButton(
            heroTag: "play_${widget.juzId}",
            backgroundColor: _isAutoScrolling ? Colors.red : colorScheme.primary,
            onPressed: _toggleAutoScroll,
            child: Icon(_isAutoScrolling ? Icons.stop : Icons.play_arrow, color: Colors.white),
          ),
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
                  TextSpan(children: _buildContinuousAyahText(qProvider)),
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
    try { WakelockPlus.disable(); } catch (e) {} 
    _scrollTimer?.cancel();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
}