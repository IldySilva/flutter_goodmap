// test/globe_arc_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:goodmap/goodmap.dart';

void main() {
  const london = LatLng(51.5, -0.1);
  const paris = LatLng(48.9, 2.35);

  group('GlobeArc — drawProgress & timestamp', () {
    test('defaults: drawProgress=1.0, timestamp=null', () {
      const arc = GlobeArc(from: london, to: paris);
      expect(arc.drawProgress, 1.0);
      expect(arc.timestamp, isNull);
    });

    test('drawProgress can be set to partial value', () {
      const arc = GlobeArc(from: london, to: paris, drawProgress: 0.5);
      expect(arc.drawProgress, 0.5);
    });

    test('drawProgress at 0 represents an empty arc', () {
      const arc = GlobeArc(from: london, to: paris, drawProgress: 0.0);
      expect(arc.drawProgress, 0.0);
    });

    test('timestamp is stored', () {
      const arc = GlobeArc(from: london, to: paris, timestamp: 3600.0);
      expect(arc.timestamp, 3600.0);
    });

    test('existing fields still work', () {
      const arc = GlobeArc(
        from: london,
        to: paris,
        dashed: false,
        width: 3.0,
        bend: 0.5,
        segments: 36,
      );
      expect(arc.dashed, isFalse);
      expect(arc.width, 3.0);
      expect(arc.bend, 0.5);
      expect(arc.segments, 36);
    });
  });
}
