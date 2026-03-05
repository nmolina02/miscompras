import 'package:flutter/material.dart';

class OptionProvider extends ChangeNotifier {  
  // Opciones disponibles en la pantalla principal
  final List<String> _options = [
    'Nueva Compra',
    'Confirmaciones Pendientes',
    'Historial de Compras',
    'Eliminar Compra',
    'Reportes / Estadísticas',
  ];

  // Iconos para cada opción
  final List<IconData> _icons = const [
    Icons.add_shopping_cart,
    Icons.pending_actions,
    Icons.history,
    Icons.delete,
    Icons.bar_chart,
  ];

  // Colores para cada opción (puedes personalizarlos según necesites)
  final List<Color> circleColors = const [
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.red,
    Colors.teal,
    Colors.purple,
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
