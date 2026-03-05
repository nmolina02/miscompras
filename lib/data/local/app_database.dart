import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _databaseName = 'supermercado_mobile.db';
  static const _databaseVersion = 1;

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

  Future<void> _migrateSchema(Database db, int oldVersion) async {
    if (oldVersion < 1) {
      await db.execute('DROP TABLE IF EXISTS item_ticket');
      await db.execute('DROP TABLE IF EXISTS ticket');
      await db.execute('DROP TABLE IF EXISTS producto');
      await db.execute('DROP TABLE IF EXISTS comercio');
      await db.execute('DROP TABLE IF EXISTS rubro');
      await _createSchema(db);
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
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
        ticket_id INTEGER NOT NULL,
        producto_id TEXT NOT NULL,
        cantidad INTEGER NOT NULL,
        precio_unitario_aplicado REAL NOT NULL,
        cantidad_descuento INTEGER NOT NULL DEFAULT 0,
        precio_descuento REAL NOT NULL DEFAULT 0,
        total_item REAL NOT NULL,
        FOREIGN KEY(ticket_id) REFERENCES ticket(id)
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
