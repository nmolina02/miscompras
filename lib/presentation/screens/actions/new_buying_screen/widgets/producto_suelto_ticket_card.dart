import 'package:miscompras/presentation/screens/actions/new_buying_screen/widgets/item_ticket_usuario.dart';
import 'package:flutter/material.dart';

class ProductoSueltoTicketCard extends StatelessWidget {
  final ItemTicketUsuario producto;
  final int index;
  final bool mostrarHintGenerarCodigo;
  final bool estaExpandido;
  final List<ItemTicketUsuario> productosFiltrados;
  final List<ItemTicketUsuario> historialProductos;
  final List<String> rubrosFiltrados;
  final List<String> historialRubros;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final VoidCallback onScaleProduct;
  final VoidCallback onDelete;
  final Future<bool> Function() onTapNombreProducto;
  final ValueChanged<String> onFiltrarProductos;
  final ValueChanged<String> onFiltrarRubros;
  final VoidCallback onMostrarHistorial;
  final VoidCallback onMostrarHistorialRubros;
  final Future<void> Function(ItemTicketUsuario) onSelectNombre;
  final ValueChanged<String> onSelectRubro;
  final VoidCallback onLimpiarProductosFiltrados;
  final VoidCallback onLimpiarRubrosFiltrados;
  final ValueChanged<String> onCodigoChanged;
  final ValueChanged<String> onPrecioChanged;
  final ValueChanged<String> onCantidadChanged;
  final ValueChanged<String> onUnidadChanged;

  const ProductoSueltoTicketCard({
    super.key,
    required this.producto,
    required this.index,
    this.mostrarHintGenerarCodigo = false,
    required this.estaExpandido,
    required this.productosFiltrados,
    required this.historialProductos,
    required this.rubrosFiltrados,
    required this.historialRubros,
    required this.onExpand,
    required this.onCollapse,
    required this.onScaleProduct,
    required this.onDelete,
    required this.onTapNombreProducto,
    required this.onFiltrarProductos,
    required this.onFiltrarRubros,
    required this.onMostrarHistorial,
    required this.onMostrarHistorialRubros,
    required this.onSelectNombre,
    required this.onSelectRubro,
    required this.onLimpiarProductosFiltrados,
    required this.onLimpiarRubrosFiltrados,
    required this.onCodigoChanged,
    required this.onPrecioChanged,
    required this.onCantidadChanged,
    required this.onUnidadChanged,
  });

  @override
  Widget build(BuildContext context) {
    const unidadesDisponibles = <String>['unidad', 'gramos', 'mililitros'];
    final unidadNormalizada = producto.unidadMedida.trim().toLowerCase();
    final unidadMapeada = <String, String>{
      'unidad': 'unidad',
      'unidades': 'unidad',
      'u': 'unidad',
      'ml': 'mililitros',
      'mililitro': 'mililitros',
      'mililitros': 'mililitros',
      'gr': 'gramos',
      'g': 'gramos',
      'gramo': 'gramos',
      'gramos': 'gramos',
    };
    final unidadActual = unidadesDisponibles.contains(unidadNormalizada)
        ? unidadNormalizada
        : (unidadMapeada[unidadNormalizada] ?? 'unidad');

    final String nombreResumen = producto.nombreController.text.trim().isEmpty
        ? 'Producto ${index + 1}'
        : producto.nombreController.text.trim();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: estaExpandido
            ? Padding(
                key: ValueKey('producto-expandido-$index'),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nombreResumen,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '\$${producto.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.expand_less),
                          tooltip: 'Plegar producto',
                          onPressed: onCollapse,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              TextField(
                                controller: producto.nombreController,
                                focusNode: producto.nombreFocusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Producto suelto',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: onFiltrarProductos,
                                onTap: () async {
                                  onExpand();
                                  final puedeEditar = await onTapNombreProducto();
                                  if (!puedeEditar) {
                                    return;
                                  }
                                  if (producto.nombreController.text.isEmpty) {
                                    onMostrarHistorial();
                                  }
                                },
                              ),
                              if (producto.nombreFocusNode.hasFocus && productosFiltrados.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: productosFiltrados.length,
                                    itemBuilder: (context, filteredIndex) {
                                      final productoSeleccionado = productosFiltrados[filteredIndex];
                                      final nombre = productoSeleccionado.nombreController.text;
                                      return ListTile(
                                        dense: true,
                                        title: Text(nombre),
                                        onTap: () async {
                                          await onSelectNombre(productoSeleccionado);
                                          onLimpiarProductosFiltrados();
                                        },
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          onPressed: onDelete,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            enabled: false, //grisa el campo y deshabilita la edición manual
                            controller: producto.codigoBarrasController,
                            decoration: const InputDecoration(
                              labelText: 'Código de barras',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: onCodigoChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: mostrarHintGenerarCodigo
                                ? Colors.amber.withValues(alpha: 0.22)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: mostrarHintGenerarCodigo
                                  ? Colors.amber.shade700
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.qr_code_2_rounded),
                            tooltip: 'Generar codigo de barras',
                            onPressed: onScaleProduct,
                          ),
                        ),
                      ],
                    ),
                    if (mostrarHintGenerarCodigo)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: const [
                            Icon(Icons.touch_app_rounded, size: 16, color: Colors.amber),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Toca el icono QR para generar el codigo de barras y poder finalizar la compra.',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              TextField(
                                controller: producto.rubroController,
                                focusNode: producto.rubroFocusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Rubro',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.text,
                                onChanged: onFiltrarRubros,
                                onTap: () {
                                  onExpand();
                                  if (producto.rubroController.text.isEmpty) {
                                    onMostrarHistorialRubros();
                                  }
                                },
                              ),
                              if (producto.rubroFocusNode.hasFocus && rubrosFiltrados.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: rubrosFiltrados.length,
                                    itemBuilder: (context, filteredIndex) {
                                      final rubro = rubrosFiltrados[filteredIndex];
                                      return ListTile(
                                        dense: true,
                                        title: Text(rubro),
                                        onTap: () {
                                          onSelectRubro(rubro);
                                          onLimpiarRubrosFiltrados();
                                        },
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ), 
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: producto.cantidadController,
                            decoration: const InputDecoration(
                              labelText: 'Cantidad',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: onCantidadChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: unidadActual,
                            isDense: true,
                            decoration: const InputDecoration(
                              labelText: 'Unidad',
                              border: OutlineInputBorder(),
                            ),
                            items: unidadesDisponibles
                                .map(
                                  (unidad) => DropdownMenuItem<String>(
                                    value: unidad,
                                    child: Text(unidad),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                onUnidadChanged(value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: producto.precioController,
                            decoration: const InputDecoration(
                              labelText: 'Precio',
                              prefixText: '\$ ',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: onPrecioChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                Text(
                                  '\$${producto.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              )
            : InkWell(
                key: ValueKey('producto-plegado-$index'),
                onTap: onExpand,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          nombreResumen,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${producto.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
