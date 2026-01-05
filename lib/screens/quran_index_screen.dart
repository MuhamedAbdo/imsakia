import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/quran_service.dart';
import '../services/quran_text_service.dart';
import '../utils/logger.dart';
import 'quran_reader_screen.dart';
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
      await _quranService.loadSurahs();
      _allSurahs = _quranService.surahs;
      _filteredSurahs = List.from(_allSurahs);
      setState(() => _isLoading = false);
      Logger.success('Loaded ${_allSurahs.length} surahs');
    } catch (e) {
      Logger.error('Error loading Quran index: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterSurahs() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredSurahs = List.from(_allSurahs);
      } else {
        _filteredSurahs = _allSurahs.where((surah) {
          return surah.name.contains(query) || 
                 surah.englishName.toLowerCase().contains(query) || 
                 surah.number.toString().contains(query);
        }).toList();
      }
    });
  }

  String _getRevelationTypeText(String revelationType) => revelationType == 'Meccan' ? 'مكية' : 'مدنية';
  Color _getRevelationTypeColor(String revelationType) => revelationType == 'Meccan' ? Colors.green : Colors.blue;

  Future<void> _goToBookmark() async {
    final quranService = QuranTextService();
    final bookmark = await quranService.getBookmark();
    if (bookmark != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => QuranReaderScreen(
        initialSurah: bookmark['surah'], initialAyah: bookmark['ayah'],
      )));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('لم يتم حفظ أي علامة بعد', style: GoogleFonts.tajawal())));
    }
  }

  @override
  Widget build(BuildContext context) {
    // تحديد اللون الأزرق المستخدم في الصورة ليكون متناسقاً
    final Color appBarBlue = Theme.of(context).primaryColor; 

    return Scaffold(
      appBar: AppBar(
        // إجبار العنوان على اللون الأبيض
        title: Text(
          'الفهرس',
          style: GoogleFonts.tajawal(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white, 
          ),
        ),
        centerTitle: true,
        backgroundColor: appBarBlue,
        elevation: 0,
        // إجبار الأيقونات على اللون الأبيض
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark, color: Colors.amber),
            onPressed: _goToBookmark,
            tooltip: 'الانتقال للعلامة',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          // تعديل ألوان التبويبات لتظهر بوضوح على الأزرق
          labelColor: Colors.white, 
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16),
          unselectedLabelStyle: GoogleFonts.tajawal(fontWeight: FontWeight.w500, fontSize: 15),
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ابحث عن سورة...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => _searchController.clear())
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Theme.of(context).cardColor,
            ),
            textDirection: TextDirection.rtl,
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredSurahs.isEmpty
                  ? Center(child: Text('لا توجد سور تطابق البحث', style: GoogleFonts.tajawal(fontSize: 16)))
                  : ListView.builder(
                      itemCount: _filteredSurahs.length,
                      itemBuilder: (context, index) => _buildSurahCard(_filteredSurahs[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildSurahCard(Surah surah) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => QuranReaderScreen(
            initialSurah: surah.number, initialAyah: 1,
          )));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  border: Border.all(color: Theme.of(context).primaryColor),
                ),
                child: Center(
                  child: Text('${surah.number}', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(surah.name, style: GoogleFonts.tajawal(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(surah.englishName, style: GoogleFonts.tajawal(fontSize: 14, color: Colors.grey[600])),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getRevelationTypeColor(surah.revelationType).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_getRevelationTypeText(surah.revelationType),
                            style: GoogleFonts.tajawal(fontSize: 12, color: _getRevelationTypeColor(surah.revelationType), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text('${surah.totalAyahs}', style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
                  Text('آية', style: GoogleFonts.tajawal(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}