import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:imsakia/features/quran_madinah/models/aya.dart';
import 'package:imsakia/features/quran_madinah/models/ayah_polygon.dart';
import 'package:imsakia/features/quran_madinah/providers/quran_provider.dart';
import 'package:imsakia/features/quran_madinah/services/madinah_db_helper.dart';
import 'package:imsakia/features/quran_madinah/services/svg_page_service.dart';
import 'package:imsakia/features/quran_madinah/utils/polygon_hit_test.dart';
import 'package:imsakia/widgets/tafsir_bottom_sheet.dart';
import 'package:imsakia/features/quran_madinah/models/surah_header_location.dart';
import 'package:imsakia/providers/quran_audio_provider.dart';
import 'package:quran/quran.dart' as quran;


// ─── SVG original viewBox dimensions ────────────────────────────────────────
// Pages 1-2 (Fatiha / start of Baqarah) use a square 235×235 canvas.
// All other pages use the standard 345×550 portrait canvas.
const double _kSquareViewSize = 235.0;
const double _kStdViewW = 345.0;
const double _kStdViewH = 550.0;

// ─── Dark-mode colour inversion matrix ──────────────────────────────────────
// Inverts luma while keeping hue — black Arabic text becomes near-white.
const List<double> _kInvertMatrix = [
  -1,  0,  0,  0, 255,
   0, -1,  0,  0, 255,
   0,  0, -1,  0, 255,
   0,  0,  0,  1,   0,
];

/// ─────────────────────────────────────────────────────────────────────────────
/// MushafSvgPageWidget
///
/// Renders one Mushaf page from a bundled Brotli-compressed `.svg.br` asset.
/// Tap detection uses a Point-in-Polygon ray-casting algorithm with exact
/// BoxFit.contain scale-factor compensation for all screen sizes.
///
/// The existing [TafsirBottomSheet] is called unchanged.
/// ─────────────────────────────────────────────────────────────────────────────
class MushafSvgPageWidget extends StatefulWidget {
  final int pageNumber;

  const MushafSvgPageWidget({super.key, required this.pageNumber});

  @override
  State<MushafSvgPageWidget> createState() => _MushafSvgPageWidgetState();
}

class _MushafSvgPageWidgetState extends State<MushafSvgPageWidget> {
  // ── State ─────────────────────────────────────────────────────────────────
  bool _loading = true;
  bool _svgError = false;         // Decompression or asset-not-found failure
  String? _svgContent;
  List<AyahPolygon> _polygons = [];
  List<Aya> _ayahs = [];          // DB rows – needed for the ayah text in tafsir
  List<SurahHeaderLocation> _headers = []; // Surah header position data


  // Visual feedback
  AyahPolygon? _lastTapped;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(MushafSvgPageWidget old) {
    super.didUpdateWidget(old);
    if (old.pageNumber != widget.pageNumber) {
      _loadData();
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Data loading
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _svgError = false;
      _svgContent = null;
      _polygons = [];
      _ayahs = [];
      _headers = [];
      _lastTapped = null;
    });

    // Parallel: SVG decompress (Isolate) + polygon parse (Isolate) + DB query + surah headers
    final results = await Future.wait([
      SvgPageService.loadSvgContent(widget.pageNumber),
      SvgPageService.loadPolygons(widget.pageNumber),
      DbHelper.getAyahsByPage(widget.pageNumber),
      SvgPageService.getSurahHeadersForPage(widget.pageNumber),
    ]);

    if (!mounted) return;

    final svg = results[0] as String?;
    setState(() {
      _loading = false;
      if (svg == null) {
        _svgError = true;
      } else {
        _svgContent = svg;
        _polygons = results[1] as List<AyahPolygon>;
        _ayahs = results[2] as List<Aya>;
        _headers = results[3] as List<SurahHeaderLocation>;
      }
    });

    // Pre-warm adjacent pages in the background (no await)
    SvgPageService.prewarm(widget.pageNumber + 1, count: 2);
    SvgPageService.prewarm(widget.pageNumber - 2, count: 2);
    // Evict pages that are far from current view
    SvgPageService.evictFarPages(widget.pageNumber, keepPages: 5);
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Tap handling
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  void _onTap(TapUpDetails details, Size widgetSize) {
    if (_polygons.isEmpty) return;

    final (vw, vh) = _viewBoxFor(widget.pageNumber);
    final hit = PolygonHitTest.hitTest(
      tapPosition: details.localPosition,
      widgetSize: widgetSize,
      svgViewWidth: vw,
      svgViewHeight: vh,
      polygons: _polygons,
    );

    if (hit == null) return;

    // Look up the full Aya row from our DB list for the ayah text
    final aya = _ayahs.firstWhere(
      (a) => a.suraNo == hit.surahNumber && a.ayaNo == hit.ayahNumber,
      orElse: () => Aya(
        id: 0,
        jozz: 0,
        suraNo: hit.surahNumber,
        suraNameEn: '',
        suraNameAr: '',
        page: widget.pageNumber,
        lineStart: 0,
        lineEnd: 0,
        ayaNo: hit.ayahNumber,
        ayaText: '',
        ayaTextEmlaey: '',
      ),
    );

    // Brief highlight feedback
    setState(() => _lastTapped = hit);
    Future.delayed(const Duration(milliseconds: 350),
        () { if (mounted) setState(() => _lastTapped = null); });

    _showTafsir(aya);
  }

  // ─── Calls the existing TafsirBottomSheet — completely unchanged ──────────
  void _showTafsir(Aya aya) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TafsirBottomSheet(ayah: {
        'surah_id': aya.suraNo,
        'number_in_surah': aya.ayaNo,
        'text': aya.ayaText,
      }),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Helpers
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static (double, double) _viewBoxFor(int page) =>
      page <= 2 ? (_kSquareViewSize, _kSquareViewSize) : (_kStdViewW, _kStdViewH);

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Build
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  @override
  Widget build(BuildContext context) {
    // Watch provider so dark-mode toggle triggers a rebuild
    final isDark = Theme.of(context).brightness == Brightness.dark;
    context.watch<QuranProvider>();

    if (_loading) return _buildShimmer(context);
    if (_svgError) return _buildErrorState(context);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final wSize = Size(constraints.maxWidth, constraints.maxHeight);
          final (vw, vh) = _viewBoxFor(widget.pageNumber);

          // BoxFit.contain scale & centering offset (for highlight painter)
          final scale = min(wSize.width / vw, wSize.height / vh);
          final ox = (wSize.width - vw * scale) / 2;
          final oy = (wSize.height - vh * scale) / 2;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTap(d, wSize),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Layer 0: Surah Headers (underneath) ───────────────────
                _buildHeadersLayer(context, scale, ox, oy, isDark),

                // ── Layer 1: SVG page ──────────────────────────────────────
                _buildSvgLayer(isDark),


                // ── Layer 2: Tap-highlight overlay ─────────────────────────
                if (_lastTapped != null)
                  CustomPaint(
                    painter: _HighlightPainter(
                      polygon: _lastTapped!,
                      scale: scale,
                      offsetX: ox,
                      offsetY: oy,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.22),
                    ),
                  ),

                // ── Layer 3: Audio highlight overlay ───────────────────────
                Consumer<QuranAudioProvider>(
                  builder: (context, audioProvider, child) {
                    if (audioProvider.currentSuraNumber != null && audioProvider.currentPlayingAyaIndex != null) {
                      try {
                        final audioHighlight = _polygons.firstWhere(
                          (p) => p.surahNumber == audioProvider.currentSuraNumber && p.ayahNumber == audioProvider.currentPlayingAyaIndex,
                        );
                        return CustomPaint(
                          painter: _HighlightPainter(
                            polygon: audioHighlight,
                            scale: scale,
                            offsetX: ox,
                            offsetY: oy,
                            color: Colors.amber.withValues(alpha: 0.25),
                          ),
                        );
                      } catch (_) {
                        return const SizedBox.shrink();
                      }
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSvgLayer(bool isDark) {
    final svg = SvgPicture.string(_svgContent!, fit: BoxFit.contain);
    if (!isDark) return svg;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_kInvertMatrix),
      child: svg,
    );
  }

  Widget _buildHeadersLayer(
      BuildContext context, double scale, double ox, double oy, bool isDark) {
    if (_headers.isEmpty) return const SizedBox.shrink();
    
    final audioProvider = context.read<QuranAudioProvider>();

    final headerImage = Image.asset(
      'assets/images/sura_hedder.png',
      fit: BoxFit.fill,
    );

    final decoration = isDark
        ? ColorFiltered(
            colorFilter: const ColorFilter.matrix(_kInvertMatrix),
            child: headerImage,
          )
        : headerImage;

    return Stack(
      children: _headers.map((h) {
        final double left = ox + 5.0 * scale;
        // Shift the header frame up by 18 units (half of height 36) to center the text inside it
        final double top = oy + (h.headerPosition - 18.0) * scale;
        final double width = 335.0 * scale;
        final double height = 36.0 * scale;


        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: GestureDetector(
            onTap: () {
              final totalAyahs = quran.getVerseCount(h.number);
              audioProvider.loadAndPlaySura(h.number, totalAyahs);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                decoration,
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 16.0 * scale),
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 20 * scale,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }


  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Loading shimmer
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildShimmer(BuildContext context) {
    final shimmerColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2a2a2a)
        : const Color(0xFFf0ece4);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: primary,
            ),
          ),
          const SizedBox(height: 24),
          // Shimmer lines — mimic the look of Quran text rows
          for (int i = 0; i < 6; i++)
            _ShimmerLine(
              color: shimmerColor,
              widthFraction: i.isEven ? 0.85 : 0.7,
            ),
        ],
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Error state (asset missing or decompression failed)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Widget _buildErrorState(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'تعذّر تحميل الصفحة ${widget.pageNumber}',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'حدث خطأ أثناء قراءة ملف الصفحة. '
                'تأكد من سلامة ملفات التطبيق.',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'إعادة المحاولة',
                  style: TextStyle(fontFamily: 'Tajawal'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Shimmer line helper
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _ShimmerLine extends StatelessWidget {
  final Color color;
  final double widthFraction;
  const _ShimmerLine({required this.color, required this.widthFraction});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFraction,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 7),
        height: 11,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Tap-highlight overlay painter
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _HighlightPainter extends CustomPainter {
  final AyahPolygon polygon;
  final double scale;
  final double offsetX;
  final double offsetY;
  final Color color;

  const _HighlightPainter({
    required this.polygon,
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (polygon.points.isEmpty && polygon.pathData.isEmpty) return;
    
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = _buildPath(polygon.pathData);
    canvas.drawPath(path, paint);
  }

  Path _buildPath(String raw) {
    final path = Path();
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return path;

    if (cleaned.startsWith('M') || cleaned.startsWith('m')) {
      final tokens = cleaned
          .replaceAllMapped(RegExp(r'([MLZmlz])'), (m) => ' ${m.group(0)} ')
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .toList();

      int i = 0;
      while (i < tokens.length) {
        final cmd = tokens[i];
        switch (cmd.toUpperCase()) {
          case 'M':
            i++;
            if (i + 1 < tokens.length) {
              final x = double.tryParse(tokens[i]) ?? 0.0;
              final y = double.tryParse(tokens[i + 1]) ?? 0.0;
              final pt = _s(Offset(x, y));
              path.moveTo(pt.dx, pt.dy);
              i += 2;
            }
            break;
          case 'L':
            i++;
            if (i + 1 < tokens.length) {
              final x = double.tryParse(tokens[i]) ?? 0.0;
              final y = double.tryParse(tokens[i + 1]) ?? 0.0;
              final pt = _s(Offset(x, y));
              path.lineTo(pt.dx, pt.dy);
              i += 2;
            }
            break;
          case 'Z':
            path.close();
            i++;
            break;
          default:
            if (double.tryParse(cmd) != null && i + 1 < tokens.length) {
              final x = double.parse(cmd);
              final y = double.tryParse(tokens[i + 1]) ?? 0.0;
              final pt = _s(Offset(x, y));
              path.lineTo(pt.dx, pt.dy);
              i += 2;
            } else {
              i++;
            }
        }
      }
    } else {
      bool isFirst = true;
      for (final pair in cleaned.split(RegExp(r'\s+'))) {
        final parts = pair.split(',');
        if (parts.length == 2) {
          final x = double.tryParse(parts[0].trim());
          final y = double.tryParse(parts[1].trim());
          if (x != null && y != null) {
            final pt = _s(Offset(x, y));
            if (isFirst) {
              path.moveTo(pt.dx, pt.dy);
              isFirst = false;
            } else {
              path.lineTo(pt.dx, pt.dy);
            }
          }
        }
      }
      path.close();
    }
    return path;
  }

  Offset _s(Offset svg) => Offset(svg.dx * scale + offsetX, svg.dy * scale + offsetY);

  @override
  bool shouldRepaint(_HighlightPainter o) =>
      o.polygon != polygon || o.color != color;
}
