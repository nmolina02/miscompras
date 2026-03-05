import 'package:mi_compra_mayorista/data/local/app_database.dart';
import 'package:mi_compra_mayorista/domain/entities/comercio.dart';
import 'package:sqflite/sqflite.dart';

class ComercioRepository {
	ComercioRepository._();

	static final ComercioRepository instance = ComercioRepository._();

	int _parseIntId(String id) => int.parse(id.trim());

	Future<DatabaseExecutor> _executor(DatabaseExecutor? executor) async {
		return executor ?? await AppDatabase.instance.database;
	}

	Future<int> upsertByNombre(String nombre, {DatabaseExecutor? executor}) async {
		final db = await _executor(executor);
		final limpio = nombre.trim();
		final existing = await db.query(
			'comercio',
			columns: ['id'],
			where: 'nombre = ?',
			whereArgs: [limpio],
			limit: 1,
		);

		if (existing.isNotEmpty) {
			return existing.first['id'] as int;
		}

		return db.insert('comercio', {'nombre': limpio});
	}

	Future<int> create(Comercio comercio, {DatabaseExecutor? executor}) async {
		final db = await _executor(executor);
		return db.insert(
			'comercio',
			{'nombre': comercio.nombre.trim()},
			conflictAlgorithm: ConflictAlgorithm.abort,
		);
	}

	Future<Comercio?> getById(String id, {DatabaseExecutor? executor}) async {
		final db = await _executor(executor);
		final rows = await db.query(
			'comercio',
			where: 'id = ?',
			whereArgs: [_parseIntId(id)],
			limit: 1,
		);
		if (rows.isEmpty) {
			return null;
		}

		return Comercio(
			id: (rows.first['id'] as int).toString(),
			nombre: (rows.first['nombre'] as String?) ?? '',
		);
	}

	Future<List<Comercio>> list({DatabaseExecutor? executor}) async {
		final db = await _executor(executor);
		final rows = await db.query('comercio', orderBy: 'nombre ASC');
		return rows
				.map(
					(row) => Comercio(
						id: (row['id'] as int).toString(),
						nombre: (row['nombre'] as String?) ?? '',
					),
				)
				.toList();
	}

	Future<bool> update(Comercio comercio, {DatabaseExecutor? executor}) async {
		final db = await _executor(executor);
		final count = await db.update(
			'comercio',
			{'nombre': comercio.nombre.trim()},
			where: 'id = ?',
			whereArgs: [_parseIntId(comercio.id)],
		);
		return count > 0;
	}

	Future<bool> delete(String id, {DatabaseExecutor? executor}) async {
		final db = await _executor(executor);
		final count = await db.delete(
			'comercio',
			where: 'id = ?',
			whereArgs: [_parseIntId(id)],
		);
		return count > 0;
	}
}

