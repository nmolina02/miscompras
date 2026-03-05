import 'package:mi_compra_mayorista/data/local/app_database.dart';
import 'package:mi_compra_mayorista/data/local/comercio_repository.dart';
import 'package:mi_compra_mayorista/data/local/item_ticket_repository.dart';
import 'package:mi_compra_mayorista/data/local/producto_repository.dart';
import 'package:mi_compra_mayorista/data/local/rubro_repository.dart';
import 'package:mi_compra_mayorista/data/local/ticket_repository.dart';
import 'package:sqflite/sqflite.dart';

class Compra {
  final int ticketId;
  final String fecha;
  final String comercio;
  final double importeTotal;
  final bool confirmado;
  final double montoRealPagado;
  final double recargoAplicado;

  const Compra({
    required this.ticketId,
    required this.fecha,
    required this.comercio,
    required this.importeTotal,
    this.confirmado = false,
    this.montoRealPagado = 0.0,
    this.recargoAplicado = 0.0,
  });

  factory Compra.fromRow(Map<String, Object?> row) {
    return Compra(
      ticketId: row['id'] as int,
      fecha: (row['fecha'] as String?) ?? '',
      comercio: (row['comercio'] as String?) ?? '',
      importeTotal: ((row['importe_total'] as num?) ?? 0).toDouble(),
      confirmado: (row['confirmacion_status'] as int?) == 1,
      montoRealPagado: ((row['monto_real_pagado'] as num?) ?? 0).toDouble(),
      recargoAplicado: ((row['recargo_aplicado'] as num?) ?? 0).toDouble()
    );
  }
}

class CompraRepository {
  CompraRepository._();

  static final CompraRepository instance = CompraRepository._();

  final RubroRepository rubroRepository = RubroRepository.instance;
  final ComercioRepository comercioRepository = ComercioRepository.instance;
  final ProductoRepository productoRepository = ProductoRepository.instance;
  final TicketTableRepository ticketTableRepository = TicketTableRepository.instance;
  final ItemTicketRepository itemTicketRepository = ItemTicketRepository.instance;

  Future<void> resetDatabase() => AppDatabase.instance.resetDatabase();

  Future<bool> guardarCompra({
    required String comercio,
    required String fecha,
    required double importeTotal,
    required List<Map<String, dynamic>> items,
  }) async {
    final comercioLimpio = comercio.trim();
    if (comercioLimpio.isEmpty || items.isEmpty || importeTotal <= 0) {
      return false;
    }

    final db = await AppDatabase.instance.database;

    await db.transaction((txn) async {
      final comercioId = await comercioRepository.upsertByNombre(comercioLimpio, executor: txn);

      final ticketId = await txn.insert(
        'ticket',
        {
          'comercio_id': comercioId,
          'fecha': fecha,
          'importe_total': importeTotal,
          'recargo_aplicado': 0,
          'confirmacion_status': 0,
        },
      );

      for (var index = 0; index < items.length; index += 1) {
        final item = items[index];

        final rubroLimpio = (item['rubro'] as String? ?? '').trim();
        final rubroId = await rubroRepository.upsertByNombre(rubroLimpio, executor: txn);

        final nombre = (item['nombre'] as String? ?? '').trim();
        final codigo = (item['codigo_barras'] as String? ?? '').trim();
        final codigoPersistir = codigo.isEmpty ? 'SIN-CODIGO-$ticketId-$index' : codigo;
        final nombrePersistir = nombre.isEmpty ? 'Producto sin nombre' : nombre;

        await txn.insert(
          'producto',
          {
            'codigo_barras': codigoPersistir,
            'nombre': nombrePersistir,
            'rubro_id': rubroId,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        await txn.update(
          'producto',
          {'nombre': nombrePersistir},
          where: 'codigo_barras = ?',
          whereArgs: [codigoPersistir],
        );

        final cantidad = (item['cantidad'] as num?)?.toInt() ?? 0;
        final precioUnitario = (item['precio_unitario'] as num?)?.toDouble() ?? 0;
        final cantidadDescuento = (item['cantidad_descuento'] as num?)?.toInt() ?? 0;
        final precioDescuento = (item['precio_descuento'] as num?)?.toDouble() ?? 0;
        final total = (item['total_item'] as num?)?.toDouble() ?? 0;

        await txn.insert('item_ticket', {
          'ticket_id': ticketId,
          'producto_id': codigoPersistir,
          'cantidad': cantidad,
          'precio_unitario_aplicado': precioUnitario,
          'cantidad_descuento': cantidadDescuento,
          'precio_descuento': precioDescuento,
          'total_item': total,
        });
      }
    });

    return true;
  }

  Future<List<Compra>> listarComprasPendientes() async {
    final rows = await ticketTableRepository.listPendientesRows();
    return rows.map(Compra.fromRow).toList();
  }

  Future<List<Compra>> listarCompras() async {
    final tickets = await ticketTableRepository.list();

    return tickets
        .map(
          (ticket) => Compra(
            ticketId: int.tryParse(ticket.id) ?? 0,
            fecha: ticket.fecha.toIso8601String(),
            comercio: ticket.comercio.nombre,
            importeTotal: ticket.importeTotal,
            confirmado: ticket.confirmacionStatus == 1,
            montoRealPagado: ticket.importeRealPagado,
            recargoAplicado: ticket.recargoAplicado,
          ),
        )
        .where((compra) => compra.ticketId > 0)
        .toList();
  }

  Future<int> eliminarComprasPorTicketIds(List<int> ticketIds) async {
    if (ticketIds.isEmpty) {
      return 0;
    }

    final idsUnicos = ticketIds.toSet().where((id) => id > 0).toList();
    if (idsUnicos.isEmpty) {
      return 0;
    }

    final db = await AppDatabase.instance.database;

    return db.transaction<int>((txn) async {
      var eliminados = 0;

      for (final ticketId in idsUnicos) {
        final ok = await ticketTableRepository.delete(
          ticketId.toString(),
          executor: txn,
        );

        if (ok) {
          eliminados += 1;
        }
      }

      return eliminados;
    });
  }

  Future<bool> confirmarCompra({required int ticketId, double? montoRealPagado}) {
    return ticketTableRepository.confirmarCompra(
      ticketId: ticketId,
      montoRealPagado: montoRealPagado,
    );
  }

  Future<String?> buscarNombreProductoPorCodigo(String codigo) {
    return productoRepository.buscarNombreProductoPorCodigo(codigo);
  }
}
