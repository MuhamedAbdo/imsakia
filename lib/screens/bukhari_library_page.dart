import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:imsakia/providers/bukhari_provider.dart';
import 'package:imsakia/providers/quran_provider.dart';
import 'package:provider/provider.dart';
import '../models/bukhari_model.dart';

class BukhariLibraryPage extends StatefulWidget {
  const BukhariLibraryPage({super.key});

  @override
  State<BukhariLibraryPage> createState() => _BukhariLibraryPageState();
}

class _BukhariLibraryPageState extends State<BukhariLibraryPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<BukhariProvider>().fetchAllSections();
    });
  }

  void _onBack() {
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      context.read<BukhariProvider>().searchHadith('');
      setState(() {});
    } else {
      Navigator.pop(context);
    }
  }

  /// تنظيف النص من التشكيل
  String _removeDiacritics(String text) {
    final diacritics = RegExp(r'[\u064B-\u0652\u0640]');
    return text.replaceAll(diacritics, '');
  }

  /// دالة التلوين المحدثة باستخدام نظام الـ Mapping لتفادي الإزاحة
  List<TextSpan> _getHighlightedText(String originalText, String query, bool isDarkMode, double fontSize) {
    if (query.isEmpty) return [TextSpan(text: originalText)];

    String normalizedQuery = _removeDiacritics(query);
    List<TextSpan> spans = [];

    String cleanText = "";
    List<int> mapping = [];

    for (int i = 0; i < originalText.length; i++) {
      String char = originalText[i];
      if (!RegExp(r'[\u064B-\u0652\u0640]').hasMatch(char)) {
        cleanText += char;
        mapping.add(i);
      }
    }

    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = cleanText.indexOf(normalizedQuery, start)) != -1) {
      int originalStart = mapping[start];
      int originalMatchStart = mapping[indexOfMatch];
      
      if (originalMatchStart > originalStart) {
        spans.add(TextSpan(text: originalText.substring(originalStart, originalMatchStart)));
      }

      int matchEndInClean = indexOfMatch + normalizedQuery.length - 1;
      int originalMatchEnd = (matchEndInClean + 1 < mapping.length) 
          ? mapping[matchEndInClean + 1] 
          : originalText.length;

      spans.add(TextSpan(
        text: originalText.substring(originalMatchStart, originalMatchEnd),
        style: TextStyle(
          // تم استبدال withOpacity بـ withValues لتجنب الـ Deprecation
          backgroundColor: Colors.amber.withValues(alpha: 0.4),
          color: isDarkMode ? Colors.amber[100] : Colors.red[900],
          fontWeight: FontWeight.bold,
        ),
      ));

      start = indexOfMatch + normalizedQuery.length;
    }

    if (start < mapping.length) {
      spans.add(TextSpan(text: originalText.substring(mapping[start])));
    } else if (mapping.isEmpty && originalText.isNotEmpty) {
       spans.add(TextSpan(text: originalText));
    }

    return spans;
  }

  void _showFontSizeDialog() {
    final quranProvider = Provider.of<QuranProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('حجم خط الأحاديث', style: GoogleFonts.tajawal(fontWeight: FontWeight.w600)),
          content: StatefulBuilder(
            builder: (context, dialogSetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${quranProvider.fontSize.toInt()}',
                    style: GoogleFonts.tajawal(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Slider(
                    value: quranProvider.fontSize,
                    min: 16.0,
                    max: 45.0,
                    divisions: 29,
                    onChanged: (value) {
                      quranProvider.setFontSize(value);
                      dialogSetState(() {});
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('تم', style: GoogleFonts.tajawal(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final fontSize = Provider.of<QuranProvider>(context).fontSize;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _onBack();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F0),
          appBar: AppBar(
            centerTitle: true,
            automaticallyImplyLeading: true,
            leading: Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _onBack,
                  )
                : null,
            title: Text(
              'صحيح البخاري',
              style: GoogleFonts.tajawal(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.text_fields),
                onPressed: _showFontSizeDialog,
              ),
            ],
          ),
          body: Column(
            children: [
              _buildSearchBar(cardBg, isDarkMode),
              Expanded(
                child: Consumer<BukhariProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading) return const Center(child: CircularProgressIndicator());

                    if (_searchController.text.isNotEmpty) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.searchResults.length,
                        itemBuilder: (context, index) => _buildHadithCard(
                            provider.searchResults[index], isDarkMode, cardBg, fontSize, _searchController.text),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: provider.sections.length,
                      itemBuilder: (context, index) {
                        final section = provider.sections[index];
                        final int id = section['id'] ?? 0;
                        final String arabicTitle = provider.getArabicSectionName(id, section['section_name'] ?? '');
                        return _buildSectionTile(section, arabicTitle, provider, isDarkMode, cardBg, fontSize);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(Color cardBg, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black54
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDarkMode ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => context.read<BukhariProvider>().searchHadith(v),
          decoration: const InputDecoration(
            hintText: 'ابحث في المتن أو رقم الحديث...',
            prefixIcon: Icon(Icons.search, color: Colors.blue),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTile(Map<String, dynamic> section, String title, BukhariProvider provider, bool isDarkMode, Color cardBg, double fontSize) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black54
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        iconColor: Colors.blue,
        title: Text(title, style: GoogleFonts.tajawal(fontWeight: FontWeight.w600, fontSize: 16)),
        leading: const Icon(Icons.menu_book, color: Colors.blue, size: 20),
        children: [
          FutureBuilder<List<BukhariHadith>>(
            future: provider.fetchHadithsBySection(section['id'] ?? 0),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
              if (!snap.hasData || snap.data!.isEmpty) return const SizedBox();
              return Column(
                children: snap.data!.map((h) => _buildHadithCard(h, isDarkMode, cardBg, fontSize, "")).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHadithCard(BukhariHadith hadith, bool isDarkMode, Color cardBg, double fontSize, String query) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50], // Keep subtle background for depth in list
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1), // تحديث هنا أيضاً
                  borderRadius: BorderRadius.circular(5)
                ),
                child: Text('حديث رقم: ${hadith.id}', style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: Colors.grey),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: hadith.text));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ الحديث')));
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            textAlign: TextAlign.justify,
            text: TextSpan(
              style: GoogleFonts.amiri(
                fontSize: fontSize,
                height: 1.6,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              children: _getHighlightedText(hadith.text, query, isDarkMode, fontSize),
            ),
          ),
        ],
      ),
    );
  }
}