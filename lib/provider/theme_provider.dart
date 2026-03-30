import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      // We can't immediately know the system brightness here without a context, 
      // but the UI handles 'system' natively. For the explicit toggle check, we'll return false 
      // or just rely on the UI's context.brightness.
      return false; 
    }
    return _themeMode == ThemeMode.dark;
  }

  void _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('tm_is_dark');
    if (isDark != null) {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  void toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else {
      // If system, explicitly set the opposite of what the system is currently showing.
      // Easiest is to force dark mode.
      _themeMode = ThemeMode.dark;
    }

    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tm_is_dark', _themeMode == ThemeMode.dark);
  }
}
