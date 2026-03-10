import 'package:flutter/material.dart';

class ResumenCompraFooter extends StatelessWidget {
  final double total;
  final bool puedeFinalizar;
  final bool tieneProductos;
  final bool lugarDefinido;
  final VoidCallback onAgregarProducto;
  final VoidCallback onAgregarProductoSuelto;
  final VoidCallback onFinalizarCompra;
  final VoidCallback onCancelarCompra;

  const ResumenCompraFooter({
    super.key,
    required this.total,
    required this.puedeFinalizar,
    required this.lugarDefinido,
    required this.tieneProductos,
    required this.onAgregarProducto,
    required this.onAgregarProductoSuelto,
    required this.onFinalizarCompra,
    required this.onCancelarCompra,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: FilledButton.icon(
                  onPressed: lugarDefinido ? onAgregarProducto : null,
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: const Text('Producto'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                child: FilledButton.icon(
                  onPressed: lugarDefinido ? onAgregarProductoSuelto : null,
                  icon: const Icon(Icons.shopping_basket_outlined),
                  label: const Text('Producto Suelto'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: tieneProductos ? onFinalizarCompra : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Finalizar Compra'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Colors.green[800],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: tieneProductos ? onCancelarCompra : null,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Cancelar Compra'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    backgroundColor: Colors.red[800],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
