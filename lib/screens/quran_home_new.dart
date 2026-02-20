import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/db_helper.dart';
import 'surah_view_new.dart';
import 'juz_view_new.dart';
import '../providers/quran_provider.dart';
import 'package:provider/provider.dart';

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
      print('Loaded juzs: $juzs'); // Debug print
      
      if (!mounted) return;
      setState(() {
        _juzs = juzs;
        _isJuzsLoading = false;
      });
    } catch (e) {
      print('Error loading juzs: $e'); // Debug print
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          centerTitle: true,
          title: Text(
            'القرآن الكريم',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.white,
            labelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16),
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            unselectedLabelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.normal, fontSize: 14),
            tabs: const [
              Tab(text: 'السور'),
              Tab(text: 'الأجزاء'),
              Tab(text: 'البحث'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [_buildSurahsTab(), _buildJuzsTab(), _buildSearchTab()],
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
                          'name_ar': quranProvider.bookmarkName?.replaceFirst('سورة ', '')
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
                style: GoogleFonts.tajawal(fontSize: 12),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            );
          },
        ),
      ),
    );
  }

  Widget _buildSurahsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ابحث عن سورة...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),
        ),
        Expanded(
          child: _isSurahsLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _filteredSurahs.length,
                  itemBuilder: (context, index) {
                    final surah = _filteredSurahs[index];
                    return Card(
                      elevation: 0,
                      color: Theme.of(context).cardColor,
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: Text(
                            '${surah['id']}',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        title: Text(
                          surah['name_ar'],
                          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('عدد الآيات: ${surah['ayah_count'] ?? ''}'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SurahViewNew(surah: surah)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildJuzsTab() {
    if (_isJuzsLoading) return const Center(child: CircularProgressIndicator());
    if (_juzs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'لا توجد بيانات الأجزاء',
              style: GoogleFonts.tajawal(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'جاري إصلاح المشكلة...',
              style: GoogleFonts.tajawal(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _juzs.length,
      itemBuilder: (context, index) {
        final juz = _juzs[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.white,
              child: Text('${juz['id']}'),
            ),
            title: Text(
              'الجزء ${juz['id']}',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'من: ${juz['start_surah_name']} - إلى: ${juz['end_surah_name']}',
              style: GoogleFonts.tajawal(fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => JuzViewNew(juz: juz)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _globalSearchController,
            decoration: InputDecoration(
              hintText: 'ابحث في نصوص القرآن...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
            ),
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      title: Text(
                        result['surah_name_ar'] ?? '',
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        result['text'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.amiri(),
                      ),
                      trailing: Text('آية: ${result['number_in_surah']}'),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SurahViewNew(
                            surah: {
                              'id': result['surah_id'],
                              'name_ar': result['surah_name_ar']
                            },
                            initialAyahNumber: result['number_in_surah'],
                            searchText: _globalSearchController.text.trim(),
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