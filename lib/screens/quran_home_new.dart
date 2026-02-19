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
  String? _surahsError;
  String? _juzsError;
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

  Future<void> _loadSurahs() async {
    try {
      setState(() {
        _isSurahsLoading = true;
        _surahsError = null;
      });
      final surahs = await dbHelper.getSurahs();
      setState(() {
        _allSurahs = surahs;
        _filteredSurahs = surahs;
        _isSurahsLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSurahsLoading = false;
          _surahsError = e.toString();
        });
      }
    }
  }

  Future<void> _loadJuzs() async {
    try {
      setState(() {
        _isJuzsLoading = true;
        _juzsError = null;
      });
      final juzs = await dbHelper.getJuzs();
      setState(() {
        _juzs = juzs;
        _isJuzsLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isJuzsLoading = false;
          _juzsError = e.toString();
        });
      }
    }
  }

  void _filterSurahs() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredSurahs = _allSurahs;
      } else {
        _filteredSurahs = _allSurahs.where((surah) {
          final nameAr = surah['name_ar']?.toString().toLowerCase() ?? '';
          final nameEn = surah['name_en']?.toString().toLowerCase() ?? '';
          final id = surah['id']?.toString() ?? '';
          return nameAr.contains(query) ||
              nameEn.contains(query) ||
              id.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _performGlobalSearch() async {
    final query = _globalSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await dbHelper.searchAyahs(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في البحث: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            'القرآن الكريم',
            style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Theme.of(context).colorScheme.onPrimary,
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white70 
                : Colors.black54,
            labelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            unselectedLabelStyle: GoogleFonts.tajawal(),
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
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'ابحث عن سورة...',
              hintStyle: GoogleFonts.tajawal(),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),
        ),
        Expanded(
          child: _isSurahsLoading
              ? const Center(child: CircularProgressIndicator())
              : _surahsError != null
              ? _buildErrorWidget(_surahsError!, _loadSurahs)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _filteredSurahs.length,
                  itemBuilder: (context, index) {
                    final surah = _filteredSurahs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: Text(
                            '${surah['id']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          surah['name_ar'] ?? '',
                          style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          surah['name_en'] ?? '',
                          style: GoogleFonts.tajawal(fontSize: 12),
                        ),
                        trailing: Text(
                          '${surah['ayah_count'] ?? 0} آية',
                          style: GoogleFonts.tajawal(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SurahViewNew(surah: surah),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildJuzsTab() {
    if (_isJuzsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_juzsError != null) {
      return _buildErrorWidget(_juzsError!, _loadJuzs);
    }
    if (_juzs.isEmpty) {
      return Center(
        child: Text(
          'لا توجد أجزاء متاحة',
          style: GoogleFonts.tajawal(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _juzs.length,
      itemBuilder: (context, index) {
        final juz = _juzs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                '${juz['id']}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              'الجزء ${juz['id']}',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'من سورة ${juz['start_surah_name']} إلى سورة ${juz['end_surah_name']}',
              style: GoogleFonts.tajawal(fontSize: 12),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => JuzViewNew(juz: juz)),
              );
            },
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
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'ابحث في نصوص القرآن...',
              hintStyle: GoogleFonts.tajawal(),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
          ),
        ),
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          child: Text(
                            '${result['surah_id']}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          result['surah_name_ar'] ?? '',
                          style: GoogleFonts.tajawal(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الآية ${result['number_in_surah']}',
                              style: GoogleFonts.tajawal(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              result['text'] ?? '',
                              style: const TextStyle(
                                fontFamily: 'AmiriQuran',
                                height: 1.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SurahViewNew(
                                surah: {
                                  'id': result['surah_id'],
                                  'name_ar': result['surah_name_ar'],
                                },
                                initialAyahNumber: result['number_in_surah'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              'حدث خطأ غير متوقع',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.tajawal(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text('إعادة المحاولة', style: GoogleFonts.tajawal()),
            ),
          ],
        ),
      ),
    );
  }
}
