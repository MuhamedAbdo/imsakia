import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reciter.dart';
import 'reciter_detail_screen.dart';
import 'favorites_reciters_screen.dart';
import 'audio_bottom_sheet.dart';

class AudioRecitersScreen extends StatefulWidget {
  const AudioRecitersScreen({super.key});

  @override
  State<AudioRecitersScreen> createState() => _AudioRecitersScreenState();
}

class _AudioRecitersScreenState extends State<AudioRecitersScreen> {
  final Dio _dio = Dio();
  List<Reciter> _allReciters = [];
  List<Reciter> _filteredReciters = [];
  List<String> _favoriteIds = [];

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";
  bool _isSearching = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _fetchReciters();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteIds = prefs.getStringList('favorite_reciters') ?? [];
    });
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorite_reciters', _favoriteIds);
  }

  void _toggleFavorite(String id) {
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
      _saveFavorites();
    });
  }

  Future<void> _fetchReciters() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await _dio.get(
        'https://mp3quran.net/api/v3/reciters?language=ar',
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> recitersList = response.data['reciters'];

        // Parse and limit to famous top voices
        List<Reciter> mappedList = recitersList
            .map((json) => Reciter.fromJson(json))
            .where((r) => r.serverUrl.isNotEmpty) // Filter broken APIs
            .toList();

        // Sort to bring favorites to top, then normally
        mappedList.sort((a, b) {
          bool aFav = _favoriteIds.contains(a.id);
          bool bFav = _favoriteIds.contains(b.id);
          if (aFav && !bFav) return -1;
          if (!aFav && bFav) return 1;
          return a.name.compareTo(b.name);
        });

        if (mounted) {
          setState(() {
            _allReciters = mappedList;
            _filteredReciters = _allReciters;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load API');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = "لا يوجد اتصال بالإنترنت أو فشل جلب البيانات.";
        });
      }
    }
  }

  void _filterReciters(String query) {
    if (query.isEmpty) {
      setState(() => _filteredReciters = _allReciters);
      return;
    }
    setState(() {
      _filteredReciters = _allReciters
          .where((reciter) => reciter.name.contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDarkMode
            ? const Color(0xFF121212)
            : const Color(0xFFF5F5F0),
        appBar: AppBar(
          backgroundColor: isDarkMode ? Colors.black : Colors.blue,
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "بحث عن قارئ...",
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onChanged: _filterReciters,
                )
              : Text(
                  'تلاوات القرآن',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.favorite, color: Colors.blue[100]),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoritesRecitersScreen(),
                ),
              ).then((_) {
                // Return refresh logic to catch any unwatched removals
                _loadFavorites();
                setState(() => _filteredReciters = _allReciters);
              });
            },
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _filteredReciters = _allReciters;
                  }
                });
              },
            ),
          ],
        ),
        body: Stack(
          children: [_buildBody(isDarkMode), const AudioBottomSheet()],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 80,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              _errorMessage,
              style: GoogleFonts.tajawal(
                fontSize: 18,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchReciters,
              icon: const Icon(Icons.refresh),
              label: Text("إعادة المحاولة", style: GoogleFonts.tajawal()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchReciters,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filteredReciters.length,
        itemBuilder: (context, index) {
          final reciter = _filteredReciters[index];
          final isFav = _favoriteIds.contains(reciter.id);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ReciterDetailScreen(reciter: reciter),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.blue,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reciter.name,
                              style: GoogleFonts.tajawal(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reciter.rewaya,
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                color: isDarkMode
                                    ? Colors.white54
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav
                              ? Colors.red
                              : (isDarkMode ? Colors.white54 : Colors.grey),
                        ),
                        onPressed: () => _toggleFavorite(reciter.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
