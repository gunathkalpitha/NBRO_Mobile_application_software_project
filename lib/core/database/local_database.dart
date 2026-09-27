import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:flutter/foundation.dart';

/// Local SQLite Database Service for Offline-First Storage
class LocalDatabase {
  static LocalDatabase? _instance;
  static Database? _db;

  LocalDatabase._();

  static LocalDatabase get instance {
    _instance ??= LocalDatabase._();
    return _instance!;
  }

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    try {
      // Ensure SQLite native libraries are initialized on Android/iOS
      applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
      
      final docsDir = await getApplicationDocumentsDirectory();
      final dbPath = p.join(docsDir.path, 'nbro_offline_v2.db');

      final database = sqlite3.open(dbPath);

      // Enable foreign keys
      database.execute('PRAGMA foreign_keys = ON;');

      // Create tables
      _createTables(database);

      debugPrint('[LocalDatabase] SQLite database initialized at $dbPath');
      return database;
    } catch (e) {
      debugPrint('[LocalDatabase] ❌ Database initialization failed: $e');
      rethrow;
    }
  }

  void _createTables(Database database) {
    database.execute('''
      CREATE TABLE IF NOT EXISTS inspections (
        local_id TEXT PRIMARY KEY,
        server_id TEXT,
        building_ref TEXT NOT NULL,
        user_id TEXT,
        owner_name TEXT NOT NULL,
        site_address TEXT NOT NULL,
        contact_no TEXT,
        latitude REAL,
        longitude REAL,
        distance_from_row REAL,
        age_of_structure INTEGER,
        type_of_structure TEXT,
        present_condition TEXT,
        has_pipe_borne_water INTEGER DEFAULT 0,
        water_source TEXT,
        has_electricity INTEGER DEFAULT 0,
        electricity_source TEXT,
        has_sewage_waste INTEGER DEFAULT 0,
        sewage_type TEXT,
        number_of_floors TEXT,
        wall_materials_json TEXT,
        door_materials_json TEXT,
        floor_materials_json TEXT,
        roof_materials_json TEXT,
        roof_covering TEXT,
        building_photo_local_path TEXT,
        building_photo_remote_url TEXT,
        remarks TEXT,
        sync_status TEXT NOT NULL DEFAULT 'PENDING',
        sync_error TEXT,
        sync_attempts INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        synced_at TEXT
      );
    ''');

    database.execute('''
      CREATE TABLE IF NOT EXISTS defects (
        local_id TEXT PRIMARY KEY,
        inspection_local_id TEXT NOT NULL,
        notation TEXT NOT NULL,
        category TEXT NOT NULL,
        floor_level TEXT,
        length_mm REAL NOT NULL,
        width_mm REAL,
        photo_local_path TEXT,
        photo_remote_url TEXT,
        upload_status TEXT NOT NULL DEFAULT 'PENDING',
        remarks TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (inspection_local_id) REFERENCES inspections(local_id) ON DELETE CASCADE
      );
    ''');

    database.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        attempt_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL,
        last_attempt_at TEXT
      );
    ''');

    // Create Indexes
    database.execute('CREATE INDEX IF NOT EXISTS idx_inspections_status ON inspections(sync_status);');
    database.execute('CREATE INDEX IF NOT EXISTS idx_defects_inspection ON defects(inspection_local_id);');
    database.execute('CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status);');
  }

  /// Run operation inside an atomic database transaction
  Future<T> transaction<T>(T Function(Database database) action) async {
    final database = await db;
    database.execute('BEGIN TRANSACTION;');
    try {
      final result = action(database);
      database.execute('COMMIT;');
      return result;
    } catch (e) {
      database.execute('ROLLBACK;');
      debugPrint('[LocalDatabase] ❌ Transaction rolled back due to error: $e');
      rethrow;
    }
  }

  /// Close database connection
  Future<void> close() async {
    if (_db != null) {
      _db!.dispose();
      _db = null;
    }
  }
}
