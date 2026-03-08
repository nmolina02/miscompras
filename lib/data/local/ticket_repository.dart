import 'package:mi_compra_mayorista/data/local/app_database.dart';
import 'package:mi_compra_mayorista/data/local/comercio_repository.dart';
import 'package:mi_compra_mayorista/domain/entities/comercio.dart';
import 'package:mi_compra_mayorista/domain/entities/item_ticket.dart';
import 'package:mi_compra_mayorista/domain/entities/ticket.dart';
import 'package:sqflite/sqflite.dart';

class TicketTableRepository {
  TicketTableRepository._();

  static final TicketTableRepository instance = TicketTableRepository._();

  final ComercioRepository _comercioRepository = ComercioRepository.instance;

  Future<DatabaseExecutor> _executor(DatabaseExecutor? executor) async {
    return executor ?? await AppDatabase.instance.database;
  }

  Future<String> create(Ticket ticket, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final comercioId = await _comercioRepository.upsertByNombre(
      ticket.comercio.nombre,
      executor: db,
    );

    final ticketId = ticket.id.trim().isEmpty
        ? _buildTicketDateTimeId(ticket.fecha)
        : ticket.id.trim();

    await db.insert(
      'ticket',
      {
        'ticket_datetime': ticketId,
        'comercio_id': comercioId,
        'fecha': ticket.fecha.toIso8601String(),
        'importe_total': ticket.importeTotal,
        'recargo_aplicado': ticket.recargoAplicado,
        'monto_real_pagado': ticket.importeRealPagado > 0 ? ticket.importeRealPagado : null,
        'confirmacion_status': ticket.confirmacionStatus,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return ticketId;
  }

  Future<Ticket?> getById(String ticketId, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final rows = await db.rawQuery(
      '''
            SELECT t.ticket_datetime AS id, t.fecha, t.importe_total, t.recargo_aplicado, t.monto_real_pagado,
             t.confirmacion_status, c.id AS comercio_id, c.nombre AS comercio_nombre
      FROM ticket t
      INNER JOIN comercio c ON c.id = t.comercio_id
            WHERE t.ticket_datetime = ?
      LIMIT 1
      ''',
      [ticketId.trim()],
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    return Ticket(
      id: (row['id'] as String?) ?? '',
      comercio: Comercio(
        id: (row['comercio_id'] as int).toString(),
        nombre: (row['comercio_nombre'] as String?) ?? '',
      ),
      fecha: DateTime.tryParse((row['fecha'] as String?) ?? '') ?? DateTime.now(),
      importeTotal: ((row['importe_total'] as num?) ?? 0).toDouble(),
      recargoAplicado: ((row['recargo_aplicado'] as num?) ?? 0).toDouble(),
      importeRealPagado: ((row['monto_real_pagado'] as num?) ?? 0).toDouble(),
      confirmacionStatus: ((row['confirmacion_status'] as num?) ?? 0).toInt(),
      items: <ItemTicket>[],
    );
  }

  Future<List<Ticket>> list({DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final rows = await db.rawQuery(
      '''
            SELECT t.ticket_datetime AS id, t.fecha, t.importe_total, t.recargo_aplicado, t.monto_real_pagado,
             t.confirmacion_status, c.id AS comercio_id, c.nombre AS comercio_nombre
      FROM ticket t
      INNER JOIN comercio c ON c.id = t.comercio_id
            ORDER BY t.ticket_datetime DESC
      ''',
    );

    return rows
        .map(
          (row) => Ticket(
            id: (row['id'] as String?) ?? '',
            comercio: Comercio(
              id: (row['comercio_id'] as int).toString(),
              nombre: (row['comercio_nombre'] as String?) ?? '',
            ),
            fecha: DateTime.tryParse((row['fecha'] as String?) ?? '') ?? DateTime.now(),
            importeTotal: ((row['importe_total'] as num?) ?? 0).toDouble(),
            recargoAplicado: ((row['recargo_aplicado'] as num?) ?? 0).toDouble(),
            importeRealPagado: ((row['monto_real_pagado'] as num?) ?? 0).toDouble(),
            confirmacionStatus: ((row['confirmacion_status'] as num?) ?? 0).toInt(),
            items: <ItemTicket>[],
          ),
        )
        .toList();
  }

  Future<List<Map<String, Object?>>> listPendientesRows({DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    return db.rawQuery(
      '''
      SELECT t.ticket_datetime AS id, t.fecha, t.importe_total, c.nombre AS comercio
      FROM ticket t
      INNER JOIN comercio c ON c.id = t.comercio_id
      WHERE t.confirmacion_status = 0
      ORDER BY t.ticket_datetime DESC
      ''',
    );
  }

  Future<bool> confirmarCompra({
    required String ticketId,
    double? montoRealPagado,
    DatabaseExecutor? executor,
  }) async {
    final db = await _executor(executor);

    final rows = await db.query(
      'ticket',
      columns: ['ticket_datetime', 'importe_total'],
      where: 'ticket_datetime = ?',
      whereArgs: [ticketId.trim()],
      limit: 1,
    );

    if (rows.isEmpty) {
      return false;
    }

    final importeTotal = ((rows.first['importe_total'] as num?) ?? 0).toDouble();
    final monto = montoRealPagado ?? importeTotal;
    if (monto <= 0) {
      return false;
    }

    final updatedCount = await db.update(
      'ticket',
      {
        'confirmacion_status': 1,
        'monto_real_pagado': monto,
        'recargo_aplicado': monto - importeTotal,
      },
      where: 'ticket_datetime = ?',
      whereArgs: [ticketId.trim()],
    );

    return updatedCount > 0;
  }

  Future<bool> update(Ticket ticket, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final comercioId = await _comercioRepository.upsertByNombre(
      ticket.comercio.nombre,
      executor: db,
    );

    final count = await db.update(
      'ticket',
      {
        'comercio_id': comercioId,
        'fecha': ticket.fecha.toIso8601String(),
        'importe_total': ticket.importeTotal,
        'recargo_aplicado': ticket.recargoAplicado,
        'monto_real_pagado': ticket.importeRealPagado > 0 ? ticket.importeRealPagado : null,
        'confirmacion_status': ticket.confirmacionStatus,
      },
      where: 'ticket_datetime = ?',
      whereArgs: [ticket.id.trim()],
    );

    return count > 0;
  }

  Future<bool> delete(String ticketId, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final count = await db.delete('ticket', where: 'ticket_datetime = ?', whereArgs: [ticketId.trim()]);
    return count > 0;
  }

  String _buildTicketDateTimeId(DateTime dateTime) {
    final d = dateTime.toUtc();
    return '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}_'
        '${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}'
        '${d.second.toString().padLeft(2, '0')}'
        '${d.millisecond.toString().padLeft(3, '0')}'
        '${d.microsecond.toString().padLeft(3, '0')}';
  }
}
