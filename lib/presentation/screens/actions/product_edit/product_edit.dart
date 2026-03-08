import 'package:mi_compra_mayorista/data/local/producto_repository.dart';
import 'package:mi_compra_mayorista/data/local/rubro_repository.dart';
import 'package:mi_compra_mayorista/domain/entities/producto.dart';
import 'package:mi_compra_mayorista/domain/entities/rubro.dart';
import 'package:flutter/material.dart';

class _EditableProductoRow {
  final String codigoDeBarras;
  final TextEditingController nombreController;
  final TextEditingController rubroController;
  final FocusNode rubroFocusNode;

  String _originalNombre;
  String _originalRubro;

  _EditableProductoRow({
    required this.codigoDeBarras,
    required String nombre,
    required String rubro,
  })  : nombreController = TextEditingController(text: nombre),
        rubroController = TextEditingController(text: rubro),
        rubroFocusNode = FocusNode(),
        _originalNombre = nombre,
        _originalRubro = rubro;

  bool get tieneCambios {
    return nombreController.text.trim() != _originalNombre.trim() ||
        rubroController.text.trim() != _originalRubro.trim();
  }

  void marcarComoGuardado() {
    _originalNombre = nombreController.text.trim();
    _originalRubro = rubroController.text.trim();
  }

  void dispose() {
    nombreController.dispose();
    rubroController.dispose();
    rubroFocusNode.dispose();
  }
}

class DatabaseEditProductsScreen extends StatefulWidget {
  const DatabaseEditProductsScreen({
    super.key,
  });

  @override
  State<DatabaseEditProductsScreen> createState() => _DatabaseEditProductsScreenState();
}

class _DatabaseEditProductsScreenState extends State<DatabaseEditProductsScreen> {
  final ProductoRepository _productoRepository = ProductoRepository.instance;
  final RubroRepository _rubroRepository = RubroRepository.instance;

  List<_EditableProductoRow> _productos = [];
  List<String> _historialRubros = [];
  List<String> _rubrosFiltrados = [];

  bool _cargando = true;
  final Set<String> _guardandoCodigos = <String>{};
  final Set<String> _eliminandoCodigos = <String>{};
  String? _productoConSugerenciasAbiertas;
  int? _productoExpandidoIndex;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    for (final producto in _productos) {
      producto.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
    });

    try {
      final productosBd = await _productoRepository.list();
      final rubrosBd = await _rubroRepository.list();

      final filas = productosBd
          .map(
            (producto) => _EditableProductoRow(
              codigoDeBarras: producto.codigoDeBarras,
              nombre: producto.nombre,
              rubro: producto.rubro?.nombre ?? '',
            ),
          )
          .toList();

      if (!mounted) {
        return;
      }

      for (final producto in _productos) {
        producto.dispose();
      }

      setState(() {
        _productos = filas;
        _historialRubros = rubrosBd.map((rubro) => rubro.nombre).toList();
        _rubrosFiltrados = [];
        _productoConSugerenciasAbiertas = null;
        _productoExpandidoIndex = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron cargar los productos.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  void _filtrarRubros(String codigo, String query) {
    setState(() {
      _productoConSugerenciasAbiertas = codigo;
      if (query.trim().isEmpty) {
        _rubrosFiltrados = _historialRubros;
      } else {
        _rubrosFiltrados = _historialRubros
            .where((rubro) => rubro.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _guardarProducto(_EditableProductoRow row) async {
    final nombreLimpio = row.nombreController.text.trim();
    final rubroLimpio = row.rubroController.text.trim();

    if (nombreLimpio.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre del producto no puede estar vacío.')),
      );
      return;
    }

    if (!row.tieneCambios) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cambios para guardar.')),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar cambios'),
          content: Text(
            'Se guardarán los cambios del producto con código ${row.codigoDeBarras}. Esta acción modificará la base de datos. ¿Desea continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() {
      _guardandoCodigos.add(row.codigoDeBarras);
    });

    try {
      Rubro? rubro;
      if (rubroLimpio.isNotEmpty) {
        final rubroId = await _rubroRepository.upsertByNombre(rubroLimpio);
        rubro = Rubro(id: rubroId.toString(), nombre: rubroLimpio);
      }

      await _productoRepository.update(
        Producto(
          codigoDeBarras: row.codigoDeBarras,
          nombre: nombreLimpio,
          rubro: rubro,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        if (rubroLimpio.isNotEmpty && !_historialRubros.contains(rubroLimpio)) {
          _historialRubros.add(rubroLimpio);
          _historialRubros.sort();
        }
        row.marcarComoGuardado();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto actualizado correctamente.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el cambio.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _guardandoCodigos.remove(row.codigoDeBarras);
        });
      }
    }
  }

  Future<void> _eliminarProducto(_EditableProductoRow row, int index) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar producto'),
          content: Text(
            'Esta accion eliminara el producto ${row.nombreController.text.trim().isEmpty ? row.codigoDeBarras : row.nombreController.text.trim()} de forma permanente. ¿Desea continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Si, eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) {
      return;
    }

    setState(() {
      _eliminandoCodigos.add(row.codigoDeBarras);
    });

    try {
      final eliminado = await _productoRepository.delete(row.codigoDeBarras);
      if (!mounted) {
        return;
      }

      if (!eliminado) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el producto.')),
        );
        return;
      }

      setState(() {
        row.dispose();
        _productos.removeAt(index);

        if (_productoExpandidoIndex == index) {
          _productoExpandidoIndex = null;
        } else if (_productoExpandidoIndex != null && _productoExpandidoIndex! > index) {
          _productoExpandidoIndex = _productoExpandidoIndex! - 1;
        }

        _productoConSugerenciasAbiertas = null;
        _rubrosFiltrados = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto eliminado correctamente.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar el producto.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _eliminandoCodigos.remove(row.codigoDeBarras);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Productos'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _productos.isEmpty
              ? const Center(
                  child: Text(
                    'No hay productos para editar.',
                    style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _productos.length,
                    itemBuilder: (context, index) {
                      final row = _productos[index];
                      final estaExpandido = _productoExpandidoIndex == index;
                      final estaGuardando = _guardandoCodigos.contains(row.codigoDeBarras);
                        final estaEliminando = _eliminandoCodigos.contains(row.codigoDeBarras);
                      final mostrarSugerencias = _productoConSugerenciasAbiertas == row.codigoDeBarras &&
                          row.rubroFocusNode.hasFocus &&
                          _rubrosFiltrados.isNotEmpty;

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            return SizeTransition(
                              sizeFactor: animation,
                              axisAlignment: -1,
                              child: FadeTransition(opacity: animation, child: child),
                            );
                          },
                          child: estaExpandido
                              ? Padding(
                                  key: ValueKey('db-producto-expandido-$index'),
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              row.nombreController.text.trim().isEmpty
                                                  ? 'Producto ${index + 1}'
                                                  : row.nombreController.text.trim(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          if (row.tieneCambios)
                                            Text(
                                              'Sin guardar',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.error,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.expand_less),
                                            tooltip: 'Plegar',
                                            onPressed: () {
                                              setState(() {
                                                _productoExpandidoIndex = null;
                                                _rubrosFiltrados = [];
                                                _productoConSugerenciasAbiertas = null;
                                              });
                                              row.rubroFocusNode.unfocus();
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Código: ${row.codigoDeBarras}',
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: row.nombreController,
                                        decoration: const InputDecoration(
                                          labelText: 'Nombre del producto',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        textInputAction: TextInputAction.next,
                                        onChanged: (_) => setState(() {}),
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: row.rubroController,
                                        focusNode: row.rubroFocusNode,
                                        decoration: const InputDecoration(
                                          labelText: 'Rubro',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        onTap: () {
                                          _filtrarRubros(row.codigoDeBarras, row.rubroController.text);
                                        },
                                        onChanged: (value) {
                                          _filtrarRubros(row.codigoDeBarras, value);
                                          setState(() {});
                                        },
                                      ),
                                      if (mostrarSugerencias)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.grey),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: _rubrosFiltrados.length,
                                            itemBuilder: (context, rubroIndex) {
                                              final rubro = _rubrosFiltrados[rubroIndex];
                                              return ListTile(
                                                dense: true,
                                                title: Text(rubro),
                                                onTap: () {
                                                  setState(() {
                                                    row.rubroController.text = rubro;
                                                    _rubrosFiltrados = [];
                                                  });
                                                  row.rubroFocusNode.unfocus();
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: (estaGuardando || estaEliminando)
                                                ? null
                                                : () => _eliminarProducto(row, index),
                                            icon: estaEliminando
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(strokeWidth: 2),
                                                  )
                                                : const Icon(Icons.delete_outline),
                                            label: Text(estaEliminando ? 'Eliminando...' : 'Eliminar producto'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Theme.of(context).colorScheme.error,
                                            ),
                                          ),
                                          const Spacer(),
                                          FilledButton.icon(
                                            onPressed: (estaGuardando || estaEliminando)
                                                ? null
                                                : () => _guardarProducto(row),
                                            icon: estaGuardando
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                  )
                                                : const Icon(Icons.save),
                                            label: Text(estaGuardando ? 'Guardando...' : 'Guardar cambios'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              : InkWell(
                                  key: ValueKey('db-producto-plegado-$index'),
                                  onTap: () {
                                    setState(() {
                                      _productoExpandidoIndex = index;
                                      _rubrosFiltrados = [];
                                      _productoConSugerenciasAbiertas = null;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                row.nombreController.text.trim().isEmpty
                                                    ? 'Producto ${index + 1}'
                                                    : row.nombreController.text.trim(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Código: ${row.codigoDeBarras}',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              if (row.rubroController.text.trim().isNotEmpty)
                                                Text(
                                                  'Rubro: ${row.rubroController.text.trim()}',
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if (row.tieneCambios)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 8),
                                            child: Text(
                                              'Sin guardar',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.error,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        const Icon(Icons.expand_more),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}