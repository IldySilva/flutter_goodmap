// test/controls_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goodmap/src/controls/controls.dart';
import 'package:goodmap/src/theme/good_map_theme.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/mock_native_controller.dart';

void main() {
  setUpAll(registerGoodFallbacks);

  late MockMapLibreMapController native;
  late GoodMapTheme theme;

  setUp(() {
    native = MockMapLibreMapController();
    when(() => native.animateCamera(any())).thenAnswer((_) async => true);
    theme = GoodMapTheme.fromColorScheme(ColorScheme.fromSeed(seedColor: Colors.blue));
  });

  Future<void> pump(WidgetTester tester, GoodControls config) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GoodControlsView(native: native, config: config, theme: theme),
        ),
      ));

  testWidgets('zoom in/out buttons call animateCamera', (tester) async {
    await pump(tester, const GoodControls(zoom: true, compass: false));
    await tester.tap(find.byKey(const ValueKey('mapcn_zoom_in')));
    await tester.tap(find.byKey(const ValueKey('mapcn_zoom_out')));
    verify(() => native.animateCamera(any())).called(2);
  });

  testWidgets('compass button resets bearing', (tester) async {
    await pump(tester, const GoodControls(zoom: false, compass: true));
    await tester.tap(find.byKey(const ValueKey('mapcn_compass')));
    verify(() => native.animateCamera(any())).called(1);
  });

  testWidgets('hidden controls are not rendered', (tester) async {
    await pump(tester, const GoodControls(zoom: false, compass: false));
    expect(find.byKey(const ValueKey('mapcn_zoom_in')), findsNothing);
    expect(find.byKey(const ValueKey('mapcn_compass')), findsNothing);
  });
}
