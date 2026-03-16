import 'package:flutter/material.dart';

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
  List<Map<String, dynamic>> _surahResults = [];
  List<Aya> _ayahResults = [];
  List<List<ParsedSpanData>> _parsedAyahResults = [];
  bool _isSearching = false;

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _surahResults = [];
        _ayahResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await DbHelper.searchAny(query.trim());
    final List<Map<String, dynamic>> surahs = results['surahs'];
    final List<Aya> ayahs = results['ayahs'];

    // Pre-parse the results
    final parsed = ayahs
        .map(
          (aya) => QuranUtils.parseVerse(
            aya.ayaText,
            aya.ayaTextEmlaey,
            query.trim(),
          ),
        )
        .toList();

    if (mounted) {
      setState(() {
        _surahResults = surahs;
        _ayahResults = ayahs;
        _parsedAyahResults = parsed;
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToPage(int page, {int? ayaId}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MushafScreen(
          initialPage: page,
          searchQuery: _searchController.text,
          targetAyaId: ayaId,
        ),
      ),
    );
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
            hintText: "ابحث في القرآن (سور، آيات)...",
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

    if (_searchController.text.isNotEmpty && _surahResults.isEmpty && _ayahResults.isEmpty) {
      return const Center(
        child: Text("لا توجد نتائج", style: TextStyle(fontSize: 18)),
      );
    }

    return ListView(
      children: [
        if (_surahResults.isNotEmpty) ...[
          _buildSectionHeader("السور"),
          ..._surahResults.map((s) => _buildSurahResult(s)),
        ],
        if (_ayahResults.isNotEmpty) ...[
          _buildSectionHeader("الآيات"),
          ..._ayahResults.asMap().entries.map((entry) {
            final index = entry.key;
            final aya = entry.value;
            return _buildAyahResult(aya, index);
          }),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.withValues(alpha: 0.1),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.grey,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }

  Widget _buildSurahResult(Map<String, dynamic> surah) {
    return ListTile(
      onTap: () => _navigateToPage(surah['page']),
      leading: const Icon(Icons.menu_book, color: Colors.green),
      title: Text(
        "سورة ${surah['sura_name_ar']}",
        style: const TextStyle(
          fontFamily: 'HafsSmart',
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        textDirection: TextDirection.rtl,
      ),
      subtitle: Text(
        surah['sura_name_en'],
        style: const TextStyle(fontSize: 14),
      ),
      trailing: Text(
        "صفحة ${surah['page']}",
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildAyahResult(Aya aya, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      onTap: () => _navigateToPage(aya.page, ayaId: aya.id),
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
              _parsedAyahResults[index],
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
  }
}
