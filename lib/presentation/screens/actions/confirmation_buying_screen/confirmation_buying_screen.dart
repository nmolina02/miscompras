import 'package:mi_compra_mayorista/data/local/compra_repository.dart';
import 'package:flutter/material.dart';

class _CompraPendiente {
  final String ticketId;
  final String fecha;
  final String comercio;
  final double importeTotal;

  const _CompraPendiente({
    required this.ticketId,
    required this.fecha,
    required this.comercio,
    required this.importeTotal,
  });
}

class ConfirmacionCompraScreen extends StatefulWidget {
  const ConfirmacionCompraScreen({
    super.key,
  });

  @override
  State<ConfirmacionCompraScreen> createState() => _ConfirmacionCompraScreenState();
}

class _ConfirmacionCompraScreenState extends State<ConfirmacionCompraScreen> {
  final CompraRepository _compraRepository = CompraRepository.instance;

  List<_CompraPendiente> _comprasPendientes = [];
  bool _cargando = true;
  bool _procesandoAccion = false;

  @override
  void initState() {
    super.initState();
    _cargarPendientes();
  }

  Future<void> _cargarPendientes() async {
    setState(() {
      _cargando = true;
    });

    try {
      final compras = (await _compraRepository.listarComprasPendientes())
          .map(
            (item) => _CompraPendiente(
              ticketId: item.ticketId,
              fecha: item.fecha,
              comercio: item.comercio,
              importeTotal: item.importeTotal,
            ),
          )
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _comprasPendientes = compras;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      if (_comprasPendientes.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron cargar las confirmaciones pendientes.'),
          ),
        );
      }

    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  Future<bool> _confirmarTicketEnBackend({
    required String ticketId,
    required double? montoRealPagado,
  }) async {
    try {
      return _compraRepository.confirmarCompra(
        ticketId: ticketId,
        montoRealPagado: montoRealPagado,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _pedirConfirmacionAccion(String mensaje) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar acción'),
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí'),
            ),
          ],
        );
      },
    );

    return confirmar == true;
  }

  Future<void> _accionMontoCorrecto(_CompraPendiente compra) async {
    final confirmar = await _pedirConfirmacionAccion(
      '¿Confirma que el monto de este ticket es correcto?',
    );
    if (!confirmar) {
      return;
    }

    setState(() {
      _procesandoAccion = true;
    });

    final ok = await _confirmarTicketEnBackend(
      ticketId: compra.ticketId,
      montoRealPagado: compra.importeTotal,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _procesandoAccion = false;
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo confirmar el ticket.')),
      );
      return;
    }

    setState(() {
      _comprasPendientes.removeWhere((item) => item.ticketId == compra.ticketId);
    });
  }

  Future<void> _accionMontoIncorrecto(_CompraPendiente compra) async {
    final montoRealStr = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final controller = TextEditingController();
        final formKey = GlobalKey<FormState>();

        return AlertDialog(
          title: const Text('Importe real pagado'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Importe calculado: \$${compra.importeTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Ingrese el importe real pagado',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final monto = double.tryParse((value ?? '').replaceAll(',', '.'));
                    if (monto == null || monto <= 0) {
                      return 'Ingrese un importe válido mayor a cero.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return; // muestra error en rojo automáticamente
                }

                final resultado = double.tryParse((controller.text).replaceAll(',', '.'));
                final output = resultado?.toStringAsFixed(2);
                Navigator.of(dialogContext).pop(output);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (montoRealStr == null) {
      return; // el usuario canceló el diálogo
    }

    final confirmar = await _pedirConfirmacionAccion(
      '¿Confirma registrar $montoRealStr como importe real pagado?',
    );
    if (!confirmar) {
      return;
    }

    setState(() {
      _procesandoAccion = true;
    });

    final montoReal = double.tryParse(montoRealStr);

    final ok = await _confirmarTicketEnBackend(
      ticketId: compra.ticketId,
      montoRealPagado: montoReal,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _procesandoAccion = false;
    });

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo confirmar el ticket.')),
      );
      return;
    }

    setState(() {
      _comprasPendientes.removeWhere((item) => item.ticketId == compra.ticketId);
    });
  }

  String _formatearFecha(String fecha) {
    try {
      final dateTime = DateTime.parse(fecha);
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return fecha; // Si no se puede parsear, devuelve la cadena original
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmación de Compra'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _comprasPendientes.isEmpty
              ? const Center(
                  child: Text(
                    'No hay compras pendientes de confirmación.',
                    style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarPendientes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _comprasPendientes.length,
                    itemBuilder: (context, index) {
                      final compra = _comprasPendientes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(compra.comercio),
                          subtitle: Text(
                            'Ticket #${compra.ticketId} · ${_formatearFecha(compra.fecha)}\nImporte calculado: \$${compra.importeTotal.toStringAsFixed(2)}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Importe correcto',
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                                onPressed: _procesandoAccion
                                    ? null
                                    : () => _accionMontoCorrecto(compra),
                              ),
                              IconButton(
                                tooltip: 'Importe incorrecto',
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: _procesandoAccion
                                    ? null
                                    : () => _accionMontoIncorrecto(compra),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

}