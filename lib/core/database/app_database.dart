import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const schemaVersion = 14;
  static const backupFormatVersion = 1;
  static const appVersion = '1.0.0';

  AppDatabase._();
  static final instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final directory = await getApplicationDocumentsDirectory();
    final databasePath = path.join(directory.path, 'inventory_app.db');
    return openDatabase(
      databasePath,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createProductsTable(db);
        await _createPurchaseTables(db);
        await _createSalesTable(db);
        await _createPriceHistoryTable(db);
        await _createMetadataTable(db);
        await _createIndexes(db);
        await _createFinancialTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createProductsTable(db);
        if (oldVersion < 3) await _createPurchaseTables(db);
        if (oldVersion < 4) await _createSalesTable(db);
        if (oldVersion < 5) await _createPriceHistoryTable(db);
        if (oldVersion < 6) await _createMetadataTable(db);
        if (oldVersion < 7) await _createIndexes(db);
        if (oldVersion < 8) {
          await db.execute(
            'ALTER TABLE products ADD COLUMN description TEXT NULL',
          );
          await db.execute(
            "ALTER TABLE products ADD COLUMN unit TEXT NOT NULL DEFAULT 'item'",
          );
          await db.execute(
            'ALTER TABLE products ADD COLUMN amount INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE products ADD COLUMN cost_price INTEGER NULL',
          );
          await db.execute(
            'ALTER TABLE products ADD COLUMN sale_price INTEGER NULL',
          );
        }
        if (oldVersion < 9) {
          await db.execute(
            'ALTER TABLE products ADD COLUMN restock_level INTEGER NOT NULL DEFAULT 10',
          );
        }
        if (oldVersion < 10) await _createPerformanceIndexes(db);
        if (oldVersion < 12) {
          await db.execute(
            "ALTER TABLE products ADD COLUMN supports_pocket INTEGER NOT NULL DEFAULT 0",
          );
          await db.execute(
            'ALTER TABLE products ADD COLUMN items_per_pocket INTEGER NULL',
          );
          await db.execute(
            'ALTER TABLE products ADD COLUMN pocket_sale_price REAL NULL',
          );
        }
        if (oldVersion < 13) {
          await _createFinancialTables(db);
        }
        if (oldVersion < 14) await _migrateFinancialEntries(db);
      },
    );
  }

  Future<void> _createProductsTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      barcode TEXT NULL,
      description TEXT NULL,
      unit TEXT NOT NULL DEFAULT 'package',
      amount REAL NOT NULL DEFAULT 0,
      restock_level REAL NOT NULL DEFAULT 10,
      supports_carton INTEGER NOT NULL DEFAULT 0,
      supports_package INTEGER NOT NULL DEFAULT 0,
      supports_pocket INTEGER NOT NULL DEFAULT 0,
      items_per_package INTEGER NULL,
      items_per_pocket INTEGER NULL,
      packages_per_carton INTEGER NULL,
      items_per_carton_direct INTEGER NULL,
      current_stock_base REAL NOT NULL DEFAULT 0,
      carton_sale_price REAL NULL,
      package_sale_price REAL NULL,
      pocket_sale_price REAL NULL,
      item_sale_price REAL NULL,
      cost_price REAL NULL,
      sale_price REAL NULL,
      price_currency TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');

  Future<void> _createPurchaseTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        quantity_base REAL NOT NULL,
      unit_cost REAL NOT NULL,
        currency TEXT NOT NULL,
      total_cost REAL NOT NULL,
        purchase_date TEXT NOT NULL,
        note TEXT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity_change REAL NOT NULL,
        reference_type TEXT NOT NULL,
        reference_id INTEGER NOT NULL,
        movement_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
      )
    ''');
  }

  Future<void> _createSalesTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      quantity REAL NOT NULL,
      unit TEXT NOT NULL,
      quantity_base REAL NOT NULL,
      unit_price REAL NOT NULL,
      currency TEXT NOT NULL,
      total_amount REAL NOT NULL,
      sale_date TEXT NOT NULL,
      note TEXT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
    )
  ''');

  Future<void> _createPriceHistoryTable(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS product_price_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      unit TEXT NOT NULL,
      old_price REAL NULL,
      new_price REAL NOT NULL,
      currency TEXT NOT NULL,
      effective_date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
    )
  ''');

  Future<void> _createMetadataTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_metadata (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        schema_version INTEGER NOT NULL,
        app_version TEXT NOT NULL,
        backup_format_version INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        last_backup_at TEXT NULL,
        last_backup_filename TEXT NULL
      )
    ''');
    await db.insert('app_metadata', {
      'id': 1,
      'schema_version': schemaVersion,
      'app_version': appVersion,
      'backup_format_version': backupFormatVersion,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_product_id ON purchases(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_purchase_date ON purchases(purchase_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_product_id ON sales(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_sale_date ON sales(sale_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_product_id ON stock_movements(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_movements_date ON stock_movements(movement_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_price_history_product_id ON product_price_history(product_id)',
    );
  }

  Future<void> _createPerformanceIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_updated_id ON products(updated_at DESC, id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_date_id ON sales(sale_date DESC, id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sales_product_date_id ON sales(product_id, sale_date DESC, id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_date_id ON purchases(purchase_date DESC, id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_product_date_id ON purchases(product_id, purchase_date DESC, id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_movements_date_id ON stock_movements(movement_date DESC, id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_movements_product_date_id ON stock_movements(product_id, movement_date DESC, id DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_price_history_product_date_id ON product_price_history(product_id, effective_date DESC, id DESC)',
    );
  }

  Future<void> _createFinancialTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('asset', 'liability')),
        is_default INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_date TEXT NOT NULL,
        note TEXT NULL,
        total_assets INTEGER NOT NULL DEFAULT 0,
        total_liabilities INTEGER NOT NULL DEFAULT 0,
        net_position INTEGER NOT NULL DEFAULT 0,
        previous_report_id INTEGER NULL,
        net_change INTEGER NULL,
        currency TEXT NOT NULL CHECK (currency IN ('afn', 'usd')),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (previous_report_id) REFERENCES financial_reports (id) ON DELETE SET NULL,
        UNIQUE(report_date)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_report_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        report_id INTEGER NOT NULL,
        category_id INTEGER NULL,
        category_name TEXT NOT NULL,
        category_type TEXT NOT NULL CHECK (category_type IN ('asset', 'liability')),
        amount INTEGER NOT NULL DEFAULT 0,
        note TEXT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (report_id) REFERENCES financial_reports (id) ON DELETE CASCADE,
        UNIQUE(report_id, category_id)
      )
    ''');
    for (final sql in [
      'CREATE INDEX IF NOT EXISTS idx_financial_reports_date_id ON financial_reports(report_date DESC, id DESC)',
      'CREATE INDEX IF NOT EXISTS idx_financial_entries_report ON financial_report_entries(report_id)',
      'CREATE INDEX IF NOT EXISTS idx_financial_categories_type_active ON financial_categories(type, is_active)',
    ]) {
      await db.execute(sql);
    }
  }

  Future<void> _migrateFinancialEntries(Database db) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE financial_report_entries_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          report_id INTEGER NOT NULL,
          category_id INTEGER NULL,
          category_name TEXT NOT NULL,
          category_type TEXT NOT NULL CHECK (category_type IN ('asset', 'liability')),
          amount INTEGER NOT NULL DEFAULT 0,
          note TEXT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (report_id) REFERENCES financial_reports (id) ON DELETE CASCADE,
          UNIQUE(report_id, category_id)
        )
      ''');
      await txn.execute('''
        INSERT INTO financial_report_entries_new
          (id, report_id, category_id, category_name, category_type, amount, note, created_at, updated_at)
        SELECT e.id, e.report_id, e.category_id, c.name, c.type, e.amount, e.note, e.created_at, e.updated_at
        FROM financial_report_entries e
        JOIN financial_categories c ON c.id = e.category_id
      ''');
      await txn.execute('DROP TABLE financial_report_entries');
      await txn.execute(
        'ALTER TABLE financial_report_entries_new RENAME TO financial_report_entries',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_financial_entries_report ON financial_report_entries(report_id)',
      );
    });
  }

  Future<String> get databasePath async {
    final directory = await getApplicationDocumentsDirectory();
    return path.join(directory.path, 'inventory_app.db');
  }

  Future<void> checkpointAndClose() async {
    final db = _database;
    if (db == null) return;
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } finally {
      await db.close();
      _database = null;
    }
  }

  Future<void> ensureOpen() async {
    await database;
  }
}
