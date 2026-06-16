// test/registry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:goodmap/src/internal/registry.dart';

void main() {
  test('add returns incrementing ids and stores values', () {
    final r = Registry<String>();
    expect(r.add('a'), 0);
    expect(r.add('b'), 1);
    expect(r.items, {0: 'a', 1: 'b'});
  });

  test('update replaces an existing value', () {
    final r = Registry<String>();
    final id = r.add('a');
    r.update(id, 'z');
    expect(r.items[id], 'z');
  });

  test('update with unknown id is a no-op', () {
    final r = Registry<String>();
    r.update(99, 'z'); // must not throw
    expect(r.items, isEmpty);
  });

  test('remove deletes; unknown id is a no-op', () {
    final r = Registry<String>();
    final id = r.add('a');
    r.remove(id);
    r.remove(99); // must not throw
    expect(r.items, isEmpty);
  });

  test('clear empties the registry', () {
    final r = Registry<String>()..add('a')..add('b');
    r.clear();
    expect(r.items, isEmpty);
  });

  test('items snapshot is unmodifiable', () {
    final r = Registry<String>()..add('a');
    expect(() => r.items[5] = 'x', throwsUnsupportedError);
  });

  test('notifies listeners on mutation only when state changes', () {
    final r = Registry<String>();
    var count = 0;
    r.addListener(() => count++);
    final id = r.add('a'); // +1
    r.update(id, 'b');     // +1
    r.update(99, 'x');     // no change, no notify
    r.remove(99);          // no change, no notify
    r.remove(id);          // +1
    r.clear();             // already empty, no notify
    expect(count, 3);
  });
}
