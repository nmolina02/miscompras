import 'package:mi_compra_mayorista/data/local/app_database.dart';
import 'package:mi_compra_mayorista/data/local/producto_repository.dart';
import 'package:mi_compra_mayorista/data/local/ticket_repository.dart';
import 'package:mi_compra_mayorista/domain/entities/item_ticket.dart';
import 'package:mi_compra_mayorista/domain/entities/producto.dart';
import 'package:mi_compra_mayorista/domain/entities/rubro.dart';
import 'package:mi_compra_mayorista/presentation/screens/actions/new_buying_screen/widgets/item_ticket_usuario.dart';
import 'package:sqflite/sqflite.dart';

class ItemTicketRepository {
  ItemTicketRepository._();

  static final ItemTicketRepository instance = ItemTicketRepository._();

  final ProductoRepository _productoRepository = ProductoRepository.instance;
  final TicketTableRepository _ticketRepository = TicketTableRepository.instance;

  int _parseIntId(String id) => int.parse(id.trim());

  Future<DatabaseExecutor> _executor(DatabaseExecutor? executor) async {
    return executor ?? await AppDatabase.instance.database;
  }

  Future<int> create(ItemTicket item, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    await _productoRepository.create(item.producto, executor: db);

    final total = item.cantidad >= item.cantidadDescuento && item.precioDescuento > 0
        ? item.cantidad * item.precioDescuento
        : item.cantidad * item.precioUnitarioAplicado;

    return db.insert(
      'item_ticket',
      {
        'ticket_id': item.ticket.id.trim(),
        'producto_id': item.producto.codigoDeBarras.trim(),
        'cantidad': item.cantidad,
        'precio_unitario_aplicado': item.precioUnitarioAplicado,
        'cantidad_descuento': item.cantidadDescuento,
        'precio_descuento': item.precioDescuento,
        'total_item': total,
      },
    );
  }

  Future<ItemTicket?> getById(String itemId, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final rows = await db.rawQuery(
      '''
      SELECT it.id, it.ticket_id, it.producto_id, it.cantidad,
             it.precio_unitario_aplicado, it.cantidad_descuento, it.precio_descuento,
             p.nombre AS producto_nombre,
             r.id AS rubro_id, r.nombre AS rubro_nombre
      FROM item_ticket it
      INNER JOIN producto p ON p.codigo_barras = it.producto_id
      LEFT JOIN rubro r ON r.id = p.rubro_id
      WHERE it.id = ?
      LIMIT 1
      ''',
      [_parseIntId(itemId)],
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    final ticket = await _ticketRepository.getById((row['ticket_id'] as String?) ?? '', executor: db);
    if (ticket == null) {
      return null;
    }

    final rubroId = row['rubro_id'];
    final rubro = rubroId == null
        ? null
        : Rubro(
            id: (rubroId as int).toString(),
            nombre: (row['rubro_nombre'] as String?) ?? '',
          );

    return ItemTicket(
      id: (row['id'] as int).toString(),
      ticket: ticket,
      producto: Producto(
        codigoDeBarras: (row['producto_id'] as String?) ?? '',
        nombre: (row['producto_nombre'] as String?) ?? '',
        rubro: rubro,
      ),
      cantidad: ((row['cantidad'] as num?) ?? 0).toInt(),
      precioUnitarioAplicado: ((row['precio_unitario_aplicado'] as num?) ?? 0).toDouble(),
      cantidadDescuento: ((row['cantidad_descuento'] as num?) ?? 0).toInt(),
      precioDescuento: ((row['precio_descuento'] as num?) ?? 0).toDouble(),
    );
  }

  Future<List<ItemTicket>> listByTicketId(String ticketId, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final ticket = await _ticketRepository.getById(ticketId, executor: db);
    if (ticket == null) {
      return [];
    }

    final rows = await db.rawQuery(
      '''
      SELECT it.id, it.ticket_id, it.producto_id, it.cantidad,
             it.precio_unitario_aplicado, it.cantidad_descuento, it.precio_descuento,
             p.nombre AS producto_nombre,
             r.id AS rubro_id, r.nombre AS rubro_nombre
      FROM item_ticket it
      INNER JOIN producto p ON p.codigo_barras = it.producto_id
      LEFT JOIN rubro r ON r.id = p.rubro_id
      WHERE it.ticket_id = ?
      ORDER BY it.id ASC
      ''',
      [ticketId.trim()],
    );

    return rows.map((row) {
      final rubroId = row['rubro_id'];
      final rubro = rubroId == null
          ? null
          : Rubro(
              id: (rubroId as int).toString(),
              nombre: (row['rubro_nombre'] as String?) ?? '',
            );

      return ItemTicket(
        id: (row['id'] as int).toString(),
        ticket: ticket,
        producto: Producto(
          codigoDeBarras: (row['producto_id'] as String?) ?? '',
          nombre: (row['producto_nombre'] as String?) ?? '',
          rubro: rubro,
        ),
        cantidad: ((row['cantidad'] as num?) ?? 0).toInt(),
        precioUnitarioAplicado: ((row['precio_unitario_aplicado'] as num?) ?? 0).toDouble(),
        cantidadDescuento: ((row['cantidad_descuento'] as num?) ?? 0).toInt(),
        precioDescuento: ((row['precio_descuento'] as num?) ?? 0).toDouble(),
      );
    }).toList();
  }

  Future<bool> update(ItemTicket item, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    await _productoRepository.create(item.producto, executor: db);

    final total = item.cantidad >= item.cantidadDescuento && item.precioDescuento > 0
        ? item.cantidad * item.precioDescuento
        : item.cantidad * item.precioUnitarioAplicado;

    final count = await db.update(
      'item_ticket',
      {
        'ticket_id': item.ticket.id.trim(),
        'producto_id': item.producto.codigoDeBarras.trim(),
        'cantidad': item.cantidad,
        'precio_unitario_aplicado': item.precioUnitarioAplicado,
        'cantidad_descuento': item.cantidadDescuento,
        'precio_descuento': item.precioDescuento,
        'total_item': total,
      },
      where: 'id = ?',
      whereArgs: [_parseIntId(item.id)],
    );

    return count > 0;
  }

  Future<bool> delete(String itemId, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final count = await db.delete('item_ticket', where: 'id = ?', whereArgs: [_parseIntId(itemId)]);
    return count > 0;
  }

  Future<ItemTicketUsuario?> getItemTicketUsuarioByCodigoDeBarras(String codigoDeBarras, String lugar, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final rows = await db.rawQuery(
      '''
      SELECT it.id, it.ticket_id, it.producto_id, it.cantidad,
             it.precio_unitario_aplicado, it.cantidad_descuento, it.precio_descuento,
             p.nombre AS producto_nombre,
             r.id AS rubro_id, r.nombre AS rubro_nombre
      FROM item_ticket it
      INNER JOIN ticket t ON t.ticket_datetime = it.ticket_id
      INNER JOIN comercio c ON c.id = t.comercio_id
      INNER JOIN producto p ON p.codigo_barras = it.producto_id
      LEFT JOIN rubro r ON r.id = p.rubro_id
      WHERE it.producto_id = ?
        AND LOWER(TRIM(c.nombre)) = LOWER(TRIM(?))
      ORDER BY it.id DESC
      ''',
      [codigoDeBarras.trim(), lugar.trim()],
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    final ticket = await _ticketRepository.getById((row['ticket_id'] as String?) ?? '', executor: db);
    if (ticket == null) {
      return null;
    }

    return ItemTicketUsuario(
      nombre: (row['producto_nombre'] as String?) ?? '',
      codigoDeBarras: (row['producto_id'] as String?) ?? '',
      rubro: (row['rubro_nombre'] as String?) ?? '',
      cantidad: ((row['cantidad'] as num?) ?? 0).toInt(),
      precioUnitarioParametro: ((row['precio_unitario_aplicado'] as num?) ?? 0).toDouble(),
      cantidadDescuento: ((row['cantidad_descuento'] as num?) ?? 0).toInt(),
      precioDescuentoParametro: ((row['precio_descuento'] as num?) ?? 0).toDouble(),
    );
  }
}