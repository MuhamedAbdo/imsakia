import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/quran_service.dart';
import '../utils/logger.dart';
import 'quran_reader_screen.dart';
import 'juz_index_screen.dart';

class QuranIndexScreen extends StatefulWidget {
  const QuranIndexScreen({super.key});

  @override
  State<QuranIndexScreen> createState() => _QuranIndexScreenState();
}

class _QuranIndexScreenState extends State<QuranIndexScreen>
    with SingleTickerProviderStateMixin {
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
      await _quranService.loadSurahs();
      _allSurahs = _quranService.surahs;
      _filteredSurahs = List.from(_allSurahs);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      Logger.error('Error loading Quran index: $e');
      if (mounted) setState(() => _isLoading = false);
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

  String _getRevelationTypeText(String revelationType) =>
      revelationType == 'Meccan' ? 'مكية' : 'مدنية';
  Color _getRevelationTypeColor(String revelationType) =>
      revelationType == 'Meccan' ? Colors.green : Colors.blue;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        // خلفية الصفحة تتغير حسب الوضع
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            'الفهرس',
            style: GoogleFonts.tajawal(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          backgroundColor: primaryColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.bookmark, color: Colors.amber),
              onPressed: () {}, // تم اختصار الوظيفة هنا للتركيز على التصميم
              tooltip: 'الانتقال للعلامة',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              fontSize: 16,
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
            _buildSurahsTab(isDark, primaryColor),
            const JuzIndexScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahsTab(bool isDark, Color primaryColor) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.tajawal(
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'ابحث عن سورة...',
              hintStyle: GoogleFonts.tajawal(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              prefixIcon: Icon(Icons.search, color: primaryColor),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredSurahs.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد سور تطابق البحث',
                    style: GoogleFonts.tajawal(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: _filteredSurahs.length,
                  itemBuilder: (context, index) => _buildSurahCard(
                    _filteredSurahs[index],
                    isDark,
                    primaryColor,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSurahCard(Surah surah, bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  QuranReaderScreen(initialSurah: surah.number, initialAyah: 1),
            ),
          );
        },
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // رقم السورة بتنسيق دائري
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.1),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(
                    '${surah.number}',
                    style: GoogleFonts.tajawal(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // معلومات السورة
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surah.name,
                      style: GoogleFonts.tajawal(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          surah.revelationType == 'Meccan' ? 'مكية' : 'مدنية',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: _getRevelationTypeColor(
                              surah.revelationType,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${surah.totalAyahs} آيات',
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // اسم السورة بالانجليزي (اختياري)
              Text(
                surah.englishName,
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
