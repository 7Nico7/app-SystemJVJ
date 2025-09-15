import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LocalDB {
  static final LocalDB _instance = LocalDB._internal();
  factory LocalDB() => _instance;
  static Database? _database;

  // Estados posibles para las inspecciones
  static const int STATUS_DRAFT = 0;
  static const int STATUS_READY_FOR_SYNC = 1; // Antes STATUS_PENDING
  static const int STATUS_CONCLUDED_OFFLINE = 2; // Antes STATUS_CONCLUDED
  static const int STATUS_SYNCED = 3;

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
      version: 7,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE inspections(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            local_id TEXT NOT NULL,
            inspection_id INTEGER NOT NULL,
            transport_unit TEXT,
            mileage TEXT,
            comment TEXT,
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
            latitude TEXT,
            longitude TEXT,
            address TEXT,     
            image_path TEXT,
            needs_address_lookup INTEGER DEFAULT 1,
            FOREIGN KEY (inspection_local_id) REFERENCES inspections(local_id)
          )
        ''');

        await db.execute('''
          CREATE TABLE inspection_photos(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            inspection_local_id TEXT NOT NULL,
            type TEXT NOT NULL,
            description TEXT NOT NULL,
            latitude TEXT,
            longitude TEXT,
            address TEXT,
            image_path TEXT NOT NULL,
 
            needs_address_lookup INTEGER DEFAULT 1,
            FOREIGN KEY (inspection_local_id) REFERENCES inspections(local_id)
          )
        ''');

        await db.execute('''
          CREATE TABLE inspection_recommendations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            inspection_local_id TEXT NOT NULL,
            description TEXT NOT NULL,
            latitude TEXT,
            longitude TEXT,
            address TEXT,
            image_path TEXT,

            needs_address_lookup INTEGER DEFAULT 1,
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
              latitude TEXT,
              longitude TEXT,
              address TEXT,
        
              needs_address_lookup INTEGER DEFAULT 1,
              FOREIGN KEY (inspection_local_id) REFERENCES inspections(local_id)
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute(
              'ALTER TABLE inspection_checks ADD COLUMN latitude TEXT');
          await db.execute(
              'ALTER TABLE inspection_checks ADD COLUMN longitude TEXT');
          await db
              .execute('ALTER TABLE inspection_checks ADD COLUMN address TEXT');

          await db.execute(
              'ALTER TABLE inspection_checks ADD COLUMN needs_address_lookup INTEGER DEFAULT 1');
        }
        if (oldVersion < 5) {
          await db.execute(
              'ALTER TABLE inspection_photos ADD COLUMN latitude TEXT');
          await db.execute(
              'ALTER TABLE inspection_photos ADD COLUMN longitude TEXT');
          await db
              .execute('ALTER TABLE inspection_photos ADD COLUMN address TEXT');

          await db.execute(
              'ALTER TABLE inspection_photos ADD COLUMN needs_address_lookup INTEGER DEFAULT 1');
        }
        if (oldVersion < 6) {
          await db.execute(
              'ALTER TABLE inspection_recommendations ADD COLUMN latitude TEXT');
          await db.execute(
              'ALTER TABLE inspection_recommendations ADD COLUMN longitude TEXT');
          await db.execute(
              'ALTER TABLE inspection_recommendations ADD COLUMN address TEXT');

          await db.execute(
              'ALTER TABLE inspection_recommendations ADD COLUMN needs_address_lookup INTEGER DEFAULT 1');
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
      whereArgs: [inspectionId, LocalDB.STATUS_DRAFT],
      limit: 1,
    );
    return result.isNotEmpty ? result.first['local_id'] as String? : null;
  }

  Future<List<Map<String, dynamic>>> getInspectionsByOriginalId(
      int inspectionId) async {
    final db = await database;
    return db.query(
      'inspections',
      where: 'inspection_id = ? AND (status = ? OR status = ?)',
      whereArgs: [
        inspectionId,
        LocalDB.STATUS_DRAFT,
        LocalDB.STATUS_READY_FOR_SYNC
      ],
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
      where: 'status = ? OR status = ?',
      whereArgs: [
        STATUS_READY_FOR_SYNC,
        STATUS_CONCLUDED_OFFLINE
      ], // Dos valores
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
    final results = await db.query(
      'inspection_checks',
      where: 'inspection_local_id = ?',
      whereArgs: [localId],
    );

    return results.map((check) {
      // Crear una copia editable del mapa
      final editableCheck = Map<String, dynamic>.from(check);

      // Realizar las conversiones en la copia editable
      if (editableCheck['latitude'] != null) {
        editableCheck['latitude'] =
            double.tryParse(editableCheck['latitude'].toString());
      }
      if (editableCheck['longitude'] != null) {
        editableCheck['longitude'] =
            double.tryParse(editableCheck['longitude'].toString());
      }

      return editableCheck;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getPhotosForInspection(
      String localId) async {
    final db = await database;
    final results = await db.query(
      'inspection_photos',
      where: 'inspection_local_id = ?',
      whereArgs: [localId],
    );

    return results.map((photo) {
      final editablePhoto = Map<String, dynamic>.from(photo);

      if (editablePhoto['latitude'] != null) {
        editablePhoto['latitude'] =
            double.tryParse(editablePhoto['latitude'].toString());
      }
      if (editablePhoto['longitude'] != null) {
        editablePhoto['longitude'] =
            double.tryParse(editablePhoto['longitude'].toString());
      }

      return editablePhoto;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getRecommendationsForInspection(
      String localId) async {
    final db = await database;
    final results = await db.query(
      'inspection_recommendations',
      where: 'inspection_local_id = ?',
      whereArgs: [localId],
    );

    return results.map((recommendation) {
      final editableRecommendation = Map<String, dynamic>.from(recommendation);

      if (editableRecommendation['latitude'] != null) {
        editableRecommendation['latitude'] =
            double.tryParse(editableRecommendation['latitude'].toString());
      }
      if (editableRecommendation['longitude'] != null) {
        editableRecommendation['longitude'] =
            double.tryParse(editableRecommendation['longitude'].toString());
      }

      return editableRecommendation;
    }).toList();
  }

  Future<void> saveFullInspection({
    required Map<String, dynamic> inspection,
    required List<Map<String, dynamic>> checks,
    required List<Map<String, dynamic>> photos,
    required List<Map<String, dynamic>> recommendations,
  }) async {
    print('Guardando inspección: ${inspection['local_id']}');
    print('Checks: ${checks.length}');
    print('Photos: ${photos.length}');
    print('Recommendations: ${recommendations.length}');

// En _loadDraft
    print('Cargando inspección: $inspection');
    print('Checks cargados: ${checks.length}');
    print('Photos cargados: ${photos.length}');
    print('Recommendations cargados: ${recommendations.length}');
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
        await txn.insert('inspection_checks', {
          'inspection_local_id': check['inspection_local_id'],
          'maintenance_checks_id': check['maintenance_checks_id'],
          'status': check['status'],
          'comment': check['comment'],
          'image_path': check['image_path'],
          // Agregar campos de ubicación
          'latitude': check['latitude'],
          'longitude': check['longitude'],
          'address': check['address'],
        });
      }

      await txn.delete(
        'inspection_photos',
        where: 'inspection_local_id = ?',
        whereArgs: [inspection['local_id']],
      );

      for (var photo in photos) {
        await txn.insert('inspection_photos', {
          'inspection_local_id': photo['inspection_local_id'],
          'type': photo['type'],
          'description': photo['description'],
          'image_path': photo['image_path'],
          // Agregar campos de ubicación
          'latitude': photo['latitude'],
          'longitude': photo['longitude'],
          'address': photo['address'],
        });
      }

      await txn.delete(
        'inspection_recommendations',
        where: 'inspection_local_id = ?',
        whereArgs: [inspection['local_id']],
      );

      for (var recommendation in recommendations) {
        await txn.insert('inspection_recommendations', {
          'inspection_local_id': recommendation['inspection_local_id'],
          'description': recommendation['description'],
          'image_path': recommendation['image_path'],
          // Agregar campos de ubicación
          'latitude': recommendation['latitude'],
          'longitude': recommendation['longitude'],
          'address': recommendation['address'],
        });
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

  // En local_db.dart
  Future<void> updatePhotoAddress(String imagePath, String address) async {
    final db = await database;
    await db.update(
      'inspection_photos',
      {'address': address, 'needs_address_lookup': 0},
      where: 'image_path = ?',
      whereArgs: [imagePath],
    );
  }

  Future<void> updateCheckItemAddress(
      String checkItemId, String address) async {
    final db = await database;
    await db.update(
      'inspection_checks',
      {'address': address, 'needs_address_lookup': 0},
      where: 'maintenance_checks_id = ?',
      whereArgs: [checkItemId],
    );
  }

  Future<void> updateRecommendationAddress(
      String recommendationId, String address) async {
    final db = await database;
    await db.update(
      'inspection_recommendations',
      {'address': address, 'needs_address_lookup': 0},
      where: 'id = ?',
      whereArgs: [recommendationId],
    );
  }
}
