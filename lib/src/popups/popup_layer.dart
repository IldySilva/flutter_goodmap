// lib/src/popups/popup_layer.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../good_map_controller.dart' show OverlayEntryData;

/// Projects geographically-anchored overlay entries onto screen offsets and
/// positions each in the enclosing [Stack]. Re-projects whenever [entries] or
/// [cameraVersion] changes. Off-screen entries are placed far out of view
/// rather than removed, to avoid flicker during gestures.
class GoodOverlayLayer extends StatefulWidget {
  const GoodOverlayLayer({
    required this.native,
    required this.entries,
    required this.cameraVersion,
    super.key,
  });

  final MapLibreMapController native;
  final List<OverlayEntryData> entries;
  final int cameraVersion;

  @override
  State<GoodOverlayLayer> createState() => _GoodOverlayLayerState();
}

class _GoodOverlayLayerState extends State<GoodOverlayLayer> {
  Map<Object, Offset> _offsets = <Object, Offset>{};

  @override
  void initState() {
    super.initState();
    _reproject();
  }

  @override
  void didUpdateWidget(GoodOverlayLayer old) {
    super.didUpdateWidget(old);
    if (old.cameraVersion != widget.cameraVersion ||
        old.entries != widget.entries) {
      _reproject();
    }
  }

  Future<void> _reproject() async {
    final next = <Object, Offset>{};
    for (final e in widget.entries) {
      final Point<num> p = await widget.native.toScreenLocation(e.position);
      next[e.key] = Offset(p.x.toDouble(), p.y.toDouble());
    }
    if (mounted) setState(() => _offsets = next);
  }

  // Fraction of child size to shift so [alignment] sits on the screen offset.
  Offset _anchorFraction(Alignment a) => Offset(-(a.x + 1) / 2, -(a.y + 1) / 2);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final e in widget.entries)
          if (_offsets.containsKey(e.key))
            Positioned(
              left: _offsets[e.key]!.dx,
              top: _offsets[e.key]!.dy,
              child: FractionalTranslation(
                translation: _anchorFraction(e.alignment),
                child: e.onTap == null
                    ? e.child
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: e.onTap,
                        child: e.child,
                      ),
              ),
            ),
      ],
    );
  }
}
