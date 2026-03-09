import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _databaseName = 'supermercado_mobile.db';
    static const _databaseVersion = 3;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async => _migrateSchema(db, oldVersion),
    );

    return _database!;
  }

  Future<void> resetDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _databaseName);
    await deleteDatabase(path);
  }

  Future<String> exportDatabaseToDeviceStorage() async {
    final dbPath = await getDatabasesPath();
    final sourcePath = p.join(dbPath, _databaseName);
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('No se encontro la base de datos local para exportar.');
    }

    final targetDir = await _resolveBackupDirectory();
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final backupName = 'supermercado_backup_$stamp.db';
    final targetPath = p.join(targetDir.path, backupName);

    await sourceFile.copy(targetPath);
    return targetPath;
  }

  Future<void> importDatabaseFromPath(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('El archivo seleccionado no existe.');
    }

    final sourceDb = await openDatabase(sourcePath, readOnly: true);
    try {
      await _validateCompatibleSchema(sourceDb);

      final sourceRubros = await sourceDb.query('rubro');
      final sourceComercios = await sourceDb.query('comercio');
      final sourceProductos = await sourceDb.query('producto');
      final sourceTickets = await sourceDb.query('ticket');
      final sourceItems = await sourceDb.query('item_ticket');

      final targetDb = await database;
      await targetDb.transaction((txn) async {
        final rubroBySourceId = <int, int>{};
        for (final row in sourceRubros) {
          final sourceId = (row['id'] as num?)?.toInt();
          final nombre = (row['nombre'] as String? ?? '').trim();
          if (nombre.isEmpty) {
            continue;
          }

          await txn.insert(
            'rubro',
            {'nombre': nombre},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          final target = await txn.query(
            'rubro',
            columns: ['id'],
            where: 'LOWER(TRIM(nombre)) = LOWER(TRIM(?))',
            whereArgs: [nombre],
            limit: 1,
          );

          if (sourceId != null && target.isNotEmpty) {
            rubroBySourceId[sourceId] = ((target.first['id'] as num?) ?? 0).toInt();
          }
        }

        final comercioBySourceId = <int, int>{};
        for (final row in sourceComercios) {
          final sourceId = (row['id'] as num?)?.toInt();
          final nombre = (row['nombre'] as String? ?? '').trim();
          if (nombre.isEmpty) {
            continue;
          }

          await txn.insert(
            'comercio',
            {'nombre': nombre},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          final target = await txn.query(
            'comercio',
            columns: ['id'],
            where: 'LOWER(TRIM(nombre)) = LOWER(TRIM(?))',
            whereArgs: [nombre],
            limit: 1,
          );

          if (sourceId != null && target.isNotEmpty) {
            comercioBySourceId[sourceId] = ((target.first['id'] as num?) ?? 0).toInt();
          }
        }

        for (final row in sourceProductos) {
          final codigo = (row['codigo_barras'] as String? ?? '').trim();
          final nombre = (row['nombre'] as String? ?? '').trim();
          if (codigo.isEmpty || nombre.isEmpty) {
            continue;
          }

          final sourceRubroId = (row['rubro_id'] as num?)?.toInt();
          final targetRubroId = sourceRubroId == null ? null : rubroBySourceId[sourceRubroId];

          await txn.insert(
            'producto',
            {
              'codigo_barras': codigo,
              'nombre': nombre,
              'rubro_id': targetRubroId,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        for (final row in sourceTickets) {
          final ticketId = _readTicketPrimaryKey(row);
          if (ticketId.isEmpty) {
            continue;
          }

          final sourceComercioId = (row['comercio_id'] as num?)?.toInt();
          final targetComercioId = sourceComercioId == null ? null : comercioBySourceId[sourceComercioId];
          if (targetComercioId == null) {
            continue;
          }

          await txn.insert(
            'ticket',
            {
              'ticket_datetime': ticketId,
              'comercio_id': targetComercioId,
              'fecha': (row['fecha'] as String?) ?? DateTime.now().toIso8601String(),
              'importe_total': ((row['importe_total'] as num?) ?? 0).toDouble(),
              'recargo_aplicado': ((row['recargo_aplicado'] as num?) ?? 0).toDouble(),
              'monto_real_pagado': (row['monto_real_pagado'] as num?)?.toDouble(),
              'confirmacion_status': ((row['confirmacion_status'] as num?) ?? 0).toInt(),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        for (final row in sourceItems) {
          final ticketId = (row['ticket_id'] as String? ?? '').trim();
          final productoId = (row['producto_id'] as String? ?? '').trim();
          if (ticketId.isEmpty || productoId.isEmpty) {
            continue;
          }

          final ticketExists = await txn.query(
            'ticket',
            columns: ['ticket_datetime'],
            where: 'ticket_datetime = ?',
            whereArgs: [ticketId],
            limit: 1,
          );
          if (ticketExists.isEmpty) {
            continue;
          }

          final productoExists = await txn.query(
            'producto',
            columns: ['codigo_barras'],
            where: 'codigo_barras = ?',
            whereArgs: [productoId],
            limit: 1,
          );
          if (productoExists.isEmpty) {
            continue;
          }

          final duplicate = await txn.query(
            'item_ticket',
            columns: ['id'],
            where:
                'ticket_id = ? AND producto_id = ? AND cantidad = ? AND unidad_medida = ? AND precio_unitario_aplicado = ? AND cantidad_descuento = ? AND precio_descuento = ? AND total_item = ?',
            whereArgs: [
              ticketId,
              productoId,
              ((row['cantidad'] as num?) ?? 0).toInt(),
              ((row['unidad_medida'] as String?) ?? 'unidad').trim().isEmpty
                  ? 'unidad'
                  : ((row['unidad_medida'] as String?) ?? 'unidad').trim(),
              ((row['precio_unitario_aplicado'] as num?) ?? 0).toDouble(),
              ((row['cantidad_descuento'] as num?) ?? 0).toInt(),
              ((row['precio_descuento'] as num?) ?? 0).toDouble(),
              ((row['total_item'] as num?) ?? 0).toDouble(),
            ],
            limit: 1,
          );
          if (duplicate.isNotEmpty) {
            continue;
          }

          await txn.insert(
            'item_ticket',
            {
              'ticket_id': ticketId,
              'producto_id': productoId,
              'cantidad': ((row['cantidad'] as num?) ?? 0).toInt(),
                'unidad_medida': ((row['unidad_medida'] as String?) ?? 'unidad').trim().isEmpty
                  ? 'unidad'
                  : ((row['unidad_medida'] as String?) ?? 'unidad').trim(),
              'precio_unitario_aplicado': ((row['precio_unitario_aplicado'] as num?) ?? 0).toDouble(),
              'cantidad_descuento': ((row['cantidad_descuento'] as num?) ?? 0).toInt(),
              'precio_descuento': ((row['precio_descuento'] as num?) ?? 0).toDouble(),
              'total_item': ((row['total_item'] as num?) ?? 0).toDouble(),
            },
          );
        }
      });
    } finally {
      await sourceDb.close();
    }
  }

  Future<Directory> _resolveBackupDirectory() async {
    if (Platform.isAndroid) {
      final candidates = <String>[
        '/storage/emulated/0/Download/MiCompraMayorista',
        '/sdcard/Download/MiCompraMayorista',
      ];

      for (final candidatePath in candidates) {
        final dir = Directory(candidatePath);
        if (await _canWriteDirectory(dir)) {
          return dir;
        }
      }
    }

    final appDocs = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDocs.path, 'backups_db'));
  }

  Future<bool> _canWriteDirectory(Directory dir) async {
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final probeFile = File(p.join(dir.path, '.write_probe'));
      await probeFile.writeAsString('ok', flush: true);
      if (await probeFile.exists()) {
        await probeFile.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _validateCompatibleSchema(Database db) async {
    final expected = <String, Set<String>>{
      'rubro': {'id', 'nombre'},
      'comercio': {'id', 'nombre'},
      'producto': {'codigo_barras', 'nombre', 'rubro_id'},
      'ticket': {
        'ticket_datetime',
        'comercio_id',
        'fecha',
        'importe_total',
        'recargo_aplicado',
        'monto_real_pagado',
        'confirmacion_status',
      },
      'item_ticket': {
        'id',
        'ticket_id',
        'producto_id',
        'cantidad',
        'unidad_medida',
        'precio_unitario_aplicado',
        'cantidad_descuento',
        'precio_descuento',
        'total_item',
      },
    };

    for (final entry in expected.entries) {
      final table = entry.key;
      final rows = await db.rawQuery('PRAGMA table_info($table)');
      if (rows.isEmpty) {
        throw FormatException('El archivo no contiene la tabla requerida: $table');
      }

      final present = rows
          .map((r) => (r['name'] as String?)?.trim())
          .whereType<String>()
          .toSet();

      final missing = entry.value.difference(present);
      if (table == 'ticket' && missing.length == 1 && missing.contains('ticket_datetime') && present.contains('id')) {
        continue;
      }

      if (table == 'item_ticket' && missing.length == 1 && missing.contains('unidad_medida')) {
        continue;
      }

      if (missing.isNotEmpty) {
        throw FormatException(
          'La tabla $table no coincide con el esquema esperado. Faltan columnas: ${missing.join(', ')}',
        );
      }
    }
  }

  String _readTicketPrimaryKey(Map<String, Object?> row) {
    final modern = (row['ticket_datetime'] as String?)?.trim();
    if (modern != null && modern.isNotEmpty) {
      return modern;
    }

    final legacy = row['id'];
    if (legacy is String && legacy.trim().isNotEmpty) {
      return legacy.trim();
    }
    if (legacy is num) {
      return legacy.toInt().toString();
    }
    return '';
  }

  Future<void> _migrateSchema(Database db, int oldVersion) async {
    if (oldVersion < 1) {
      await _createSchema(db);
      return;
    }

    if (oldVersion < 2) {
      await db.execute('PRAGMA foreign_keys = OFF');

      await db.execute('''
        CREATE TABLE ticket_new (
          ticket_datetime TEXT PRIMARY KEY,
          comercio_id INTEGER NOT NULL,
          fecha TEXT NOT NULL,
          importe_total REAL NOT NULL,
          recargo_aplicado REAL NOT NULL DEFAULT 0,
          monto_real_pagado REAL,
          confirmacion_status INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY(comercio_id) REFERENCES comercio(id)
            ON UPDATE CASCADE
            ON DELETE RESTRICT
        )
      ''');

      await db.execute('''
        INSERT INTO ticket_new (
          ticket_datetime,
          comercio_id,
          fecha,
          importe_total,
          recargo_aplicado,
          monto_real_pagado,
          confirmacion_status
        )
        SELECT
          CAST(id AS TEXT),
          comercio_id,
          fecha,
          importe_total,
          recargo_aplicado,
          monto_real_pagado,
          confirmacion_status
        FROM ticket
      ''');

      await db.execute('''
        CREATE TABLE item_ticket_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ticket_id TEXT NOT NULL,
          producto_id TEXT NOT NULL,
          cantidad INTEGER NOT NULL,
          precio_unitario_aplicado REAL NOT NULL,
          cantidad_descuento INTEGER NOT NULL DEFAULT 0,
          precio_descuento REAL NOT NULL DEFAULT 0,
          total_item REAL NOT NULL,
          FOREIGN KEY(ticket_id) REFERENCES ticket_new(ticket_datetime)
            ON UPDATE CASCADE
            ON DELETE CASCADE,
          FOREIGN KEY(producto_id) REFERENCES producto(codigo_barras)
            ON UPDATE CASCADE
            ON DELETE RESTRICT
        )
      ''');

      await db.execute('''
        INSERT INTO item_ticket_new (
          id,
          ticket_id,
          producto_id,
          cantidad,
          precio_unitario_aplicado,
          cantidad_descuento,
          precio_descuento,
          total_item
        )
        SELECT
          id,
          CAST(ticket_id AS TEXT),
          producto_id,
          cantidad,
          precio_unitario_aplicado,
          cantidad_descuento,
          precio_descuento,
          total_item
        FROM item_ticket
      ''');

      await db.execute('DROP TABLE item_ticket');
      await db.execute('DROP TABLE ticket');
      await db.execute('ALTER TABLE ticket_new RENAME TO ticket');
      await db.execute('ALTER TABLE item_ticket_new RENAME TO item_ticket');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_ticket_comercio_id ON ticket(comercio_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ticket_confirmacion_status ON ticket(confirmacion_status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_item_ticket_ticket_id ON item_ticket(ticket_id)');

      await db.execute('PRAGMA foreign_keys = ON');
    }

    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE item_ticket ADD COLUMN unidad_medida TEXT NOT NULL DEFAULT 'unidad'",
      );
    }
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE rubro (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE COLLATE NOCASE
      )
    ''');

    await db.execute('''
      CREATE TABLE comercio (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE COLLATE NOCASE
      )
    ''');

    await db.execute('''
      CREATE TABLE producto (
        codigo_barras TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        rubro_id INTEGER,
        FOREIGN KEY(rubro_id) REFERENCES rubro(id)
          ON UPDATE CASCADE
          ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ticket (
        ticket_datetime TEXT PRIMARY KEY,
        comercio_id INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        importe_total REAL NOT NULL,
        recargo_aplicado REAL NOT NULL DEFAULT 0,
        monto_real_pagado REAL,
        confirmacion_status INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(comercio_id) REFERENCES comercio(id)
          ON UPDATE CASCADE
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE item_ticket (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ticket_id TEXT NOT NULL,
        producto_id TEXT NOT NULL,
        cantidad INTEGER NOT NULL,
        unidad_medida TEXT NOT NULL DEFAULT 'unidad',
        precio_unitario_aplicado REAL NOT NULL,
        cantidad_descuento INTEGER NOT NULL DEFAULT 0,
        precio_descuento REAL NOT NULL DEFAULT 0,
        total_item REAL NOT NULL,
        FOREIGN KEY(ticket_id) REFERENCES ticket(ticket_datetime)
          ON UPDATE CASCADE
          ON DELETE CASCADE,
        FOREIGN KEY(producto_id) REFERENCES producto(codigo_barras)
          ON UPDATE CASCADE
          ON DELETE RESTRICT
      )
    ''');

    await db.execute('CREATE INDEX idx_producto_rubro_id ON producto(rubro_id)');
    await db.execute('CREATE INDEX idx_ticket_comercio_id ON ticket(comercio_id)');
    await db.execute('CREATE INDEX idx_ticket_confirmacion_status ON ticket(confirmacion_status)');
    await db.execute('CREATE INDEX idx_item_ticket_ticket_id ON item_ticket(ticket_id)');
  }

  // Solo util para development, borra toda la database y la vuelve a crear
  // Future<void> _dropSchema(Database db) async {
  //   await db.execute('DROP TABLE IF EXISTS item_ticket');
  //   await db.execute('DROP TABLE IF EXISTS ticket');
  //   await db.execute('DROP TABLE IF EXISTS producto');
  //   await db.execute('DROP TABLE IF EXISTS comercio');
  //   await db.execute('DROP TABLE IF EXISTS rubro');
  // }
  
}
