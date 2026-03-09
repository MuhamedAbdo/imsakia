import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:imsakia/features/quran_madinah/models/aya.dart';
import 'package:imsakia/features/quran_madinah/providers/quran_provider.dart';
import 'package:imsakia/features/quran_madinah/services/madinah_db_helper.dart';
import 'package:imsakia/features/quran_madinah/utils/madinah_quran_utils.dart';
import 'package:flutter/gestures.dart';
import 'package:imsakia/widgets/tafsir_bottom_sheet.dart';

class MushafPageBuilder extends StatefulWidget {
  final int pageNumber;
  final String? searchQuery;
  final int? targetAyaId;

  const MushafPageBuilder({
    super.key,
    required this.pageNumber,
    this.searchQuery,
    this.targetAyaId,
  });

  @override
  State<MushafPageBuilder> createState() => _MushafPageBuilderState();
}

class _MushafPageBuilderState extends State<MushafPageBuilder> {
  List<Aya> _ayahs = [];
  List<List<ParsedSpanData>> _parsedAyahs = [];
  bool _isLoading = true;
  final Map<int, TapGestureRecognizer> _recognizers = {};

  @override
  void initState() {
    super.initState();
    _loadPage();
  }

  @override
  void didUpdateWidget(MushafPageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber) {
      _loadPage();
    }
  }

  @override
  void dispose() {
    for (var recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  void _showTafsir(int surahId, int ayahNum, String ayahText) {
    final ayahData = {
      'surah_id': surahId,
      'number_in_surah': ayahNum,
      'text': ayahText,
    };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TafsirBottomSheet(ayah: ayahData),
    );
  }

  Future<void> _loadPage() async {
    setState(() => _isLoading = true);
    final ayahs = await DbHelper.getAyahsByPage(widget.pageNumber);

    // Parse them quickly in the background before rendering
    final parsed = ayahs
        .map(
          (aya) => QuranUtils.parseVerse(
            aya.ayaText,
            aya.ayaTextEmlaey,
            widget.searchQuery,
          ),
        )
        .toList();

    if (mounted) {
      setState(() {
        _ayahs = ayahs;
        _parsedAyahs = parsed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ayahs.isEmpty) {
      return const Center(child: Text('No Data'));
    }

    // Use context.watch to rebuild when font size or theme changes
    final quranProvider = context.watch<QuranProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double fontSize = quranProvider.currentFontSize;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(children: _buildPageContent(fontSize, isDarkMode)),
      ),
    );
  }

  List<Widget> _buildPageContent(double fontSize, bool isDarkMode) {
    List<Widget> content = [];
    List<InlineSpan> currentSpans = [];

    for (int i = 0; i < _ayahs.length; i++) {
      final aya = _ayahs[i];

      // Check for Surah Header
      if (aya.ayaNo == 1) {
        // If we have accumulated text, flush it before the header
        if (currentSpans.isNotEmpty) {
          content.add(_buildJustifiedText(currentSpans));
          currentSpans = [];
        }

        // Add Header
        content.add(_buildSurahHeader(aya.suraNameAr, isDarkMode));

        // Add Basmala
        if (aya.suraNo != 9 && aya.suraNo != 1) {
          content.add(_buildBasmala(fontSize, isDarkMode));
        }
      }

      final recognizer = _recognizers.putIfAbsent(
        aya.id,
        () => TapGestureRecognizer()..onTap = () => _showTafsir(aya.suraNo, aya.ayaNo, aya.ayaText),
      );

      bool isTargetAya = widget.targetAyaId != null && aya.id == widget.targetAyaId;

      // Build verse spans directly from the pre-parsed memory
      currentSpans.addAll(
        QuranUtils.buildSpansFromParsed(_parsedAyahs[i], context, fontSize, recognizer, isTargetAya),
      );
    }

    // Flush remaining spans
    if (currentSpans.isNotEmpty) {
      content.add(_buildJustifiedText(currentSpans));
    }

    return content;
  }

  Widget _buildJustifiedText(List<InlineSpan> spans) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: RichText(
          textAlign: TextAlign.justify,
          textScaler: const TextScaler.linear(1.0),
          text: TextSpan(
            children: spans,
            style: const TextStyle(height: 1.8), // Default line height
          ),
        ),
      ),
    );
  }

  Widget _buildSurahHeader(String name, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      width: double.infinity,
      height: 60, // Fixed height to prevent image distortion
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/sura_hedder.png'),
          fit: BoxFit.contain, // Keep frame ratio
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name,
        style: TextStyle(
          fontFamily: 'HafsSmart',
          fontSize: 22, // Fixed size so it doesn't leave the frame
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : const Color(0xFF1B5E20),
          shadows: const [
            Shadow(color: Colors.black26, offset: Offset(1, 1), blurRadius: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildBasmala(double fontSize, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        "بسم الله الرحمن الرحيم",
        style: TextStyle(
          fontFamily: 'HafsSmart',
          fontSize: fontSize * 0.9,
          color: isDarkMode ? Colors.white : const Color(0xFF1B5E20),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
      ),
    );
  }
}
