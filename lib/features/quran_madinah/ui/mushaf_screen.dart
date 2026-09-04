import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:imsakia/features/quran_madinah/providers/quran_provider.dart';
import 'package:imsakia/features/quran_madinah/ui/widgets/mushaf_svg_page_widget.dart';
import 'package:imsakia/features/quran_madinah/ui/widgets/vertical_mushaf_view.dart';
import 'package:imsakia/features/quran_madinah/ui/widgets/reciter_selection_bottom_sheet.dart';
import 'package:imsakia/features/quran_madinah/services/madinah_db_helper.dart';
import 'package:imsakia/features/quran_madinah/utils/madinah_quran_utils.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:imsakia/features/quran_madinah/ui/index_screen.dart';
import 'package:imsakia/providers/quran_audio_provider.dart';
import 'package:quran/quran.dart' as quran;
import 'package:just_audio/just_audio.dart';

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
  int    _currentMainSuraNumber = 1;
  int    _currentMainAyaNumber  = 1;

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

  late QuranAudioProvider _audioProvider;

  @override
  void initState() {
    super.initState();
    _updateAllowedOrientations();
    _currentPage    = widget.initialPage;
    _pageController = PageController(initialPage: widget.initialPage - 1);
    _updatePageInfo(_currentPage);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _audioProvider = context.read<QuranAudioProvider>();
      _audioProvider.addListener(_onAudioProviderChanged);
    });
  }

  void _onAudioProviderChanged() {
    if (!mounted || _isVerticalMode) return;
    
    final playing = _audioProvider.player.playing;
    final aya = _audioProvider.currentPlayingAyaIndex;
    final sura = _audioProvider.currentSuraNumber;
    
    if (playing && aya != null && sura != null) {
      final page = quran.getPageNumber(sura, aya);
      if (page != _currentPage) {
        _pageController.animateToPage(
          page - 1,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _updatePageInfo(int page) async {
    final ayahs = await DbHelper.getAyahsByPage(page);
    if (ayahs.isNotEmpty && mounted) {
      final surahNames = ayahs.map((a) => a.suraNameAr).toSet().toList();
      setState(() {
        _pageSurahNames = surahNames.join(' | ');
        _currentJuz     = QuranUtils.getJuzNumber(page);
        _hizbInfo       = QuranUtils.getHizbInfo(page);
        _currentMainSuraNumber = ayahs.first.suraNo;
        _currentMainAyaNumber  = ayahs.first.ayaNo;
      });
    }
  }

  @override
  void dispose() {
    _audioProvider.removeListener(_onAudioProviderChanged);
    _pageController.dispose();
    super.dispose();
  }

  // ── Page-change handlers ───────────────────────────────────────────────────

  void _onHorizontalPageChanged(int index, QuranProvider provider) {
    final page = index + 1;
    setState(() => _currentPage = page);
    provider.setPage(page);
    _updatePageInfo(page);
    _saveLastReadPage(page);
  }

  void _onVerticalPageChanged(int page, QuranProvider provider) {
    // Avoid a redundant setState when the same page is reported twice.
    if (page == _currentPage) return;
    setState(() => _currentPage = page);
    provider.setPage(page);
    _updatePageInfo(page);
    _saveLastReadPage(page);
  }

  Future<void> _saveLastReadPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_read_quran_page', page);
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
        IconButton(
          icon: const Icon(Icons.format_list_bulleted_rounded),
          tooltip: 'فهرس السور',
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const IndexScreen()),
            );
          },
        ),

        // ── Audio Options Menu ───────────────────────────────────────────────
        Consumer<QuranAudioProvider>(
          builder: (context, audioProvider, child) {
            final isSameSura = audioProvider.currentSuraNumber == _currentMainSuraNumber;
            final isPlaying = isSameSura && audioProvider.player.playing;
            final totalAyahs = quran.getVerseCount(_currentMainSuraNumber);
            
            return FutureBuilder<bool>(
              future: audioProvider.isSuraDownloaded(_currentMainSuraNumber, totalAyahs),
              builder: (context, snapshot) {
                final isDownloaded = snapshot.data ?? false;
                final isDownloading = audioProvider.isDownloading;
                final downloadProgress = audioProvider.downloadProgress;

                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'خيارات التلاوة',
                  onSelected: (value) async {
                    if (value == 'play_pause') {
                      if (isSameSura) {
                        if (audioProvider.player.playing) {
                          audioProvider.pause();
                        } else {
                          audioProvider.player.play();
                        }
                      } else {
                        audioProvider.loadAndPlaySura(_currentMainSuraNumber, totalAyahs, startAyah: _currentMainAyaNumber);
                      }
                    } else if (value == 'download') {
                      if (isDownloaded) {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('حذف التلاوة', textAlign: TextAlign.right),
                            content: const Text(
                              'هل تريد حذف التلاوة الصوتية لهذه السورة لتوفير المساحة؟',
                              textAlign: TextAlign.right,
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('إلغاء'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('حذف', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          audioProvider.deleteSuraAudio(_currentMainSuraNumber, totalAyahs);
                        }
                      } else if (!isDownloading) {
                        audioProvider.downloadSura(_currentMainSuraNumber, totalAyahs);
                      }
                    } else if (value == 'loop_off') {
                      audioProvider.setRepeatMode(LoopMode.off);
                    } else if (value == 'loop_one') {
                      audioProvider.setRepeatMode(LoopMode.one);
                    } else if (value == 'loop_all') {
                      audioProvider.setRepeatMode(LoopMode.all);
                    } else if (value == 'change_reciter') {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const ReciterSelectionBottomSheet(),
                      );
                    }
                  },
                  itemBuilder: (context) {
                    final primaryColor = Theme.of(context).colorScheme.primary;
                    final onSurface = Theme.of(context).colorScheme.onSurface;
                    
                    return [
                      // Play/Pause Item
                      PopupMenuItem(
                        value: 'play_pause',
                        child: Row(
                          children: [
                            Icon(isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline, color: onSurface),
                            const SizedBox(width: 12),
                            Text(isPlaying ? 'إيقاف مؤقت' : (isSameSura ? 'استئناف التلاوة' : 'تشغيل السورة')),
                          ],
                        ),
                      ),
                      
                      // Download/Delete Item
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            if (isDownloading) ...[
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  value: downloadProgress > 0 ? downloadProgress : null,
                                  strokeWidth: 2.0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text('جاري التحميل...'),
                            ] else if (isDownloaded) ...[
                              Icon(Icons.delete_outline, color: Colors.red.shade400),
                              const SizedBox(width: 12),
                              const Text('حذف السورة المحملة', style: TextStyle(color: Colors.red)),
                            ] else ...[
                              Icon(Icons.cloud_download_outlined, color: onSurface),
                              const SizedBox(width: 12),
                              const Text('تحميل السورة'),
                            ],
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      // Change Reciter Item
                      PopupMenuItem(
                        value: 'change_reciter',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, color: onSurface),
                            const SizedBox(width: 12),
                            const Text('تغيير القارئ'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      // Repeat Modes
                      PopupMenuItem(
                        value: 'loop_off',
                        child: Row(
                          children: [
                            Icon(Icons.repeat, color: audioProvider.loopMode == LoopMode.off ? primaryColor : Colors.grey),
                            const SizedBox(width: 12),
                            Text('بدون تكرار', style: TextStyle(color: audioProvider.loopMode == LoopMode.off ? primaryColor : onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'loop_one',
                        child: Row(
                          children: [
                            Icon(Icons.repeat_one, color: audioProvider.loopMode == LoopMode.one ? primaryColor : Colors.grey),
                            const SizedBox(width: 12),
                            Text('تكرار الآية', style: TextStyle(color: audioProvider.loopMode == LoopMode.one ? primaryColor : onSurface)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'loop_all',
                        child: Row(
                          children: [
                            Icon(Icons.loop, color: audioProvider.loopMode == LoopMode.all ? primaryColor : Colors.grey),
                            const SizedBox(width: 12),
                            Text('تكرار السورة', style: TextStyle(color: audioProvider.loopMode == LoopMode.all ? primaryColor : onSurface)),
                          ],
                        ),
                      ),
                    ];
                  },
                );
              },
            );
          },
        ),

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
