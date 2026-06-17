import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  static const _fixedKey = 'fixed_budget';
  static const _customLabelsKey = 'custom_labels';

  static SharedPreferences? _prefs;
  static Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  static Future<double> getFixed() async => (await _instance).getDouble(_fixedKey) ?? 0.0;
  static Future<void> setFixed(double v) async => (await _instance).setDouble(_fixedKey, v);

  static Future<List<String>> getCustomLabels() async =>
      (await _instance).getStringList(_customLabelsKey) ?? [];

  static Future<void> setCustomLabels(List<String> labels) async =>
      (await _instance).setStringList(_customLabelsKey, labels);

  // 清掉「固定預算」跟「自建標籤」這兩項本機設定
  // 用在登出/切換帳號時，避免下一個登入的帳號看到上一個帳號留下的設定
  static Future<void> clearAccountSpecificSettings() async {
    final prefs = await _instance;
    await prefs.remove(_fixedKey);
    await prefs.remove(_customLabelsKey);
  }
}