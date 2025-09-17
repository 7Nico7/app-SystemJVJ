import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:systemjvj/core/utils/urlBase.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';

import 'package:systemjvj/schedule/repository/databaseHelper.dart';
import 'package:workmanager/workmanager.dart';
import 'local_db.dart';

class MaintenanceSyncService {
  final Dio dio = Dio();
  final LocalDB localDB = LocalDB();
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final AuthService authService;
  String baseUrl = BASE_URL;

  MaintenanceSyncService({
    required this.authService,
  });

  Future<bool> checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<bool> syncInspection(String localId) async {
    try {
      // 1. Obtener token de autenticación
      final user = authService.currentUser;
      final token = user?.token;
      if (token == null) {
        print(' SYNC Token de autenticación no encontrado');
        return false;
      }

      // 2. Obtener datos de inspección local
      final inspection = await localDB.getInspection(localId);
      if (inspection == null ||
          (inspection['status'] != LocalDB.STATUS_CONCLUDED_OFFLINE &&
              inspection['status'] != LocalDB.STATUS_READY_FOR_SYNC)) {
        print(
            ' SYNC Inspección no encontrada o no está lista para sincronizar');
        return false;
      }
      // 3. Obtener checks, fotos y recomendaciones
      final checks = await localDB.getChecksForInspection(localId);
      final photos = await localDB.getPhotosForInspection(localId);
      final recommendations =
          await localDB.getRecommendationsForInspection(localId); // NUEVO

      print(' SYNC Datos inspección: ${inspection['inspection_id']}');
      print(' SYNC Checks: ${checks.length}');
      print(' SYNC Fotos: ${photos.length}');
      print(' SYNC Recomendaciones: ${recommendations.length}'); // NUEVO

      // 4. Preparar lista de fotos generales, checks y recomendaciones
      final List<Map<String, dynamic>> modifiedChecks = [];
      final List<Map<String, dynamic>> generalPhotosData = [];
      final List<Map<String, dynamic>> modifiedRecommendations = []; // NUEVO
      final List<File> filesToUpload = [];

      // Procesar checks
      for (var check in checks) {
        final Map<String, dynamic> currentCheck = Map.from(check);
        if (currentCheck['image_path'] != null) {
          final path = currentCheck['image_path'] as String;
          final file = File(path);
          if (await file.exists()) {
            final fileName = path.split('/').last;
            currentCheck['image_path'] = fileName;
            filesToUpload.add(file);
          } else {
            print(' SYNC Archivo de check no encontrado: $path');
            currentCheck['image_path'] = null;
          }
        }
        modifiedChecks.add(currentCheck);
      }

      // Procesar fotos generales
/*       for (var photo in photos) {
        final path = photo['image_path'] as String;
        final file = File(path);
        if (await file.exists()) {
          final fileName = path.split('/').last;
          generalPhotosData.add({
            'file_name': fileName,
            'type': photo['type'],
            'description': photo['description'],
          });
          filesToUpload.add(file);
        } else {
          print(' SYNC Archivo de foto general no encontrado: $path');
        }
      } */

      for (var photo in photos) {
        final Map<String, dynamic> currentPhoto = Map.from(photo);
        final path = currentPhoto['image_path'] as String;
        final file = File(path);
        if (await file.exists()) {
          final fileName = path.split('/').last;
          currentPhoto['file_name'] = fileName;
          filesToUpload.add(file);
        } else {
          print(' SYNC Archivo de foto general no encontrado: $path');
          continue; // Saltar esta foto si el archivo no existe
        }
        generalPhotosData.add(currentPhoto);
      }

      // NUEVO: Procesar recomendaciones
      for (var rec in recommendations) {
        final Map<String, dynamic> currentRec = Map.from(rec);
        if (currentRec['image_path'] != null) {
          final path = currentRec['image_path'] as String;
          final file = File(path);
          if (await file.exists()) {
            final fileName = path.split('/').last;
            currentRec['image_path'] = fileName;
            filesToUpload.add(file);
          } else {
            print(' SYNC Archivo de recomendación no encontrado: $path');
            currentRec['image_path'] = null;
          }
        }
        modifiedRecommendations.add(currentRec);
      }

      print(' SYNC Total archivos adjuntos: ${filesToUpload.length}');

      // 5. Construir FormData
      final formData = FormData();

      // Añadir datos básicos de la inspección
      formData.fields.add(
          MapEntry('inspectionId', inspection['inspection_id'].toString()));
      formData.fields.add(
          MapEntry('transportUnit', inspection['transport_unit'].toString()));
      formData.fields
          .add(MapEntry('mileage', inspection['mileage'].toString()));
      formData.fields
          .add(MapEntry('comment', inspection['comment'].toString()));

      formData.fields.add(MapEntry(
          'maintenanceType', inspection['maintenance_type'].toString()));
      formData.fields
          .add(MapEntry('horometer', inspection['horometer'].toString()));
      formData.fields.add(MapEntry(
          'serviceToPerform', inspection['service_to_perform'].toString()));
      formData.fields.add(MapEntry('inspectionConcluded', 'true'));

      // Añadir 'checks' como un array de objetos
      for (int i = 0; i < modifiedChecks.length; i++) {
        formData.fields.add(MapEntry('checks[$i][maintenance_checks_id]',
            modifiedChecks[i]['maintenance_checks_id'].toString()));
        formData.fields.add(MapEntry(
            'checks[$i][status]', modifiedChecks[i]['status'].toString()));
        if (modifiedChecks[i]['comment'] != null) {
          formData.fields.add(MapEntry(
              'checks[$i][comment]', modifiedChecks[i]['comment'].toString()));
        }
        if (modifiedChecks[i]['image_path'] != null) {
          formData.fields.add(MapEntry('checks[$i][image_path]',
              modifiedChecks[i]['image_path'].toString()));
        }

        // Añadir datos de ubicación para checks
        if (modifiedChecks[i]['latitude'] != null) {
          formData.fields.add(MapEntry('checks[$i][latitude]',
              modifiedChecks[i]['latitude'].toString()));
        }

        if (modifiedChecks[i]['longitude'] != null) {
          formData.fields.add(MapEntry('checks[$i][longitude]',
              modifiedChecks[i]['longitude'].toString()));
        }

        if (modifiedChecks[i]['address'] != null) {
          formData.fields.add(MapEntry(
              'checks[$i][address]', modifiedChecks[i]['address'].toString()));
        }
      }

      // Añadir 'general_photos' como un array de objetos
      for (int i = 0; i < generalPhotosData.length; i++) {
        formData.fields.add(MapEntry('general_photos[$i][file_name]',
            generalPhotosData[i]['file_name'].toString()));
        formData.fields.add(MapEntry('general_photos[$i][type]',
            generalPhotosData[i]['type'].toString()));
        if (generalPhotosData[i]['description'] != null) {
          formData.fields.add(MapEntry('general_photos[$i][description]',
              generalPhotosData[i]['description'].toString()));
        }
        // Añadir datos de ubicación para fotos generales
        if (generalPhotosData[i]['latitude'] != null) {
          formData.fields.add(MapEntry('general_photos[$i][latitude]',
              generalPhotosData[i]['latitude'].toString()));
        }

        if (generalPhotosData[i]['longitude'] != null) {
          formData.fields.add(MapEntry('general_photos[$i][longitude]',
              generalPhotosData[i]['longitude'].toString()));
        }

        if (generalPhotosData[i]['address'] != null) {
          formData.fields.add(MapEntry('general_photos[$i][address]',
              generalPhotosData[i]['address'].toString()));
        }
      }

      // NUEVO: Añadir 'recommendations' como un array de objetos
      for (int i = 0; i < modifiedRecommendations.length; i++) {
        formData.fields.add(MapEntry('recommendations[$i][description]',
            modifiedRecommendations[i]['description'].toString()));
        if (modifiedRecommendations[i]['image_path'] != null) {
          formData.fields.add(MapEntry('recommendations[$i][image_path]',
              modifiedRecommendations[i]['image_path'].toString()));
        }
        // Añadir datos de ubicación para recomendaciones
        if (modifiedRecommendations[i]['latitude'] != null) {
          formData.fields.add(MapEntry('recommendations[$i][latitude]',
              modifiedRecommendations[i]['latitude'].toString()));
        }

        if (modifiedRecommendations[i]['longitude'] != null) {
          formData.fields.add(MapEntry('recommendations[$i][longitude]',
              modifiedRecommendations[i]['longitude'].toString()));
        }

        if (modifiedRecommendations[i]['address'] != null) {
          formData.fields.add(MapEntry('recommendations[$i][address]',
              modifiedRecommendations[i]['address'].toString()));
        }
      }

      // Añadir los archivos físicos
      for (var file in filesToUpload) {
        final fileName = file.path.split('/').last;
        formData.files.add(MapEntry(
          'photo_files[]',
          await MultipartFile.fromFile(file.path, filename: fileName),
        ));
      }

      // 6. Enviar solicitud al backend
      final response = await dio.post(
        '$baseUrl/api/inspections/save-full',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      // 7. Procesar respuesta
      if (response.statusCode == 200) {
        print(' SYNC Sincronización exitosa!');
        await localDB.updateInspectionStatus(localId, LocalDB.STATUS_SYNCED);

        // Actualizar la actividad relacionada con mejor logging
        try {
          final dbHelper = DatabaseHelper.instance;
          final inspectionId = inspection['inspection_id'];
          final transportUnitValue = inspection['transport_unit'].toString();

          print(
              ' SYNC Actualizando actividad: inspectionId=$inspectionId, concluded=true, transportUnit=$transportUnitValue');

          final result = await dbHelper.updateActivityInspectionStatus(
            inspectionId,
            true,
            transportUnitValue,
          );

          print(' SYNC Resultado de actualización: $result filas afectadas');

          if (result > 0) {
            print(' SYNC Actividad actualizada exitosamente');
          } else {
            print(
                ' SYNC Advertencia: No se afectaron filas al actualizar la actividad');
          }
        } catch (e) {
          print(' SYNC Error actualizando actividad local: $e');
        }

        return true;
      } else {
        print(' SYNC Error del servidor: ${response.statusCode}');
        print(' SYNC Respuesta: ${response.data}');
        return false;
      }
    } on DioException catch (e) {
      print(' SYNC Error de Dio: ${e.type}');
      print(' SYNC Mensaje: ${e.message}');

      if (e.response != null) {
        print(' SYNC Status: ${e.response?.statusCode}');
        print(' SYNC Datos: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      print(' SYNC Error inesperado: $e');
      return false;
    }
  }

  Future<void> syncPendingInspections() async {
    try {
      print(' SYNC Buscando inspecciones pendientes...');
      final pending = await localDB.getPendingInspections();
      print(' SYNC Encontradas ${pending.length} inspecciones pendientes');

      for (var inspection in pending) {
        final localId = inspection['local_id'] as String;
        print(' SYNC Sincronizando inspección: $localId');
        final success = await syncInspection(localId);

        if (success) {
          print(' SYNC Inspección $localId sincronizada con éxito');
        } else {
          print(' SYNC Falló sincronización de $localId');
        }
      }
    } catch (e) {
      print(' SYNC Error en syncPendingInspections: $e');
    }
  }

  static void registerBackgroundSync() {
    Workmanager().registerPeriodicTask(
      "syncInspections",
      "syncInspectionsTask",
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  static Future<void> syncPendingInspectionsBackground() async {
    try {
      print('[BACKGROUND SYNC] Iniciando sincronización de inspecciones...');

      // Inicializar dependencias manualmente para background
      final sharedPreferences = await SharedPreferences.getInstance();
      final localDB = LocalDB();
      final authService = AuthService();

      // Cargar el token desde SharedPreferences
      final token = sharedPreferences.getString('auth_token');
      if (token != null) {
        authService.setToken(token);
      }

      final syncService = MaintenanceSyncService(authService: authService);

      // Verificar conectividad
      final connectivity = Connectivity();
      final connectivityResult = await connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('[BACKGROUND SYNC] Sin conexión, abortando sincronización');
        return;
      }

      // Sincronizar inspecciones pendientes
      final pending = await localDB.getPendingInspections();
      print(
          '[BACKGROUND SYNC] ${pending.length} inspecciones pendientes encontradas');

      for (var inspection in pending) {
        try {
          final localId = inspection['local_id'] as String;
          print('[BACKGROUND SYNC] Sincronizando inspección: $localId');
          final success = await syncService.syncInspection(localId);

          if (success) {
            print(
                '[BACKGROUND SYNC] Inspección $localId sincronizada con éxito');
          } else {
            print('[BACKGROUND SYNC] Falló sincronización de $localId');
          }
        } catch (e) {
          print('[BACKGROUND SYNC] Error sincronizando inspección: $e');
        }
      }

      print('[BACKGROUND SYNC] Sincronización de inspecciones completada');
    } catch (e) {
      print('[BACKGROUND SYNC] Error en sincronización de inspecciones: $e');
    }
  }

  @pragma('vm:entry-point')
  static void callbackDispatcher(AuthService authService) {
    Workmanager().executeTask((task, inputData) async {
      if (task == "syncInspectionsTask") {
        print(' BACKGROUND Iniciando sincronización en background...');
        final service = MaintenanceSyncService(authService: authService);
        await service.syncPendingInspections();
        print(' BACKGROUND Sincronización completada');
        return true;
      }
      return false;
    });
  }
}
