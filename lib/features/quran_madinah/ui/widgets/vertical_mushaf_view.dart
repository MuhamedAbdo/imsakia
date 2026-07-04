import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:imsakia/features/quran_madinah/providers/quran_provider.dart';
import 'package:imsakia/features/quran_madinah/ui/widgets/mushaf_svg_page_widget.dart';
import 'package:imsakia/features/quran_madinah/utils/madinah_quran_utils.dart';

// ─── SVG viewBox dimensions (mirrors mushaf_svg_page_widget.dart constants) ──
// Pages 1-2 use a square 235×235 canvas; all others use 345×550 portrait.
const double _kSqVW  = 235.0;
const double _kSqVH  = 235.0;
const double _kStdVW = 345.0;
const double _kStdVH = 550.0;

/// Height of the decorative separator rendered between pages.
const double _kDivH = 56.0;

(double, double) _viewBox(int page) =>
    page <= 2 ? (_kSqVW, _kSqVH) : (_kStdVW, _kStdVH);

// ─────────────────────────────────────────────────────────────────────────────
// VerticalMushafView
// ─────────────────────────────────────────────────────────────────────────────

/// Continuous vertical-scroll reader for the Madinah Mushaf.
///
/// The state class is **public** so the parent [MushafScreen] can control it
/// via a [GlobalKey<VerticalMushafViewState>]:
///
/// ```dart
/// final _vKey = GlobalKey<VerticalMushafViewState>();
/// // ...
/// _vKey.currentState?.toggleAutoScroll();
/// _vKey.currentState?.jumpToPage(page);
/// ```
class VerticalMushafView extends StatefulWidget {
  final int initialPage;

  /// Called whenever the topmost visible page changes while scrolling.
  final void Function(int page) onPageChanged;

  /// Called whenever the auto-scroll engine starts or stops (allows the
  /// parent to update its AppBar play/pause icon with a plain setState).
  final VoidCallback? onAutoScrollChanged;

  const VerticalMushafView({
    super.key,
    required this.initialPage,
    required this.onPageChanged,
    this.onAutoScrollChanged,
  });

  @override
  VerticalMushafViewState createState() => VerticalMushafViewState();
}

class VerticalMushafViewState extends State<VerticalMushafView> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final ScrollController _vCtrl = ScrollController(); // vertical (main reading)

  // ── UI state ───────────────────────────────────────────────────────────────
  bool   _isAutoScroll  = false;
  double _scrollSpeed   = 1.5;  // pixels advanced per 16 ms frame
  Timer? _scrollTimer;
  int    _currentPage   = 1;
  double _currentFraction = 0.0;

  // ── Public getters (read by MushafScreen's AppBar) ─────────────────────────
  bool get isAutoScrolling => _isAutoScroll;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    // Jump to the correct page after the first frame so the ListView has
    // performed its initial layout and the ScrollController has a client.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _jumpToPage(_currentPage);
    });
  }

  @override
  void dispose() {
    try {
      context.read<QuranProvider>().setPageOffset(_currentPage, _currentFraction);
    } catch (_) {}
    _scrollTimer?.cancel();
    _vCtrl.dispose();
    super.dispose();
  }

  // ── Geometry helpers ────────────────────────────────────────────────────────

  double _itemWidth(BuildContext ctx) {
    final size = MediaQuery.of(ctx).size;
    final isLandscape = size.width > size.height;
    return isLandscape ? size.width * 0.8 : size.width;
  }

  double _pageH(int page, double iw) {
    final (vw, vh) = _viewBox(page);
    return (iw / vw) * vh;
  }

  /// Cumulative scroll offset at which [targetPage] begins in the ListView.
  double _offsetFor(int targetPage, double iw) {
    double off = 0;
    for (int p = 1; p < targetPage; p++) {
      off += _pageH(p, iw) + _kDivH;
    }
    return off;
  }

  /// Returns the page number whose item contains scroll [offset].
  int _pageFor(double offset, double iw) {
    double acc = 0;
    for (int p = 1; p <= 604; p++) {
      acc += _pageH(p, iw) + _kDivH;
      if (acc > offset) return p;
    }
    return 604;
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Immediately scrolls to [page] within the vertical list.
  void jumpToPage(int page) => _jumpToPage(page);

  /// Starts or stops the auto-scroll engine.
  void toggleAutoScroll() {
    if (_isAutoScroll) {
      _stopScroll();
    } else {
      setState(() => _isAutoScroll = true);
      widget.onAutoScrollChanged?.call();
      _startScroll();
    }
  }

  // ── Auto-scroll engine ─────────────────────────────────────────────────────

  void _startScroll() {
    _scrollTimer?.cancel();
    // Drive the ListView by calling jumpTo at ~60 fps.  jumpTo is a
    // programmatic move and does NOT fire UserScrollNotification, so the
    // manual-touch detector below cannot accidentally cancel itself.
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_vCtrl.hasClients) return;
      final max  = _vCtrl.position.maxScrollExtent;
      final next = (_vCtrl.offset + _scrollSpeed).clamp(0.0, max);
      _vCtrl.jumpTo(next);
      if (next >= max) _stopScroll();
    });
  }

  void _stopScroll() {
    _scrollTimer?.cancel();
    if (mounted) {
      setState(() => _isAutoScroll = false);
      widget.onAutoScrollChanged?.call();
      try {
        context.read<QuranProvider>().setPageOffset(_currentPage, _currentFraction);
      } catch (_) {}
    }
  }

  void _jumpToPage(int page) {
    if (!_vCtrl.hasClients) return;
    final iw  = _itemWidth(context);
    double fraction = 0.0;
    try {
      fraction = context.read<QuranProvider>().getPageOffset(page);
    } catch (_) {}
    final baseOff = _offsetFor(page, iw);
    final exactOff = (baseOff + fraction * _pageH(page, iw))
        .clamp(0.0, _vCtrl.position.maxScrollExtent);
    _vCtrl.jumpTo(exactOff);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final iw = _itemWidth(context);
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return Stack(
      children: [
        // ── Scrollable content ───────────────────────────────────────────
        NotificationListener<ScrollNotification>(
          onNotification: (notif) {
            if (notif.metrics.axis == Axis.vertical) {
              if (notif is ScrollUpdateNotification) {
                final p = _pageFor(notif.metrics.pixels, iw);
                final pageTop = _offsetFor(p, iw);
                final pageH = _pageH(p, iw);
                _currentFraction = pageH > 0 ? ((notif.metrics.pixels - pageTop) / pageH).clamp(0.0, 1.0) : 0.0;
                if (p != _currentPage) {
                  _currentPage = p;
                  widget.onPageChanged(p);
                }
              }
              if (notif is ScrollEndNotification) {
                final p = _pageFor(notif.metrics.pixels, iw);
                final pageTop = _offsetFor(p, iw);
                final pageH = _pageH(p, iw);
                _currentFraction = pageH > 0 ? ((notif.metrics.pixels - pageTop) / pageH).clamp(0.0, 1.0) : 0.0;
                try {
                  context.read<QuranProvider>().setPageOffset(p, _currentFraction);
                } catch (_) {}
              }
              // When the user manually touches and scrolls, cancel auto-scroll.
              if (notif is UserScrollNotification && _isAutoScroll) {
                _stopScroll();
              }
            }
            return false; // let the notification continue to bubble
          },
          child: Scrollbar(
            controller: _vCtrl,
            child: ListView.builder(
              controller: _vCtrl,
              itemCount: 604,
              // We add our own RepaintBoundary only around the SVG layer,
              // so disable ListView's default per-item boundary.
              addRepaintBoundaries: false,
              // Cache ~1.5 page heights ahead/behind the viewport so that
              // auto-scroll never renders a blank frame.
              // ignore: deprecated_member_use
              cacheExtent: 1200,
              itemBuilder: (ctx, index) {
                final pn = index + 1;
                final (vw, vh) = _viewBox(pn);
                final pH = (iw / vw) * vh;
                return Center(
                  child: _PageItem(
                    pageNumber: pn,
                    itemWidth: iw,
                    pageHeight: pH,
                  ),
                );
              },
            ),
          ),
        ),

        // ── Floating speed-control bar (auto-scroll only) ────────────────
        if (_isAutoScroll)
          isLandscape
              ? Positioned(
                  left: 14,
                  top: 16,
                  bottom: 16,
                  child: _SpeedBar(
                    speed: _scrollSpeed,
                    isVertical: true,
                    onSpeedChanged: (v) {
                      setState(() => _scrollSpeed = v);
                      // Restart the timer so the new speed takes effect immediately.
                      if (_isAutoScroll) {
                        _scrollTimer?.cancel();
                        _startScroll();
                      }
                    },
                    onStop: _stopScroll,
                  ),
                )
              : Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _SpeedBar(
                    speed: _scrollSpeed,
                    isVertical: false,
                    onSpeedChanged: (v) {
                      setState(() => _scrollSpeed = v);
                      // Restart the timer so the new speed takes effect immediately.
                      if (_isAutoScroll) {
                        _scrollTimer?.cancel();
                        _startScroll();
                      }
                    },
                    onStop: _stopScroll,
                  ),
                ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PageItem
// ─────────────────────────────────────────────────────────────────────────────

/// One row in the vertical ListView: an SVG page wrapped in [RepaintBoundary]
/// (to isolate the heavy SVG layer from surrounding animation repaints),
/// followed by an optional decorative page divider.
class _PageItem extends StatelessWidget {
  final int    pageNumber;
  final double itemWidth;
  final double pageHeight;

  const _PageItem({
    required this.pageNumber,
    required this.itemWidth,
    required this.pageHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── SVG page ─────────────────────────────────────────────────────
        SizedBox(
          width:  itemWidth,
          height: pageHeight,
          child: RepaintBoundary(
            child: MushafSvgPageWidget(
              key: ValueKey('vert_p_$pageNumber'),
              pageNumber: pageNumber,
            ),
          ),
        ),

        // ── Page divider (not after the last page) ────────────────────────
        if (pageNumber < 604)
          _PageDivider(
            nextPage: pageNumber + 1,
            juz: QuranUtils.getJuzNumber(pageNumber + 1),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PageDivider
// ─────────────────────────────────────────────────────────────────────────────

/// Decorative separator rendered between consecutive Mushaf pages.
class _PageDivider extends StatelessWidget {
  final int nextPage;
  final int juz;

  const _PageDivider({required this.nextPage, required this.juz});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: _kDivH,
      child: Row(
        children: [
          // Left fading gradient line
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  primary.withValues(alpha: 0.45),
                ]),
              ),
            ),
          ),

          // Centre badge
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : primary.withValues(alpha: 0.07),
              border: Border.all(
                color: primary.withValues(alpha: 0.45),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$nextPage',
                  style: TextStyle(
                    fontFamily: 'HafsSmart',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primary,
                    height: 1.1,
                  ),
                ),
                Text(
                  'الجزء $juz',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 9,
                    color: primary.withValues(alpha: 0.75),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Right fading gradient line
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  primary.withValues(alpha: 0.45),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SpeedBar  (floating auto-scroll speed control)
// ─────────────────────────────────────────────────────────────────────────────

class _SpeedBar extends StatelessWidget {
  final double speed;
  final bool isVertical;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onStop;

  const _SpeedBar({
    required this.speed,
    this.isVertical = false,
    required this.onSpeedChanged,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final stopButton = IconButton(
      icon: Icon(Icons.stop_circle_outlined, color: cs.error, size: 28),
      tooltip: 'إيقاف القراءة التلقائية',
      onPressed: onStop,
    );

    final slowText = Text(
      'بطيء',
      style: TextStyle(
        fontFamily: 'Tajawal',
        fontSize: 11,
        color: cs.onSurface.withValues(alpha: 0.55),
      ),
    );

    final fastText = Text(
      'سريع',
      style: TextStyle(
        fontFamily: 'Tajawal',
        fontSize: 11,
        color: cs.onSurface.withValues(alpha: 0.55),
      ),
    );

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.primary.withValues(alpha: 0.2),
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.12),
        trackHeight: 3,
      ),
      child: Slider(
        value: speed,
        min: 0.3,
        max: 8.0,
        onChanged: onSpeedChanged,
      ),
    );

    if (isVertical) {
      return Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.85)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            stopButton,
            const SizedBox(height: 4),
            fastText,
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: slider,
              ),
            ),
            slowText,
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          stopButton,
          slowText,
          Expanded(child: slider),
          fastText,
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
