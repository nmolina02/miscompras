import 'comercio.dart';
import 'item_ticket.dart';

class Ticket {
  final String id;
  final Comercio comercio;
  final DateTime fecha;
  final double importeTotal;
  double recargoAplicado = 0.0;
  double importeRealPagado = 0.0;
  int confirmacionStatus = 0; // 0: Pendiente, 1: Confirmado
  final List<ItemTicket> items;

  Ticket({
    required this.id,
    required this.comercio,
    required this.fecha,
    required this.importeTotal,
    this.recargoAplicado = 0.0,
    this.importeRealPagado = 0.0,
    this.confirmacionStatus = 0,
    required this.items,
  });

  @override
  String toString() {
    return 'Ticket{id: $id, comercio: ${comercio.nombre}, fecha: $fecha, importeTotal: $importeTotal, recargoAplicado: $recargoAplicado, importeRealPagado: $importeRealPagado, confirmacionStatus: $confirmacionStatus, items: $items}';
  }
}