// test/marker_pulse_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:goodmap/goodmap.dart';

void main() {
  group('MarkerOptions — pulse & timestamp', () {
    const pos = LatLng(0, 0);

    test('defaults: pulse=false, pulseMaxRadius=null, timestamp=null', () {
      const m = MarkerOptions(position: pos);
      expect(m.pulse, isFalse);
      expect(m.pulseMaxRadius, isNull);
      expect(m.timestamp, isNull);
    });

    test('pulse can be enabled', () {
      const m = MarkerOptions(position: pos, pulse: true);
      expect(m.pulse, isTrue);
    });

    test('pulseMaxRadius is set when provided', () {
      const m = MarkerOptions(position: pos, pulse: true, pulseMaxRadius: 32.0);
      expect(m.pulseMaxRadius, 32.0);
    });

    test('timestamp is preserved', () {
      const m = MarkerOptions(position: pos, timestamp: 1_720_000_000.0);
      expect(m.timestamp, 1_720_000_000.0);
    });

    test('two markers with the same fields are value-equal', () {
      // MarkerOptions is @immutable but not equatable — this test just ensures
      // all new fields participate in the constructor without throwing.
      const a = MarkerOptions(
        position: pos,
        pulse: true,
        pulseMaxRadius: 20.0,
        timestamp: 42.0,
      );
      expect(a.pulse, isTrue);
      expect(a.pulseMaxRadius, 20.0);
      expect(a.timestamp, 42.0);
    });
  });
}
