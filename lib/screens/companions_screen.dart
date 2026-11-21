import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/companion.dart';
import '../providers/font_settings_provider.dart';

class CompanionsScreen extends StatefulWidget {
  const CompanionsScreen({super.key});

  @override
  State<CompanionsScreen> createState() => _CompanionsScreenState();
}

class _CompanionsScreenState extends State<CompanionsScreen> {
  List<Companion> _allCompanions = [];
  List<Companion> _filteredCompanions = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _categories = [
    {'id': 'all', 'label': 'الكل'},
    {'id': 'ashara', 'label': 'المبشرون بالجنة'},
    {'id': 'ahl_albayt_women', 'label': 'آل البيت والصحابيات'},
    {'id': 'men', 'label': 'رجال حول الرسول'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCompanionsData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        _applyFilter();
      });
    }
  }

  Future<void> _loadCompanionsData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final results = await Future.wait([
        rootBundle.loadString('assets/data/companions/01_ashara.json'),
        rootBundle.loadString('assets/data/companions/02_ahl_albayt_women.json'),
        rootBundle.loadString('assets/data/companions/03_men_around_prophet.json'),
      ]);

      final List<Companion> asharaList = (json.decode(results[0]) as List<dynamic>)
          .map((item) => Companion.fromJson(item as Map<String, dynamic>))
          .toList();
      asharaList.sort((a, b) => a.sequence.compareTo(b.sequence));

      final List<Companion> ahlAlbaytList = (json.decode(results[1]) as List<dynamic>)
          .map((item) => Companion.fromJson(item as Map<String, dynamic>))
          .toList();
      ahlAlbaytList.sort((a, b) => a.sequence.compareTo(b.sequence));

      final List<Companion> menList = (json.decode(results[2]) as List<dynamic>)
          .map((item) => Companion.fromJson(item as Map<String, dynamic>))
          .toList();
      menList.sort((a, b) => a.sequence.compareTo(b.sequence));

      final combined = [...asharaList, ...ahlAlbaytList, ...menList];

      if (mounted) {
        setState(() {
          _allCompanions = combined;
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر تحميل بيانات سير الصحابة: $e';
        });
      }
    }
  }

  void _applyFilter() {
    List<Companion> list = _allCompanions;

    if (_selectedCategory != 'all') {
      list = list.where((c) => c.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.title.toLowerCase().contains(q) ||
            c.summary.toLowerCase().contains(q);
      }).toList();
    }

    setState(() {
      _filteredCompanions = list;
    });
  }

  Color _getAccentColor(bool isDark) {
    return isDark ? const Color(0xFFD4AF37) : const Color(0xFFB8860B);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = _getAccentColor(isDark);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F6F0),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_forward_ios_rounded,
            color: isDark ? Colors.white : const Color(0xFF263238),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isSearchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.tajawal(
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF263238),
                ),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو اللقب...',
                  hintStyle: GoogleFonts.tajawal(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  border: InputBorder.none,
                ),
              )
            : Text(
                'سير الصحابة الكرام',
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF263238),
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
              color: isDark ? accentColor : const Color(0xFF263238),
            ),
            onPressed: () {
              setState(() {
                if (_isSearchOpen) {
                  _searchController.clear();
                  _searchQuery = '';
                  _isSearchOpen = false;
                  _applyFilter();
                } else {
                  _isSearchOpen = true;
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 48, color: Colors.red.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadCompanionsData,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Horizontal Filter Bar
                    _buildFilterBar(isDark),

                    // Counter & search info
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            'العدد: ${_filteredCompanions.length}',
                            style: GoogleFonts.tajawal(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                          const Spacer(),
                          if (_searchQuery.isNotEmpty)
                            Flexible(
                              child: Text(
                                'نتائج البحث عن: "$_searchQuery"',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.tajawal(
                                  fontSize: 12,
                                  color: accentColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Companions List
                    Expanded(
                      child: _filteredCompanions.isEmpty
                          ? Center(
                              child: Text(
                                'لا توجد نتائج مطابقة للبحث أو الفلتر المختار',
                                style: GoogleFonts.tajawal(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black45,
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 32),
                              itemCount: _filteredCompanions.length,
                              itemBuilder: (context, index) {
                                final companion = _filteredCompanions[index];
                                return _buildCompanionCard(
                                  companion: companion,
                                  isDark: isDark,
                                  onTap: () => _showCompanionDetailsSheet(
                                      context, companion, isDark),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    final activeGold = _getAccentColor(isDark);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _categories.map((filter) {
            final isSelected = _selectedCategory == filter['id'];
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(
                  filter['label']!,
                  style: GoogleFonts.tajawal(
                    fontSize: 12.5,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.black : Colors.white)
                        : (isDark ? Colors.white70 : const Color(0xFF4A4A4A)),
                  ),
                ),
                selected: isSelected,
                selectedColor: activeGold,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? activeGold
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFDDD9CD)),
                    width: 0.8,
                  ),
                ),
                showCheckmark: false,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedCategory = filter['id']!;
                      _applyFilter();
                    });
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCompanionCard({
    required Companion companion,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final fontSettings = Provider.of<FontSettingsProvider>(context);
    final accent = _getAccentColor(isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE8E5DC),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Badges Row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF10B981).withValues(alpha: 0.16)
                            : const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : const Color(0xFFA7D7B5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.groups_rounded,
                            size: 11,
                            color: isDark
                                ? const Color(0xFF34D399)
                                : const Color(0xFF1E7E34),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            companion.categoryTitle,
                            style: GoogleFonts.tajawal(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF1E7E34),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Caliph Badge if present
                    if (companion.caliphBadge.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.18 : 0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.military_tech_rounded,
                              size: 12,
                              color: accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              companion.caliphBadge,
                              style: GoogleFonts.tajawal(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Name
                Text(
                  companion.name,
                  softWrap: true,
                  style: GoogleFonts.tajawal(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF212121),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),

                // Title (اللقب)
                Row(
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      size: 14,
                      color: accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        companion.title,
                        softWrap: true,
                        style: GoogleFonts.tajawal(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Summary
                Text(
                  companion.summary,
                  softWrap: true,
                  style: GoogleFonts.tajawal(
                    fontSize: 13.5,
                    color: isDark ? Colors.white70 : const Color(0xFF424242),
                    height: fontSettings.lineHeight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Action hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'عرض السيرة والمناقب',
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 11,
                      color: accent,
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

  void _showCompanionDetailsSheet(
      BuildContext context, Companion companion, bool isDark) {
    final accent = _getAccentColor(isDark);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: DraggableScrollableSheet(
            initialChildSize: 0.88,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              final fontSettings = Provider.of<FontSettingsProvider>(context);
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag handle & close button
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 12, bottom: 8, right: 16, left: 16),
                      child: Row(
                        children: [
                          const SizedBox(width: 40),
                          const Spacer(),
                          Container(
                            width: 44,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.black12,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: isDark ? Colors.white70 : Colors.black54,
                              size: 22,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'إغلاق',
                          ),
                        ],
                      ),
                    ),

                    // Sheet Content
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        children: [
                          // Header Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFFFBF9F4),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.25),
                                width: 0.9,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badges
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 9, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF10B981).withValues(alpha: 0.16)
                                            : const Color(0xFFE6F4EA),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                              : const Color(0xFFA7D7B5),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        companion.categoryTitle,
                                        style: GoogleFonts.tajawal(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? const Color(0xFF34D399)
                                              : const Color(0xFF1E7E34),
                                        ),
                                      ),
                                    ),
                                    if (companion.caliphBadge.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: accent.withValues(alpha: isDark ? 0.18 : 0.14),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: accent.withValues(alpha: 0.5),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          companion.caliphBadge,
                                          style: GoogleFonts.tajawal(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Full Name
                                Text(
                                  companion.name,
                                  softWrap: true,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF212121),
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Title (اللقب)
                                Text(
                                  companion.title,
                                  softWrap: true,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: accent,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Birth / Death
                                Row(
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      size: 14,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        companion.birthDeath,
                                        softWrap: true,
                                        style: GoogleFonts.tajawal(
                                          fontSize: 12.5,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Summary Section
                          _buildSectionHeader(
                            icon: Icons.info_outline_rounded,
                            title: 'نبذة عامة',
                            accentColor: accent,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            companion.summary,
                            softWrap: true,
                            style: GoogleFonts.tajawal(
                              fontSize: 14.5,
                              color: isDark ? Colors.white70 : const Color(0xFF333333),
                              height: fontSettings.lineHeight,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Islam Story Section
                          _buildSectionHeader(
                            icon: Icons.wb_sunny_outlined,
                            title: 'إسلامه ونشأته',
                            accentColor: accent,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            companion.islamStory,
                            softWrap: true,
                            style: GoogleFonts.tajawal(
                              fontSize: 14.5,
                              color: isDark ? Colors.white70 : const Color(0xFF333333),
                              height: fontSettings.lineHeight,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Virtues Section
                          if (companion.virtues.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.military_tech_outlined,
                              title: 'أبرز المناقب والفضائل',
                              accentColor: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            ...companion.virtues.map((virtue) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Icon(
                                        Icons.check_circle_rounded,
                                        size: 15,
                                        color: accent,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        virtue,
                                        softWrap: true,
                                        style: GoogleFonts.tajawal(
                                          fontSize: 14,
                                          color: isDark ? Colors.white70 : const Color(0xFF333333),
                                          height: fontSettings.lineHeight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],

                          // Key Moments Section
                          if (companion.keyMoments.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.flag_outlined,
                              title: 'مواقف خالدة من حياته',
                              accentColor: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            ...companion.keyMoments.asMap().entries.map((entry) {
                              final index = entry.key + 1;
                              final moment = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: accent.withValues(alpha: 0.4),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        '$index',
                                        style: GoogleFonts.tajawal(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        moment,
                                        softWrap: true,
                                        style: GoogleFonts.tajawal(
                                          fontSize: 14,
                                          color: isDark ? Colors.white70 : const Color(0xFF333333),
                                          height: fontSettings.lineHeight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 16),
                          ],

                          // Famous Quote Section
                          if (companion.famousQuote.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.format_quote_rounded,
                              title: 'مقولة شهيرة',
                              accentColor: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: isDark ? 0.08 : 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.3),
                                  width: 0.9,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.format_quote_rounded,
                                    size: 24,
                                    color: accent,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      companion.famousQuote,
                                      softWrap: true,
                                      style: GoogleFonts.tajawal(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                        color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF263238),
                                        height: fontSettings.lineHeight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Source Section
                          if (companion.source.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.menu_book_rounded,
                              title: 'المصدر والتوثيق',
                              accentColor: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              companion.source,
                              softWrap: true,
                              style: GoogleFonts.tajawal(
                                fontSize: 12.5,
                                color: isDark ? Colors.white54 : Colors.black54,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color accentColor,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: accentColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.tajawal(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF263238),
          ),
        ),
      ],
    );
  }
}
