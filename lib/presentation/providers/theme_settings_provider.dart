import 'package:flutter/material.dart';

class ThemeSettingsProvider extends ChangeNotifier {
  ThemeSettingsProvider._();

  static final ThemeSettingsProvider instance = ThemeSettingsProvider._();

  int _selectedColorIndex = 0;
  ThemeMode _themeMode = ThemeMode.system;

  int get selectedColorIndex => _selectedColorIndex;
  ThemeMode get themeMode => _themeMode;

  void setSelectedColorIndex(int index) {
    if (_selectedColorIndex == index) {
      return;
    }
    _selectedColorIndex = index;
    notifyListeners();
  }

  void setThemeMode(ThemeMode? mode) {
    ThemeMode newMode = mode ?? ThemeMode.system;
    if (_themeMode == newMode) {
      return;
    }
    _themeMode = newMode;
    notifyListeners();
  }
}
