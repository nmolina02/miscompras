import 'package:mi_compra_mayorista/presentation/screens/actions/new_buying_screen/new_buying_screen.dart';
import 'package:mi_compra_mayorista/presentation/screens/actions/confirmation_buying_screen/confirmation_buying_screen.dart';
import 'package:mi_compra_mayorista/presentation/screens/actions/delete_buying_screen/delete_buying_screen.dart';
import 'package:mi_compra_mayorista/presentation/screens/actions/history_buying_screen/history_buying_screen.dart';
import 'package:flutter/material.dart';

// Pantalla de detalle para cada opción
class ActionsScreen extends StatelessWidget {
  final String actionName;

  const ActionsScreen({
    super.key,
    required this.actionName,
  });

  @override
  Widget build(BuildContext context) {
    switch (actionName) {
      case 'Nueva Compra':
        return const NuevaCompraScreen();
      case 'Confirmaciones Pendientes':
        return const ConfirmacionCompraScreen();
      case 'Historial de Compras':
        return const HistorialComprasScreen();
      case 'Eliminar Compra':
        return const EliminarCompraScreen();
      /*case 'Reportes / Estadísticas':
        return const ReportesEstadisticasScreen();*/
      default:
        return Scaffold(
          appBar: AppBar(
            title: Text(actionName),
            elevation: 0,
          ),
          body: Center(
            child: Text(
              'Contenido de $actionName',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
    }
  }
}