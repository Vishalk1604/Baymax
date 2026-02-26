import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal() {
    _loadSettings();
  }

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  String _tempUnit = 'Celsius'; // 'Celsius' or 'Fahrenheit'
  String get tempUnit => _tempUnit;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _tempUnit = prefs.getString('tempUnit') ?? 'Celsius';
    notifyListeners();
  }

  Future<void> toggleTheme(bool val) async {
    _isDarkMode = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', val);
    notifyListeners();
  }

  Future<void> setTempUnit(String unit) async {
    _tempUnit = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tempUnit', unit);
    notifyListeners();
  }

  String formatTemp(double celsius) {
    if (_tempUnit == 'Fahrenheit') {
      double f = (celsius * 9 / 5) + 32;
      return "${f.round()}°F";
    } else {
      return "${celsius.toStringAsFixed(1)}°C";
    }
  }
}
