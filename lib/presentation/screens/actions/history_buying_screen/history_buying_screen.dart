import 'package:mi_compra_mayorista/data/local/compra_repository.dart';
import 'package:mi_compra_mayorista/presentation/screens/actions/history_buying_screen/history_buying_card.dart';
import 'package:flutter/material.dart';

class HistorialComprasScreen extends StatefulWidget {
	const HistorialComprasScreen({super.key});

	@override
	State<HistorialComprasScreen> createState() => _HistorialComprasScreenState();
}

class _HistorialComprasScreenState extends State<HistorialComprasScreen> {
	final CompraRepository _compraRepository = CompraRepository.instance;

	List<Compra> _compras = [];
	bool _cargando = true;

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
			final compras = await _compraRepository.listarCompras();

			if (!mounted) {
				return;
			}

			setState(() {
				_compras = compras;
			});
		} catch (_) {
			if (!mounted) {
				return;
			}

			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No se pudo cargar el historial de compras.')),
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

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Historial de Compras'),
			),
			body: _cargando
					? const Center(child: CircularProgressIndicator())
					: _compras.isEmpty
							? const Center(
									child: Text(
										'No hay compras registradas.',
										style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
									),
								)
							: RefreshIndicator(
									onRefresh: _cargarCompras,
									child: ListView.builder(
										padding: const EdgeInsets.all(12),
										itemCount: _compras.length,
										itemBuilder: (context, index) {
											final compra = _compras[index];

											return Card(
												margin: const EdgeInsets.only(bottom: 10),
												child: ListTile(
													leading: const Icon(Icons.receipt_long),
													title: Text(compra.comercio),
													subtitle: Text(
														'Ticket #${compra.ticketId} · ${_formatearFecha(compra.fecha)}\nTotal: \$${compra.importeTotal.toStringAsFixed(2)}',
													),
													isThreeLine: true,
													trailing: const Icon(Icons.chevron_right),
													onTap: () {
														Navigator.push(
															context,
															MaterialPageRoute(
																builder: (_) => HistorialCompraDetalleScreen(compra: compra),
															),
														);
													},
												),
											);
										},
									),
								),
		);
	}
}
