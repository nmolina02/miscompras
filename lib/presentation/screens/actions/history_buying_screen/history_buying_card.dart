import 'package:miscompras/data/local/item_ticket_repository.dart';
import 'package:miscompras/data/local/compra_repository.dart';
import 'package:miscompras/domain/entities/item_ticket.dart';
import 'package:flutter/material.dart';

class HistorialCompraDetalleScreen extends StatefulWidget {
	const HistorialCompraDetalleScreen({
		super.key,
		required this.compra,
	});

	final Compra compra;

	@override
	State<HistorialCompraDetalleScreen> createState() => _HistorialCompraDetalleScreenState();
}

class _HistorialCompraDetalleScreenState extends State<HistorialCompraDetalleScreen> {
	final ItemTicketRepository _itemTicketRepository = ItemTicketRepository.instance;

	List<ItemTicket> _items = [];
	bool _cargando = true;

	@override
	void initState() {
		super.initState();
		_cargarDetalle();
	}

	Future<void> _cargarDetalle() async {
		setState(() {
			_cargando = true;
		});

		try {
			final items = await _itemTicketRepository.listByTicketId(widget.compra.ticketId.toString());

			if (!mounted) {
				return;
			}

			setState(() {
				_items = items;
			});
		} catch (_) {
			if (!mounted) {
				return;
			}

			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No se pudo cargar el detalle de la compra.')),
			);
		} finally {
			if (mounted) {
				setState(() {
					_cargando = false;
				});
			}
		}
	}

	String _formatearFecha(String fecha) {
		try {
			final dateTime = DateTime.parse(fecha);
			return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
		} catch (_) {
			return fecha;
		}
	}

	double _calcularTotalItem(ItemTicket item) {
		final usaDescuento = item.cantidad >= item.cantidadDescuento && item.precioDescuento > 0;
		final precio = usaDescuento ? item.precioDescuento : item.precioUnitarioAplicado;
		return item.cantidad * precio;
	}

	@override
	Widget build(BuildContext context) {		
    return Scaffold(
			appBar: AppBar(
				title: Text('Detalle Ticket #${widget.compra.ticketId}'),
			),
			body: _cargando
					? const Center(child: CircularProgressIndicator())
					: RefreshIndicator(
							onRefresh: _cargarDetalle,
							child: ListView(
								physics: const AlwaysScrollableScrollPhysics(),
								padding: const EdgeInsets.all(12),
								children: [
									Card(
										shape: RoundedRectangleBorder(
											borderRadius: BorderRadius.circular(12),
											side: BorderSide(
												color: Theme.of(context).colorScheme.outlineVariant,
											),
										),
										child: Padding(
											padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
											child: Column(
												crossAxisAlignment: CrossAxisAlignment.stretch,
												children: [
													Text(
														widget.compra.comercio.toUpperCase(),
														textAlign: TextAlign.center,
														style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
													),
													const SizedBox(height: 8),
													Text(
														'Fecha: ${_formatearFecha(widget.compra.fecha)}',
														textAlign: TextAlign.center,
													),
													Text(
														'Ticket #${widget.compra.ticketId} - Confirmación: ${widget.compra.confirmado ? 'Sí' : 'No'}',
														textAlign: TextAlign.center,
													),
													const SizedBox(height: 12),
													const Divider(height: 1),
													const SizedBox(height: 10),
													const Text(
														'DETALLE',
														style: TextStyle(fontWeight: FontWeight.w700),
													),
													const SizedBox(height: 10),
													if (_items.isEmpty)
														const Text('No se encontraron productos para este ticket.')
													else
														..._items.map(
															(item) => Padding(
																padding: const EdgeInsets.only(bottom: 10),
																child: Column(
																	crossAxisAlignment: CrossAxisAlignment.start,
																	children: [
																		Text(
																			item.producto.nombre,
																			style: const TextStyle(fontWeight: FontWeight.w600),
																		),
																		const SizedBox(height: 4),
																		Row(
																			children: [
																				Expanded(
																					child: Text(
																						'${item.cantidad} x \$${item.precioUnitarioAplicado.toStringAsFixed(2)}',
																					),
																				),
																				Text('\$${_calcularTotalItem(item).toStringAsFixed(2)}'),
																			],
																		),
																		if (item.cantidadDescuento > 0 && item.precioDescuento > 0)
																			Padding(
																				padding: const EdgeInsets.only(top: 2),
																				child: Text(
																					'Desde ${item.cantidadDescuento}u: \$${item.precioDescuento.toStringAsFixed(2)}',
																					style: TextStyle(
																						fontSize: 12,
																						color: Theme.of(context).colorScheme.onSurfaceVariant,
																					),
																				),
																			),
																	],
																),
															),
														),
													const SizedBox(height: 4),
													const Divider(height: 1),
													const SizedBox(height: 12),
													const Text(
														'TOTAL CALCULADO',
														textAlign: TextAlign.right,
														style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
													),
													const SizedBox(height: 4),
													Text(
														'\$${widget.compra.importeTotal.toStringAsFixed(2)}',
														textAlign: TextAlign.right,
														style: TextStyle(
															fontSize: 32,
															fontWeight: FontWeight.w900,
															color: Theme.of(context).colorScheme.primary,
														),
													),

                          const Divider(height: 2),
													const SizedBox(height: 12),

                          const Text(
														'DIFERENCIA CON EL TOTAL PAGADO',
														textAlign: TextAlign.right,
														style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
													),
													const SizedBox(height: 4),
													Text(
														'\$${widget.compra.recargoAplicado.toStringAsFixed(2)}',
														textAlign: TextAlign.right,
														style: TextStyle(
															fontSize: 32,
															fontWeight: FontWeight.w900,
															color: Theme.of(context).colorScheme.primary,
														),
													),

                          const Divider(height: 2),
													const SizedBox(height: 12),
                          const Text(
														'TOTAL PAGADO',
														textAlign: TextAlign.right,
														style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
													),
													const SizedBox(height: 4),
													Text(
														'\$${widget.compra.montoRealPagado.toStringAsFixed(2)}',
														textAlign: TextAlign.right,
														style: TextStyle(
															fontSize: 32,
															fontWeight: FontWeight.w900,
															color: Theme.of(context).colorScheme.primary,
														),
													),
												],
											),
										),
									),
								],
							),
						),
		);
	}
}
