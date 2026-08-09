import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStore {
  static const _key = 'portless.favorites.ports';

  Future<Set<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    return list.map(int.parse).toSet();
  }

  Future<void> save(Set<int> ports) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = ports.toList()..sort();
    await prefs.setStringList(_key, sorted.map((e) => '$e').toList());
  }

  Future<Set<int>> toggle(int port) async {
    final current = await load();
    if (current.contains(port)) {
      current.remove(port);
    } else {
      current.add(port);
    }
    await save(current);
    return current;
  }
}
