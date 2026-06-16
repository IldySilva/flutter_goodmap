import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import 'sphere_projection.dart';

/// A labelled point plotted on the globe.
@immutable
class GlobePoint {
  const GlobePoint({
    required this.coordinate,
    this.label,
    this.color = const Color(0xFF4F86F7),
    this.radius = 4,
  });

  final LatLng coordinate;
  final String? label;
  final Color color;
  final double radius;
}

/// A great-circle arc between two coordinates, bowing off the globe surface.
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
  });

  final LatLng from;
  final LatLng to;
  final Color color;
  final double width;
  final bool dashed;

  /// How far the arc lifts off the surface at its midpoint (fraction of radius).
  final double bend;
  final int segments;
}

/// Paints arcs, points and labels over the globe, hiding anything on the far
/// hemisphere. Re-created each frame with the current [projection].
class GlobeOverlayPainter extends CustomPainter {
  GlobeOverlayPainter({
    required this.projection,
    required this.arcs,
    required this.points,
  });

  final SphereProjection projection;
  final List<GlobeArc> arcs;
  final List<GlobePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    for (final arc in arcs) {
      _paintArc(canvas, arc);
    }
    for (final point in points) {
      _paintPoint(canvas, point);
    }
  }

  void _paintArc(Canvas canvas, GlobeArc arc) {
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
        _strokePath(canvas, run, paint, arc.dashed);
        run = null;
      }
    }
    if (run != null) _strokePath(canvas, run, paint, arc.dashed);
  }

  void _strokePath(Canvas canvas, Path path, Paint paint, bool dashed) {
    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  void _paintPoint(Canvas canvas, GlobePoint point) {
    final screen = projection.project(point.coordinate);
    if (screen == null) return; // behind the globe

    canvas.drawCircle(
      screen,
      point.radius + 2,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(screen, point.radius, Paint()..color = point.color);

    final label = point.label;
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
        Offset(screen.dx - tp.width / 2, screen.dy - point.radius - tp.height - 4),
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
      old.points != points;
}
