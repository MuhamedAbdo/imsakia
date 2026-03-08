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
  List<Aya> _searchResults = [];
  List<List<ParsedSpanData>> _parsedSearchResults = [];
  bool _isSearching = false;

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final results = await DbHelper.searchAyahs(query.trim());

    // Pre-parse the results so the main thread doesn't jank on scroll
    final parsed = results
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
        _searchResults = results;
        _parsedSearchResults = parsed;
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToPage(int pageNumber) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MushafScreen(
          initialPage: pageNumber,
          searchQuery: _searchController.text,
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
            hintText: "ابحث في القرآن (بدون تشكيل)...",
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 18,
          ),
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

    if (_searchController.text.isNotEmpty && _searchResults.isEmpty) {
      return const Center(
        child: Text("لا توجد نتائج", style: TextStyle(fontSize: 18)),
      );
    }

    return ListView.separated(
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final aya = _searchResults[index];
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ListTile(
          onTap: () => _navigateToPage(aya.page),
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
                  _parsedSearchResults[index],
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
