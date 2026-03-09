import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:imsakia/features/quran_madinah/providers/quran_provider.dart';
import 'package:imsakia/features/quran_madinah/ui/widgets/mushaf_page_builder.dart';
import 'package:imsakia/features/quran_madinah/services/madinah_db_helper.dart';
import 'package:imsakia/features/quran_madinah/utils/madinah_quran_utils.dart';

class MushafScreen extends StatefulWidget {
  final int initialPage;
  final String? searchQuery;
  final int? targetAyaId;

  const MushafScreen({super.key, required this.initialPage, this.searchQuery, this.targetAyaId});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  late PageController _pageController;
  int _currentPage = 1;
  String _pageSurahNames = '';
  int _currentJuz = 1;
  String _hizbInfo = '';

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage - 1);
    _updatePageInfo(_currentPage);
  }

  Future<void> _updatePageInfo(int page) async {
    final ayahs = await DbHelper.getAyahsByPage(page);
    if (ayahs.isNotEmpty && mounted) {
      // Get all unique surah names on this page
      final surahNames = ayahs.map((a) => a.suraNameAr).toSet().toList();

      setState(() {
        _pageSurahNames = surahNames.join(' | ');
        _currentJuz = QuranUtils.getJuzNumber(page);
        _hizbInfo = QuranUtils.getHizbInfo(page);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, QuranProvider quranProvider) {
    final actualPage = index + 1;
    setState(() {
      _currentPage = actualPage;
    });
    quranProvider.setPage(actualPage);
    _updatePageInfo(actualPage);
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers to trigger rebuilds
    final quranProvider = context.watch<QuranProvider>();

    return Scaffold(
      appBar: _buildDynamicAppBar(context),
      body: PageView.builder(
        controller: _pageController,
        reverse: true,
        itemCount: 604,
        allowImplicitScrolling: true,
        onPageChanged: (index) => _onPageChanged(index, quranProvider),
        itemBuilder: (context, index) {
          final quranPageNumber = index + 1;
          return MushafPageBuilder(
            key: ValueKey(
              'page_${quranPageNumber}_${Theme.of(context).brightness == Brightness.dark}',
            ),
            pageNumber: quranPageNumber,
            searchQuery: widget.searchQuery,
            targetAyaId: widget.targetAyaId,
          );
        },
      ),
      bottomNavigationBar: _buildPageNumberIndicator(context),
    );
  }

  PreferredSizeWidget _buildDynamicAppBar(BuildContext context) {
    // In light mode, the primary color is used for the AppBar background, so text must be light.
    final appBarTextColor = Theme.of(context).brightness == Brightness.light
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return AppBar(
      elevation: 2,
      centerTitle: true,
      foregroundColor: appBarTextColor,
      title: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _pageSurahNames,
              style: TextStyle(
                fontFamily: 'HafsSmart',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: appBarTextColor,
              ),
            ),
          ),
          Text(
            "الجزء $_currentJuz | $_hizbInfo",
            style: TextStyle(
              fontSize: 12,
              color: appBarTextColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.format_size),
          onPressed: () => _showFontSizeSlider(context),
        ),
        Consumer<QuranProvider>(
          builder: (context, provider, child) {
            return IconButton(
              icon: Icon(
                provider.isBookmarked(_currentPage)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
              ),
              onPressed: () => provider.toggleBookmark(_currentPage),
            );
          },
        ),
      ],
    );
  }

  void _showFontSizeSlider(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<QuranProvider>(
          builder: (context, provider, child) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              height: 180,
              child: Column(
                children: [
                  const Text(
                    "حجم الخط",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.text_fields, size: 16),
                      Expanded(
                        child: Slider(
                          value: provider.currentFontSize,
                          min: 16,
                          max: 42,
                          divisions: 13,
                          label: provider.currentFontSize.round().toString(),
                          onChanged: (value) {
                            provider.setFontSize(value);
                          },
                        ),
                      ),
                      const Icon(Icons.text_fields, size: 28),
                    ],
                  ),
                  Text(
                    "الحجم الحالي: ${provider.currentFontSize.round()}",
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPageNumberIndicator(BuildContext context) {
    return GestureDetector(
      onTap: () => _showJumpToPageDialog(context),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        ),
        alignment: Alignment.center,
        child: Text(
          '$_currentPage',
          style: TextStyle(
            fontFamily: 'HafsSmart',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  void _showJumpToPageDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('الانتقال إلى صفحة', textAlign: TextAlign.right),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              hintText: 'أدخل رقم الصفحة (1 - 604)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                final page = int.tryParse(controller.text);
                if (page != null && page >= 1 && page <= 604) {
                  Navigator.pop(context);
                  _pageController.jumpToPage(page - 1);
                }
              },
              child: const Text('انتقال'),
            ),
          ],
        );
      },
    );
  }
}
