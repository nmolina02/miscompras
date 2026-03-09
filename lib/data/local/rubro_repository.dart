import 'package:miscompras/data/local/app_database.dart';
import 'package:miscompras/domain/entities/rubro.dart';
import 'package:sqflite/sqflite.dart';

class RubroRepository {
	RubroRepository._();

	static final RubroRepository instance = RubroRepository._();

	int _parseIntId(String id) => int.parse(id.trim());

	Future<DatabaseExecutor> _executor(DatabaseExecutor? executor) async {
		return executor ?? await AppDatabase.instance.database;
	}

  Future<int> upsertByNombre(String nombre, {DatabaseExecutor? executor}) async {
		final db = await _executor(executor);
		final limpio = nombre.trim();
		final existing = await db.query(
			'rubro',
			columns: ['id'],
			where: 'nombre = ?',
			whereArgs: [limpio],
			limit: 1,
		);

		if (existing.isNotEmpty) {
			return existing.first['id'] as int;
		}

		return db.insert('rubro', {'nombre': limpio});
	}

	Future<int> create(Rubro rubro, {DatabaseExecutor? executor}) async {
		final db = await _executor(executor);
		return db.insert(
			'rubro',
			{'nombre': rubro.nombre.trim()},
			conflictAlgorithm: ConflictAlgorithm.abort,
		);
	}

	Future<Rubro?> getById(String id, {DatabaseExecutor? executor}) async {
		final db = await _executor(executor);
		final rows = await db.query(
			'rubro',
			where: 'id = ?',
			whereArgs: [_parseIntId(id)],
			limit: 1,
		);
		if (rows.isEmpty) {
			return null;
		}

		return Rubro(
			id: (rows.first['id'] as int).toString(),
			nombre: (rows.first['nombre'] as String?) ?? '',
		);
	}

	Future<List<Rubro>> list({DatabaseExecutor? executor}) async {
		final db = await _executor(executor);
		final rows = await db.query('rubro', orderBy: 'nombre ASC');
		return rows
				.map(
					(row) => Rubro(
						id: (row['id'] as int).toString(),
						nombre: (row['nombre'] as String?) ?? '',
					),
				)
				.toList();
	}

	Future<bool> update(Rubro rubro, {DatabaseExecutor? executor}) async {
		final db = await _executor(executor);
		final count = await db.update(
			'rubro',
			{'nombre': rubro.nombre.trim()},
			where: 'id = ?',
			whereArgs: [_parseIntId(rubro.id)],
		);
		return count > 0;
	}

	Future<bool> delete(String id, {DatabaseExecutor? executor}) async {
		final db = await _executor(executor);
		final count = await db.delete(
			'rubro',
			where: 'id = ?',
			whereArgs: [_parseIntId(id)],
		);
		return count > 0;
	}
}

