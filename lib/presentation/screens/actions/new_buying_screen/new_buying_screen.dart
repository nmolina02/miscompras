import 'package:mi_compra_mayorista/data/local/item_ticket_repository.dart';
import 'package:mi_compra_mayorista/data/local/producto_repository.dart';
import 'package:mi_compra_mayorista/data/local/compra_repository.dart';
import 'package:mi_compra_mayorista/data/local/comercio_repository.dart';
import 'package:mi_compra_mayorista/presentation/screens/actions/new_buying_screen/widgets/item_ticket_usuario.dart';
import 'package:mi_compra_mayorista/presentation/screens/actions/new_buying_screen/barcode_scanner_page.dart';
import 'package:mi_compra_mayorista/presentation/screens/actions/new_buying_screen/models/compra_borrador.dart';
import 'package:mi_compra_mayorista/presentation/screens/actions/new_buying_screen/widgets/lugar_compra_field.dart';
import 'package:mi_compra_mayorista/presentation/screens/actions/new_buying_screen/widgets/producto_ticket_card.dart';
import 'package:mi_compra_mayorista/presentation/screens/actions/new_buying_screen/widgets/resumen_compra_footer.dart';
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
          .map((p) => ItemTicketUsuario(nombre: p.nombre, codigoDeBarras: p.codigoDeBarras))
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

  void _filtrarProductos(String query) {
    setState(() {
      if (query.isEmpty) {
        _productosFiltrados = _historialProductos;
      } else {
        _productosFiltrados = _historialProductos
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
      _productos.add(ItemTicketUsuario());
      _productoExpandidoIndex = _productos.length - 1;
    });
    _guardarBorrador();
  }

  void _eliminarProducto(int index) {
    setState(() {
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

  bool _puedeFinalizarCompra() {
    return _productos.isNotEmpty && _tieneComercioValido() && _tienenCodigoDeBarras() && _calcularTotal() > 0;
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

    setState(() {
      producto.codigoBarrasController.text = code;
    });

    String? nombre;
    try {
      nombre = await _buscarNombreProductoPorCodigo(code);
    } catch (_) {
      nombre = null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      producto.nombreController.text = nombre ?? 'Producto $code';
    });

    await _cargarUltimaInfoProducto(producto, lugar);

    if (!mounted) {
      return;
    }

    if (nombre == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En este momento, no se pudo identificar el producto.'),
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
                      return ProductoTicketCard(
                        producto: producto,
                        index: index,
                        estaExpandido: _productoExpandidoIndex == index,
                        productosFiltrados: _productosFiltrados,
                        historialProductos: _historialProductos,
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
                          producto.dispose();
                          _eliminarProducto(index);
                        },
                        onScan: () => _escanearProducto(producto, index, lugarSeleccionado),
                        onFiltrarProductos: _filtrarProductos,
                        onFiltrarRubros: _filtrarRubros,
                        onMostrarHistorial: () {
                          setState(() {
                            _productosFiltrados = _historialProductos;
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
                    onFinalizarCompra: _confirmarFinalizarCompra,
                    onCancelarCompra: _confirmarCancelarCompra,
                  ),
          ),
        ],
      ),
    );
  }
}
