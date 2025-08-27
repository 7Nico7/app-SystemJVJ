import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:systemjvj/schedule/models/activity_model.dart';
import 'dart:convert';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('activities.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4, // Incrementado por cambios en esquema
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        name TEXT,
        title TEXT,
        start TEXT,
        end TEXT,
        description TEXT,
        location TEXT,
        client TEXT,
        technical TEXT,
        equipment TEXT,
        status INTEGER,
        folio TEXT,
        maintenanceIdPdf TEXT,
        technicalId TEXT,
        maintenance_status INTEGER,
        service_scope INTEGER,
        inspection_id INTEGER,
        transportUnit TEXT,
        hourStart TEXT,
        hourEnd TEXT,
        hourIn TEXT,
        hourBaseIn TEXT,
        hourBaseOut TEXT,
        inspection_concluded INTEGER,
        maintenanceId INTEGER,
        is_synced INTEGER DEFAULT 1,
        local_status INTEGER DEFAULT 0,
        pending_times TEXT,
        serviceRating INTEGER,
        technicalSignature INTEGER,
        mileage TEXT,
        comment TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activityId TEXT,
        operation TEXT,
        timeValue TEXT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE activities ADD COLUMN is_synced INTEGER DEFAULT 1');
      await db.execute(
          'ALTER TABLE activities ADD COLUMN local_status INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE activities ADD COLUMN pending_times TEXT');
    }
    if (oldVersion < 3) {
      // Migración para asegurar valores por defecto
      await db.execute(
          'UPDATE activities SET local_status = 0 WHERE local_status IS NULL');
      await db.execute(
          'ALTER TABLE activities ADD COLUMN inspection_concluded INTEGER DEFAULT 0');
      await db.execute(
          'UPDATE activities SET inspection_concluded = 0 WHERE inspection_concluded IS NULL');
    }
  }

  Future<int> insertActivity(Activity activity) async {
    final db = await instance.database;
    return await db.insert('activities', activity.toMap());
  }

  Future<List<Activity>> getActivities() async {
    final db = await instance.database;
    final maps = await db.query('activities');
    return maps.map((map) => Activity.fromMap(map)).toList();
  }

  Future<int> updateActivity(Activity activity) async {
    final db = await instance.database;
    return await db.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  Future<Activity?> getActivityById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Activity.fromMap(maps.first);
    }
    return null;
  }

  Future<int> addPendingOperation(Map<String, dynamic> operation) async {
    final db = await instance.database;
    return await db.insert('pending_operations', operation);
  }

  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final db = await instance.database;
    return await db.query('pending_operations');
  }

  Future<int> removePendingOperation(int id) async {
    final db = await instance.database;
    return await db.delete(
      'pending_operations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteActivity(String id) async {
    final db = await instance.database;
    return await db.delete(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> hasPendingOperations(String activityId) async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM pending_operations WHERE activityId = ?',
      [activityId],
    ));
    return count != null && count > 0;
  }

  Future<void> bulkInsertOrUpdateActivities(List<Activity> activities) async {
    final db = await database;
    final batch = db.batch();

    for (final activity in activities) {
      final existing = await getActivityById(activity.id);
      if (existing != null) {
        batch.update(
          'activities',
          activity.toMap(),
          where: 'id = ?',
          whereArgs: [activity.id],
        );
      } else {
        batch.insert('activities', activity.toMap());
      }
    }

    await batch.commit();
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  Future<int> updateActivityInspectionStatus(
      int inspectionId, bool concluded, String transportUnit) async {
    final db = await database;

    // Verificar que la tabla tiene las columnas necesarias
    try {
      final result = await db.update(
        'activities',
        {
          'inspection_concluded': concluded ? 1 : 0,
          'transportUnit': transportUnit,
        },
        where: 'inspection_id = ?',
        whereArgs: [inspectionId],
      );

      print(' DB Update result: $result rows affected');
      return result;
    } catch (e) {
      print(' DB Error updating activity: $e');
      rethrow;
    }
  }
}
