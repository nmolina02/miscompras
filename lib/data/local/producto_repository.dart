import 'dart:convert';

import 'package:miscompras/data/local/app_database.dart';
import 'package:miscompras/domain/entities/producto.dart';
import 'package:miscompras/domain/entities/rubro.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

class ProductoRepository {
  ProductoRepository._();

  static final ProductoRepository instance = ProductoRepository._();

  int _parseIntId(String id) => int.parse(id.trim());

  Future<DatabaseExecutor> _executor(DatabaseExecutor? executor) async {
    return executor ?? await AppDatabase.instance.database;
  }

  Future<void> create(Producto producto, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final rubroFk = producto.rubro == null ? null : _parseIntId(producto.rubro!.id);
    final codigo = producto.codigoDeBarras.trim();
    final nombre = producto.nombre.trim();

    await db.insert(
      'producto',
      {
        'codigo_barras': codigo,
        'nombre': nombre,
        'rubro_id': rubroFk,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.update(
      'producto',
      {
        'nombre': nombre,
        'rubro_id': rubroFk,
      },
      where: 'codigo_barras = ?',
      whereArgs: [codigo],
    );
  }

  Future<Producto?> getByCodigo(String codigoDeBarras, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final rows = await db.rawQuery(
      '''
      SELECT p.codigo_barras, p.nombre, r.id AS rubro_id, r.nombre AS rubro_nombre
      FROM producto p
      LEFT JOIN rubro r ON r.id = p.rubro_id
      WHERE p.codigo_barras = ?
      LIMIT 1
      ''',
      [codigoDeBarras.trim()],
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    final rubroId = row['rubro_id'];
    final rubro = rubroId == null
        ? null
        : Rubro(
            id: (rubroId as int).toString(),
            nombre: (row['rubro_nombre'] as String?) ?? '',
          );

    return Producto(
      codigoDeBarras: (row['codigo_barras'] as String?) ?? '',
      nombre: (row['nombre'] as String?) ?? '',
      rubro: rubro,
    );
  }

  Future<List<Producto>> list({DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final rows = await db.rawQuery(
      '''
      SELECT p.codigo_barras, p.nombre, r.id AS rubro_id, r.nombre AS rubro_nombre
      FROM producto p
      LEFT JOIN rubro r ON r.id = p.rubro_id
      ORDER BY p.nombre ASC
      ''',
    );

    return rows.map((row) {
      final rubroId = row['rubro_id'];
      final rubro = rubroId == null
          ? null
          : Rubro(
              id: (rubroId as int).toString(),
              nombre: (row['rubro_nombre'] as String?) ?? '',
            );

      return Producto(
        codigoDeBarras: (row['codigo_barras'] as String?) ?? '',
        nombre: (row['nombre'] as String?) ?? '',
        rubro: rubro,
      );
    }).toList();
  }

  Future<void> update(Producto producto, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final rubroFk = producto.rubro == null ? null : _parseIntId(producto.rubro!.id);

    await db.update(
      'producto',
      {
        'nombre': producto.nombre.trim(),
        'rubro_id': rubroFk,
      },
      where: 'codigo_barras = ?',
      whereArgs: [producto.codigoDeBarras.trim()],
    );
  }

  Future<bool> delete(String codigoDeBarras, {DatabaseExecutor? executor}) async {
    final db = await _executor(executor);
    final count = await db.delete(
      'producto',
      where: 'codigo_barras = ?',
      whereArgs: [codigoDeBarras.trim()],
    );
    return count > 0;
  }

  Future<String?> buscarNombreProductoPorCodigo(String codigo) async {
    final codigoLimpio = codigo.trim();
    if (codigoLimpio.isEmpty) {
      return null;
    }

    final productoLocal = await getByCodigo(codigoLimpio);
    if (productoLocal != null && productoLocal.nombre.trim().isNotEmpty) {
      return productoLocal.nombre.trim();
    }

    final nombreWeb = await _buscarNombreProductoEnWeb(codigoLimpio);
    if (nombreWeb == null || nombreWeb.isEmpty) {
      return null;
    }

    await create(
      Producto(codigoDeBarras: codigoLimpio, nombre: nombreWeb, rubro: null),
    );

    return nombreWeb;
  }

  Future<String?> _buscarNombreProductoEnWeb(String codigo) async {
    try {
      final uri = Uri.https('go-upc.com', '/search', {'q': codigo});
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'Mozilla/5.0',
          'Accept-Language': 'es-AR,es;q=0.9,en;q=0.8',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return null;
      }

      final html = utf8.decode(response.bodyBytes, allowMalformed: true);
      return _extraerNombreDesdeHtml(html);
    } catch (_) {
      return null;
    }
  }

  String? _extraerNombreDesdeHtml(String html) {
    final patterns = [
      RegExp(r'<h1[^>]*class="[^"]*product-name[^"]*"[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true),
      RegExp(r'<title>(.*?)</title>', caseSensitive: false, dotAll: true),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match == null) {
        continue;
      }

      final raw = match.group(1) ?? '';
      final sinTags = raw.replaceAll(RegExp(r'<[^>]+>'), ' ');
      final normalizado = _decodificarHtmlBasico(sinTags).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalizado.isNotEmpty) {
        return normalizado;
      }
    }

    return null;
  }

  String _decodificarHtmlBasico(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }
}
