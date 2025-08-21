/* import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LocalDB {
  static final LocalDB _instance = LocalDB._internal();
  factory LocalDB() => _instance;
  static Database? _database;

  // Estados posibles para las inspecciones
  static const int STATUS_DRAFT = 0; // Borrador (editable)
  static const int STATUS_PENDING = 1; // Pendiente de sincronización
  static const int STATUS_CONCLUDED = 2; // Concluida (no editable)
  static const int STATUS_SYNCED = 3; // Sincronizada con el backend

  LocalDB._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory dir = await getApplicationDocumentsDirectory();
    String path = join(dir.path, 'inspections.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE inspections(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            local_id TEXT NOT NULL,
            inspection_id INTEGER NOT NULL,
            transport_unit TEXT,
            maintenance_type TEXT,
            horometer REAL,
            service_to_perform TEXT, 
            status INTEGER DEFAULT 0, 
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        await db.execute('''
          CREATE TABLE inspection_checks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            inspection_local_id TEXT NOT NULL,
            maintenance_checks_id INTEGER NOT NULL,
            status INTEGER NOT NULL,
            comment TEXT,
            image_path TEXT,
            FOREIGN KEY (inspection_local_id) REFERENCES inspections(local_id)
          )
        ''');

        await db.execute('''
          CREATE TABLE inspection_photos(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            inspection_local_id TEXT NOT NULL,
            type TEXT NOT NULL,
            description TEXT NOT NULL,
            image_path TEXT NOT NULL,
            FOREIGN KEY (inspection_local_id) REFERENCES inspections(local_id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE inspections ADD COLUMN service_to_perform TEXT');
        }
      },
    );
  }

  Future<String?> getLocalIdForInspection(int inspectionId) async {
    final db = await database;
    final result = await db.query(
      'inspections',
      columns: ['local_id'],
      where: 'inspection_id = ? AND status = ?',
      whereArgs: [inspectionId, 0],
      limit: 1,
    );
    return result.isNotEmpty ? result.first['local_id'] as String? : null;
  }

  Future<List<Map<String, dynamic>>> getInspectionsByOriginalId(
      int inspectionId) async {
    final db = await database;
    return db.query(
      'inspections',
      where: 'inspection_id = ? AND (status = 0 OR status = 1)',
      whereArgs: [inspectionId],
    );
  }

  Future<int> saveInspection(Map<String, dynamic> inspection) async {
    final db = await database;
    return db.insert('inspections', inspection);
  }

  Future<int> updateInspectionStatus(String localId, int status) async {
    final db = await database;
    return db.update(
      'inspections',
      {'status': status},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingInspections() async {
    final db = await database;
    return db.query(
      'inspections',
      where: 'status = ?',
      whereArgs: [1],
    );
  }

  Future<Map<String, dynamic>?> getInspection(String localId) async {
    final db = await database;
    final inspections = await db.query(
      'inspections',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return inspections.isNotEmpty ? inspections.first : null;
  }

  Future<List<Map<String, dynamic>>> getChecksForInspection(
      String localId) async {
    final db = await database;
    return db.query(
      'inspection_checks',
      where: 'inspection_local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getPhotosForInspection(
      String localId) async {
    final db = await database;
    return db.query(
      'inspection_photos',
      where: 'inspection_local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> saveFullInspection({
    required Map<String, dynamic> inspection,
    required List<Map<String, dynamic>> checks,
    required List<Map<String, dynamic>> photos,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'inspections',
        where: 'local_id = ?',
        whereArgs: [inspection['local_id']],
      );

      if (existing.isNotEmpty) {
        await txn.update(
          'inspections',
          inspection,
          where: 'local_id = ?',
          whereArgs: [inspection['local_id']],
        );
      } else {
        await txn.insert('inspections', inspection);
      }

      await txn.delete(
        'inspection_checks',
        where: 'inspection_local_id = ?',
        whereArgs: [inspection['local_id']],
      );

      for (var check in checks) {
        await txn.insert('inspection_checks', check);
      }

      await txn.delete(
        'inspection_photos',
        where: 'inspection_local_id = ?',
        whereArgs: [inspection['local_id']],
      );

      for (var photo in photos) {
        await txn.insert('inspection_photos', photo);
      }
    });
  }

  Future<void> saveChecks(List<Map<String, dynamic>> checks) async {
    final db = await database;
    final batch = db.batch();
    for (var check in checks) {
      batch.insert('inspection_checks', check);
    }
    await batch.commit();
  }

  Future<void> savePhotos(List<Map<String, dynamic>> photos) async {
    final db = await database;
    final batch = db.batch();
    for (var photo in photos) {
      batch.insert('inspection_photos', photo);
    }
    await batch.commit();
  }
}
 */

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LocalDB {
  static final LocalDB _instance = LocalDB._internal();
  factory LocalDB() => _instance;
  static Database? _database;

  // Estados posibles para las inspecciones
  static const int STATUS_DRAFT = 0; // Borrador (editable)
  static const int STATUS_PENDING = 1; // Pendiente de sincronización
  static const int STATUS_CONCLUDED = 2; // Concluida (no editable)
  static const int STATUS_SYNCED = 3; // Sincronizada con el backend

  LocalDB._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory dir = await getApplicationDocumentsDirectory();
    String path = join(dir.path, 'inspections.db');
    return openDatabase(
      path,
      version: 5, // Incrementamos la versión por la nueva tabla
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE inspections(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            local_id TEXT NOT NULL,
            inspection_id INTEGER NOT NULL,
            transport_unit TEXT,
            maintenance_type TEXT,
            horometer REAL,
            service_to_perform TEXT, 
            status INTEGER DEFAULT 0, 
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        await db.execute('''
          CREATE TABLE inspection_checks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            inspection_local_id TEXT NOT NULL,
            maintenance_checks_id INTEGER NOT NULL,
            status INTEGER NOT NULL,
            comment TEXT,
            image_path TEXT,
            FOREIGN KEY (inspection_local_id) REFERENCES inspections(local_id)
          )
        ''');

        await db.execute('''
          CREATE TABLE inspection_photos(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            inspection_local_id TEXT NOT NULL,
            type TEXT NOT NULL,
            description TEXT NOT NULL,
            image_path TEXT NOT NULL,
            FOREIGN KEY (inspection_local_id) REFERENCES inspections(local_id)
          )
        ''');

        // Nueva tabla para recomendaciones
        await db.execute('''
          CREATE TABLE inspection_recommendations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            inspection_local_id TEXT NOT NULL,
            description TEXT NOT NULL,
            image_path TEXT,
            FOREIGN KEY (inspection_local_id) REFERENCES inspections(local_id)
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE inspections ADD COLUMN service_to_perform TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE inspection_recommendations(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              inspection_local_id TEXT NOT NULL,
              description TEXT NOT NULL,
              image_path TEXT,
              FOREIGN KEY (inspection_local_id) REFERENCES inspections(local_id)
            )
          ''');
        }
      },
    );
  }

  Future<String?> getLocalIdForInspection(int inspectionId) async {
    final db = await database;
    final result = await db.query(
      'inspections',
      columns: ['local_id'],
      where: 'inspection_id = ? AND status = ?',
      whereArgs: [inspectionId, 0],
      limit: 1,
    );
    return result.isNotEmpty ? result.first['local_id'] as String? : null;
  }

  Future<List<Map<String, dynamic>>> getInspectionsByOriginalId(
      int inspectionId) async {
    final db = await database;
    return db.query(
      'inspections',
      where: 'inspection_id = ? AND (status = 0 OR status = 1)',
      whereArgs: [inspectionId],
    );
  }

  Future<int> saveInspection(Map<String, dynamic> inspection) async {
    final db = await database;
    return db.insert('inspections', inspection);
  }

  Future<int> updateInspectionStatus(String localId, int status) async {
    final db = await database;
    return db.update(
      'inspections',
      {'status': status},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getPendingInspections() async {
    final db = await database;
    return db.query(
      'inspections',
      where: 'status = ?',
      whereArgs: [1],
    );
  }

  Future<Map<String, dynamic>?> getInspection(String localId) async {
    final db = await database;
    final inspections = await db.query(
      'inspections',
      where: 'local_id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return inspections.isNotEmpty ? inspections.first : null;
  }

  Future<List<Map<String, dynamic>>> getChecksForInspection(
      String localId) async {
    final db = await database;
    return db.query(
      'inspection_checks',
      where: 'inspection_local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getPhotosForInspection(
      String localId) async {
    final db = await database;
    return db.query(
      'inspection_photos',
      where: 'inspection_local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<List<Map<String, dynamic>>> getRecommendationsForInspection(
      String localId) async {
    final db = await database;
    return db.query(
      'inspection_recommendations',
      where: 'inspection_local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> saveFullInspection({
    required Map<String, dynamic> inspection,
    required List<Map<String, dynamic>> checks,
    required List<Map<String, dynamic>> photos,
    required List<Map<String, dynamic>> recommendations,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'inspections',
        where: 'local_id = ?',
        whereArgs: [inspection['local_id']],
      );

      if (existing.isNotEmpty) {
        await txn.update(
          'inspections',
          inspection,
          where: 'local_id = ?',
          whereArgs: [inspection['local_id']],
        );
      } else {
        await txn.insert('inspections', inspection);
      }

      await txn.delete(
        'inspection_checks',
        where: 'inspection_local_id = ?',
        whereArgs: [inspection['local_id']],
      );

      for (var check in checks) {
        await txn.insert('inspection_checks', check);
      }

      await txn.delete(
        'inspection_photos',
        where: 'inspection_local_id = ?',
        whereArgs: [inspection['local_id']],
      );

      for (var photo in photos) {
        await txn.insert('inspection_photos', photo);
      }

      // Eliminar recomendaciones existentes y guardar las nuevas
      await txn.delete(
        'inspection_recommendations',
        where: 'inspection_local_id = ?',
        whereArgs: [inspection['local_id']],
      );

      for (var recommendation in recommendations) {
        // Crear un nuevo mapa sin el campo 'id' si existe
        final recData = {
          'inspection_local_id': recommendation['inspection_local_id'],
          'description': recommendation['description'],
          'image_path': recommendation['image_path'],
        };

        await txn.insert('inspection_recommendations', recData);
      }
    });
  }

  Future<void> saveChecks(List<Map<String, dynamic>> checks) async {
    final db = await database;
    final batch = db.batch();
    for (var check in checks) {
      batch.insert('inspection_checks', check);
    }
    await batch.commit();
  }

  Future<void> savePhotos(List<Map<String, dynamic>> photos) async {
    final db = await database;
    final batch = db.batch();
    for (var photo in photos) {
      batch.insert('inspection_photos', photo);
    }
    await batch.commit();
  }

  Future<void> saveRecommendations(
      List<Map<String, dynamic>> recommendations) async {
    final db = await database;
    final batch = db.batch();
    for (var recommendation in recommendations) {
      batch.insert('inspection_recommendations', recommendation);
    }
    await batch.commit();
  }
}
