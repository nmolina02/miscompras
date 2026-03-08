import 'package:flutter/material.dart';

class AppColorThemeOption {
  final String name;
  final Color color;

  const AppColorThemeOption({
    required this.name,
    required this.color,
  });
}

const List<Color> _colorThemes = [
    Color(0xFF779ECB), // Azul claro
    Color(0xFF81C784), // Verde claro
    Color(0xFFFFB74D), // Naranja claro
    Color(0xFFEF9A9A), // Rojo claro
    Color(0xFF4DB6AC), // Teal claro
    Color(0xFF9575CD), // Púrpura claro
];

List<AppColorThemeOption> appColorThemes = [
  AppColorThemeOption(name: 'Azul', color: _colorThemes[0]),
  AppColorThemeOption(name: 'Verde', color: _colorThemes[1]),
  AppColorThemeOption(name: 'Naranja', color: _colorThemes[2]),
  AppColorThemeOption(name: 'Rojo', color: _colorThemes[3]),
  AppColorThemeOption(name: 'Teal', color: _colorThemes[4]),
  AppColorThemeOption(name: 'Púrpura', color: _colorThemes[5]),
];

class AppTheme {
  final int selectedColorIndex;

  AppTheme({
    this.selectedColorIndex = 0,
  }) : assert(selectedColorIndex >= 0 && selectedColorIndex < _colorThemes.length,
          'selectedColorIndex must be between 0 and ${_colorThemes.length - 1}');

  ThemeData theme({Brightness brightness = Brightness.light}) {
    final base = ColorScheme.fromSeed(
      seedColor: _colorThemes[selectedColorIndex],
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: base.copyWith(
        primary: _colorThemes[selectedColorIndex],
      ),
      useMaterial3: true,
      brightness: brightness,
    );
  }
}