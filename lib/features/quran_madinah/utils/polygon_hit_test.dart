import 'dart:math';
import 'dart:ui';

import 'package:imsakia/features/quran_madinah/models/ayah_polygon.dart';

/// Hit-test utilities for Quran page interaction.
///
/// The JSON files define Ayah regions in the **original SVG coordinate space**.
/// When the SVG is rendered via [BoxFit.contain], it is scaled and potentially
/// offset (letter-boxed). This class converts a raw [tapPosition] from the
/// widget's local coordinate system back to SVG coordinates before testing.
class PolygonHitTest {
  PolygonHitTest._();

  // ──────────────────────────────────────────────────────────────────────────
  // Core algorithm: Ray-Casting (Jordan curve theorem)
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns `true` when [point] is strictly inside [polygon].
  ///
  /// Uses an even–odd ray casting test along the positive X axis.
  /// Works for convex, concave, and simple self-intersecting polygons.
  static bool isPointInPolygon(Offset point, List<Offset> polygon) {
    if (polygon.length < 3) return false;

    final px = point.dx;
    final py = point.dy;
    int crossings = 0;
    final n = polygon.length;

    for (int i = 0; i < n; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % n];

      // Check if the ray from (px, py) rightward crosses segment (a → b).
      final minY = min(a.dy, b.dy);
      final maxY = max(a.dy, b.dy);

      if (py <= minY || py > maxY) continue; // Ray misses segment vertically

      // x-coordinate of intersection of the segment with the horizontal ray
      final t = (py - a.dy) / (b.dy - a.dy);
      final xIntersect = a.dx + t * (b.dx - a.dx);

      if (px < xIntersect) crossings++;
    }

    return crossings.isOdd;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Scale-factor & offset calculation for BoxFit.contain
  // ──────────────────────────────────────────────────────────────────────────

  /// Converts a tap position (in widget-local pixel coords) into the original
  /// SVG coordinate space, accounting for [BoxFit.contain] scaling.
  ///
  /// [tapPosition]   – local offset of the tap inside the widget.
  /// [widgetSize]    – rendered size of the widget (from LayoutBuilder).
  /// [svgViewWidth]  – viewBox width of the SVG file.
  /// [svgViewHeight] – viewBox height of the SVG file.
  ///
  /// Returns `null` when the tap is in the letterbox area (outside the SVG).
  static Offset? tapToSvgCoords({
    required Offset tapPosition,
    required Size widgetSize,
    required double svgViewWidth,
    required double svgViewHeight,
  }) {
    final wW = widgetSize.width;
    final wH = widgetSize.height;

    // BoxFit.contain scale: the SVG is scaled so the *entire* viewBox fits
    // inside the widget, maintaining aspect ratio.
    final scale = min(wW / svgViewWidth, wH / svgViewHeight);

    // The scaled SVG dimensions
    final scaledW = svgViewWidth * scale;
    final scaledH = svgViewHeight * scale;

    // Letter-box offsets (the SVG is centred within the widget)
    final offsetX = (wW - scaledW) / 2;
    final offsetY = (wH - scaledH) / 2;

    // Map tap → SVG space
    final svgX = (tapPosition.dx - offsetX) / scale;
    final svgY = (tapPosition.dy - offsetY) / scale;

    // Reject taps in the letter-box margins
    if (svgX < 0 ||
        svgY < 0 ||
        svgX > svgViewWidth ||
        svgY > svgViewHeight) {
      return null;
    }

    return Offset(svgX, svgY);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // High-level: find Ayah from tap
  // ──────────────────────────────────────────────────────────────────────────

  /// Finds the first [AyahPolygon] whose region contains [svgPoint].
  ///
  /// [svgPoint] must already be in SVG coordinate space (use
  /// [tapToSvgCoords] first).
  ///
  /// Returns `null` if no polygon contains the point, or if the point lands
  /// on a non-verse area (surahNumber == 0, e.g. Basmala / header).
  static AyahPolygon? findAyah(Offset svgPoint, List<AyahPolygon> polygons) {
    for (final poly in polygons) {
      // Skip decorative/non-verse regions
      if (poly.surahNumber == 0 || poly.ayahNumber == 0) continue;
      if (poly.points.length < 3) continue;

      if (isPointInPolygon(svgPoint, poly.points)) {
        return poly;
      }
    }
    return null;
  }

  /// All-in-one convenience method.
  ///
  /// Given a raw [tapPosition] on the widget, returns the tapped [AyahPolygon]
  /// or `null` if the tap didn't land on any verse region.
  static AyahPolygon? hitTest({
    required Offset tapPosition,
    required Size widgetSize,
    required double svgViewWidth,
    required double svgViewHeight,
    required List<AyahPolygon> polygons,
  }) {
    final svgPoint = tapToSvgCoords(
      tapPosition: tapPosition,
      widgetSize: widgetSize,
      svgViewWidth: svgViewWidth,
      svgViewHeight: svgViewHeight,
    );

    if (svgPoint == null) return null;
    return findAyah(svgPoint, polygons);
  }
}
