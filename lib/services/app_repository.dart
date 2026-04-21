import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

const _storageKey = 'employa:v1';

class AppRepository {
  AppRepository._();

  static Future<AppStorage> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_storageKey);
    if (raw == null || raw.isEmpty) return AppStorage.empty();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AppStorage.fromJson(map);
    } catch (_) {
      return AppStorage.empty();
    }
  }

  static Future<void> save(AppStorage storage) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_storageKey, jsonEncode(storage.toJson()));
  }

  static Future<AppStorage> update(AppStorage Function(AppStorage prev) updater) async {
    final prev = await load();
    final next = updater(prev);
    await save(next);
    return next;
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_storageKey);
  }
}
