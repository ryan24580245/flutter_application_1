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
}