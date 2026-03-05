import 'package:flutter/material.dart';

class AppColorThemeOption {
  final String name;
  final Color color;

  const AppColorThemeOption({
    required this.name,
    required this.color,
  });
}

const List<AppColorThemeOption> appColorThemes = [
  AppColorThemeOption(name: 'Azul', color: Colors.blue),
  AppColorThemeOption(name: 'Amarillo', color: Colors.yellow),
  AppColorThemeOption(name: 'Teal', color: Colors.teal),
  AppColorThemeOption(name: 'Verde', color: Colors.green),
  AppColorThemeOption(name: 'Naranja', color: Colors.orange),
  AppColorThemeOption(name: 'Rosa', color: Colors.pink),
];

const List<Color> _colorThemes = [
  Colors.blue,
  Colors.yellow,
  Colors.teal,
  Colors.green,
  Colors.orange,
  Colors.pink,
];

class AppTheme {
  final int selectedColorIndex;

  AppTheme({
    this.selectedColorIndex = 0,
  }) : assert(selectedColorIndex >= 0 && selectedColorIndex < _colorThemes.length,
          'selectedColorIndex must be between 0 and ${_colorThemes.length - 1}');

  ThemeData theme({Brightness brightness = Brightness.light}) {
    return ThemeData(
      colorSchemeSeed: _colorThemes[selectedColorIndex],
      useMaterial3: true,
      brightness: brightness,
    );
  }
}