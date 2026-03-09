import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:imsakia/features/quran_madinah/providers/quran_provider.dart';
import 'package:imsakia/features/quran_madinah/ui/mushaf_screen.dart';
import 'package:imsakia/features/quran_madinah/ui/search_screen.dart';

class IndexScreen extends StatelessWidget {
  const IndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'فهرس السور',
          style: TextStyle(
            fontFamily: 'HafsSmart',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: Consumer<QuranProvider>(
        builder: (context, quranProvider, child) {
          if (quranProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final surahs = quranProvider.surahs;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: surahs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final surah = surahs[index];
              final suraNo = surah['sura_no'] as int;
              final arabicName = surah['sura_name_ar'] as String;
              final englishName = surah['sura_name_en'] as String;
              final ayahCount = surah['ayah_count'] as int;
              final startPage = surah['start_page'] as int;
              final isMadani = QuranProvider.isMadani(suraNo);
              final imageAsset = isMadani
                  ? 'assets/images/Madinah.png'
                  : 'assets/images/Makkah.png';

              return _buildSurahCard(
                context: context,
                suraNo: suraNo,
                arabicName: arabicName,
                englishName: englishName,
                ayahCount: ayahCount,
                startPage: startPage,
                imageAsset: imageAsset,
                isDark: isDark,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSurahCard({
    required BuildContext context,
    required int suraNo,
    required String arabicName,
    required String englishName,
    required int ayahCount,
    required int startPage,
    required String imageAsset,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black54
                : Colors.green.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.green.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MushafScreen(initialPage: startPage),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Surah Number styling
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    suraNo.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Surah Names
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        englishName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '\$ayahCount Ayahs',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arabic Name & Revelation Type
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      arabicName,
                      style: TextStyle(
                        fontFamily: 'HafsSmart',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Image.asset(
                      imageAsset,
                      width: 24,
                      height: 24,
                      color: Theme.of(context).colorScheme.secondary,
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

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Consumer<QuranProvider>(
        builder: (context, quranProvider, child) {
          final bookmarks = quranProvider.bookmarks;

          return Column(
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: const Center(
                  child: Text(
                    'العلامات المرجعية (Bookmarks)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: bookmarks.isEmpty
                    ? const Center(child: Text('لا توجد علامات مرجعية'))
                    : ListView.builder(
                        itemCount: bookmarks.length,
                        itemBuilder: (context, index) {
                          final page = bookmarks[index];
                          return ListTile(
                            leading: const Icon(Icons.bookmark),
                            title: Text('الصفحة $page'),
                            onTap: () {
                              Navigator.pop(context); // Close Drawer
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MushafScreen(initialPage: page),
                                ),
                              );
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                quranProvider.toggleBookmark(page);
                              },
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

}
