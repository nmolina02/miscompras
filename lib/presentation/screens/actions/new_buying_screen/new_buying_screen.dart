import 'package:miscompras/data/local/item_ticket_repository.dart';
import 'package:miscompras/data/local/producto_repository.dart';
import 'package:miscompras/data/local/compra_repository.dart';
import 'package:miscompras/data/local/comercio_repository.dart';
import 'package:miscompras/presentation/screens/actions/new_buying_screen/widgets/item_ticket_usuario.dart';
import 'package:miscompras/presentation/screens/actions/new_buying_screen/barcode_scanner_page.dart';
import 'package:miscompras/presentation/screens/actions/new_buying_screen/models/compra_borrador.dart';
import 'package:miscompras/presentation/screens/actions/new_buying_screen/widgets/lugar_compra_field.dart';
import 'package:miscompras/presentation/screens/actions/new_buying_screen/widgets/producto_ticket_card.dart';
import 'package:miscompras/presentation/screens/actions/new_buying_screen/widgets/producto_suelto_ticket_card.dart';
import 'package:miscompras/presentation/screens/actions/new_buying_screen/widgets/resumen_compra_footer.dart';
import 'package:flutter/material.dart';

class NuevaCompraScreen extends StatefulWidget {
  const NuevaCompraScreen({
    super.key,
  });

  @override
  State<NuevaCompraScreen> createState() => _NuevaCompraScreenState();
}

class _NuevaCompraScreenState extends State<NuevaCompraScreen> {
  final CompraRepository _compraRepository = CompraRepository.instance; // Es ticket_repository
  final ComercioRepository _comercioRepository = ComercioRepository.instance;
  final ProductoRepository _productoRepository = ProductoRepository.instance;
  final ItemTicketRepository _itemTicketRepository = ItemTicketRepository.instance;

  static CompraBorrador? _compraBorrador;

  late TextEditingController _lugarController;
  late FocusNode _lugarFocusNode;

  List<String> _historialLugares = [];
  List<String> _lugaresFiltrados = [];

  List<ItemTicketUsuario> _productos = [];
  int? _productoExpandidoIndex;

  List<ItemTicketUsuario> _historialProductos = [];
  List<ItemTicketUsuario> _productosFiltrados = [];

  List<String> _historialRubros = [];
  List<String> _rubrosFiltrados = [];
  final Set<ItemTicketUsuario> _nombreProductoSueltoTocado = <ItemTicketUsuario>{};
  final Set<ItemTicketUsuario> _codigoProductoValidado = <ItemTicketUsuario>{};
  final Set<ItemTicketUsuario> _codigoProductoEscaneado = <ItemTicketUsuario>{};

  @override
  void initState() {
    super.initState();
    _lugarController = TextEditingController();
    _lugarFocusNode = FocusNode();
    _lugaresFiltrados = [];
    _productosFiltrados = [];
    _rubrosFiltrados = [];
    _restaurarBorrador();
    _cargarInfoInicial();
  }

  Future<void> _cargarInfoInicial() async {
    // Carga comercios para autocompletar el campo de lugar de compra
    // Carga productos para autocompletar el campo de nombre de producto
    // Carga rubros para autocompletar el campo de rubro

    final comercios = await _comercioRepository.list();
    final productos = await _productoRepository.list();
    final rubros = await _compraRepository.rubroRepository.list();

    if (!mounted) return;

    setState(() {
      _historialLugares = comercios.map((c) => c.nombre).toList();
      _historialProductos = productos
          .map(
            (p) => ItemTicketUsuario(
              nombre: p.nombre,
              codigoDeBarras: p.codigoDeBarras,
              esProductoSuelto: _esCodigoProductoSuelto(p.codigoDeBarras),
            ),
          )
          .toList();
      _historialRubros = rubros.map((r) => r.nombre).toList();
    });
  }

  @override
  void dispose() {
    _guardarBorrador();
    _lugarController.dispose();
    _lugarFocusNode.dispose();
    for (var producto in _productos) {
      producto.dispose();
    }
    super.dispose();
  }

  void _filtrarLugares(String query) {
    setState(() {
      if (query.isEmpty) {
        _lugaresFiltrados = _historialLugares;
      } else {
        _lugaresFiltrados = _historialLugares
            .where((lugar) => lugar.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
    _guardarBorrador();
  }

  bool _esCodigoProductoSuelto(String codigo) {
    final codigoLimpio = codigo.trim();
    return codigoLimpio.length >= 21 && RegExp(r'^\d+$').hasMatch(codigoLimpio);
  }

  List<ItemTicketUsuario> _obtenerHistorialProductosPorTipo({
    required bool esProductoSuelto,
  }) {
    return _historialProductos
        .where((producto) => producto.esProductoSuelto == esProductoSuelto)
        .toList();
  }

  void _filtrarProductos(String query, {required bool esProductoSuelto}) {
    final historialFiltrado = _obtenerHistorialProductosPorTipo(
      esProductoSuelto: esProductoSuelto,
    );

    setState(() {
      if (query.isEmpty) {
        _productosFiltrados = historialFiltrado;
      } else {
        _productosFiltrados = historialFiltrado
            .where(
              (producto) => producto.nombreController.text
                  .toLowerCase()
                  .contains(query.toLowerCase()),
            )
            .toList();
      }
    });
    _guardarBorrador();
  }

  void _filtrarRubros(String query) {
    setState(() {
      if (query.isEmpty) {
        _rubrosFiltrados = _historialRubros;
      } else {
        _rubrosFiltrados = _historialRubros
            .where((rubro) => rubro.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
    _guardarBorrador();
  }

  void _agregarProducto() {
    setState(() {
      final nuevoProducto = ItemTicketUsuario();
      _productos.add(nuevoProducto);
      _productoExpandidoIndex = _productos.length - 1;
    });
    _guardarBorrador();
  }

  void _agregarProductoSuelto() {
    setState(() {
      _productos.add(ItemTicketUsuario(esProductoSuelto: true));
      _productoExpandidoIndex = _productos.length - 1;
    });
    _guardarBorrador();
  }

  bool _tieneInfoCargadaProductoSuelto(ItemTicketUsuario producto) {
    final tieneCodigo = producto.codigoBarrasController.text.trim().isNotEmpty;
    final tieneRubro = producto.rubroController.text.trim().isNotEmpty;
    final tienePrecio = producto.precioUnitario > 0;
    final tieneDescuento = producto.cantidadDescuento > 0 || producto.precioDescuento > 0;
    final tieneUnidadDistinta = producto.unidadMedida.trim().isNotEmpty && producto.unidadMedida.trim().toLowerCase() != 'unidad';
    return tieneCodigo || tieneRubro || tienePrecio || tieneDescuento || tieneUnidadDistinta;
  }

  void _limpiarInfoCargadaProductoSuelto(ItemTicketUsuario producto) {
    producto.codigoBarrasController.clear();
    producto.codigoDeBarras = '';
    producto.rubroController.clear();
    producto.rubro = '';
    producto.unidadMedida = 'unidad';
    producto.precioUnitario = 0.0;
    producto.precioController.text = '0';
    producto.cantidadDescuento = 0;
    producto.cantidadDescuentoController.text = '0';
    producto.precioDescuento = 0.0;
    producto.precioDescuentoController.text = '0';
  }

  Future<bool> _confirmarEdicionNombreProductoSuelto(ItemTicketUsuario producto) async {
    if (!_nombreProductoSueltoTocado.contains(producto)) {
      _nombreProductoSueltoTocado.add(producto);
      return true;
    }

    if (!_tieneInfoCargadaProductoSuelto(producto)) {
      return true;
    }

    final confirma = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cambiar nombre del producto'),
          content: const Text(
            'Si cambia el nombre, se borrará la información cargada de este producto. ¿Desea continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirma == true) {
      setState(() {
        _limpiarInfoCargadaProductoSuelto(producto);
      });
      _guardarBorrador();
      return true;
    }

    producto.nombreFocusNode.unfocus();
    return false;
  }

  Future<void> _autocompletarCodigoDeBarrasParaProductoSuelto(ItemTicketUsuario producto) async {
    // Los códigos de barras genéricos para productos sueltos se completan en base a un diccionario definido por el sistema.
    // Se arma el código a partir del nombre del producto y se rellena con ceros a la izquierda hasta 21 dígitos.

    final abecedario = {
      'A': '0',
      'B': '1',
      'C': '2',
      'D': '3',
      'E': '4',
      'F': '5',
      'G': '6',
      'H': '7',
      'I': '8',
      'J': '9',
      'K': '10',
      'L': '11',
      'M': '12',
      'N': '13',
      'Ñ': '14',
      'O': '15',
      'P': '16',
      'Q': '17',
      'R': '18',
      'S': '19',
      'T': '20',
      'U': '21',
      'V': '22',
      'W': '23',
      'X': '24',
      'Y': '25',
      'Z': '26',
    };

    try {
      final nombreProducto = producto.nombreController.text.trim();
      if (nombreProducto.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complete el nombre del producto antes de autogenerar el código de barras.')),
        );
        return;
      }

      final nombreNormalizado = nombreProducto
          .toUpperCase()
          .replaceAll('Á', 'A')
          .replaceAll('É', 'E')
          .replaceAll('Í', 'I')
          .replaceAll('Ó', 'O')
          .replaceAll('Ú', 'U')
          .replaceAll('Ü', 'U');

      final buffer = StringBuffer();
      for (final caracter in nombreNormalizado.split('')) {
        final codigo = abecedario[caracter];
        if (codigo != null) {
          buffer.write(codigo);
        }
      }

      final codigoBase = buffer.toString();
      if (codigoBase.isEmpty) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El nombre ingresado no contiene letras válidas para generar el código.')),
        );
        return;
      }

      final codigoFinal = codigoBase.length >= 21 ? codigoBase : codigoBase.padLeft(21, '0');

      setState(() {
        producto.codigoBarrasController.text = codigoFinal;
      });
      _guardarBorrador();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo generar el codigo del producto suelto.')),
      );
    }
  }

  void _eliminarProducto(int index) {
    setState(() {
      final producto = _productos[index];
      _nombreProductoSueltoTocado.remove(producto);
      _codigoProductoValidado.remove(producto);
      _codigoProductoEscaneado.remove(producto);
      _productos.removeAt(index);

      if (_productos.isEmpty) {
        _productoExpandidoIndex = null;
      } else if (_productoExpandidoIndex == index) {
        _productoExpandidoIndex = (index - 1).clamp(0, _productos.length - 1);
      } else if (_productoExpandidoIndex != null && _productoExpandidoIndex! > index) {
        _productoExpandidoIndex = _productoExpandidoIndex! - 1;
      }
    });
    _guardarBorrador();
  }

  void _restaurarBorrador() {
    final borrador = _compraBorrador;
    if (borrador == null) {
      return;
    }

    _lugarController.text = borrador.lugar;
    _productos = borrador.productos.map((item) => item.toItem()).toList();
    _codigoProductoValidado.clear();
    _codigoProductoEscaneado.clear();
    _productoExpandidoIndex = _productos.isNotEmpty ? _productos.length - 1 : null;
  }

  void _guardarBorrador() {
    _compraBorrador = CompraBorrador(
      lugar: _lugarController.text,
      productos: _productos.map(ItemTicketBorrador.fromItem).toList(),
    );
  }

  Future<void> _confirmarCancelarCompra() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancelar compra'),
          content: const Text('Se borrará toda la compra cargada. ¿Querés continuar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, cancelar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      _cancelarCompraCompleta();
    }
  }

  void _cancelarCompraCompleta() {
    _compraBorrador = null;

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Su compra ha sido cancelada exitosamente'),
        duration: Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      _limpiarCompraActual();
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<bool> _confirmarCambioDeLugar() async{
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Borrar compra actual'),
          content: const Text('Se borrarán los productos cargados. ¿Querés continuar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, borrar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) {
          return;
        }
        _limpiarCompraActual();
      });
    }
    
    return confirmar == true; 
  }

  double _calcularTotal() {
    return _productos.fold(0.0, (sum, item) => sum + item.total);
  }

  bool _tieneComercioValido() {
    return _lugarController.text.trim().isNotEmpty;
  }

  bool _tienenCodigoDeBarras() {
    return _productos.every((item) => item.codigoBarrasController.text.trim().isNotEmpty);
  }

  bool _tienenNombre() {
    return _productos.every((item) => item.nombreController.text.trim().isNotEmpty);
  }

  bool _codigosProductosNormalesValidados() {
    return _productos
        .where((item) => !item.esProductoSuelto)
        .every((item) => _codigoProductoValidado.contains(item) || _codigoProductoEscaneado.contains(item));
  }

  bool _puedeFinalizarCompra() {
    return _productos.isNotEmpty &&
        _tieneComercioValido() &&
        _tienenCodigoDeBarras() &&
        _tienenNombre() &&
        _codigosProductosNormalesValidados() &&
        _productos.every((item) => item.total > 0);
  }

  Future<void> _confirmarFinalizarCompra() async {
    if (!_tieneComercioValido()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe completar el comercio donde compró.'),
        ),
      );
      return;
    }

    if (_calcularTotal() <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El monto total debe ser mayor a 0.'),
        ),
      );
      return;
    }

    if (!_codigosProductosNormalesValidados()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe validar con la tilde cada código de barras ingresado manualmente.'),
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Finalizar compra'),
          content: const Text('¿Confirma que desea finalizar la compra?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, finalizar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      await _finalizarCompraCompleta();
    }
  }

  Future<void> _finalizarCompraCompleta() async {
    final bool compraGuardada = await _guardarCompraEnDispositivo();
    if (!compraGuardada) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la compra en el dispositivo.'),
        ),
      );
      return;
    }

    _compraBorrador = null;

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compra finalizada exitosamente'),
        duration: Duration(seconds: 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      _limpiarCompraActual();
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  Future<bool> _guardarCompraEnDispositivo() async {
    final payload = {
      'comercio': _lugarController.text.trim(),
      'fecha': DateTime.now().toIso8601String(),
      'importe_total': _calcularTotal(),
      'items': _productos
          .map(
            (item) => {
              'codigo_barras': item.codigoBarrasController.text.trim(),
              'nombre': item.nombreController.text.trim(),
              'rubro': item.rubroController.text.trim(),
              'cantidad': item.cantidad,
                'unidad_medida': item.esProductoSuelto
                  ? item.unidadMedida.trim().isEmpty
                    ? 'unidad'
                    : item.unidadMedida.trim()
                  : 'unidad',
              'precio_unitario': item.precioUnitario,
              'cantidad_descuento': item.cantidadDescuento,
              'precio_descuento': item.precioDescuento,
              'total_item': item.total,
            },
          )
          .toList(),
    };

    try {
      return await _compraRepository.guardarCompra(
        comercio: payload['comercio'] as String,
        fecha: payload['fecha'] as String,
        importeTotal: payload['importe_total'] as double,
        items: (payload['items'] as List<dynamic>).cast<Map<String, dynamic>>(),
      );
    } catch (_) {
      return false;
    }
  }

  void _limpiarCompraActual() {
    setState(() {
      for (final producto in _productos) {
        producto.dispose();
      }

      _productos = [];
      _nombreProductoSueltoTocado.clear();
      _codigoProductoValidado.clear();
      _codigoProductoEscaneado.clear();
      _productoExpandidoIndex = null;
      _productosFiltrados = [];
      _lugaresFiltrados = [];
      _lugarController.clear();
      _lugarFocusNode.unfocus();
    });
  }

  Future<String?> _buscarNombreProductoPorCodigo(String codigo) async {
    return _compraRepository.buscarNombreProductoPorCodigo(codigo);
  }

  Future<void> _escanearProducto(ItemTicketUsuario producto, int index, String lugar) async {
    setState(() {
      _productoExpandidoIndex = index;
    });

    final String? code = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerPage(),
      ),
    );

    if (code == null || code.isEmpty) {
      return;
    }

    await _setearNombreProducto(producto, code, lugar, vieneDeEscaneo: true);
  }

  Future<void> _setearNombreProducto(
    ItemTicketUsuario producto,
    String code,
    String lugar, {
    required bool vieneDeEscaneo,
  }) async {
    setState(() {
      producto.codigoBarrasController.text = code;
    });

    String? nombre;
    try {
      nombre = await _buscarNombreProductoPorCodigo(code);
    } catch (_) {
      nombre = null;

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo buscar el producto por código de barras.'),
        ),
      );
      return;
    }

    await _cargarUltimaInfoProducto(producto, lugar);

    setState(() {
      if (nombre != null) {
        producto.nombreController.text = nombre;
      }

      _codigoProductoValidado.remove(producto);
      _codigoProductoEscaneado.remove(producto);
      if (vieneDeEscaneo) {
        _codigoProductoEscaneado.add(producto);
      } else if (nombre != null) {
        _codigoProductoValidado.add(producto);
      }
    });

    if (!mounted) {
      return;
    }

    if (nombre == null || nombre == 'Product Not Found — Go-UPC') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El código de barras ingresado no corresponde a un producto válido.'),
        ),
      );
    }

    _guardarBorrador();
  }

  Future<void> _cargarUltimaInfoProducto(ItemTicketUsuario producto, String lugar) async {
    final productoHistorial = await _itemTicketRepository
        .getItemTicketUsuarioByCodigoDeBarras(producto.codigoBarrasController.text.trim(), lugar);

    if (productoHistorial == null || !mounted) {
      return;
    }

    setState(() {
      if (productoHistorial.nombreController.text.isNotEmpty) {
        producto.nombreController.text = productoHistorial.nombreController.text;
      }

      if (productoHistorial.rubroController.text.isNotEmpty) {
        producto.rubroController.text = productoHistorial.rubroController.text;
      }

      producto.unidadMedida = productoHistorial.unidadMedida.trim().isEmpty
          ? 'unidad'
          : productoHistorial.unidadMedida;

      if (productoHistorial.precioController.text.isNotEmpty) {
        producto.precioUnitario = double.tryParse(productoHistorial.precioController.text) ?? 0.0;
        producto.precioController.text = producto.precioUnitario.toString();
      }

      if (productoHistorial.cantidadDescuentoController.text.isNotEmpty) {
        producto.cantidadDescuento = int.tryParse(productoHistorial.cantidadDescuentoController.text) ?? 0;
        producto.cantidadDescuentoController.text = producto.cantidadDescuento.toString();
      }

      if (productoHistorial.precioDescuentoController.text.isNotEmpty) {
        producto.precioDescuento = double.tryParse(productoHistorial.precioDescuentoController.text) ?? 0.0;
        producto.precioDescuentoController.text = producto.precioDescuento.toString();
      }

      _nombreProductoSueltoTocado.remove(producto);
    });

    _guardarBorrador();
  }

  @override
  Widget build(BuildContext context) {
    String lugarSeleccionado = _lugarController.text.trim();
    final tecladoVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Compra'),
        elevation: 0,
      ),
      body: Column(
        children: [
          LugarCompraField(
            controller: _lugarController,
            focusNode: _lugarFocusNode,
            lugaresFiltrados: _lugaresFiltrados,
            historialLugares: _historialLugares,
            onChanged: _filtrarLugares,
            onTap: () async {
              if (_lugarController.text.isEmpty) {
                setState(() {
                  _lugaresFiltrados = _historialLugares;
                });
              }
              else{
                await _confirmarCambioDeLugar();
              }
            },
            onSelectLugar: (lugar) {
              _lugarController.text = lugar;
              lugarSeleccionado = lugar;
              _lugarFocusNode.unfocus();
              setState(() {
                _lugaresFiltrados = [];
              });
              _guardarBorrador();
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: _productos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No hay productos agregados',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _productos.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final producto = _productos[index];
                      if (producto.esProductoSuelto) {
                        return ProductoSueltoTicketCard(
                          producto: producto,
                          index: index,
                          estaExpandido: _productoExpandidoIndex == index,
                          productosFiltrados: _productosFiltrados,
                          historialProductos: _obtenerHistorialProductosPorTipo(esProductoSuelto: true),
                          rubrosFiltrados: _rubrosFiltrados,
                          historialRubros: _historialRubros,
                          onExpand: () {
                            setState(() {
                              _productoExpandidoIndex = index;
                              _productosFiltrados = [];
                              _rubrosFiltrados = [];
                            });
                          },
                          onCollapse: () {
                            setState(() {
                              _productoExpandidoIndex = null;
                              _productosFiltrados = [];
                              _rubrosFiltrados = [];
                            });
                          },
                          onScaleProduct: () async {
                            await _autocompletarCodigoDeBarrasParaProductoSuelto(producto);
                          },
                          onDelete: () {
                            _nombreProductoSueltoTocado.remove(producto);
                            producto.dispose();
                            _eliminarProducto(index);
                          },
                          onTapNombreProducto: () => _confirmarEdicionNombreProductoSuelto(producto),
                          onFiltrarProductos: (query) => _filtrarProductos(
                            query,
                            esProductoSuelto: true,
                          ),
                          onFiltrarRubros: _filtrarRubros,
                          onMostrarHistorial: () {
                            setState(() {
                              _productosFiltrados = _obtenerHistorialProductosPorTipo(
                                esProductoSuelto: true,
                              );
                            });
                          },
                          onMostrarHistorialRubros: () {
                            setState(() {
                              _rubrosFiltrados = _historialRubros;
                            });
                          },
                          onSelectNombre: (productoSeleccionado) async {
                            producto.nombreController.text = productoSeleccionado.nombreController.text;
                            producto.codigoBarrasController.text = productoSeleccionado.codigoBarrasController.text;
                            producto.nombreFocusNode.unfocus();

                            // si selecciono un producto del historial, cargo su última info conocida del mismo
                            await _cargarUltimaInfoProducto(producto, lugarSeleccionado);

                            _guardarBorrador();
                          },
                          onLimpiarProductosFiltrados: () {
                            setState(() {
                              _productosFiltrados = [];
                            });
                          },
                          onSelectRubro: (rubro) {
                            setState(() {
                              producto.rubroController.text = rubro;
                            });
                            producto.rubroFocusNode.unfocus();
                            _guardarBorrador();
                          },
                          onLimpiarRubrosFiltrados: () {
                            setState(() {
                              _rubrosFiltrados = [];
                            });
                          },
                          onCodigoChanged: (_) => _guardarBorrador(),
                          onPrecioChanged: (value) {
                            setState(() {
                              producto.precioUnitario = double.tryParse(value) ?? 0.0;
                            });
                            _guardarBorrador();
                          },
                          onCantidadChanged: (value) {
                            setState(() {
                              producto.cantidad = int.tryParse(value) ?? 1;
                            });
                            _guardarBorrador();
                          },
                          onUnidadChanged: (value) {
                            setState(() {
                              producto.unidadMedida = value;
                            });
                            _guardarBorrador();
                          },
                        );
                      }

                      return ProductoTicketCard(
                        producto: producto,
                        index: index,
                        estaExpandido: _productoExpandidoIndex == index,
                        productosFiltrados: _productosFiltrados,
                        historialProductos: _obtenerHistorialProductosPorTipo(esProductoSuelto: false),
                        rubrosFiltrados: _rubrosFiltrados,
                        historialRubros: _historialRubros,
                        onExpand: () {
                          setState(() {
                            _productoExpandidoIndex = index;
                            _productosFiltrados = [];
                            _rubrosFiltrados = [];
                          });
                        },
                        onCollapse: () {
                          setState(() {
                            _productoExpandidoIndex = null;
                            _productosFiltrados = [];
                            _rubrosFiltrados = [];
                          });
                        },
                        onDelete: () {
                          _codigoProductoValidado.remove(producto);
                          _codigoProductoEscaneado.remove(producto);
                          producto.dispose();
                          _eliminarProducto(index);
                        },
                        onScan: () => _escanearProducto(producto, index, lugarSeleccionado),
                        onCheckCodigo: () => _setearNombreProducto(
                          producto,
                          producto.codigoBarrasController.text.trim(),
                          lugarSeleccionado,
                          vieneDeEscaneo: false,
                        ),
                        onFiltrarProductos: (query) => _filtrarProductos(
                          query,
                          esProductoSuelto: false,
                        ),
                        onFiltrarRubros: _filtrarRubros,
                        onMostrarHistorial: () {
                          setState(() {
                            _productosFiltrados = _obtenerHistorialProductosPorTipo(
                              esProductoSuelto: false,
                            );
                          });
                        },
                        onMostrarHistorialRubros: () {
                          setState(() {
                            _rubrosFiltrados = _historialRubros;
                          });
                        },
                        onSelectNombre: (productoSeleccionado) async {
                          producto.nombreController.text = productoSeleccionado.nombreController.text;
                          producto.codigoBarrasController.text = productoSeleccionado.codigoBarrasController.text;
                          producto.nombreFocusNode.unfocus();

                          // si selecciono un producto del historial, cargo su última info conocida del mismo
                          await _cargarUltimaInfoProducto(producto, lugarSeleccionado);

                          _guardarBorrador();
                        },
                        onLimpiarProductosFiltrados: () {
                          setState(() {
                            _productosFiltrados = [];
                          });
                        },
                        onSelectRubro: (rubro) {
                          setState(() {
                            producto.rubroController.text = rubro;
                          });
                          producto.rubroFocusNode.unfocus();
                          _guardarBorrador();
                        },
                        onLimpiarRubrosFiltrados: () {
                          setState(() {
                            _rubrosFiltrados = [];
                          });
                        },
                        onCodigoChanged: (_) {
                          setState(() {
                            _codigoProductoValidado.remove(producto);
                            _codigoProductoEscaneado.remove(producto);
                          });
                          _guardarBorrador();
                        },
                        onPrecioChanged: (value) {
                          setState(() {
                            producto.precioUnitario = double.tryParse(value) ?? 0.0;
                          });
                          _guardarBorrador();
                        },
                        onCantidadMinus: () {
                          setState(() {
                            if (producto.cantidad > 1) {
                              producto.cantidad--;
                            }
                          });
                          _guardarBorrador();
                        },
                        onCantidadPlus: () {
                          setState(() {
                            producto.cantidad++;
                          });
                          _guardarBorrador();
                        },
                        onPrecioDescuentoChanged: (value) {
                          setState(() {
                            producto.precioDescuento = double.tryParse(value) ?? 0.0;
                          });
                          _guardarBorrador();
                        },
                        onCantidadDescuentoChanged: (value) {
                          setState(() {
                            producto.cantidadDescuento = int.tryParse(value) ?? 0;
                          });
                          _guardarBorrador();
                        },
                      );
                    },
                  ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: tecladoVisible
                ? const SizedBox.shrink()
                : ResumenCompraFooter(
                    total: _calcularTotal(),
                    puedeFinalizar: _puedeFinalizarCompra(),
                    tieneProductos: _productos.isNotEmpty,
                    lugarDefinido: _tieneComercioValido(),
                    onAgregarProducto: _agregarProducto,
                    onAgregarProductoSuelto: _agregarProductoSuelto,
                    onFinalizarCompra: _confirmarFinalizarCompra,
                    onCancelarCompra: _confirmarCancelarCompra,
                  ),
          ),
        ],
      ),
    );
  }
}
