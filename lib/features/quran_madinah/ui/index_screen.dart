import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:imsakia/features/quran_madinah/providers/quran_provider.dart';
import 'package:imsakia/features/quran_madinah/ui/mushaf_screen.dart';
import 'package:imsakia/features/quran_madinah/ui/search_screen.dart';
import 'package:imsakia/core/theme/app_colors.dart';

class IndexScreen extends StatelessWidget {
  const IndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
        appBar: AppBar(
          centerTitle: true,
          automaticallyImplyLeading: true,
          title: const Text(
            'فهرس القرآن',
            style: TextStyle(
              fontFamily: 'HafsSmart',
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.white,
            ),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'فهرس السور'),
              Tab(text: 'فهرس الأجزاء'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'HafsSmart',
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 14,
              fontFamily: 'HafsSmart',
            ),
          ),
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
    
            return TabBarView(
              children: [
                _buildSurahList(quranProvider, isDark),
                _buildJuzList(quranProvider, isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSurahList(QuranProvider quranProvider, bool isDark) {
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
  }

  Widget _buildJuzList(QuranProvider quranProvider, bool isDark) {
    final juzs = quranProvider.juzs;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: juzs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final juz = juzs[index];
        final juzNo = juz['juz_no'] as int;
        final startPage = juz['start_page'] as int;
        final startSura = juz['start_sura_name'] as String;

        return _buildJuzCard(
          context: context,
          juzNo: juzNo,
          startPage: startPage,
          startSura: startSura,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildJuzCard({
    required BuildContext context,
    required int juzNo,
    required int startPage,
    required String startSura,
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
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          width: 0.8,
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    juzNo.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الجزء $juzNo',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'HafsSmart',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'بداية من سورة $startSura',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontFamily: 'HafsSmart',
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'صفحة $startPage',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.secondary,
                    fontFamily: 'HafsSmart',
                  ),
                ),
              ],
            ),
          ),
        ),
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
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          width: 0.8,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1A1C1E) : Colors.white,
      child: Consumer<QuranProvider>(
        builder: (context, quranProvider, child) {
          final bookmarks = quranProvider.bookmarks;

          return Column(
            children: [
              // Enhanced Drawer Header
              DrawerHeader(
                margin: EdgeInsets.zero,
                padding: EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: primaryColor,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(
                        Icons.bookmark_added_rounded,
                        size: 150,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.bookmarks_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'العلامات المرجعية',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'HafsSmart',
                            ),
                          ),
                          Text(
                            'المحفوظة في المصحف الشريف',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                              fontFamily: 'HafsSmart',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bookmarks List
              Expanded(
                child: bookmarks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bookmark_border_rounded,
                              size: 64,
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد علامات مرجعية حالياً',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? Colors.white54 : Colors.black45,
                                fontFamily: 'HafsSmart',
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: bookmarks.length,
                        separatorBuilder: (context, index) => Divider(
                          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                          indent: 16,
                          endIndent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final page = bookmarks[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chrome_reader_mode_rounded,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'الصفحة $page',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'HafsSmart',
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                              onPressed: () {
                                quranProvider.toggleBookmark(page);
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context); // Close Drawer
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MushafScreen(initialPage: page),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              
              // Footer info
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'زاد المسلم - المصحف الشريف',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontFamily: 'HafsSmart',
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

}
