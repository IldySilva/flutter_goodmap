// lib/src/internal/registry.dart
import 'package:flutter/foundation.dart';

/// In-memory, id-keyed store with change notification. Pure Dart — no native deps.
class Registry<T> extends ChangeNotifier {
  final Map<int, T> _items = <int, T>{};
  int _nextId = 0;

  int add(T value) {
    final int id = _nextId++;
    _items[id] = value;
    notifyListeners();
    return id;
  }

  void update(int id, T value) {
    if (!_items.containsKey(id)) return;
    _items[id] = value;
    notifyListeners();
  }

  void remove(int id) {
    if (_items.remove(id) != null) notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }

  Map<int, T> get items => Map<int, T>.unmodifiable(_items);
}
