import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import '../models/battle_event.dart';

class BattlesScreen extends StatefulWidget {
  const BattlesScreen({super.key});

  @override
  State<BattlesScreen> createState() => _BattlesScreenState();
}

class _BattlesScreenState extends State<BattlesScreen> {
  List<BattleEvent> _allBattles = [];
  List<BattleEvent> _filteredBattles = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all'; // 'all', 'ghazwa', 'sariyya'
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _filters = [
    {'id': 'all', 'label': 'الكل'},
    {'id': 'ghazwa', 'label': 'الغزوات'},
    {'id': 'sariyya', 'label': 'السرايا'},
  ];

  @override
  void initState() {
    super.initState();
    _loadBattlesData();
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

  Future<void> _loadBattlesData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load both JSON files in parallel
      final results = await Future.wait([
        rootBundle.loadString('assets/data/battles/01_ghazawat.json'),
        rootBundle.loadString('assets/data/battles/02_saraya.json'),
      ]);

      final List<BattleEvent> ghazawatList = (json.decode(results[0]) as List<dynamic>)
          .map((item) => BattleEvent.fromJson(item as Map<String, dynamic>))
          .toList();
      ghazawatList.sort((a, b) => a.sequence.compareTo(b.sequence));

      final List<BattleEvent> sarayaList = (json.decode(results[1]) as List<dynamic>)
          .map((item) => BattleEvent.fromJson(item as Map<String, dynamic>))
          .toList();
      sarayaList.sort((a, b) => a.sequence.compareTo(b.sequence));

      final combined = [...ghazawatList, ...sarayaList];
      combined.sort((a, b) {
        final cmp = a.chronoOrder.compareTo(b.chronoOrder);
        if (cmp != 0) return cmp;
        return a.sequence.compareTo(b.sequence);
      });

      if (mounted) {
        setState(() {
          _allBattles = combined;
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر تحميل بيانات الغزوات والسرايا: $e';
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredBattles = _allBattles.where((battle) {
        final matchesType =
            _selectedFilter == 'all' || battle.type == _selectedFilter;
        final query = _searchQuery.toLowerCase();
        final matchesSearch = _searchQuery.isEmpty ||
            battle.name.toLowerCase().contains(query) ||
            battle.commander.toLowerCase().contains(query) ||
            battle.location.toLowerCase().contains(query) ||
            battle.summary.toLowerCase().contains(query) ||
            battle.dateLabel.toLowerCase().contains(query);
        return matchesType && matchesSearch;
      }).toList();
    });
  }

  Color _getAccentColor(bool isDark) {
    return isDark ? const Color(0xFFD4AF37) : const Color(0xFF8A6614);
  }

  Color _getDateBadgeBg(bool isDark) {
    return isDark
        ? const Color(0xFFD4AF37).withValues(alpha: 0.12)
        : const Color(0xFFF3EFE2);
  }

  Color _getDateBadgeText(bool isDark) {
    return isDark ? const Color(0xFFD4AF37) : const Color(0xFF7A5910);
  }

  Color _getDateBadgeBorder(bool isDark) {
    return isDark
        ? const Color(0xFFD4AF37).withValues(alpha: 0.35)
        : const Color(0xFFE5DEC9);
  }

  _TypeBadgeColors _getTypeColors(String type, bool isDark) {
    if (type == 'ghazwa') {
      if (isDark) {
        return _TypeBadgeColors(
          background: const Color(0xFFD4AF37).withValues(alpha: 0.15),
          text: const Color(0xFFD4AF37),
          border: const Color(0xFFD4AF37).withValues(alpha: 0.4),
        );
      } else {
        return const _TypeBadgeColors(
          background: Color(0xFFF3EFE2),
          text: Color(0xFF7A5910),
          border: Color(0xFFE5DEC9),
        );
      }
    } else {
      // sariyya
      if (isDark) {
        return _TypeBadgeColors(
          background: const Color(0xFF059669).withValues(alpha: 0.18),
          text: const Color(0xFF34D399),
          border: const Color(0xFF059669).withValues(alpha: 0.45),
        );
      } else {
        return const _TypeBadgeColors(
          background: Color(0xFFE6F2EE),
          text: Color(0xFF1B5E4A),
          border: Color(0xFFC3DFD6),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = _getAccentColor(isDark);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF6F5F0), // Warm off-white
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: _isSearchOpen
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF263238),
                  ),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم، القائد، أو الموقع...',
                    hintStyle: GoogleFonts.tajawal(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    border: InputBorder.none,
                  ),
                )
              : Text(
                  'الغزوات والسرايا النبوية',
                  style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : const Color(0xFF263238),
                  ),
                ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : const Color(0xFF263238),
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                color: isDark ? Colors.white : const Color(0xFF263238),
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _isSearchOpen = !_isSearchOpen;
                  if (!_isSearchOpen) {
                    _searchController.clear();
                    _searchQuery = '';
                    _applyFilter();
                  }
                });
              },
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: accentColor,
                      strokeWidth: 2.5,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'جاري تحميل سجلات الغزوات والسرايا...',
                      style: GoogleFonts.tajawal(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : const Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: GoogleFonts.tajawal(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: isDark ? Colors.black : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(
                              'إعادة المحاولة',
                              style: GoogleFonts.tajawal(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _loadBattlesData,
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Filter bar
                      _buildFilterBar(isDark),

                      // Count badge & search hint
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              'العدد: ${_filteredBattles.length}',
                              style: GoogleFonts.tajawal(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            const Spacer(),
                            if (_searchQuery.isNotEmpty)
                              Text(
                                'نتائج البحث عن: "$_searchQuery"',
                                style: GoogleFonts.tajawal(
                                  fontSize: 12,
                                  color: accentColor,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Battles list
                      Expanded(
                        child: _filteredBattles.isEmpty
                            ? Center(
                                child: Text(
                                  'لا توجد عناصر مطابقة للبحث أو الفلتر المختار',
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
                                itemCount: _filteredBattles.length,
                                itemBuilder: (context, index) {
                                  final battle = _filteredBattles[index];
                                  return _buildBattleCard(
                                    battle: battle,
                                    isDark: isDark,
                                    onTap: () => _showBattleDetailsSheet(
                                        context, battle, isDark),
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
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter['id'];
            return Padding(
              padding: const EdgeInsets.only(left: 8),
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
                      _selectedFilter = filter['id']!;
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

  Widget _buildBattleCard({
    required BattleEvent battle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final typeColors = _getTypeColors(battle.type, isDark);
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
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges Wrap (Prevents overflow)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Type Badge (غزوة / سرية)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: typeColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: typeColors.border,
                          width: 0.7,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            battle.type == 'ghazwa'
                                ? Icons.shield_rounded
                                : Icons.flag_rounded,
                            size: 11,
                            color: typeColors.text,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            battle.typeTitle,
                            style: GoogleFonts.tajawal(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: typeColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Date Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: _getDateBadgeBg(isDark),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getDateBadgeBorder(isDark),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: _getDateBadgeText(isDark),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            battle.dateLabel,
                            style: GoogleFonts.tajawal(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _getDateBadgeText(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Has Fighting Badge
                    if (battle.hasFighting)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFFEF4444).withValues(alpha: 0.16)
                              : const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                : const Color(0xFFFCA5A5),
                            width: 0.7,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.flash_on_rounded,
                              size: 11,
                              color: isDark
                                  ? const Color(0xFFF87171)
                                  : const Color(0xFFDC2626),
                            ),
                            const SizedBox(width: 3.5),
                            Text(
                              'قتال فعلي',
                              style: GoogleFonts.tajawal(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Name / Title
                Text(
                  battle.name,
                  style: GoogleFonts.tajawal(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF212121),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Commander and Location chips
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_pin_circle_outlined,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          battle.commander,
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF4A4A4A),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          battle.location,
                          style: GoogleFonts.tajawal(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : const Color(0xFF616161),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Summary
                Text(
                  battle.summary,
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF424242),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // Action hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'عرض التفاصيل والدروس',
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

  void _showBattleDetailsSheet(
      BuildContext context, BattleEvent battle, bool isDark) {
    final typeColors = _getTypeColors(battle.type, isDark);
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
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                        children: [
                          // Badges Wrap
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: typeColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: typeColors.border,
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  battle.typeTitle,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: typeColors.text,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _getDateBadgeBg(isDark),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getDateBadgeBorder(isDark),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 12,
                                      color: _getDateBadgeText(isDark),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      battle.dateLabel,
                                      style: GoogleFonts.tajawal(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: _getDateBadgeText(isDark),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'الترتيب #${battle.sequence}',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                              if (battle.hasFighting)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFFEF4444).withValues(alpha: 0.16)
                                        : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                                          : const Color(0xFFFCA5A5),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.flash_on_rounded,
                                        size: 12,
                                        color: isDark
                                            ? const Color(0xFFF87171)
                                            : const Color(0xFFDC2626),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'شهدت قتالاً فعلياً',
                                        style: GoogleFonts.tajawal(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? const Color(0xFFF87171)
                                              : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Title
                          Text(
                            battle.name,
                            style: GoogleFonts.tajawal(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF212121),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Summary
                          Text(
                            battle.summary,
                            style: GoogleFonts.tajawal(
                              fontSize: 14,
                              height: 1.6,
                              color: isDark ? Colors.white70 : const Color(0xFF424242),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Quick Stats Card (بطاقة إحصائية سريعة)
                          _buildQuickStatsCard(battle, isDark, accent),
                          const SizedBox(height: 18),

                          // 1. Causes Section (الأسباب)
                          if (battle.causes.isNotEmpty) ...[
                            _buildSectionHeader(
                              title: battle.type == 'ghazwa' ? 'أسباب الغزوة' : 'أسباب السرية',
                              icon: Icons.lightbulb_outline_rounded,
                              isDark: isDark,
                              accent: accent,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoBox(battle.causes, isDark),
                            const SizedBox(height: 16),
                          ],

                          // 2. Events Highlights Section (أبرز الأحداث)
                          if (battle.events.isNotEmpty) ...[
                            _buildSectionHeader(
                              title: 'أبرز أحداث ومجريات المعركة',
                              icon: Icons.timeline_rounded,
                              isDark: isDark,
                              accent: accent,
                            ),
                            const SizedBox(height: 8),
                            ...battle.events.asMap().entries.map((entry) {
                              return _buildNumberedItem(
                                index: entry.key + 1,
                                text: entry.value,
                                isDark: isDark,
                                accent: accent,
                              );
                            }),
                            const SizedBox(height: 16),
                          ],

                          // 3. Outcome Section (النتيجة)
                          if (battle.outcome.isNotEmpty) ...[
                            _buildSectionHeader(
                              title: 'النتيجة والآثار',
                              icon: Icons.military_tech_outlined,
                              isDark: isDark,
                              accent: accent,
                            ),
                            const SizedBox(height: 8),
                            _buildInfoBox(battle.outcome, isDark),
                            const SizedBox(height: 16),
                          ],

                          // 4. Lessons Section (الدروس والعبر)
                          if (battle.lessons.isNotEmpty) ...[
                            _buildSectionHeader(
                              title: 'الدروس والعبر المستفادة',
                              icon: Icons.auto_stories_outlined,
                              isDark: isDark,
                              accent: accent,
                            ),
                            const SizedBox(height: 8),
                            ...battle.lessons.map((lesson) {
                              return _buildBulletedItem(
                                text: lesson,
                                isDark: isDark,
                                accent: accent,
                              );
                            }),
                            const SizedBox(height: 16),
                          ],

                          // 5. Source Section (المصدر)
                          if (battle.source.isNotEmpty) ...[
                            _buildSectionHeader(
                              title: 'المصدر والتوثيق',
                              icon: Icons.verified_outlined,
                              isDark: isDark,
                              accent: accent,
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : const Color(0xFFF9F8F5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white12
                                      : const Color(0xFFE2DDD3),
                                  width: 0.7,
                                ),
                              ),
                              child: Text(
                                battle.source,
                                style: GoogleFonts.tajawal(
                                  fontSize: 12.5,
                                  fontStyle: FontStyle.italic,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF555555),
                                ),
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

  Widget _buildQuickStatsCard(BattleEvent battle, bool isDark, Color accent) {
    final hasLossesInfo = battle.muslimsMartyrs.isNotEmpty ||
        battle.enemiesCasualties.isNotEmpty ||
        battle.prisoners.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFFAF9F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : const Color(0xFFE5E0D5),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                'بطاقة إحصائية سريعة',
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            icon: Icons.calendar_month_outlined,
            label: 'التاريخ الزمني',
            value: battle.dateLabel,
            isDark: isDark,
            accent: accent,
          ),
          const SizedBox(height: 8),
          _buildStatRow(
            icon: Icons.place_outlined,
            label: 'المكان والموقع',
            value: battle.location,
            isDark: isDark,
            accent: accent,
          ),
          const SizedBox(height: 8),
          _buildStatRow(
            icon: Icons.person_pin_outlined,
            label: 'القائد الميداني',
            value: battle.commander,
            isDark: isDark,
            accent: accent,
          ),
          if (battle.enemyCommander.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildStatRow(
              icon: Icons.person_outline_rounded,
              label: 'قائد الخصم',
              value: battle.enemyCommander,
              isDark: isDark,
              accent: accent,
            ),
          ],
          const SizedBox(height: 8),
          _buildStatRow(
            icon: Icons.shield_outlined,
            label: 'قوات المسلمين',
            value: battle.muslimsCount,
            isDark: isDark,
            accent: accent,
          ),
          const SizedBox(height: 8),
          _buildStatRow(
            icon: Icons.groups_outlined,
            label: 'قوات الخصم',
            value: battle.enemiesCount,
            isDark: isDark,
            accent: accent,
          ),
          if (hasLossesInfo) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              thickness: 0.6,
              color: isDark ? Colors.white12 : const Color(0xFFE5E0D5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.military_tech_outlined, size: 14, color: accent),
                const SizedBox(width: 5),
                Text(
                  'الخسائر والأسرى',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ],
            ),
            if (battle.muslimsMartyrs.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildStatRow(
                icon: Icons.favorite_border_rounded,
                label: 'الشهداء',
                value: battle.muslimsMartyrs,
                isDark: isDark,
                accent: accent,
              ),
            ],
            if (battle.enemiesCasualties.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildStatRow(
                icon: Icons.close_rounded,
                label: 'قتلى الخصم',
                value: battle.enemiesCasualties,
                isDark: isDark,
                accent: accent,
              ),
            ],
            if (battle.prisoners.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildStatRow(
                icon: Icons.lock_outline_rounded,
                label: 'الأسرى',
                value: battle.prisoners,
                isDark: isDark,
                accent: accent,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required Color accent,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: accent.withValues(alpha: 0.85)),
        const SizedBox(width: 6),
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: GoogleFonts.tajawal(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF666666),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            softWrap: true,
            style: GoogleFonts.tajawal(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF222222),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required bool isDark,
    required Color accent,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: accent),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.tajawal(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF263238),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox(String text, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.035)
            : const Color(0xFFFBFBF9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFECE7DE),
          width: 0.8,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.tajawal(
          fontSize: 13,
          height: 1.6,
          color: isDark ? Colors.white70 : const Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildNumberedItem({
    required int index,
    required String text,
    required bool isDark,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$index',
                style: GoogleFonts.tajawal(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.tajawal(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white70 : const Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletedItem({
    required String text,
    required bool isDark,
    required Color accent,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.tajawal(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white70 : const Color(0xFF333333),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadgeColors {
  final Color background;
  final Color text;
  final Color border;

  const _TypeBadgeColors({
    required this.background,
    required this.text,
    required this.border,
  });
}
