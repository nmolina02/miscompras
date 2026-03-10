import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:miscompras/data/local/compra_repository.dart';
import 'package:miscompras/data/local/item_ticket_repository.dart';

class ReportesEstadisticasScreen extends StatefulWidget {
	const ReportesEstadisticasScreen({super.key});

	@override
	State<ReportesEstadisticasScreen> createState() => _ReportesEstadisticasScreenState();
}

class _ReportesEstadisticasScreenState extends State<ReportesEstadisticasScreen> {
	final CompraRepository _compraRepository = CompraRepository.instance;
	final ItemTicketRepository _itemTicketRepository = ItemTicketRepository.instance;

	final List<_FiltroTiempo> _filtros = const <_FiltroTiempo>[
		_FiltroTiempo(etiqueta: '1 semana', duracion: Duration(days: 7)),
		_FiltroTiempo(etiqueta: '2 semanas', duracion: Duration(days: 14)),
		_FiltroTiempo(etiqueta: '1 mes', duracion: Duration(days: 30)),
		_FiltroTiempo(etiqueta: '2 meses', duracion: Duration(days: 60)),
		_FiltroTiempo(etiqueta: '6 meses', duracion: Duration(days: 180)),
		_FiltroTiempo(etiqueta: '1 año', duracion: Duration(days: 365)),
		_FiltroTiempo(etiqueta: 'Todo', duracion: null),
	];

	late _FiltroTiempo _filtroActual;
	bool _cargando = true;

	_ReporteData _reporte = _ReporteData.empty();

	@override
	void initState() {
		super.initState();
		_filtroActual = _filtros[0];
		_cargarReporte();
	}

	Future<void> _cargarReporte() async {
		setState(() {
			_cargando = true;
		});

		try {
			final compras = await _compraRepository.listarCompras();
			final ahora = DateTime.now();
			final fechaMinima = _filtroActual.duracion == null ? null : ahora.subtract(_filtroActual.duracion!);

			final comprasFiltradas = compras.where((compra) {
				final fecha = DateTime.tryParse(compra.fecha);
				if (fecha == null) {
					return false;
				}
				if (fechaMinima == null) {
					return true;
				}
				return !fecha.isBefore(fechaMinima);
			}).toList();

			final List<_RegistroItem> registros = <_RegistroItem>[];
			for (final compra in comprasFiltradas) {
				final fechaCompra = DateTime.tryParse(compra.fecha);
				if (fechaCompra == null) {
					continue;
				}

				final items = await _itemTicketRepository.listByTicketId(compra.ticketId);
				for (final item in items) {
					final precioEfectivo = item.precioDescuento > 0 && item.cantidad >= item.cantidadDescuento
							? item.precioDescuento
							: item.precioUnitarioAplicado;
					final total = item.cantidad * precioEfectivo;

					registros.add(
						_RegistroItem(
							ticketId: compra.ticketId,
							fecha: fechaCompra,
							comercio: compra.comercio,
							producto: item.producto.nombre.trim().isEmpty ? 'Producto sin nombre' : item.producto.nombre.trim(),
							rubro: item.producto.rubro?.nombre.trim().isNotEmpty == true
									? item.producto.rubro!.nombre.trim()
									: 'Sin rubro',
							cantidad: item.cantidad,
							total: total,
							unidadMedida: item.unidadMedida,
							esProductoSuelto: _esCodigoProductoSuelto(item.producto.codigoDeBarras),
						),
					);
				}
			}

			final reporte = _generarReporte(comprasFiltradas, registros);

			if (!mounted) {
				return;
			}

			setState(() {
				_reporte = reporte;
			});
		} catch (_) {
			if (!mounted) {
				return;
			}
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('No se pudieron cargar los reportes.')),
			);
		} finally {
			if (mounted) {
				setState(() {
					_cargando = false;
				});
			}
		}
	}

	_ReporteData _generarReporte(List<Compra> compras, List<_RegistroItem> registros) {
		if (compras.isEmpty) {
			return _ReporteData.empty();
		}

		final agrupacionTemporal = _resolverAgrupacionTemporal(_filtroActual);

		final porProductoNoSuelto = <String, _Acumulador>{};
		final porSueltoGramos = <String, _AcumuladorDouble>{};
		final porSueltoMl = <String, _AcumuladorDouble>{};
		final porComercio = <String, _Acumulador>{};
		final porRubroTickets = <String, Set<String>>{};
		final porRubroMonto = <String, double>{};
		final porPeriodo = <DateTime, double>{};

		var itemsTotales = 0;
		var unidadesTotales = 0;
		final montoTotal = compras.fold<double>(0, (sum, compra) => sum + compra.importeTotal);

		for (final r in registros) {
			itemsTotales += 1;
			unidadesTotales += r.cantidad;

			if (!r.esProductoSuelto && _esUnidad(r.unidadMedida)) {
				porProductoNoSuelto.putIfAbsent(r.producto, _Acumulador.new).agregar(r.cantidad, r.total);
			}

			if (r.esProductoSuelto && _esGramo(r.unidadMedida)) {
				final cantidadKg = r.cantidad / 1000;
				porSueltoGramos.putIfAbsent(r.producto, _AcumuladorDouble.new).agregar(cantidadKg, r.total);
			}

			if (r.esProductoSuelto && _esMililitro(r.unidadMedida)) {
				final cantidadLitros = r.cantidad / 1000;
				porSueltoMl.putIfAbsent(r.producto, _AcumuladorDouble.new).agregar(cantidadLitros, r.total);
			}

			porRubroTickets.putIfAbsent(r.rubro, () => <String>{}).add(r.ticketId);
			porRubroMonto.update(r.rubro, (value) => value + r.total, ifAbsent: () => r.total);

		}

		for (final compra in compras) {
			porComercio.putIfAbsent(compra.comercio, _Acumulador.new).agregar(1, compra.importeTotal);

			final fechaCompra = DateTime.tryParse(compra.fecha);
			if (fechaCompra != null) {
				final inicioPeriodo = _inicioPeriodo(fechaCompra, agrupacionTemporal);
				porPeriodo.update(inicioPeriodo, (value) => value + compra.importeTotal, ifAbsent: () => compra.importeTotal);
			}
		}

		final topProductos = porProductoNoSuelto.entries
				.map((e) => _RankingFila(nombre: e.key, cantidad: e.value.cantidad, monto: e.value.monto))
				.toList()
			..sort((a, b) {
				final porCantidad = b.cantidad.compareTo(a.cantidad);
				if (porCantidad != 0) {
					return porCantidad;
				}
				return b.monto.compareTo(a.monto);
			});

		final topSueltosKg = porSueltoGramos.entries
				.map((e) => _RankingMedidoFila(nombre: e.key, cantidad: e.value.cantidad, monto: e.value.monto))
				.toList()
			..sort((a, b) {
				final porCantidad = b.cantidad.compareTo(a.cantidad);
				if (porCantidad != 0) {
					return porCantidad;
				}
				return b.monto.compareTo(a.monto);
			});

		final topSueltosLitros = porSueltoMl.entries
				.map((e) => _RankingMedidoFila(nombre: e.key, cantidad: e.value.cantidad, monto: e.value.monto))
				.toList()
			..sort((a, b) {
				final porCantidad = b.cantidad.compareTo(a.cantidad);
				if (porCantidad != 0) {
					return porCantidad;
				}
				return b.monto.compareTo(a.monto);
			});

		final topComercios = porComercio.entries
				.map((e) => _RankingFila(nombre: e.key, cantidad: e.value.cantidad, monto: e.value.monto))
				.toList()
			..sort((a, b) {
				final porCantidad = b.cantidad.compareTo(a.cantidad);
				if (porCantidad != 0) {
					return porCantidad;
				}
				return b.monto.compareTo(a.monto);
			});

		final topRubros = porRubroTickets.entries
				.map(
					(e) => _RankingFila(
						nombre: e.key,
						cantidad: e.value.length,
						monto: porRubroMonto[e.key] ?? 0,
					),
				)
				.toList()
			..sort((a, b) {
				final porFrecuencia = b.cantidad.compareTo(a.cantidad);
				if (porFrecuencia != 0) {
					return porFrecuencia;
				}
				return b.monto.compareTo(a.monto);
			});

		final evolucionMensual = porPeriodo.entries
				.map(
					(e) => _PuntoMensual(
						mes: _etiquetaPeriodo(e.key, agrupacionTemporal),
						monto: e.value,
						fechaOrden: e.key,
					),
				)
				.toList()
			..sort((a, b) => a.fechaOrden.compareTo(b.fechaOrden));

		final rubroPie = topRubros
				.take(6)
				.map((r) => _RankingFila(nombre: r.nombre, cantidad: r.cantidad, monto: r.cantidad.toDouble()))
				.toList();

		return _ReporteData(
			comprasTotal: compras.length,
			itemsTotal: itemsTotales,
			unidadesTotal: unidadesTotales,
			montoTotal: montoTotal,
			promedioTicket: compras.isEmpty ? 0 : montoTotal / compras.length,
			topProductos: topProductos,
			topSueltosKg: topSueltosKg,
			topSueltosLitros: topSueltosLitros,
			topComercios: topComercios,
			topRubros: topRubros,
			pieRubros: rubroPie,
			evolucionMensual: evolucionMensual,
		);
	}

	bool _esUnidad(String unidad) => unidad.trim().toLowerCase() == 'unidad';

	bool _esGramo(String unidad) => unidad.trim().toLowerCase() == 'gramos';

	bool _esMililitro(String unidad) => unidad.trim().toLowerCase() == 'mililitros';

	bool _esCodigoProductoSuelto(String codigo) {
		final codigoLimpio = codigo.trim();
		return codigoLimpio.length >= 21 && RegExp(r'^\d+$').hasMatch(codigoLimpio);
	}

	_AgrupacionTemporal _resolverAgrupacionTemporal(_FiltroTiempo filtro) {
		final dias = filtro.duracion?.inDays;
		if (dias == null || dias >= 365) {
			return _AgrupacionTemporal.anio;
		}
		if (dias == 1) {
			return _AgrupacionTemporal.dia;
		}
		if (dias <= 7) {
			return _AgrupacionTemporal.semana;
		}
		if (dias <= 14) {
			return _AgrupacionTemporal.quincena;
		}
		return _AgrupacionTemporal.mes;
	}

	DateTime _inicioPeriodo(DateTime fecha, _AgrupacionTemporal agrupacion) {
		switch (agrupacion) {
			case _AgrupacionTemporal.dia:
				return DateTime(fecha.year, fecha.month, fecha.day);
			case _AgrupacionTemporal.semana:
				final inicioSemana = fecha.subtract(Duration(days: fecha.weekday - 1));
				return DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
			case _AgrupacionTemporal.quincena:
				final diaInicio = fecha.day <= 15 ? 1 : 16;
				return DateTime(fecha.year, fecha.month, diaInicio);
			case _AgrupacionTemporal.mes:
				return DateTime(fecha.year, fecha.month, 1);
			case _AgrupacionTemporal.anio:
				return DateTime(fecha.year, 1, 1);
		}
	}

	String _etiquetaPeriodo(DateTime inicio, _AgrupacionTemporal agrupacion) {
		switch (agrupacion) {
			case _AgrupacionTemporal.dia:
				return '${inicio.day.toString().padLeft(2, '0')}/${inicio.month.toString().padLeft(2, '0')}';
			case _AgrupacionTemporal.semana:
				return 'Sem ${inicio.day.toString().padLeft(2, '0')}/${inicio.month.toString().padLeft(2, '0')}';
			case _AgrupacionTemporal.quincena:
				return inicio.day == 1
					? 'Q1 ${inicio.month.toString().padLeft(2, '0')}/${inicio.year.toString().substring(2)}'
					: 'Q2 ${inicio.month.toString().padLeft(2, '0')}/${inicio.year.toString().substring(2)}';
			case _AgrupacionTemporal.mes:
				return '${inicio.month.toString().padLeft(2, '0')}/${inicio.year.toString().substring(2)}';
			case _AgrupacionTemporal.anio:
				return '${inicio.year}';
		}
	}

	String _tituloEvolucion() {
		switch (_resolverAgrupacionTemporal(_filtroActual)) {
			case _AgrupacionTemporal.dia:
				return 'Evolución de gasto por día';
			case _AgrupacionTemporal.semana:
				return 'Evolución de gasto por semana';
			case _AgrupacionTemporal.quincena:
				return 'Evolución de gasto por quincena';
			case _AgrupacionTemporal.mes:
				return 'Evolución de gasto por mes';
			case _AgrupacionTemporal.anio:
				return 'Evolución de gasto por año';
		}
	}

	String _formatearMonto(double monto) {
		final valor = monto.toStringAsFixed(2);
		return '\$$valor';
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Reportes y Estadísticas'),
			),
			body: _cargando
					? const Center(child: CircularProgressIndicator())
					: RefreshIndicator(
							onRefresh: _cargarReporte,
							child: ListView(
								padding: const EdgeInsets.all(16),
								children: <Widget>[
									Wrap(
										spacing: 8,
										runSpacing: 8,
										children: _filtros.map((filtro) {
											return ChoiceChip(
												label: Text(filtro.etiqueta),
												selected: _filtroActual.etiqueta == filtro.etiqueta,
												onSelected: (selected) {
													if (!selected) {
														return;
													}
													setState(() {
														_filtroActual = filtro;
													});
													_cargarReporte();
												},
											);
										}).toList(),
									),
									const SizedBox(height: 16),
									if (_reporte.comprasTotal == 0)
										const Card(
											child: Padding(
												padding: EdgeInsets.all(20),
												child: Text(
													'No hay datos para el período seleccionado.',
													style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
													textAlign: TextAlign.center,
												),
											),
										)
									else ...<Widget>[
										_ResumenGrid(
											montoTotal: _formatearMonto(_reporte.montoTotal),
											comprasTotal: _reporte.comprasTotal,
											itemsTotal: _reporte.itemsTotal,
											promedioTicket: _formatearMonto(_reporte.promedioTicket),
										),
										const SizedBox(height: 16),
										_SeccionCard(
											titulo: 'Top productos registrados (en unidades)',
											child: _RankingTabla(
												filas: _reporte.topProductos.take(10).toList(),
												encabezadoCantidad: 'Unidades',
												nombreColumnaAncho: 160,
												nombresMultilinea: true,
											),
										),
										const SizedBox(height: 16),
										_SeccionCard(
											titulo: 'Productos sueltos por peso (kg)',
											child: _RankingMedidoTabla(
												filas: _reporte.topSueltosKg.take(10).toList(),
												encabezadoCantidad: 'Kg',
											),
										),
										const SizedBox(height: 16),
										_SeccionCard(
											titulo: 'Productos sueltos por volumen (litros)',
											child: _RankingMedidoTabla(
												filas: _reporte.topSueltosLitros.take(10).toList(),
												encabezadoCantidad: 'L',
											),
										),
										const SizedBox(height: 16),
										_SeccionCard(
											titulo: 'Lugares más visitados',
											child: _RankingTabla(
												filas: _reporte.topComercios.take(10).toList(),
												encabezadoCantidad: 'Visitas',
											),
										),
										const SizedBox(height: 16),
										_SeccionCard(
											titulo: 'Rubro consumido con más frecuencia',
											child: _RankingTabla(
												filas: _reporte.topRubros.take(10).toList(),
												encabezadoCantidad: 'Frecuencia',
											),
										),
										const SizedBox(height: 16),
										_SeccionCard(
											titulo: 'Distribución por rubro',
											child: SizedBox(
												height: 260,
												child: _PieChartRubros(filas: _reporte.pieRubros),
											),
										),
										const SizedBox(height: 16),
										_SeccionCard(
											titulo: _tituloEvolucion(),
											child: SizedBox(
												height: 240,
												child: _BarChartMensual(puntos: _reporte.evolucionMensual),
											),
										),
									],
								],
							),
						),
		);
	}
}

class _ResumenGrid extends StatelessWidget {
	final String montoTotal;
	final int comprasTotal;
	final int itemsTotal;
	final String promedioTicket;

	const _ResumenGrid({
		required this.montoTotal,
		required this.comprasTotal,
		required this.itemsTotal,
		required this.promedioTicket,
	});

	@override
	Widget build(BuildContext context) {
		final cards = <Widget>[
			_ResumenCard(titulo: 'Gasto total', valor: montoTotal, icono: Icons.payments_outlined),
			_ResumenCard(titulo: 'Compras', valor: '$comprasTotal', icono: Icons.receipt_long),
			_ResumenCard(titulo: 'Items', valor: '$itemsTotal', icono: Icons.inventory_2_outlined),
			_ResumenCard(titulo: 'Promedio ticket', valor: promedioTicket, icono: Icons.trending_up),
		];

		return LayoutBuilder(
			builder: (context, constraints) {
				final columnas = constraints.maxWidth > 900
						? 3
						: constraints.maxWidth > 600
								? 2
								: 1;

				return GridView.builder(
					itemCount: cards.length,
					shrinkWrap: true,
					physics: const NeverScrollableScrollPhysics(),
					gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
						crossAxisCount: columnas,
						crossAxisSpacing: 12,
						mainAxisSpacing: 12,
						childAspectRatio: 2.4,
					),
					itemBuilder: (_, index) => cards[index],
				);
			},
		);
	}
}

class _ResumenCard extends StatelessWidget {
	final String titulo;
	final String valor;
	final IconData icono;

	const _ResumenCard({required this.titulo, required this.valor, required this.icono});

	@override
	Widget build(BuildContext context) {
		final color = Theme.of(context).colorScheme.primary;

		return Card(
			child: Padding(
				padding: const EdgeInsets.all(12),
				child: Row(
					children: <Widget>[
						CircleAvatar(
							backgroundColor: color.withValues(alpha: 0.14),
							child: Icon(icono, color: color),
						),
						const SizedBox(width: 10),
						Expanded(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								mainAxisAlignment: MainAxisAlignment.center,
								children: <Widget>[
									Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
									const SizedBox(height: 4),
									Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
								],
							),
						),
					],
				),
			),
		);
	}
}

class _SeccionCard extends StatelessWidget {
	final String titulo;
	final Widget child;

	const _SeccionCard({required this.titulo, required this.child});

	@override
	Widget build(BuildContext context) {
		return Card(
			child: Padding(
				padding: const EdgeInsets.all(14),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: <Widget>[
						Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
						const SizedBox(height: 10),
						child,
					],
				),
			),
		);
	}
}

class _RankingTabla extends StatelessWidget {
	final List<_RankingFila> filas;
	final String encabezadoCantidad;
	final double nombreColumnaAncho;
	final bool nombresMultilinea;

	const _RankingTabla({
		required this.filas,
		required this.encabezadoCantidad,
		this.nombreColumnaAncho = 220,
		this.nombresMultilinea = false,
	});

	@override
	Widget build(BuildContext context) {
		if (filas.isEmpty) {
			return const Padding(
				padding: EdgeInsets.symmetric(vertical: 16),
				child: Center(child: Text('Sin datos para mostrar.')),
			);
		}

		return SingleChildScrollView(
			scrollDirection: Axis.horizontal,
			child: DataTable(
				dataRowMinHeight: 52,
				dataRowMaxHeight: nombresMultilinea ? 140 : 56,
				columns: <DataColumn>[
					const DataColumn(label: Text('#')),
					const DataColumn(label: Text('Nombre')),
					DataColumn(label: Text(encabezadoCantidad)),
					const DataColumn(label: Text('Monto')),
				],
				rows: filas.asMap().entries.map((entry) {
					final i = entry.key + 1;
					final fila = entry.value;
					return DataRow(
						cells: <DataCell>[
							DataCell(Text('$i')),
							DataCell(
								SizedBox(
									width: nombreColumnaAncho,
									child: Text(
										fila.nombre,
										softWrap: nombresMultilinea,
										maxLines: nombresMultilinea ? null : 1,
										overflow: nombresMultilinea ? TextOverflow.visible : TextOverflow.ellipsis,
									),
								),
							),
							DataCell(Text('${fila.cantidad}')),
							DataCell(Text('\$${fila.monto.toStringAsFixed(2)}')),
						],
					);
				}).toList(),
			),
		);
	}
}

class _RankingMedidoTabla extends StatelessWidget {
	final List<_RankingMedidoFila> filas;
	final String encabezadoCantidad;

	const _RankingMedidoTabla({required this.filas, required this.encabezadoCantidad});

	@override
	Widget build(BuildContext context) {
		if (filas.isEmpty) {
			return const Padding(
				padding: EdgeInsets.symmetric(vertical: 16),
				child: Center(child: Text('Sin datos para mostrar.')),
			);
		}

		return SingleChildScrollView(
			scrollDirection: Axis.horizontal,
			child: DataTable(
				columns: <DataColumn>[
					const DataColumn(label: Text('#')),
					const DataColumn(label: Text('Nombre')),
					DataColumn(label: Text(encabezadoCantidad)),
					const DataColumn(label: Text('Monto')),
				],
				rows: filas.asMap().entries.map((entry) {
					final i = entry.key + 1;
					final fila = entry.value;
					return DataRow(
						cells: <DataCell>[
							DataCell(Text('$i')),
							DataCell(SizedBox(width: 220, child: Text(fila.nombre))),
							DataCell(Text(fila.cantidad.toStringAsFixed(3))),
							DataCell(Text('\$${fila.monto.toStringAsFixed(2)}')),
						],
					);
				}).toList(),
			),
		);
	}
}

class _PieChartRubros extends StatelessWidget {
	final List<_RankingFila> filas;

	const _PieChartRubros({required this.filas});

	@override
	Widget build(BuildContext context) {
		if (filas.isEmpty) {
			return const Center(child: Text('Sin datos para el grafico de torta.'));
		}

		final total = filas.fold<double>(0, (sum, f) => sum + f.monto);
		final colores = <Color>[
			Colors.teal,
			Colors.orange,
			Colors.blue,
			Colors.green,
			Colors.red,
			Colors.indigo,
		];

		return Row(
			children: <Widget>[
				Expanded(
					flex: 4,
					child: Center(
						child: AspectRatio(
							aspectRatio: 1,
							child: CustomPaint(
								painter: _PiePainter(
									valores: filas.map((f) => f.monto).toList(),
									colores: colores,
								),
								child: const SizedBox.expand(),
							),
						),
					),
				),
				const SizedBox(width: 8),
				Expanded(
					flex: 5,
					child: ListView.builder(
						itemCount: filas.length,
						itemBuilder: (_, i) {
							final fila = filas[i];
							final porcentaje = total == 0 ? 0 : (fila.monto / total) * 100;
							return Padding(
								padding: const EdgeInsets.symmetric(vertical: 4),
								child: Row(
									children: <Widget>[
										Container(
											width: 12,
											height: 12,
											color: colores[i % colores.length],
										),
										const SizedBox(width: 8),
										Expanded(
											child: Text(
												'${fila.nombre} (${porcentaje.toStringAsFixed(1)}%)',
												maxLines: 1,
												overflow: TextOverflow.ellipsis,
											),
										),
									],
								),
							);
						},
					),
				),
			],
		);
	}
}

class _PiePainter extends CustomPainter {
	final List<double> valores;
	final List<Color> colores;

	_PiePainter({required this.valores, required this.colores});

	@override
	void paint(Canvas canvas, Size size) {
		final total = valores.fold<double>(0, (sum, item) => sum + item);
		if (total <= 0) {
			return;
		}

		final diametro = math.min(size.width, size.height);
		final left = (size.width - diametro) / 2;
		final top = (size.height - diametro) / 2;
		final rect = Rect.fromLTWH(left, top, diametro, diametro);
		var anguloInicio = -math.pi / 2;

		for (var i = 0; i < valores.length; i += 1) {
			final barrido = (valores[i] / total) * 2 * math.pi;
			final paint = Paint()
				..style = PaintingStyle.fill
				..color = colores[i % colores.length];

			canvas.drawArc(rect, anguloInicio, barrido, true, paint);
			anguloInicio += barrido;
		}
	}

	@override
	bool shouldRepaint(covariant _PiePainter oldDelegate) {
		return oldDelegate.valores != valores;
	}
}

class _BarChartMensual extends StatelessWidget {
	final List<_PuntoMensual> puntos;

	const _BarChartMensual({required this.puntos});

	@override
	Widget build(BuildContext context) {
		if (puntos.isEmpty) {
			return const Center(child: Text('Sin datos para el grafico mensual.'));
		}

		final maximo = puntos.fold<double>(0, (m, p) => p.monto > m ? p.monto : m);
		final color = Theme.of(context).colorScheme.primary;

		return Row(
			crossAxisAlignment: CrossAxisAlignment.end,
			children: puntos.map((punto) {
				final factor = maximo == 0 ? 0.0 : punto.monto / maximo;
				final mesLabel = punto.mes.substring(2).replaceFirst('-', '/');

				return Expanded(
					child: Padding(
						padding: const EdgeInsets.symmetric(horizontal: 4),
						child: Column(
							mainAxisAlignment: MainAxisAlignment.end,
							children: <Widget>[
								Text(
									'\$${punto.monto.toStringAsFixed(0)}',
									style: const TextStyle(fontSize: 10),
									maxLines: 1,
									overflow: TextOverflow.ellipsis,
								),
								const SizedBox(height: 6),
								AnimatedContainer(
									duration: const Duration(milliseconds: 450),
									curve: Curves.easeOut,
									height: 140 * factor.clamp(0.0, 1.0),
									decoration: BoxDecoration(
										color: color.withValues(alpha: 0.8),
										borderRadius: BorderRadius.circular(8),
									),
								),
								const SizedBox(height: 6),
								Text(mesLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
							],
						),
					),
				);
			}).toList(),
		);
	}
}

class _FiltroTiempo {
	final String etiqueta;
	final Duration? duracion;

	const _FiltroTiempo({required this.etiqueta, required this.duracion});
}

class _Acumulador {
	int cantidad = 0;
	double monto = 0;

	void agregar(int cantidadNueva, double montoNuevo) {
		cantidad += cantidadNueva;
		monto += montoNuevo;
	}
}

class _AcumuladorDouble {
	double cantidad = 0;
	double monto = 0;

	void agregar(double cantidadNueva, double montoNuevo) {
		cantidad += cantidadNueva;
		monto += montoNuevo;
	}
}

class _RegistroItem {
	final String ticketId;
	final DateTime fecha;
	final String comercio;
	final String producto;
	final String rubro;
	final int cantidad;
	final double total;
	final String unidadMedida;
	final bool esProductoSuelto;

	const _RegistroItem({
		required this.ticketId,
		required this.fecha,
		required this.comercio,
		required this.producto,
		required this.rubro,
		required this.cantidad,
		required this.total,
		required this.unidadMedida,
		required this.esProductoSuelto,
	});
}

class _RankingFila {
	final String nombre;
	final int cantidad;
	final double monto;

	const _RankingFila({required this.nombre, required this.cantidad, required this.monto});
}

class _PuntoMensual {
	final String mes;
	final double monto;
	final DateTime fechaOrden;

	const _PuntoMensual({required this.mes, required this.monto, required this.fechaOrden});
}

enum _AgrupacionTemporal {
	dia,
	semana,
	quincena,
	mes,
	anio,
}

class _RankingMedidoFila {
	final String nombre;
	final double cantidad;
	final double monto;

	const _RankingMedidoFila({required this.nombre, required this.cantidad, required this.monto});
}

class _ReporteData {
	final int comprasTotal;
	final int itemsTotal;
	final int unidadesTotal;
	final double montoTotal;
	final double promedioTicket;
	final List<_RankingFila> topProductos;
	final List<_RankingMedidoFila> topSueltosKg;
	final List<_RankingMedidoFila> topSueltosLitros;
	final List<_RankingFila> topComercios;
	final List<_RankingFila> topRubros;
	final List<_RankingFila> pieRubros;
	final List<_PuntoMensual> evolucionMensual;

	const _ReporteData({
		required this.comprasTotal,
		required this.itemsTotal,
		required this.unidadesTotal,
		required this.montoTotal,
		required this.promedioTicket,
		required this.topProductos,
		required this.topSueltosKg,
		required this.topSueltosLitros,
		required this.topComercios,
		required this.topRubros,
		required this.pieRubros,
		required this.evolucionMensual,
	});

	factory _ReporteData.empty() {
		return const _ReporteData(
			comprasTotal: 0,
			itemsTotal: 0,
			unidadesTotal: 0,
			montoTotal: 0,
			promedioTicket: 0,
			topProductos: <_RankingFila>[],
			topSueltosKg: <_RankingMedidoFila>[],
			topSueltosLitros: <_RankingMedidoFila>[],
			topComercios: <_RankingFila>[],
			topRubros: <_RankingFila>[],
			pieRubros: <_RankingFila>[],
			evolucionMensual: <_PuntoMensual>[],
		);
	}
}
