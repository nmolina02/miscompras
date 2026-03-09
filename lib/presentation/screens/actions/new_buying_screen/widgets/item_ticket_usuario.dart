import 'package:flutter/material.dart';

// Modelo para un item de producto
class ItemTicketUsuario {
  late TextEditingController nombreController;
  late TextEditingController codigoBarrasController;
  late TextEditingController rubroController;
  late TextEditingController precioController;
  late TextEditingController cantidadController;
  late TextEditingController cantidadDescuentoController;
  late TextEditingController precioDescuentoController;

  late FocusNode nombreFocusNode;
  late FocusNode rubroFocusNode;
  
  int cantidad;
  double precioUnitario;
  int cantidadDescuento;
  double precioDescuento;
  String codigoDeBarras;
  String rubro;
  String unidadMedida;
  bool esProductoSuelto;

  ItemTicketUsuario({
    String nombre = '',
    this.cantidad = 1,
    double precioUnitarioParametro = 0.0,
    this.cantidadDescuento = 0,
    double precioDescuentoParametro = 0.0,
    this.codigoDeBarras = '',
    this.rubro = '',
    this.unidadMedida = 'unidad',
    this.esProductoSuelto = false,
  }) : precioUnitario = precioUnitarioParametro,
       precioDescuento = precioDescuentoParametro {
    nombreController = TextEditingController(text: nombre);
    codigoBarrasController = TextEditingController(text: codigoDeBarras);
    rubroController = TextEditingController(text: rubro);
    precioController = TextEditingController(text: precioUnitario.toString());
    cantidadController = TextEditingController(text: cantidad.toString());
    cantidadDescuentoController = TextEditingController(text: cantidadDescuento.toString());
    precioDescuentoController = TextEditingController(text: precioDescuento.toString());
    nombreFocusNode = FocusNode();
    rubroFocusNode = FocusNode();
  }

  double get total {
    if (esProductoSuelto) {
      return precioUnitario;
    }
    if (cantidadDescuento > 0 && precioDescuento > 0 && cantidad >= cantidadDescuento) {
      return cantidad * precioDescuento;
    }
    return cantidad * precioUnitario;
  }

  void dispose() {
    nombreController.dispose();
    codigoBarrasController.dispose();
    rubroController.dispose();
    precioController.dispose();
    cantidadController.dispose();
    cantidadDescuentoController.dispose();
    precioDescuentoController.dispose();
    nombreFocusNode.dispose();
    rubroFocusNode.dispose();
  }
}