import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:imsakia/features/quran_madinah/models/aya.dart';
import 'package:imsakia/features/quran_madinah/services/madinah_db_helper.dart';
import 'package:imsakia/features/quran_madinah/ui/mushaf_screen.dart';
import 'package:imsakia/features/quran_madinah/utils/madinah_quran_utils.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Aya> _searchResults = [];
  List<Map<String, dynamic>> _surahSearchResults = [];
  List<List<ParsedSpanData>> _parsedSearchResults = [];
  bool _isSearching = false;
  String? _errorMessage;

  final Map<String, String> _surahAliases = {
    'ياسين': 'يس',
    'طاهه': 'طه',
    'طاها': 'طه',
    'عمه': 'النبأ',
    'عم': 'النبأ',
    'تبارك': 'الملك',
    'القتال': 'محمد',
    'بني اسرائيل': 'الإسراء',
  };

  String _normalizeArabicText(String text) {
    // Remove Tashkeel
    final tashkeelRegex = RegExp(r'[\u0617-\u061A\u064B-\u0652]');
    String normalized = text.replaceAll(tashkeelRegex, '');
    // Normalize Alefs, Taa Marbutah, and Yaa
    normalized = normalized
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ي', 'ى');
    return normalized;
  }

  void _performSearch(String query) async {
    final rawQuery = query.trim();
    if (rawQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _surahSearchResults = [];
        _isSearching = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      // Normalize user query
      String normalizedQuery = _normalizeArabicText(rawQuery);
      // Check aliases
      for (final alias in _surahAliases.keys) {
        if (normalizedQuery.contains(_normalizeArabicText(alias))) {
          normalizedQuery = normalizedQuery.replaceAll(
              _normalizeArabicText(alias), 
              _normalizeArabicText(_surahAliases[alias]!)
          );
        }
      }

      // We run both searches in parallel
      final ayahsFuture = DbHelper.searchAyahs(normalizedQuery);
      final allSurahsFuture = DbHelper.getAllSurahs();

      final futuresResults = await Future.wait([ayahsFuture, allSurahsFuture]);
      final results = futuresResults[0] as List<Aya>;
      final allSurahs = futuresResults[1] as List<Map<String, dynamic>>;

      // Filter Surahs in Dart
      final matchedSurahs = allSurahs.where((s) {
        final name = s['sura_name_ar'].toString();
        return _normalizeArabicText(name).contains(normalizedQuery);
      }).toList();

      // Pre-parse the results so the main thread doesn't jank on scroll
      final parsed = results
          .map(
            (aya) => QuranUtils.parseVerse(
              aya.ayaText,
              aya.ayaTextEmlaey,
              rawQuery,
            ),
          )
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = results;
          _surahSearchResults = matchedSurahs;
          _parsedSearchResults = parsed;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isSearching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToPage(Aya aya) async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MushafScreen(
          initialPage: aya.page,
          searchQuery: _searchController.text,
          targetAyaId: aya.id,
        ),
      ),
    );
    if (mounted) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: "ابحث في القرآن (بدون تشكيل)...",
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
          cursorColor: Colors.white,
          onChanged: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_searchController.text.isNotEmpty && _searchResults.isEmpty && _surahSearchResults.isEmpty) {
      return const Center(
        child: Text("لا توجد نتائج", style: TextStyle(fontSize: 18)),
      );
    }

    final int totalCount = _surahSearchResults.length + _searchResults.length;

    return ListView.separated(
      itemCount: totalCount,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        // Render Surahs first
        if (index < _surahSearchResults.length) {
          final surah = _surahSearchResults[index];
          return ListTile(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => MushafScreen(
                    initialPage: surah['start_page'] as int,
                    searchQuery: '',
                  ),
                ),
              );
              if (mounted) {
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                ]);
              }
            },
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(50),
              child: Text(
                surah['sura_no'].toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                "سورة ${surah['sura_name_ar']}",
                style: TextStyle(
                  fontFamily: 'HafsSmart',
                  fontSize: 22,
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            subtitle: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                "${surah['ayah_count']} آية",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          );
        }

        // Render Ayahs
        final ayahIndex = index - _surahSearchResults.length;
        final aya = _searchResults[ayahIndex];

        return ListTile(
          onTap: () => _navigateToPage(aya),
          title: Directionality(
            textDirection: TextDirection.rtl,
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'HafsSmart',
                  fontSize: 20,
                  color: isDark ? Colors.white : Colors.black,
                ),
                children: QuranUtils.buildSpansFromParsed(
                  _parsedSearchResults[ayahIndex],
                  context,
                  20,
                ),
              ),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "سورة ${aya.suraNameAr} - آية ${aya.ayaNo}",
                    style: TextStyle(
                      fontFamily: 'HafsSmart',
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "صفحة ${aya.page}",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
