import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App preferences, persisted on the device.
class SettingsService extends ChangeNotifier {
  static const _kTheme = 'settings.themeMode';
  static const _kLegacyDark = 'isDarkMode';
  static const _kTempUnit = 'tempUnit';
  static const notificationsKey = 'notificationsEnabled';

  ThemeMode _themeMode = ThemeMode.system;
  bool _fahrenheit = false;
  bool _notifications = true;

  ThemeMode get themeMode => _themeMode;
  bool get fahrenheit => _fahrenheit;
  bool get notificationsEnabled => _notifications;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kTheme);
    if (stored != null) {
      _themeMode = ThemeMode.values.firstWhere((m) => m.name == stored, orElse: () => ThemeMode.system);
    } else if (prefs.containsKey(_kLegacyDark)) {
      // Earlier versions only had an on/off dark mode switch.
      _themeMode = (prefs.getBool(_kLegacyDark) ?? false) ? ThemeMode.dark : ThemeMode.light;
    }
    _fahrenheit = prefs.getString(_kTempUnit) == 'Fahrenheit';
    _notifications = prefs.getBool(notificationsKey) ?? true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTheme, mode.name);
  }

  Future<void> setFahrenheit(bool value) async {
    _fahrenheit = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTempUnit, value ? 'Fahrenheit' : 'Celsius');
  }

  Future<void> setNotifications(bool value) async {
    _notifications = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notificationsKey, value);
  }

  /// Body temperature in the chosen unit, e.g. "36.8 °C".
  String formatTemp(double celsius, {bool unit = true}) {
    if (_fahrenheit) {
      final f = celsius * 9 / 5 + 32;
      return '${f.toStringAsFixed(1)}${unit ? ' °F' : ''}';
    }
    return '${celsius.toStringAsFixed(1)}${unit ? ' °C' : ''}';
  }

  String get tempUnitLabel => _fahrenheit ? '°F' : '°C';
}
