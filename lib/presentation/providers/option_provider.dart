import 'package:flutter/material.dart';

class OptionProvider extends ChangeNotifier {  
  // Opciones disponibles en la pantalla principal
  final List<String> _options = [
    'Nueva Compra',
    'Confirmaciones Pendientes',
    'Historial de Compras',
    'Eliminar Compra',
    'Reportes / Estadísticas',
    'Editar Productos',
  ];

  // Iconos para cada opción
  final List<IconData> _icons = const [
    Icons.add_shopping_cart_rounded,
    Icons.pending_actions_rounded,
    Icons.history_rounded,
    Icons.delete_rounded,
    Icons.bar_chart,
    Icons.edit_document,
  ];

  // Colores para cada opción (puedes personalizarlos según necesites)
  final List<Color> circleColors = const [
    Color(0xFF779ECB), // Azul claro
    Color(0xFF81C784), // Verde claro
    Color(0xFFFFB74D), // Naranja claro
    Color(0xFFEF9A9A), // Rojo claro
    Color(0xFF4DB6AC), // Teal claro
    Color(0xFF9575CD), // Púrpura claro
  ];

  List<String> get optionList => _options;

  IconData getIconForOption(String option) {
    final index = _options.indexOf(option);
    if (index != -1 && index < _icons.length) {
      return _icons[index];
    }
    return Icons.help_outline; // Icono por defecto si no se encuentra
  }

  Color getColorForOption(String option) {
    final index = _options.indexOf(option);
    if (index != -1 && index < circleColors.length) {
      return circleColors[index];
    }
    return Colors.grey; // Color por defecto si no se encuentra
  }
}
