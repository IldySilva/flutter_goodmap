// lib/src/globe/globe_overlays.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../heatmap/heatmap.dart';
import '../markers/marker.dart';
import 'sphere_projection.dart';
import 'world_land_dots.dart';

/// A great-circle arc between two coordinates, bowing off the globe surface.
///
/// **Draw-in animation** — set [drawProgress] (0..1) to draw only a fraction of
/// the arc. Animate this value externally to get a line-drawing effect.
///
/// **Time-series** — set [timestamp] so that the globe's `timeRange` filter can
/// show/hide this arc dynamically.
@immutable
class GlobeArc {
  const GlobeArc({
    required this.from,
    required this.to,
    this.color = const Color(0xFF4F86F7),
    this.width = 1.5,
    this.dashed = true,
    this.bend = 0.35,
    this.segments = 72,
    this.drawProgress = 1.0,
    this.timestamp,
  });

  final LatLng from;
  final LatLng to;
  final Color color;
  final double width;
  final bool dashed;

  /// How far the arc lifts off the surface at its midpoint (fraction of radius).
  final double bend;
  final int segments;

  /// Fraction [0, 1] of the arc to draw. 0 = nothing, 1 = full arc.
  /// Animate from 0→1 to produce a line-drawing effect.
  final double drawProgress;

  /// Optional timestamp for time-series filtering via [GoodGlobe.timeRange].
  final double? timestamp;
}

/// Paints arcs, points, labels, heatmaps and an optional dotted world grid over
/// the globe, hiding anything on the far hemisphere. Re-created each frame with
/// the current [projection].
class GlobeOverlayPainter extends CustomPainter {
  GlobeOverlayPainter({
    required this.projection,
    required this.arcs,
    required this.markers,
    this.dashAnimation,
    this.showDottedGrid = false,
    this.dottedGridColor,
    this.dottedGridRadius = 1.2,
    this.heatmaps = const [],
  }) : super(repaint: dashAnimation);

  final SphereProjection projection;
  final List<GlobeArc> arcs;
  final List<MarkerOptions> markers;

  /// Drives the marching-dash phase (0..1, repeating). Also drives pulse
  /// ring animations when markers have [MarkerOptions.pulse] enabled.
  final Animation<double>? dashAnimation;

  /// When true, draws the dotted world landmass grid.
  final bool showDottedGrid;

  /// Colour of the dotted grid dots. Defaults to 35% black.
  final Color? dottedGridColor;

  /// Radius of each grid dot in logical pixels. Default: 1.2.
  final double dottedGridRadius;

  /// Heatmaps to render on the globe canvas as radial gradient blobs.
  final List<HeatmapOptions> heatmaps;

  @override
  void paint(Canvas canvas, Size size) {
    // Dotted world grid (bottom-most overlay layer)
    if (showDottedGrid) {
      _paintDottedGrid(canvas);
    }

    // Heatmap blobs
    for (final heatmap in heatmaps) {
      _paintHeatmap(canvas, heatmap);
    }

    final phase = dashAnimation?.value ?? 0.0;

    // Arcs (drawn before markers so markers are on top)
    for (final arc in arcs) {
      _paintArc(canvas, arc, phase);
    }

    // Points / markers
    for (final marker in markers) {
      _paintPoint(canvas, marker, phase);
    }
  }

  // --- Dotted grid ---------------------------------------------------------

  void _paintDottedGrid(Canvas canvas) {
    final color = dottedGridColor ?? const Color(0x59000000);
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    for (final latLng in kWorldLandDots) {
      final screen = projection.project(latLng);
      if (screen == null) continue;
      canvas.drawCircle(screen, dottedGridRadius, paint);
    }
  }

  // --- Heatmap -------------------------------------------------------------

  void _paintHeatmap(Canvas canvas, HeatmapOptions heatmap) {
    for (var idx = 0; idx < heatmap.points.length; idx++) {
      final screen = projection.project(heatmap.points[idx]);
      if (screen == null) continue;

      final w = (heatmap.weights != null && idx < heatmap.weights!.length)
          ? heatmap.weights![idx].clamp(0.0, 1.0)
          : 1.0;

      final r = heatmap.radius * (0.4 + 0.6 * w);

      // Colour ramp: blue (w=0) → cyan → lime → yellow → red (w=1)
      final hue = (1.0 - w) * 240.0;
      final opacity =
          (heatmap.intensity * w * 0.65 * heatmap.opacity).clamp(0.0, 1.0);
      final coreColor =
          HSVColor.fromAHSV(opacity, hue, 0.85, 1.0).toColor();

      canvas.drawCircle(
        screen,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              coreColor,
              coreColor.withValues(alpha: opacity * 0.35),
              coreColor.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: screen, radius: r))
          ..blendMode = BlendMode.screen
          ..isAntiAlias = true,
      );
    }
  }

  // --- Arcs ----------------------------------------------------------------

  void _paintArc(Canvas canvas, GlobeArc arc, double phase) {
    final a = SphereProjection.latLngUnit(arc.from);
    final b = SphereProjection.latLngUnit(arc.to);
    final dot = (a[0] * b[0] + a[1] * b[1] + a[2] * b[2]).clamp(-1.0, 1.0);
    final omega = math.acos(dot);
    final sinOmega = math.sin(omega);

    final paint = Paint()
      ..color = arc.color
      ..strokeWidth = arc.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Build sub-paths of consecutive visible samples so the arc breaks where it
    // dips behind the globe.
    Path? run;
    for (var i = 0; i <= arc.segments; i++) {
      final t = i / arc.segments;
      // Honour drawProgress: stop drawing beyond the fraction requested.
      if (t > arc.drawProgress) break;
      final dir = _slerp(a, b, t, omega, sinOmega);
      final lift = 1.0 + arc.bend * math.sin(t * math.pi);
      final p = projection.projectDirection(dir, lift);
      if (p.depth > 0) {
        if (run == null) {
          run = Path()..moveTo(p.screen.dx, p.screen.dy);
        } else {
          run.lineTo(p.screen.dx, p.screen.dy);
        }
      } else if (run != null) {
        _strokePath(canvas, run, paint, arc.dashed, phase);
        run = null;
      }
    }
    if (run != null) _strokePath(canvas, run, paint, arc.dashed, phase);
  }

  void _strokePath(
      Canvas canvas, Path path, Paint paint, bool dashed, double phase) {
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    const dash = 6.0;
    const gap = 5.0;
    const period = dash + gap;
    for (final metric in path.computeMetrics()) {
      // Negative start offset scrolls dashes from `from` toward `to`.
      var d = -(phase % 1.0) * period;
      while (d < metric.length) {
        final start = math.max(0.0, d);
        final end = math.min(d + dash, metric.length);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), paint);
        }
        d += period;
      }
    }
  }

  // --- Points / markers ----------------------------------------------------

  void _paintPoint(Canvas canvas, MarkerOptions marker, double animValue) {
    final screen = projection.project(marker.position);
    if (screen == null) return; // behind the globe

    final baseR = marker.radius ?? 4.0;
    final color = marker.color ?? const Color(0xFF4F86F7);

    // Pulse ring (uses the same animation ticker as marching dashes)
    if (marker.pulse) {
      final maxR = marker.pulseMaxRadius ?? (baseR * 5.0).clamp(12.0, 30.0);
      final pulseR = baseR + animValue * (maxR - baseR);
      final pulseAlpha = (1.0 - animValue).clamp(0.0, 1.0) * 0.55;
      canvas.drawCircle(
        screen,
        pulseR,
        Paint()
          ..color = color.withValues(alpha: pulseAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..isAntiAlias = true,
      );
    }

    // Filled dot with white halo
    canvas.drawCircle(
      screen,
      baseR + 2,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(screen, baseR, Paint()..color = color);

    final label = marker.label;
    if (label != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(screen.dx - tp.width / 2, screen.dy - baseR - tp.height - 4),
      );
    }
  }

  List<double> _slerp(
      List<double> a, List<double> b, double t, double omega, double sinOmega) {
    if (sinOmega.abs() < 1e-6) return a;
    final w1 = math.sin((1 - t) * omega) / sinOmega;
    final w2 = math.sin(t * omega) / sinOmega;
    return [
      w1 * a[0] + w2 * b[0],
      w1 * a[1] + w2 * b[1],
      w1 * a[2] + w2 * b[2],
    ];
  }

  @override
  bool shouldRepaint(GlobeOverlayPainter old) =>
      old.projection != projection ||
      old.arcs != arcs ||
      old.markers != markers ||
      old.showDottedGrid != showDottedGrid ||
      old.dottedGridColor != dottedGridColor ||
      old.dottedGridRadius != dottedGridRadius ||
      old.heatmaps != heatmaps;
}

/// A soft glow ring around the globe silhouette. Drawn behind the sphere so only
/// the part outside the disc shows.
class AtmospherePainter extends CustomPainter {
  AtmospherePainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  final Offset center;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final glowRadius = radius * 1.22;
    final edge = radius / glowRadius; // where the globe silhouette sits
    final gradient = RadialGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0.45),
        color.withValues(alpha: 0),
      ],
      stops: [edge - 0.06, edge, 1.0],
    );
    final rect = Rect.fromCircle(center: center, radius: glowRadius);
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(AtmospherePainter old) =>
      old.center != center || old.radius != radius || old.color != color;
}
