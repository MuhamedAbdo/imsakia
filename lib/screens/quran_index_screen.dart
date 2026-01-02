import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;
import '../utils/logger.dart';
import '../services/quran_pages_service.dart';
import '../widgets/download_progress_dialog.dart';
import 'quran_pages_viewer_screen.dart';

class QuranIndexScreen extends StatefulWidget {
  const QuranIndexScreen({super.key});

  @override
  State<QuranIndexScreen> createState() => _QuranIndexScreenState();
}

class _QuranIndexScreenState extends State<QuranIndexScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<quran.Surah> _filteredSurahs = [];
  List<quran.Surah> _allSurahs = [];
  bool _isLoading = true;

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
    try {
      Logger.info('Loading Quran index using quran package...');
      
      // Get all surahs from quran package
      _allSurahs = quran.getAllSurahs();
      _filteredSurahs = List.from(_allSurahs);
      
      setState(() {
        _isLoading = false;
      });
      
      Logger.success('Loaded ${_allSurahs.length} surahs from quran package');
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

  String _getRevelationTypeText(quran.RevelationType type) {
    switch (type) {
      case quran.RevelationType.Meccan:
        return 'مكية';
      case quran.RevelationType.Medinan:
        return 'مدنية';
      default:
        return 'مكية';
    }
  }

  Color _getRevelationTypeColor(quran.RevelationType type) {
    switch (type) {
      case quran.RevelationType.Meccan:
        return Colors.green;
      case quran.RevelationType.Medinan:
        return Colors.blue;
      default:
        return Colors.green;
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
            icon: const Icon(Icons.download),
            onPressed: _showDownloadDialog,
            tooltip: 'تحميل المصحف',
          ),
        ],
      ),
      body: Column(
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لم يتم العثور على سور',
                              style: GoogleFonts.tajawal(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
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
      ),
    );
  }

  Widget _buildSurahCard(quran.Surah surah) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuranPagesViewerScreen(
                initialPage: _getSurahStartPage(surah.number),
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
                      Theme.of(context).primaryColor.withOpacity(0.8),
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
                            color: _getRevelationTypeColor(surah.revelation).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getRevelationTypeColor(surah.revelation).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _getRevelationTypeText(surah.revelation),
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              color: _getRevelationTypeColor(surah.revelation),
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
                    '${surah.ayahs.length}',
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
              _startQuranDownload();
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

  int _getSurahStartPage(int surahNumber) {
    // Simplified mapping - in a real app, this would be more accurate
    const surahStartPages = {
      1: 1, 2: 2, 3: 50, 4: 77, 5: 106, 6: 128, 7: 151, 8: 177,
      9: 187, 10: 208, 11: 221, 12: 235, 13: 249, 14: 255, 15: 262,
      16: 267, 17: 282, 18: 293, 19: 305, 20: 312, 21: 322, 22: 332,
      23: 342, 24: 350, 25: 359, 26: 367, 27: 377, 28: 385, 29: 396,
      30: 405, 31: 412, 32: 418, 33: 428, 34: 434, 35: 440, 36: 446,
      37: 453, 38: 458, 39: 467, 40: 477, 41: 483, 42: 493, 43: 499,
      44: 506, 45: 513, 46: 521, 47: 527, 48: 534, 49: 542, 50: 549,
      51: 555, 52: 560, 53: 567, 54: 574, 55: 580, 56: 585, 57: 591,
      58: 597, 59: 604, 60: 604, 61: 604, 62: 604, 63: 604, 64: 604,
      65: 604, 66: 604, 67: 604, 68: 604, 69: 604, 70: 604, 71: 604,
      72: 604, 73: 604, 74: 604, 75: 604, 76: 604, 77: 604, 78: 604,
      79: 604, 80: 604, 81: 604, 82: 604, 83: 604, 84: 604, 85: 604,
      86: 604, 87: 604, 88: 604, 89: 604, 90: 604, 91: 604, 92: 604,
      93: 604, 94: 604, 95: 604, 96: 604, 97: 604, 98: 604, 99: 604,
      100: 604, 101: 604, 102: 604, 103: 604, 104: 604, 105: 604, 106: 604,
      107: 604, 108: 604, 109: 604, 110: 604, 111: 604, 112: 604, 113: 604,
      114: 604,
    };
    
    return surahStartPages[surahNumber] ?? 1;
  }

  void _startQuranDownload() {
    _showDownloadProgressDialog();
  }

  void _showDownloadProgressDialog() {
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
