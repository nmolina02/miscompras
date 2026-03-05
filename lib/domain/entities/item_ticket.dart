import 'package:mi_compra_mayorista/domain/entities/producto.dart';
import 'package:mi_compra_mayorista/domain/entities/ticket.dart';

class ItemTicket {
  final String id;
  final Ticket ticket;
  final Producto producto;
  final int cantidad;
  final double precioUnitarioAplicado;
  final int cantidadDescuento;
  final double precioDescuento;

  ItemTicket({
    required this.id,
    required this.ticket,
    required this.producto,
    required this.cantidad,
    required this.precioUnitarioAplicado,
    this.cantidadDescuento = 0,
    this.precioDescuento = 0.0,
  });

  @override
  String toString() {
    return 'ItemTicket(id: $id, ticketId: ${ticket.id}, producto: ${producto.nombre}, cantidad: $cantidad, precioUnitarioAplicado: $precioUnitarioAplicado, cantidadDescuento: $cantidadDescuento, precioDescuento: $precioDescuento)';
  }
}