import 'package:mi_compra_mayorista/presentation/screens/actions/new_buying_screen/widgets/item_ticket_usuario.dart';

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
  final String cantidadDescuentoTexto;
  final String precioDescuentoTexto;

  const ItemTicketBorrador({
    required this.nombre,
    required this.codigoBarras,
    required this.rubro,
    required this.precioTexto,
    required this.cantidad,
    required this.cantidadDescuentoTexto,
    required this.precioDescuentoTexto,
  });

  factory ItemTicketBorrador.fromItem(ItemTicketUsuario item) {
    return ItemTicketBorrador(
      nombre: item.nombreController.text,
      codigoBarras: item.codigoBarrasController.text,
      rubro: item.rubroController.text,
      precioTexto: item.precioController.text,
      cantidad: item.cantidad,
      cantidadDescuentoTexto: item.cantidadDescuentoController.text,
      precioDescuentoTexto: item.precioDescuentoController.text,
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
