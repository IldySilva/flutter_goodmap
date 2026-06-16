import 'package:flutter/material.dart';

import 'demo_data.dart';

/// The teardrop-style overlay marker for a [Poi]. Pure Flutter widget — this is
/// the default (interactive) marker path, anchored at its bottom tip.
class PoiPin extends StatelessWidget {
  const PoiPin({required this.poi, this.selected = false, super.key});

  final Poi poi;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scale = selected ? 1.15 : 1.0;
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 150),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: poi.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Icon(poi.icon, color: Colors.white, size: 18),
          ),
          // Little stem so the circle reads as a pin anchored at the bottom.
          Transform.translate(
            offset: const Offset(0, -2),
            child: Icon(Icons.arrow_drop_down, color: poi.color, size: 18),
          ),
        ],
      ),
    );
  }
}

/// The card shown in a popup when a [Poi] marker is tapped.
class PoiPopupCard extends StatelessWidget {
  const PoiPopupCard({required this.poi, required this.onClose, super.key});

  final Poi poi;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Lift the card above the marker tip it anchors to.
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 6,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: poi.color,
                  child: Icon(poi.icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(poi.name, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        poi.subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small pill label used for the live-marker tooltip.
class LiveBadge extends StatelessWidget {
  const LiveBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_boat, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
