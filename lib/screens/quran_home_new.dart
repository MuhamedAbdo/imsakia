import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/db_helper.dart';
import '../providers/quran_provider.dart';
import 'surah_view_new.dart';
import 'juz_view_new.dart';

class QuranHomeNew extends StatefulWidget {
  const QuranHomeNew({super.key});

  @override
  State<QuranHomeNew> createState() => _QuranHomeNewState();
}

class _QuranHomeNewState extends State<QuranHomeNew>
    with SingleTickerProviderStateMixin {
  final DbHelper dbHelper = DbHelper();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _globalSearchController = TextEditingController();
  List<Map<String, dynamic>> _allSurahs = [];
  List<Map<String, dynamic>> _filteredSurahs = [];
  List<Map<String, dynamic>> _juzs = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSurahsLoading = true;
  bool _isJuzsLoading = true;
  bool _isSearching = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSurahs();
    _loadJuzs();
    _searchController.addListener(_filterSurahs);
    _globalSearchController.addListener(_performGlobalSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _globalSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String _normalizeText(String text) {
    return text
        .replaceAll(RegExp(r'[\u064B-\u0652\u0670]'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
  }

  Future<void> _loadSurahs() async {
    try {
      if (!mounted) return;
      setState(() => _isSurahsLoading = true);
      final surahs = await dbHelper.getSurahs();
      if (!mounted) return;
      setState(() {
        _allSurahs = surahs;
        _filteredSurahs = surahs;
        _isSurahsLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isSurahsLoading = false);
    }
  }

  Future<void> _loadJuzs() async {
    try {
      if (!mounted) return;
      setState(() => _isJuzsLoading = true);
      final juzs = await dbHelper.getJuzs();
      if (!mounted) return;
      setState(() {
        _juzs = juzs;
        _isJuzsLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isJuzsLoading = false);
    }
  }

  void _filterSurahs() {
    if (!mounted) return;
    final rawQuery = _searchController.text.trim();
    final query = _normalizeText(rawQuery).toLowerCase();
    final queryWithoutAl = query.startsWith('ال') ? query.substring(2) : query;

    setState(() {
      if (query.isEmpty) {
        _filteredSurahs = _allSurahs;
      } else {
        _filteredSurahs = _allSurahs.where((surah) {
          final nameAr = _normalizeText(surah['name_ar'] ?? '');
          final nameEn = surah['name_en']?.toString().toLowerCase() ?? '';
          return nameAr.contains(query) ||
              nameAr.contains(queryWithoutAl) ||
              nameEn.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _performGlobalSearch() async {
    final query = _globalSearchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _isSearching = true);
    try {
      final results = await dbHelper.searchAyahs(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: isDarkMode ? null : colorScheme.primary,
          centerTitle: true,
          title: Text(
            'القرآن الكريم',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? colorScheme.onSurface : Colors.white,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: isDarkMode ? colorScheme.primary : Colors.white,
            indicatorWeight: 3,
            labelColor: isDarkMode ? colorScheme.primary : Colors.white,
            unselectedLabelColor: isDarkMode
                ? colorScheme.onSurface.withValues(alpha: 0.6) // تم التحديث هنا
                : Colors.white.withValues(alpha: 0.7), // تم التحديث هنا
            labelStyle: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            tabs: const [
              Tab(text: 'السور'),
              Tab(text: 'الأجزاء'),
              Tab(text: 'البحث'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSurahsTab(colorScheme),
            _buildJuzsTab(colorScheme),
            _buildSearchTab(colorScheme),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Consumer<QuranProvider>(
          builder: (context, quranProvider, child) {
            if (!quranProvider.hasBookmark) return const SizedBox.shrink();
            return FloatingActionButton.extended(
              onPressed: () {
                if (quranProvider.isJuzMode) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JuzViewNew(
                        juz: {'id': quranProvider.lastJuzId},
                        initialAyahNumber: quranProvider.lastAyahNumber,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SurahViewNew(
                        surah: {
                          'id': quranProvider.lastSurahId,
                          'name_ar': quranProvider.bookmarkName?.replaceFirst(
                            'سورة ',
                            '',
                          ),
                        },
                        initialAyahNumber: quranProvider.lastAyahNumber,
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.bookmark),
              label: Text(
                'متابعة القراءة: ${quranProvider.bookmarkName}',
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            );
          },
        ),
      ),
    );
  }

  Widget _buildSurahsTab(ColorScheme colorScheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.tajawal(),
            decoration: InputDecoration(
              hintText: 'ابحث عن سورة...',
              prefixIcon: Icon(Icons.search, color: colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15.0),
                borderSide: BorderSide(
                  color: colorScheme.primary.withValues(
                    alpha: 0.3,
                  ), // تم التحديث هنا
                ),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),
        ),
        Expanded(
          child: _isSurahsLoading
              ? Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _filteredSurahs.length,
                  itemBuilder: (context, index) {
                    final surah = _filteredSurahs[index];
                    return Card(
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.only(bottom: 10.0),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(
                              alpha: 0.1,
                            ), // تم التحديث هنا
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${surah['id']}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          surah['name_ar'],
                          style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        subtitle: Text(
                          'عدد الآيات: ${surah['ayah_count'] ?? ''}',
                          style: GoogleFonts.tajawal(fontSize: 13),
                        ),
                        trailing: Icon(
                          Icons.chevron_left,
                          color: colorScheme.primary,
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SurahViewNew(surah: surah),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildJuzsTab(ColorScheme colorScheme) {
    if (_isJuzsLoading) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _juzs.length,
      itemBuilder: (context, index) {
        final juz = _juzs[index];
        return Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.secondary.withValues(
                alpha: 0.8,
              ), // تم التحديث هنا
              foregroundColor: Colors.white,
              child: Text(
                '${juz['id']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              'الجزء ${juz['id']}',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            subtitle: Text(
              'من: ${juz['start_surah_name']} - إلى: ${juz['end_surah_name']}',
              style: GoogleFonts.tajawal(fontSize: 12),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: colorScheme.primary,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => JuzViewNew(juz: juz)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchTab(ColorScheme colorScheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _globalSearchController,
            style: GoogleFonts.tajawal(),
            decoration: InputDecoration(
              hintText: 'ابحث في نصوص القرآن...',
              prefixIcon: Icon(Icons.manage_search, color: colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15.0),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),
        ),
        Expanded(
          child: _isSearching
              ? Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          result['surah_name_ar'] ?? '',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            result['text'] ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'AmiriQuran',
                              fontSize: 18,
                              height: 1.5,
                            ),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(
                              alpha: 0.1,
                            ), // تم التحديث هنا
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'آية: ${result['number_in_surah']}',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SurahViewNew(
                              surah: {
                                'id': result['surah_id'],
                                'name_ar': result['surah_name_ar'],
                              },
                              initialAyahNumber: result['number_in_surah'],
                              searchText: _globalSearchController.text.trim(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
