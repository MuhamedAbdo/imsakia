import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/surah.dart';
import '../services/quran_service.dart';
import '../utils/app_constants.dart';
import 'surah_detail_screen.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen> {
  final TextEditingController _searchController = TextEditingController();
  final QuranService _quranService = QuranService();
  List<Surah> _filteredSurahs = [];
  bool _isLoading = true;
  Map<String, dynamic>? _lastReadAyah;

  @override
  void initState() {
    super.initState();
    _loadSurahs();
    _searchController.addListener(_filterSurahs);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterSurahs);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSurahs() async {
    await _quranService.loadSurahs();
    
    // Load last read ayah info
    _lastReadAyah = await _quranService.getLastReadAyah();
    
    setState(() {
      _filteredSurahs = List.from(_quranService.surahs);
      _isLoading = false;
    });
  }

  void _filterSurahs() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredSurahs = List.from(_quranService.surahs);
      } else {
        _filteredSurahs = _quranService.searchSurahs(query);
      }
    });
  }

  void _showJumpToPageDialog() {
    final TextEditingController pageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'الانتقال إلى الصفحة',
          style: GoogleFonts.tajawal(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          controller: pageController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'رقم الصفحة (1-604)',
            hintText: 'أدخل رقم الصفحة',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
            ),
          ),
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
            onPressed: () async {
              final pageNumber = int.tryParse(pageController.text);
              print('🔄 Jump to page requested: $pageNumber');
              
              if (pageNumber != null && pageNumber >= 1 && pageNumber <= 604) {
                print('✅ Valid page number: $pageNumber, navigating...');
                
                // Ensure QuranService is loaded before navigation
                if (!_quranService.isLoaded) {
                  print('⏳ QuranService not loaded, loading before navigation...');
                  await _quranService.loadSurahs();
                }
                
                Navigator.pop(context);
                final surah = _quranService.getSurahByPage(pageNumber);
                print('📖 Found surah for page $pageNumber: ${surah?.name ?? 'Unknown'}');
                
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SurahDetailScreen(
                        surah: surah ?? _quranService.surahs.first,
                        initialVerse: pageNumber,
                      ),
                    ),
                  );
                }
              } else {
                print('❌ Invalid page number: $pageNumber');
              }
            },
            child: Text(
              'انتقال',
              style: GoogleFonts.tajawal(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'القرآن الكريم',
          style: GoogleFonts.tajawal(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showJumpToPageDialog,
            icon: const Icon(Icons.book),
            tooltip: 'الانتقال إلى الصفحة',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                // Search Bar
                Container(
                  margin: const EdgeInsets.all(AppConstants.mediumPadding),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن سورة...',
                          hintStyle: GoogleFonts.tajawal(),
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.mediumPadding,
                            vertical: 12,
                          ),
                        ),
                      ),
                      
                      // Last read info
                      if (_lastReadAyah != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.bookmark,
                                size: 16,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'آخر قراءة: ${_lastReadAyah!['surahName']}, آية ${_lastReadAyah!['ayahNumber']}',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green[700],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Surah List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.mediumPadding),
                    itemCount: _filteredSurahs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final surah = _filteredSurahs[index];
                      return _buildSurahCard(surah);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSurahCard(Surah surah) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppConstants.mediumBorderRadius),
          onTap: () async {
            print('📖 Tapped surah: ${surah.name} (${surah.number})');
            
            // Ensure QuranService is loaded before navigation
            if (!_quranService.isLoaded) {
              print('⏳ QuranService not loaded, loading before navigation...');
              await _quranService.loadSurahs();
              print('✅ QuranService loaded, navigating to SurahDetailScreen');
            } else {
              print('✅ QuranService already loaded, navigating to SurahDetailScreen');
            }
            
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SurahDetailScreen(surah: surah),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.mediumPadding),
            child: Row(
              children: [
                // Surah Number in Islamic Star Shape
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Star shape
                      Icon(
                        Icons.star,
                        color: Theme.of(context).primaryColor,
                        size: 32,
                      ),
                      // Number
                      Text(
                        '${surah.number}',
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Surah Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.name,
                        style: GoogleFonts.tajawal(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        surah.englishName,
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Additional Info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: surah.revelationType == 'Meccan'
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        surah.revelationType == 'Meccan' ? 'مكية' : 'مدنية',
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: surah.revelationType == 'Meccan'
                              ? Colors.blue
                              : Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${surah.totalAyahs} آية',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'صفحة ${surah.startPage}',
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
      ),
    );
  }
}
