import 'package:miscompras/domain/entities/producto.dart';
import 'package:miscompras/domain/entities/ticket.dart';

class ItemTicket {
  final String id;
  final Ticket ticket;
  final Producto producto;
  final int cantidad;
  final String unidadMedida;
  final double precioUnitarioAplicado;
  final int cantidadDescuento;
  final double precioDescuento;

  ItemTicket({
    required this.id,
    required this.ticket,
    required this.producto,
    required this.cantidad,
    this.unidadMedida = 'unidad',
    required this.precioUnitarioAplicado,
    this.cantidadDescuento = 0,
    this.precioDescuento = 0.0,
  });

  @override
  String toString() {
    return 'ItemTicket(id: $id, ticketId: ${ticket.id}, producto: ${producto.nombre}, cantidad: $cantidad, unidadMedida: $unidadMedida, precioUnitarioAplicado: $precioUnitarioAplicado, cantidadDescuento: $cantidadDescuento, precioDescuento: $precioDescuento)';
  }
}