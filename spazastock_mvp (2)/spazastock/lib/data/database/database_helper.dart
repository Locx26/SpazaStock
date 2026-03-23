// lib/data/database/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';

final _log = Logger();

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  static const String _dbName = 'spazastock.db';
  static const int _dbVersion = 1;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    _log.i('Opening database at $path');
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    _log.i('Creating database tables...');
    await db.execute(_createProductsTable);
    await db.execute(_createNfcTagsTable);
    await db.execute(_createSalesTable);
    await db.execute(_createStockMovementsTable);
    await db.execute(_createSyncQueueTable);
    await db.execute(_createProductsIndex);
    await db.execute(_createSyncQueueIndex);
    _log.i('Database tables created');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _log.w('Upgrading database from $oldVersion to $newVersion');
    // Future migrations go here
  }

  // ── DDL ─────────────────────────────────────────────────────────────────────

  static const String _createProductsTable = '''
    CREATE TABLE products (
      id                   TEXT PRIMARY KEY,
      name                 TEXT NOT NULL,
      name_setswana        TEXT NOT NULL DEFAULT '',
      sku                  TEXT UNIQUE,
      category             TEXT NOT NULL DEFAULT 'General',
      price                REAL NOT NULL DEFAULT 0.0,
      cost_price           REAL NOT NULL DEFAULT 0.0,
      quantity             INTEGER NOT NULL DEFAULT 0,
      low_stock_threshold  INTEGER NOT NULL DEFAULT 5,
      expiry_date          TEXT,
      nfc_tag_id           TEXT,
      image_path           TEXT,
      is_active            INTEGER NOT NULL DEFAULT 1,
      synced               INTEGER NOT NULL DEFAULT 0,
      created_at           TEXT NOT NULL,
      updated_at           TEXT NOT NULL
    )
  ''';

  static const String _createNfcTagsTable = '''
    CREATE TABLE nfc_tags (
      id          TEXT PRIMARY KEY,
      tag_uid     TEXT NOT NULL UNIQUE,
      product_id  TEXT,
      written_at  TEXT NOT NULL,
      is_active   INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY (product_id) REFERENCES products(id)
    )
  ''';

  static const String _createSalesTable = '''
    CREATE TABLE sales (
      id              TEXT PRIMARY KEY,
      product_id      TEXT NOT NULL,
      product_name    TEXT NOT NULL,
      quantity_sold   INTEGER NOT NULL DEFAULT 1,
      unit_price      REAL NOT NULL,
      total_amount    REAL NOT NULL,
      payment_method  TEXT NOT NULL DEFAULT 'cash',
      payment_ref     TEXT,
      synced          INTEGER NOT NULL DEFAULT 0,
      sold_at         TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES products(id)
    )
  ''';

  static const String _createStockMovementsTable = '''
    CREATE TABLE stock_movements (
      id              TEXT PRIMARY KEY,
      product_id      TEXT NOT NULL,
      movement_type   TEXT NOT NULL,
      quantity_delta  INTEGER NOT NULL,
      reason          TEXT NOT NULL DEFAULT '',
      reference_id    TEXT,
      synced          INTEGER NOT NULL DEFAULT 0,
      moved_at        TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES products(id)
    )
  ''';

  static const String _createSyncQueueTable = '''
    CREATE TABLE sync_queue (
      id            TEXT PRIMARY KEY,
      entity_type   TEXT NOT NULL,
      entity_id     TEXT NOT NULL,
      operation     TEXT NOT NULL,
      payload_json  TEXT NOT NULL,
      retry_count   INTEGER NOT NULL DEFAULT 0,
      status        TEXT NOT NULL DEFAULT 'pending',
      queued_at     TEXT NOT NULL,
      last_attempt  TEXT
    )
  ''';

  static const String _createProductsIndex =
      'CREATE INDEX idx_products_sku ON products(sku)';
  static const String _createSyncQueueIndex =
      'CREATE INDEX idx_sync_queue_status ON sync_queue(status)';

  // ── Utility ────────────────────────────────────────────────────────────────

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sync_queue');
      await txn.delete('stock_movements');
      await txn.delete('sales');
      await txn.delete('nfc_tags');
      await txn.delete('products');
    });
  }
}
