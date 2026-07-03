import 'dart:convert';
import 'dart:isolate';

import 'package:brotli/brotli.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:imsakia/features/quran_madinah/models/ayah_polygon.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Isolate entry-points (top-level — required by Isolate.run)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Decompresses Brotli bytes → UTF-8 SVG string.
/// Runs in a background Isolate so the UI thread is never blocked.
String _decompressBrotli(List<int> compressedBytes) {
  final decompressed = brotliDecode(compressedBytes);
  return utf8.decode(decompressed);
}

// ─── Regex to match <path class="ayahPolygon" … ayah="N" surah="N" d="…"/> ──
// The KFQC SVG files embed surah/ayah directly on the invisible polygon paths.
// This is the authoritative source for all pages (pages 3-604 have 0/0 in JSON).
final _polygonTagRe = RegExp(
  r'''<path[^>]*class="ayahPolygon"[^>]*ayah="(\d+)"[^>]*surah="(\d+)"[^>]*d="([^"]+)"''',
);
// Surah comes BEFORE ayah in some files — handle both orderings
final _polygonTagRe2 = RegExp(
  r'''<path[^>]*class="ayahPolygon"[^>]*surah="(\d+)"[^>]*ayah="(\d+)"[^>]*d="([^"]+)"''',
);

/// Extracts [AyahPolygon] list by parsing `<path class="ayahPolygon">` tags
/// embedded in the SVG markup.  This works for ALL 604 pages.
List<AyahPolygon> _parsePolygonsFromSvg(String svgContent) {
  final results = <AyahPolygon>[];

  // Try pattern: ayah= before surah=
  Iterable<RegExpMatch> matches = _polygonTagRe.allMatches(svgContent);

  for (final m in matches) {
    final ayahStr = m.group(1);
    final surahStr = m.group(2);
    final dAttr = m.group(3);
    if (ayahStr == null || surahStr == null || dAttr == null) continue;

    final ayah = int.tryParse(ayahStr) ?? 0;
    final surah = int.tryParse(surahStr) ?? 0;
    if (ayah == 0 || surah == 0) continue;

    final points = AyahPolygon.parsePolygon(dAttr);
    if (points.length >= 3) {
      results.add(AyahPolygon(
        ayahNumber: ayah,
        surahNumber: surah,
        points: points,
      ));
    }
  }

  // If nothing matched, try pattern: surah= before ayah=
  if (results.isEmpty) {
    matches = _polygonTagRe2.allMatches(svgContent);
    for (final m in matches) {
      final surahStr = m.group(1);
      final ayahStr = m.group(2);
      final dAttr = m.group(3);
      if (ayahStr == null || surahStr == null || dAttr == null) continue;

      final ayah = int.tryParse(ayahStr) ?? 0;
      final surah = int.tryParse(surahStr) ?? 0;
      if (ayah == 0 || surah == 0) continue;

      final points = AyahPolygon.parsePolygon(dAttr);
      if (points.length >= 3) {
        results.add(AyahPolygon(
          ayahNumber: ayah,
          surahNumber: surah,
          points: points,
        ));
      }
    }
  }

  return results;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Service
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Manages SVG page assets for the Mushaf viewer.
///
/// • SVG pages are stored as Brotli-compressed `.svg.br` files (~71 MB for all
///   604 pages) bundled in the app's assets.
/// • Polygon hit-test data is extracted **directly from the SVG markup**
///   (`<path class="ayahPolygon" surah="N" ayah="N" d="…"/>`) which is the
///   authoritative source for all pages in the KFQC dataset.
/// • All heavy work (Brotli decompression + regex polygon extraction) runs in
///   a background [Isolate] via [Isolate.run], never blocking the UI thread.
class SvgPageService {
  SvgPageService._();

  // ── In-memory caches ──────────────────────────────────────────────────────
  static final Map<int, List<AyahPolygon>> _polygonCache = {};
  static final Map<int, String> _svgCache = {};

  // ── Pending-future deduplication ─────────────────────────────────────────
  static final Map<int, Future<_PageData?>> _pending = {};

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Primary API
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Returns the decompressed SVG content for [pageNumber] (1-based).
  /// Returns `null` if the asset is missing or decompression fails.
  static Future<String?> loadSvgContent(int pageNumber) async {
    if (_svgCache.containsKey(pageNumber)) return _svgCache[pageNumber];
    final data = await _loadPage(pageNumber);
    return data?.svg;
  }

  /// Returns the [AyahPolygon] list for [pageNumber] (extracted from SVG).
  static Future<List<AyahPolygon>> loadPolygons(int pageNumber) async {
    if (_polygonCache.containsKey(pageNumber)) {
      return _polygonCache[pageNumber]!;
    }
    final data = await _loadPage(pageNumber);
    return data?.polygons ?? [];
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Internal: single load operation per page (deduped)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static Future<_PageData?> _loadPage(int pageNumber) {
    // Check caches first (both may already be populated from a prior call)
    if (_svgCache.containsKey(pageNumber) &&
        _polygonCache.containsKey(pageNumber)) {
      return Future.value(_PageData(
        svg: _svgCache[pageNumber]!,
        polygons: _polygonCache[pageNumber]!,
      ));
    }

    // Deduplicate concurrent requests
    return _pending.putIfAbsent(pageNumber, () => _doLoad(pageNumber));
  }

  static Future<_PageData?> _doLoad(int pageNumber) async {
    try {
      final filename = '${pageNumber.toString().padLeft(3, '0')}.svg.br';
      final assetPath = 'assets/quran_svg/hafs/kfqc/svg-br/$filename';

      // 1. Read compressed bytes from asset bundle (fast, main isolate)
      final byteData = await rootBundle.load(assetPath);
      final compressed = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      // 2. Decompress AND extract polygons in one Isolate.run call to avoid
      //    transferring a large string back and forth between isolates.
      final result = await Isolate.run(() {
        final svgText = _decompressBrotli(compressed);
        final polys = _parsePolygonsFromSvg(svgText);
        return _IsolateResult(svgText, polys);
      });

      // 3. Populate caches
      _svgCache[pageNumber] = result.svg;
      _polygonCache[pageNumber] = result.polygons;
      _pending.remove(pageNumber);

      return _PageData(svg: result.svg, polygons: result.polygons);
    } catch (e) {
      _pending.remove(pageNumber);
      return null;
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Pre-warming
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Pre-warms [count] pages starting at [fromPage] in the background.
  static void prewarm(int fromPage, {int count = 2}) {
    for (int i = fromPage; i <= fromPage + count && i >= 1 && i <= 604; i++) {
      if (!_svgCache.containsKey(i) || !_polygonCache.containsKey(i)) {
        _loadPage(i); // fire-and-forget
      }
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Cache management
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  /// Evicts SVG content for pages far from [currentPage] to free memory.
  /// Polygon data is kept since it's small and immutable.
  static void evictFarPages(int currentPage, {int keepPages = 5}) {
    _svgCache.removeWhere(
        (page, _) => (page - currentPage).abs() > keepPages);
  }

  /// Clears all caches.
  static void clearAll() {
    _svgCache.clear();
    _polygonCache.clear();
    _pending.clear();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Private data-transfer objects
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/// Returned by Isolate.run — carries both the decompressed SVG string and
/// the parsed polygon list so we only cross the isolate boundary once.
class _IsolateResult {
  final String svg;
  final List<AyahPolygon> polygons;
  _IsolateResult(this.svg, this.polygons);
}

/// Internal cache record per page.
class _PageData {
  final String svg;
  final List<AyahPolygon> polygons;
  _PageData({required this.svg, required this.polygons});
}
