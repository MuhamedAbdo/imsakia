import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/surah.dart';
import '../services/quran_service.dart';
import '../utils/logger.dart';
import '../services/quran_pages_service.dart';
import '../widgets/download_progress_dialog.dart';
import 'quran_pages_viewer_screen.dart';
import 'juz_index_screen.dart';

class QuranIndexScreen extends StatefulWidget {
  const QuranIndexScreen({super.key});

  @override
  State<QuranIndexScreen> createState() => _QuranIndexScreenState();
}

class _QuranIndexScreenState extends State<QuranIndexScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final QuranService _quranService = QuranService();
  List<Surah> _filteredSurahs = [];
  List<Surah> _allSurahs = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSurahs();
    _searchController.addListener(_filterSurahs);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_filterSurahs);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
    try {
      Logger.info('Loading Quran index using QuranService...');
      
      // Get all surahs from QuranService
      await _quranService.loadSurahs();
      _allSurahs = _quranService.surahs;
      _filteredSurahs = List.from(_allSurahs);
      
      setState(() {
        _isLoading = false;
      });
      
      Logger.success('Loaded ${_allSurahs.length} surahs from QuranService');
    } catch (e) {
      Logger.error('Error loading Quran index: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterSurahs() {
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      if (query.isEmpty) {
        _filteredSurahs = List.from(_allSurahs);
      } else {
        _filteredSurahs = _allSurahs.where((surah) {
          final arabicName = surah.name.toLowerCase();
          final englishName = surah.englishName.toLowerCase();
          final number = surah.number.toString();
          
          return arabicName.contains(query) ||
                 englishName.contains(query) ||
                 number.contains(query);
        }).toList();
      }
    });
  }

  String _getRevelationTypeText(String revelationType) {
    return revelationType == 'Meccan' ? 'مكية' : 'مدنية';
  }

  Color _getRevelationTypeColor(String revelationType) {
    return revelationType == 'Meccan' ? Colors.green : Colors.blue;
  }

  Future<void> _goToBookmark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarkedPage = prefs.getInt('quran_bookmark_page');
      final bookmarkedSurah = prefs.getString('quran_bookmark_surah') ?? '';

      if (bookmarkedPage != null) {
        Logger.info('Navigating to bookmark: page $bookmarkedPage, surah $bookmarkedSurah');
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QuranPagesViewerScreen(
              initialPage: bookmarkedPage,
              surahName: bookmarkedSurah,
            ),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'لم يتم حفظ أي علامة بعد',
                style: GoogleFonts.tajawal(),
              ),
              backgroundColor: Colors.orange[700],
              duration: const Duration(seconds: 2),
            ),
          );
        }
        Logger.info('No bookmark found');
      }
    } catch (e) {
      Logger.error('Error navigating to bookmark: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء فتح العلامة',
              style: GoogleFonts.tajawal(),
            ),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'القرآن الكريم',
          style: GoogleFonts.tajawal(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark, color: Colors.amber),
            onPressed: _goToBookmark,
            tooltip: 'الانتقال للعلامة',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
          labelColor: MediaQuery.of(context).platformBrightness == Brightness.dark
              ? Colors.white
              : Colors.black,
          unselectedLabelColor: Colors.grey.withOpacity(0.7),
          indicatorColor: Theme.of(context).primaryColor,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 2.0,
            ),
          ),
          tabs: const [
            Tab(text: 'فهرس السور'),
            Tab(text: 'فهرس الأجزاء'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSurahsTab(),
          const JuzIndexScreen(),
        ],
      ),
    );
  }

  Widget _buildSurahsTab() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ابحث عن سورة...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            textDirection: TextDirection.rtl,
          ),
        ),
        
        // Surahs list
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(),
                )
              : _filteredSurahs.isEmpty
                  ? Center(
                      child: Text(
                        'لا توجد سور تطابق البحث',
                        style: GoogleFonts.tajawal(fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredSurahs.length,
                      itemBuilder: (context, index) {
                        final surah = _filteredSurahs[index];
                        return _buildSurahCard(surah);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSurahCard(Surah surah) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuranPagesViewerScreen(
                initialPage: surah.startPage,
                surahName: surah.name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Surah number
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withValues(alpha: 0.8),
                      Theme.of(context).primaryColor,
                    ],
                  ),
                ),
                child: Center(
                  child: Text(
                    '${surah.number}',
                    style: GoogleFonts.tajawal(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Surah info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Arabic name
                    Text(
                      surah.name,
                      style: GoogleFonts.tajawal(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.headlineSmall?.color,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // English name and revelation info
                    Row(
                      children: [
                        Text(
                          surah.englishName,
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getRevelationTypeColor(surah.revelationType).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getRevelationTypeColor(surah.revelationType).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            _getRevelationTypeText(surah.revelationType),
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              color: _getRevelationTypeColor(surah.revelationType),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Ayahs count
              Column(
                children: [
                  Text(
                    '${surah.totalAyahs}',
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    'آية',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تحميل المصحف',
          style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل تريد تحميل جميع صفحات المصحف للقراءة بدون اتصال بالإنترنت؟\n\nسيتم تحميل 604 صفحة من المصحف الشريف.',
          style: GoogleFonts.tajawal(),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: GoogleFonts.tajawal(),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadAllPages();
            },
            child: Text(
              'تحميل',
              style: GoogleFonts.tajawal(),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadAllPages() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DownloadProgressDialog(
        onCancel: () {
          QuranPagesService.instance.cancelDownload();
          Navigator.pop(context);
        },
      ),
    );
  }
}
