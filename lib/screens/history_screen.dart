import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/history_event.dart';
import '../providers/font_settings_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryEvent> _allEvents = [];
  List<HistoryEvent> _filteredEvents = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _categories = [
    {'id': 'all', 'label': 'الكل'},
    {'id': 'rashidun', 'label': 'الخلافة الراشدة'},
    {'id': 'fitna', 'label': 'الفتنة الكبرى'},
    {'id': 'umayyad', 'label': 'الأموية'},
    {'id': 'abbasid', 'label': 'العباسية'},
    {'id': 'contemporary', 'label': 'الدول المعاصرة'},
    {'id': 'ottoman', 'label': 'العثمانية'},
    {'id': 'andalus', 'label': 'الأندلس'},
    {'id': 'crusades', 'label': 'الحروب الصليبية'},
    {'id': 'mongols', 'label': 'المغول'},
  ];

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
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

  Future<void> _loadHistoryData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final results = await Future.wait([
        rootBundle.loadString('assets/data/history/01_rashidun.json'),
        rootBundle.loadString('assets/data/history/02_fitna.json'),
        rootBundle.loadString('assets/data/history/03_umayyad.json'),
        rootBundle.loadString('assets/data/history/04_abbasid.json'),
        rootBundle.loadString('assets/data/history/05_contemporary_states.json'),
        rootBundle.loadString('assets/data/history/06_ottoman.json'),
        rootBundle.loadString('assets/data/history/07_andalus.json'),
        rootBundle.loadString('assets/data/history/08_crusades.json'),
        rootBundle.loadString('assets/data/history/09_mongols.json'),
      ]);

      final List<HistoryEvent> combined = [];
      for (final jsonStr in results) {
        if (jsonStr.trim().isNotEmpty) {
          final decoded = json.decode(jsonStr) as List<dynamic>;
          for (final item in decoded) {
            combined.add(HistoryEvent.fromJson(item as Map<String, dynamic>));
          }
        }
      }

      combined.sort((a, b) {
        final cmp = a.chronoOrder.compareTo(b.chronoOrder);
        if (cmp != 0) return cmp;
        return a.sequence.compareTo(b.sequence);
      });

      if (mounted) {
        setState(() {
          _allEvents = combined;
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر تحميل بيانات التاريخ والحضارة: $e';
        });
      }
    }
  }

  void _applyFilter() {
    List<HistoryEvent> list = _allEvents;

    if (_selectedCategory != 'all') {
      list = list.where((e) => e.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((e) {
        return e.title.toLowerCase().contains(q) ||
            e.keyFigures.toLowerCase().contains(q) ||
            e.period.toLowerCase().contains(q) ||
            e.summary.toLowerCase().contains(q) ||
            e.location.toLowerCase().contains(q);
      }).toList();
    }

    setState(() {
      _filteredEvents = list;
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
                    hintText: 'ابحث بالحدث، الفترة، أو الشخصيات...',
                    hintStyle: GoogleFonts.tajawal(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    border: InputBorder.none,
                  ),
                )
              : Text(
                  'التاريخ والحضارة الإسلامية',
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
                            onPressed: _loadHistoryData,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('إعادة المحاولة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor:
                                  isDark ? Colors.black : Colors.white,
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
                              'العدد: ${_filteredEvents.length}',
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

                      // History Events List
                      Expanded(
                        child: _filteredEvents.isEmpty
                            ? Center(
                                child: Text(
                                  'لا توجد أحداث مطابقة للبحث أو القسم المختار',
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
                                itemCount: _filteredEvents.length,
                                itemBuilder: (context, index) {
                                  final event = _filteredEvents[index];
                                  return _buildHistoryCard(
                                    event: event,
                                    isDark: isDark,
                                    onTap: () => _showHistoryDetailsSheet(
                                        context, event, isDark),
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

  Widget _buildHistoryCard({
    required HistoryEvent event,
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
                // Badges Row
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
                        color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        event.categoryTitle,
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                    ),

                    // Period Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF1EFEA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : const Color(0xFFD6D1C4),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            event.period,
                            style: GoogleFonts.tajawal(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title
                Text(
                  event.title,
                  softWrap: true,
                  style: GoogleFonts.tajawal(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF212121),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Key Figures / Location
                if (event.keyFigures.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.person_pin_rounded,
                          size: 13,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          event.keyFigures,
                          softWrap: true,
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF555555),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),

                // Summary
                Text(
                  event.summary,
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
                      'عرض التفاصيل والأثر',
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

  void _showHistoryDetailsSheet(
      BuildContext context, HistoryEvent event, bool isDark) {
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
                                // Category Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(
                                        alpha: isDark ? 0.18 : 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.4),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    event.categoryTitle,
                                    style: GoogleFonts.tajawal(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: accent,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Title
                                Text(
                                  event.title,
                                  softWrap: true,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF212121),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Period
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 13,
                                      color: accent,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        event.period,
                                        softWrap: true,
                                        style: GoogleFonts.tajawal(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Location
                                if (event.location.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_rounded,
                                        size: 13,
                                        color: accent,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          event.location,
                                          softWrap: true,
                                          style: GoogleFonts.tajawal(
                                            fontSize: 12.5,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                ],

                                // Key Figures
                                if (event.keyFigures.isNotEmpty)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.group_rounded,
                                          size: 13,
                                          color: accent,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'أبرز الشخصيات: ${event.keyFigures}',
                                          softWrap: true,
                                          style: GoogleFonts.tajawal(
                                            fontSize: 12.5,
                                            color: isDark
                                                ? Colors.white60
                                                : Colors.black54,
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
                            title: 'ملخص مركز',
                            accentColor: accent,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            event.summary,
                            softWrap: true,
                            style: GoogleFonts.tajawal(
                              fontSize: 14.5,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF333333),
                              height: fontSettings.lineHeight,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Details Section
                          if (event.details.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.list_alt_rounded,
                              title: 'أبرز الأحداث والوقائع',
                              accentColor: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            ...event.details.asMap().entries.map((entry) {
                              final index = entry.key + 1;
                              final detail = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                        detail,
                                        softWrap: true,
                                        style: GoogleFonts.tajawal(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xFF333333),
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

                          // Impact Section
                          if (event.impact.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.auto_awesome_rounded,
                              title: 'الأثر التاريخي والحضاري',
                              accentColor: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                    alpha: isDark ? 0.08 : 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.3),
                                  width: 0.9,
                                ),
                              ),
                              child: Text(
                                event.impact,
                                softWrap: true,
                                style: GoogleFonts.tajawal(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : const Color(0xFF263238),
                                  height: fontSettings.lineHeight,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Source Section
                          if (event.source.isNotEmpty) ...[
                            _buildSectionHeader(
                              icon: Icons.menu_book_rounded,
                              title: 'المصدر والتوثيق',
                              accentColor: accent,
                              isDark: isDark,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              event.source,
                              softWrap: true,
                              style: GoogleFonts.tajawal(
                                fontSize: 12.5,
                                color:
                                    isDark ? Colors.white54 : Colors.black54,
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
