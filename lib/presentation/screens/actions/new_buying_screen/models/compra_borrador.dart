import 'package:miscompras/presentation/screens/actions/new_buying_screen/widgets/item_ticket_usuario.dart';

class CompraBorrador {
  final String lugar;
  final List<ItemTicketBorrador> productos;

  const CompraBorrador({
    required this.lugar,
    required this.productos,
  });
}

class ItemTicketBorrador {
  final String nombre;
  final String codigoBarras;
  final String rubro;
  final String precioTexto;
  final int cantidad;
  final String unidadMedida;
  final String cantidadDescuentoTexto;
  final String precioDescuentoTexto;
  final bool esProductoSuelto;

  const ItemTicketBorrador({
    required this.nombre,
    required this.codigoBarras,
    required this.rubro,
    required this.precioTexto,
    required this.cantidad,
    required this.unidadMedida,
    required this.cantidadDescuentoTexto,
    required this.precioDescuentoTexto,
    required this.esProductoSuelto,
  });

  factory ItemTicketBorrador.fromItem(ItemTicketUsuario item) {
    return ItemTicketBorrador(
      nombre: item.nombreController.text,
      codigoBarras: item.codigoBarrasController.text,
      rubro: item.rubroController.text,
      precioTexto: item.precioController.text,
      cantidad: item.cantidad,
      unidadMedida: item.unidadMedida,
      cantidadDescuentoTexto: item.cantidadDescuentoController.text,
      precioDescuentoTexto: item.precioDescuentoController.text,
      esProductoSuelto: item.esProductoSuelto,
    );
  }

  ItemTicketUsuario toItem() {
    final item = ItemTicketUsuario(
      nombre: nombre,
      cantidad: cantidad,
      rubro: rubro,
      precioUnitarioParametro: double.tryParse(precioTexto) ?? 0.0,
      cantidadDescuento: int.tryParse(cantidadDescuentoTexto) ?? 0,
      precioDescuentoParametro: double.tryParse(precioDescuentoTexto) ?? 0.0,
      unidadMedida: unidadMedida,
      esProductoSuelto: esProductoSuelto,
    );

    item.codigoBarrasController.text = codigoBarras;
    item.rubroController.text = rubro;
    item.precioController.text = precioTexto;
    item.cantidadDescuentoController.text = cantidadDescuentoTexto;
    item.precioDescuentoController.text = precioDescuentoTexto;

    item.precioUnitario = double.tryParse(precioTexto) ?? 0.0;
    item.cantidadDescuento = int.tryParse(cantidadDescuentoTexto) ?? 0;
    item.precioDescuento = double.tryParse(precioDescuentoTexto) ?? 0.0;

    return item;
  }
}
