import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class SignatureDatabaseHelper {
  static final SignatureDatabaseHelper instance =
      SignatureDatabaseHelper._init();
  static Database? _database;

  SignatureDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('signatures.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final fullPath = path.join(dbPath.path, filePath);

    return await openDatabase(
      fullPath,
      version: 2, // Incrementar versión
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE signatures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        maintenanceId TEXT NOT NULL,
        rating INTEGER NOT NULL,
        signature TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        UNIQUE(maintenanceId)
      )
    ''');

    await db.execute('''
      CREATE TABLE technician_signatures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        maintenanceId TEXT NOT NULL,
        signature TEXT NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        UNIQUE(maintenanceId)
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE technician_signatures (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          maintenanceId TEXT NOT NULL,
          signature TEXT NOT NULL,
          isSynced INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL,
          UNIQUE(maintenanceId)
        )
      ''');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingSignatures() async {
    final db = await database;
    return await db.query(
      'signatures',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingTechnicianSignatures() async {
    final db = await database;
    return await db.query(
      'technician_signatures',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
  }

  Future<void> markAsSynced(int id) async {
    final db = await database;
    await db.update(
      'signatures',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markTechnicianSignatureAsSynced(int id) async {
    final db = await database;
    await db.update(
      'technician_signatures',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> hasSignature(String maintenanceId) async {
    final db = await database;
    final result = await db.query(
      'signatures',
      where: 'maintenanceId = ?',
      whereArgs: [maintenanceId],
    );
    return result.isNotEmpty;
  }
}
