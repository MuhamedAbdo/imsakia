import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reciter.dart';
import 'reciter_detail_screen.dart';
import 'audio_bottom_sheet.dart';

class FavoritesRecitersScreen extends StatefulWidget {
  const FavoritesRecitersScreen({super.key});

  @override
  State<FavoritesRecitersScreen> createState() =>
      _FavoritesRecitersScreenState();
}

class _FavoritesRecitersScreenState extends State<FavoritesRecitersScreen> {
  final Dio _dio = Dio();
  List<Reciter> _favoriteReciters = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchAndFilterFavorites();
  }

  Future<void> _fetchAndFilterFavorites() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> favoriteIds =
          prefs.getStringList('favorite_reciters') ?? [];

      if (favoriteIds.isEmpty) {
        setState(() {
          _favoriteReciters = [];
          _isLoading = false;
        });
        return;
      }

      final response = await _dio.get(
        'https://mp3quran.net/api/v3/reciters?language=ar',
      );

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> recitersList = response.data['reciters'];

        List<Reciter> mappedList = recitersList
            .map((json) => Reciter.fromJson(json))
            .where(
              (r) => r.serverUrl.isNotEmpty && favoriteIds.contains(r.id),
            ) // Filter broken and non-fav
            .toList();

        if (mounted) {
          setState(() {
            _favoriteReciters = mappedList;
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
        });
      }
    }
  }

  Future<void> _removeFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoriteIds =
        prefs.getStringList('favorite_reciters') ?? [];
    favoriteIds.remove(id);
    await prefs.setStringList('favorite_reciters', favoriteIds);

    // Animate removal out of UI dynamically
    setState(() {
      _favoriteReciters.removeWhere((r) => r.id == id);
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
          title: Text(
            'القراء المفضلون',
            style: GoogleFonts.tajawal(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
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
              "حدث خطأ أثناء الاتصال",
              style: GoogleFonts.tajawal(
                fontSize: 18,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchAndFilterFavorites,
              icon: const Icon(Icons.refresh),
              label: Text("إعادة المحاولة", style: GoogleFonts.tajawal()),
            ),
          ],
        ),
      );
    }

    if (_favoriteReciters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 80,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              "لم تقم بإضافة مفضلة بعد",
              style: GoogleFonts.tajawal(
                fontSize: 18,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _favoriteReciters.length,
      itemBuilder: (context, index) {
        final reciter = _favoriteReciters[index];

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
                    builder: (context) => ReciterDetailScreen(reciter: reciter),
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
                              color: isDarkMode ? Colors.white : Colors.black87,
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
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _removeFavorite(reciter.id),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
