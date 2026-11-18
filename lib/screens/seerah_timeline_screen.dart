import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import '../models/seerah_event.dart';

class SeerahTimelineScreen extends StatefulWidget {
  const SeerahTimelineScreen({super.key});

  @override
  State<SeerahTimelineScreen> createState() => _SeerahTimelineScreenState();
}

class _SeerahTimelineScreenState extends State<SeerahTimelineScreen> {
  List<SeerahEvent> _events = [];
  List<SeerahEvent> _filteredEvents = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedPhase = 'all';
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _phases = [
    {'id': 'all', 'label': 'الكل'},
    {'id': 'before_prophethood', 'label': 'قبل البعثة'},
    {'id': 'meccan_era', 'label': 'العهد المكي'},
    {'id': 'medinan_era', 'label': 'العهد المدني'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSeerahData();
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

  Future<void> _loadSeerahData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      const filePaths = [
        'assets/data/seerah/01_before_prophethood.json',
        'assets/data/seerah/02_meccan_era.json',
        'assets/data/seerah/03_medinan_era.json',
      ];

      final results = await Future.wait(
        filePaths.map((path) => rootBundle.loadString(path)),
      );

      final List<SeerahEvent> allEvents = [];
      for (final jsonString in results) {
        final List<dynamic> data = json.decode(jsonString);
        allEvents.addAll(
          data.map((item) => SeerahEvent.fromJson(item as Map<String, dynamic>)),
        );
      }

      allEvents.sort((a, b) => a.sequence.compareTo(b.sequence));

      if (mounted) {
        setState(() {
          _events = allEvents;
          _isLoading = false;
          _applyFilter();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'تعذر تحميل بيانات السيرة النبوية: $e';
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      _filteredEvents = _events.where((event) {
        final matchesPhase =
            _selectedPhase == 'all' || event.phase == _selectedPhase;
        final matchesSearch = _searchQuery.isEmpty ||
            event.title.contains(_searchQuery) ||
            event.summary.contains(_searchQuery) ||
            event.dateLabel.contains(_searchQuery) ||
            event.phaseTitle.contains(_searchQuery);
        return matchesPhase && matchesSearch;
      }).toList();
    });
  }

  /// Accent gold color: vibrant in dark mode, calm deep bronze-gold in light mode
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

  _PhaseColors _getPhaseColors(String phase, bool isDark) {
    if (isDark) {
      Color base;
      switch (phase) {
        case 'before_prophethood':
          base = const Color(0xFFD97706);
          break;
        case 'meccan_era':
          base = const Color(0xFF059669);
          break;
        case 'medinan_era':
          base = const Color(0xFFD4AF37);
          break;
        default:
          base = const Color(0xFFD4AF37);
      }
      return _PhaseColors(
        background: base.withValues(alpha: 0.15),
        text: base,
        border: base.withValues(alpha: 0.4),
      );
    } else {
      switch (phase) {
        case 'before_prophethood':
          return const _PhaseColors(
            background: Color(0xFFFDF2E2),
            text: Color(0xFF8F4700),
            border: Color(0xFFF0D5B5),
          );
        case 'meccan_era':
          return const _PhaseColors(
            background: Color(0xFFE6F2EE),
            text: Color(0xFF1B5E4A),
            border: Color(0xFFC3DFD6),
          );
        case 'medinan_era':
          return const _PhaseColors(
            background: Color(0xFFF3EFE2),
            text: Color(0xFF7A5910),
            border: Color(0xFFE5DEC9),
          );
        default:
          return const _PhaseColors(
            background: Color(0xFFF3EFE2),
            text: Color(0xFF7A5910),
            border: Color(0xFFE5DEC9),
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
                    hintText: 'ابحث في محطات السيرة...',
                    hintStyle: GoogleFonts.tajawal(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    border: InputBorder.none,
                  ),
                )
              : Text(
                  'مختصر السيرة النبوية',
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
                child: CircularProgressIndicator(
                  color: accentColor,
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: GoogleFonts.tajawal(
                              fontSize: 15,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadSeerahData,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              'إعادة المحاولة',
                              style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Upper Filter Bar
                      _buildFilterBar(isDark),

                      // Counter & Header Summary
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            Text(
                              'الخط الزمني المبارك',
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFFD4AF37).withValues(alpha: 0.12)
                                    : const Color(0xFFF3EFE2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.transparent
                                      : const Color(0xFFE5DEC9),
                                  width: 0.7,
                                ),
                              ),
                              child: Text(
                                '${_filteredEvents.length} محطة',
                                style: GoogleFonts.tajawal(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFFD4AF37)
                                      : const Color(0xFF7A5910),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Timeline list
                      Expanded(
                        child: _filteredEvents.isEmpty
                            ? Center(
                                child: Text(
                                  'لا توجد محطات مطابقة للبحث أو الفلتر المختار',
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
                                    16, 12, 16, 32),
                                itemCount: _filteredEvents.length,
                                itemBuilder: (context, index) {
                                  final event = _filteredEvents[index];
                                  final isFirst = index == 0;
                                  final isLast =
                                      index == _filteredEvents.length - 1;

                                  return _buildTimelineItem(
                                    event: event,
                                    isFirst: isFirst,
                                    isLast: isLast,
                                    isDark: isDark,
                                    onTap: () => _showEventDetailsSheet(
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
          children: _phases.map((phase) {
            final isSelected = _selectedPhase == phase['id'];
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChoiceChip(
                label: Text(
                  phase['label']!,
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
                      _selectedPhase = phase['id']!;
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

  Widget _buildTimelineItem({
    required SeerahEvent event,
    required bool isFirst,
    required bool isLast,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final lineColor = isDark
        ? const Color(0xFFD4AF37).withValues(alpha: 0.35)
        : const Color(0xFF8A6614).withValues(alpha: 0.28);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Node and Connecting Line
          SizedBox(
            width: 42,
            child: Column(
              children: [
                // Top line connector
                Container(
                  width: 2.5,
                  height: 20,
                  color: isFirst ? Colors.transparent : lineColor,
                ),
                // Glowing Node with sequence number
                _buildTimelineNode(event, isDark),
                // Bottom line connector
                Expanded(
                  child: Container(
                    width: 2.5,
                    color: isLast ? Colors.transparent : lineColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Event Station Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildEventCard(event, isDark, onTap),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineNode(SeerahEvent event, bool isDark) {
    final accent = _getAccentColor(isDark);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border.all(
          color: accent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.40 : 0.16),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          '${event.sequence}',
          style: GoogleFonts.tajawal(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
      ),
    );
  }

  Widget _buildEventCard(
      SeerahEvent event, bool isDark, VoidCallback onTap) {
    final phaseColors = _getPhaseColors(event.phase, isDark);
    final accent = _getAccentColor(isDark);

    return Container(
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
                // Badges Wrap (Prevents overflow on all screen sizes)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Date badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
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
                          Flexible(
                            child: Text(
                              event.dateLabel,
                              style: GoogleFonts.tajawal(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: _getDateBadgeText(isDark),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Phase badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: phaseColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: phaseColors.border,
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        event.phaseTitle,
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: phaseColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Station Title
                Text(
                  event.title,
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF212121),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Station Summary (Soft dark gray in Light Mode for reading comfort)
                Text(
                  event.summary,
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF424242),
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Action hint
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'عرض التفاصيل والعبر',
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

  void _showEventDetailsSheet(
      BuildContext context, SeerahEvent event, bool isDark) {
    final phaseColors = _getPhaseColors(event.phase, isDark);
    final accent = _getAccentColor(isDark);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
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
                          // Phase & Date Header Tags (Wrap to prevent overflow)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: phaseColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: phaseColors.border,
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  event.phaseTitle,
                                  style: GoogleFonts.tajawal(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: phaseColors.text,
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
                                      event.dateLabel,
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
                                  'المحطة #${event.sequence}',
                                  style: GoogleFonts.tajawal(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Title
                          Text(
                            event.title,
                            style: GoogleFonts.tajawal(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1F2937),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Summary Box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFFF7F5EE),
                              borderRadius: BorderRadius.circular(12),
                              border: Border(
                                right: BorderSide(
                                  color: accent,
                                  width: 3.5,
                                ),
                              ),
                            ),
                            child: Text(
                              event.summary,
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.85)
                                    : const Color(0xFF424242),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Details section
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFFD4AF37).withValues(alpha: 0.12)
                                      : const Color(0xFFF3EFE2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.format_list_bulleted_rounded,
                                  size: 18,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'تفاصيل المحطة التاريخية',
                                style: GoogleFonts.tajawal(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Bullet details
                          ...event.details.map((detail) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 7),
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      detail,
                                      style: GoogleFonts.tajawal(
                                        fontSize: 13.5,
                                        height: 1.6,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xFF424242),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 18),

                          // Lessons & Reflections Box
                          if (event.lessons.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFFD4AF37)
                                        .withValues(alpha: 0.08)
                                    : const Color(0xFFFBF8EE),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFFD4AF37).withValues(alpha: 0.35)
                                      : const Color(0xFFE5DEC9),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFFD4AF37)
                                                  .withValues(alpha: 0.2)
                                              : const Color(0xFFF3EFE2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.lightbulb_outline_rounded,
                                          size: 18,
                                          color: accent,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'الدروس والعبر المستفادة',
                                        style: GoogleFonts.tajawal(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? const Color(0xFFFDE68A)
                                              : const Color(0xFF7A5910),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ...event.lessons.map((lesson) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 16,
                                            color: accent,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              lesson,
                                              style: GoogleFonts.tajawal(
                                                fontSize: 13,
                                                height: 1.55,
                                                fontWeight: FontWeight.w500,
                                                color: isDark
                                                    ? Colors.white
                                                        .withValues(alpha: 0.9)
                                                    : const Color(0xFF4A3E26),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Source Citation
                          if (event.source.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.03)
                                    : const Color(0xFFF7F5EE),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.transparent
                                      : const Color(0xFFEDE8DC),
                                  width: 0.7,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.menu_book_rounded,
                                    size: 16,
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF7A5910),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'المصدر: ',
                                    style: GoogleFonts.tajawal(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF424242),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      event.source,
                                      style: GoogleFonts.tajawal(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white60
                                            : const Color(0xFF616161),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
}

class _PhaseColors {
  final Color background;
  final Color text;
  final Color border;

  const _PhaseColors({
    required this.background,
    required this.text,
    required this.border,
  });
}
