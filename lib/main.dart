import 'package:mi_compra_mayorista/config/theme/app_theme.dart';
import 'package:mi_compra_mayorista/presentation/providers/theme_settings_provider.dart';
import 'package:mi_compra_mayorista/presentation/screens/home/home_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeSettings = ThemeSettingsProvider.instance;

    return AnimatedBuilder(
      animation: themeSettings,
      builder: (context, _) {
        final appTheme = AppTheme(
          selectedColorIndex: themeSettings.selectedColorIndex,
        );

        return MaterialApp(
          title: 'MiCompraMayorista',
          debugShowCheckedModeBanner: false,
          theme: appTheme.theme(brightness: Brightness.light),
          darkTheme: appTheme.theme(brightness: Brightness.dark),
          themeMode: themeSettings.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}