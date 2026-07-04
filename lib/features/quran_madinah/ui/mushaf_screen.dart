import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:imsakia/features/quran_madinah/providers/quran_provider.dart';
import 'package:imsakia/features/quran_madinah/ui/widgets/mushaf_svg_page_widget.dart';
import 'package:imsakia/features/quran_madinah/ui/widgets/vertical_mushaf_view.dart';
import 'package:imsakia/features/quran_madinah/services/madinah_db_helper.dart';
import 'package:imsakia/features/quran_madinah/utils/madinah_quran_utils.dart';

class MushafScreen extends StatefulWidget {
  final int initialPage;
  final String? searchQuery;
  final int? targetAyaId;

  const MushafScreen({
    super.key,
    required this.initialPage,
    this.searchQuery,
    this.targetAyaId,
  });

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  // ── Horizontal (PageView) state ────────────────────────────────────────────
  late PageController _pageController;

  // ── Shared ─────────────────────────────────────────────────────────────────
  int    _currentPage     = 1;
  String _pageSurahNames  = '';
  int    _currentJuz      = 1;
  String _hizbInfo        = '';

  // ── Vertical mode ──────────────────────────────────────────────────────────
  bool _isVerticalMode = false;

  /// Key used to call public methods on [VerticalMushafViewState] from the
  /// AppBar without lifting all auto-scroll state into this widget.
  final GlobalKey<VerticalMushafViewState> _verticalKey =
      GlobalKey<VerticalMushafViewState>();

  /// Convenience getter so the AppBar play/pause icon reflects the live state.
  bool get _autoScrollActive =>
      _verticalKey.currentState?.isAutoScrolling ?? false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  void _updateAllowedOrientations() {
    if (_isVerticalMode) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

  @override
  void initState() {
    super.initState();
    _updateAllowedOrientations();
    _currentPage    = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage - 1);
    _updatePageInfo(_currentPage);
  }

  Future<void> _updatePageInfo(int page) async {
    final ayahs = await DbHelper.getAyahsByPage(page);
    if (ayahs.isNotEmpty && mounted) {
      final surahNames = ayahs.map((a) => a.suraNameAr).toSet().toList();
      setState(() {
        _pageSurahNames = surahNames.join(' | ');
        _currentJuz     = QuranUtils.getJuzNumber(page);
        _hizbInfo       = QuranUtils.getHizbInfo(page);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Page-change handlers ───────────────────────────────────────────────────

  void _onHorizontalPageChanged(int index, QuranProvider provider) {
    final page = index + 1;
    setState(() => _currentPage = page);
    provider.setPage(page);
    _updatePageInfo(page);
  }

  void _onVerticalPageChanged(int page, QuranProvider provider) {
    // Avoid a redundant setState when the same page is reported twice.
    if (page == _currentPage) return;
    setState(() => _currentPage = page);
    provider.setPage(page);
    _updatePageInfo(page);
  }

  // ── Mode toggle ────────────────────────────────────────────────────────────

  /// Switches between horizontal (PageView) and vertical (ListView) modes,
  /// always restoring the reader to [_currentPage] after the switch.
  void _toggleMode() {
    if (_isVerticalMode) {
      // ── Vertical → Horizontal ──────────────────────────────────────────
      _pageController.dispose();
      _pageController = PageController(initialPage: _currentPage - 1);
      setState(() => _isVerticalMode = false);
      _updateAllowedOrientations();
    } else {
      // ── Horizontal → Vertical ──────────────────────────────────────────
      setState(() => _isVerticalMode = true);
      _updateAllowedOrientations();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final quranProvider = context.watch<QuranProvider>();

    return Scaffold(
      appBar: _buildAppBar(context, quranProvider),
      body: _isVerticalMode
          ? VerticalMushafView(
              key: _verticalKey,
              initialPage: _currentPage,
              onPageChanged: (p) => _onVerticalPageChanged(p, quranProvider),
              // When auto-scroll starts/stops, rebuild so the AppBar icon updates.
              onAutoScrollChanged: () => setState(() {}),
            )
          : PageView.builder(
              controller: _pageController,
              reverse: true,
              itemCount: 604,
              allowImplicitScrolling: true,
              onPageChanged: (i) => _onHorizontalPageChanged(i, quranProvider),
              itemBuilder: (context, index) {
                final pn = index + 1;
                return MushafSvgPageWidget(
                  key: ValueKey('svg_page_$pn'),
                  pageNumber: pn,
                );
              },
            ),
      // The page-number bar is only shown in horizontal mode.
      bottomNavigationBar:
          _isVerticalMode ? null : _buildPageNumberBar(context),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(
      BuildContext context, QuranProvider quranProvider) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    // In light mode the AppBar background uses the primary colour, so
    // text/icons must be white.  In dark mode use the surface text colour.
    final appBarTextColor =
        Theme.of(context).brightness == Brightness.light
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
            'الجزء $_currentJuz | $_hizbInfo',
            style: TextStyle(
              fontSize: 12,
              color: appBarTextColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
      actions: [
        // ── Bookmark (hidden in landscape mode to avoid confusion) ───────
        if (!isLandscape)
          Consumer<QuranProvider>(
          builder: (context, provider, child) {
            final isMarked = provider.isBookmarked(_currentPage);
            return IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  isMarked ? Icons.bookmark : Icons.bookmark_border,
                  key: ValueKey(isMarked),
                ),
              ),
              tooltip: isMarked ? 'إزالة العلامة' : 'حفظ الصفحة',
              onPressed: () {
                final willAdd = !provider.isBookmarked(_currentPage);
                provider.toggleBookmark(_currentPage);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      margin:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: willAdd
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF5D4037),
                      content: Row(
                        children: [
                          Icon(
                            willAdd
                                ? Icons.bookmark_added_rounded
                                : Icons.bookmark_remove_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            willAdd
                                ? 'تم حفظ الصفحة بنجاح'
                                : 'تم إزالة العلامة المرجعية',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
              },
            );
          },
        ),

        // ── Vertical-mode extras (AutoScroll only) ───────────────────────
        if (_isVerticalMode) ...[
          // Auto-scroll play / pause
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                _autoScrollActive
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                key: ValueKey(_autoScrollActive),
              ),
            ),
            tooltip: _autoScrollActive
                ? 'إيقاف القراءة التلقائية'
                : 'بدء القراءة التلقائية',
            onPressed: () =>
                _verticalKey.currentState?.toggleAutoScroll(),
          ),
        ],

        // ── Mode toggle (always visible) ─────────────────────────────────
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              _isVerticalMode
                  ? Icons.import_contacts_rounded // back to page mode
                  : Icons.view_day_outlined,       // switch to scroll mode
              key: ValueKey(_isVerticalMode),
            ),
          ),
          tooltip: _isVerticalMode ? 'وضع الصفحات' : 'وضع التمرير',
          onPressed: _toggleMode,
        ),
      ],
    );
  }

  // ── Bottom page-number bar (horizontal mode only) ──────────────────────────

  Widget _buildPageNumberBar(BuildContext context) {
    return GestureDetector(
      onTap: () => _showJumpToPageDialog(context),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
              top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
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

  // ── Jump-to-page dialog (horizontal mode) ──────────────────────────────────

  void _showJumpToPageDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('الانتقال إلى صفحة', textAlign: TextAlign.right),
        content: TextField(
          controller: ctrl,
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
              final page = int.tryParse(ctrl.text);
              if (page != null && page >= 1 && page <= 604) {
                Navigator.pop(context);
                _pageController.jumpToPage(page - 1);
              }
            },
            child: const Text('انتقال'),
          ),
        ],
      ),
    );
  }
}
