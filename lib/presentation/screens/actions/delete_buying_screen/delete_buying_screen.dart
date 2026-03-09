import 'package:miscompras/data/local/compra_repository.dart';
import 'package:flutter/material.dart';

class _CompraItem {
	final String ticketId;
	final String fecha;
	final String comercio;
	final double importeTotal;

	const _CompraItem({
		required this.ticketId,
		required this.fecha,
		required this.comercio,
		required this.importeTotal,
	});
}

class EliminarCompraScreen extends StatefulWidget {
	const EliminarCompraScreen({super.key});

	@override
	State<EliminarCompraScreen> createState() => _EliminarCompraScreenState();
}

class _EliminarCompraScreenState extends State<EliminarCompraScreen> {
	final CompraRepository _compraRepository = CompraRepository.instance;

	List<_CompraItem> _compras = [];
	final Set<String> _seleccionados = <String>{};
	bool _cargando = true;
	bool _eliminando = false;

	@override
	void initState() {
		super.initState();
		_cargarCompras();
	}

	Future<void> _cargarCompras() async {
		setState(() {
			_cargando = true;
		});

		try {
			final compras = (await _compraRepository.listarCompras())
					.map(
						(item) => _CompraItem(
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
				_compras = compras;
				_seleccionados.removeWhere(
					(id) => !_compras.any((compra) => compra.ticketId == id),
				);
			});
		} catch (_) {
			if (!mounted) {
				return;
			}

			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('No se pudieron cargar las compras.'),
				),
			);
		} finally {
			if (mounted) {
				setState(() {
					_cargando = false;
				});
			}
		}
	}

	void _toggleSeleccion(String ticketId, bool seleccionado) {
		setState(() {
			if (seleccionado) {
				_seleccionados.add(ticketId);
			} else {
				_seleccionados.remove(ticketId);
			}
		});
	}

	void _toggleSeleccionarTodos(bool seleccionar) {
		setState(() {
			if (seleccionar) {
				_seleccionados
					..clear()
					..addAll(_compras.map((compra) => compra.ticketId));
			} else {
				_seleccionados.clear();
			}
		});
	}

	Future<bool> _pedirConfirmacionEliminacion(int cantidad) async {
		final confirmar = await showDialog<bool>(
			context: context,
			builder: (context) {
				return AlertDialog(
					title: const Text('Confirmar eliminación'),
					content: Text(
						cantidad == 1
								? 'Se eliminará 1 compra de forma permanente. Esta acción no se puede deshacer. ¿Desea continuar?'
								: 'Se eliminarán $cantidad compras de forma permanente. Esta acción no se puede deshacer. ¿Desea continuar?',
					),
					actions: [
						TextButton(
							onPressed: () => Navigator.of(context).pop(false),
							child: const Text('Cancelar'),
						),
						FilledButton(
							onPressed: () => Navigator.of(context).pop(true),
							child: const Text('Eliminar'),
						),
					],
				);
			},
		);

		return confirmar == true;
	}

	Future<void> _eliminarSeleccionadas() async {
		if (_seleccionados.isEmpty || _eliminando) {
			return;
		}

		final cantidad = _seleccionados.length;
		final confirmado = await _pedirConfirmacionEliminacion(cantidad);
		if (!confirmado) {
			return;
		}

		setState(() {
			_eliminando = true;
		});

		final idsAEliminar = _seleccionados.toList();
		int eliminadas = 0;

		try {
			eliminadas = await _compraRepository.eliminarComprasPorTicketIds(idsAEliminar);
		} catch (_) {
			eliminadas = 0;
		}

		if (!mounted) {
			return;
		}

		setState(() {
			_eliminando = false;
		});

		if (eliminadas <= 0) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(
					content: Text('No se pudo eliminar ninguna compra.'),
				),
			);
			return;
		}

		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text(
					eliminadas == 1
							? 'Se eliminó 1 compra de forma permanente.'
							: 'Se eliminaron $eliminadas compras de forma permanente.',
				),
			),
		);

		await _cargarCompras();
	}

	String _formatearFecha(String fecha) {
		try {
			final dateTime = DateTime.parse(fecha);
			return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
		} catch (_) {
			return fecha;
		}
	}

	@override
	Widget build(BuildContext context) {
		final hayCompras = _compras.isNotEmpty;
		final todosSeleccionados = hayCompras && _seleccionados.length == _compras.length;

		return Scaffold(
			appBar: AppBar(
				title: const Text('Eliminar Compra'),
			),
			body: _cargando
					? const Center(child: CircularProgressIndicator())
					: !hayCompras
							? const Center(
									child: Text(
										'No hay compras registradas.',
										style: TextStyle(
											color: Colors.grey,
											fontSize: 16,
											fontWeight: FontWeight.bold,
										),
									),
								)
							: Column(
									children: [
										CheckboxListTile(
											value: todosSeleccionados,
											title: const Text('Seleccionar todas'),
											onChanged: _eliminando
													? null
													: (value) => _toggleSeleccionarTodos(value ?? false),
										),
										Expanded(
											child: RefreshIndicator(
												onRefresh: _cargarCompras,
												child: ListView.builder(
													padding: const EdgeInsets.only(bottom: 90),
													itemCount: _compras.length,
													itemBuilder: (context, index) {
														final compra = _compras[index];
														final seleccionado = _seleccionados.contains(compra.ticketId);

														return Card(
															margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
															child: CheckboxListTile(
																value: seleccionado,
																controlAffinity: ListTileControlAffinity.leading,
																onChanged: _eliminando
																		? null
																		: (value) => _toggleSeleccion(compra.ticketId, value ?? false),
																title: Text(compra.comercio),
																subtitle: Text(
																	'Ticket #${compra.ticketId} · ${_formatearFecha(compra.fecha)}\nImporte: \$${compra.importeTotal.toStringAsFixed(2)}',
																),
																isThreeLine: true,
															),
														);
													},
												),
											),
										),
									],
								),
			floatingActionButton: hayCompras
					? FloatingActionButton.extended(
							onPressed: (_seleccionados.isEmpty || _eliminando) ? null : _eliminarSeleccionadas,
							icon: _eliminando
									? const SizedBox(
											width: 18,
											height: 18,
											child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
										)
									: const Icon(Icons.delete_forever),
							label: Text(
								_eliminando ? 'Eliminando...' : 'Eliminar (${_seleccionados.length})',
							),
						)
					: null,
		);
	}
}
