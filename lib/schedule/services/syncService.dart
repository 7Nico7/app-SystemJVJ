/* import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:systemjvj/core/utils/urlBase.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/schedule/models/activity_model.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';

class SyncService {
  final OfflineService offlineService;
  final DatabaseHelper dbHelper;
  final AuthService authService;
  String _baseUrl = BASE_URL;

  SyncService({
    required this.offlineService,
    required this.dbHelper,
    required this.authService,
  });

  Future<void> syncData() async {
    final user = authService.currentUser;
    if (user == null) {
      print('[SYNC] Usuario no autenticado, no se puede sincronizar');
      return;
    }

    print('[SYNC] Iniciando sincronización...');

    try {
      // 1. Sincronizar operaciones pendientes
      await _syncPendingOperations(user.token);

      // 2. Sincronizar actividades con el servidor
      await _syncActivities(user.token);

      print('[SYNC] Sincronización completada con éxito');
    } catch (e) {
      print('[SYNC] Error durante la sincronización: $e');
    }
  }

  Future<void> _syncPendingOperations(String? token) async {
    print('[SYNC] Obteniendo operaciones pendientes');
    final operations = await dbHelper.getPendingOperations();
    print('[SYNC] ${operations.length} operaciones pendientes encontradas');

    for (final op in operations) {
      try {
        final operationType = op['operation'];
        print('[SYNC] Procesando operación: $operationType');

        final success = await _sendOperationToServer(op, token);
        if (success) {
          print(
              '[SYNC] Operación exitosa, eliminando de pendientes: ${op['id']}');
          await dbHelper.removePendingOperation(op['id']);

          // Actualizar actividad local con datos del servidor
          await _updateLocalActivityAfterSync(op, token);
        } else {
          print('[SYNC] La operación falló, se mantiene en pendientes');
        }
      } catch (e) {
        print('[SYNC] Error sincronizando operación: $e');
      }
    }
  }

  Future<bool> _sendOperationToServer(
      Map<String, dynamic> operation, String? token) async {
    final activityId = operation['activityId'];
    final operationType = operation['operation'];
    final timeValue = operation['timeValue'];

    String endpoint;
    Map<String, dynamic> body = {
      'inspectionId': activityId,
    };

    switch (operationType) {
      case 'base_out':
        endpoint = '$_baseUrl/api/schedule/register-base-out';
        body['hourBaseOut'] = timeValue;
        body['serviceScope'] = 2;
        break;
      case 'arrival':
        endpoint = '$_baseUrl/api/schedule/register-arrival';
        body['hourIn'] = timeValue;
        break;
      case 'start':
        endpoint = '$_baseUrl/api/schedule/register-start';
        body['hourStart'] = timeValue;
        break;
      case 'end':
        endpoint = '$_baseUrl/api/schedule/register-end';
        body['hourEnd'] = timeValue;
        break;
      case 'base_in':
        endpoint = '$_baseUrl/api/schedule/register-base-in';
        body['hourBaseIn'] = timeValue;
        break;
      case 'technicalSignature':
        endpoint = '$_baseUrl/api/schedule/register-technicalSignature';
        body['technicalSignature'] = timeValue;
        break;

      default:
        print('[SYNC] Tipo de operación no reconocida: $operationType');
        return false;
    }

    print('[SYNC] Enviando operación a $endpoint');

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      print('[SYNC] Respuesta: ${response.statusCode} - ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('[SYNC] Error en la solicitud: $e');
      return false;
    }
  }

  Future<void> _updateLocalActivityAfterSync(
      Map<String, dynamic> operation, String? token) async {
    final activityId = operation['activityId'];
    final operationType = operation['operation'];

    try {
      final updatedActivity = await _fetchUpdatedActivity(activityId, token);
      if (updatedActivity != null) {
        // Obtener actividad local actual
        final localActivity = await dbHelper.getActivityById(activityId);

        if (localActivity != null) {
          // Crear nuevo mapa de pendingTimes sin la operación sincronizada
          final newPendingTimes = {...localActivity.pendingTimes};
          newPendingTimes.remove(operationType);

          // Determinar si la actividad está completamente sincronizada
          final isSynced = newPendingTimes.isEmpty;

          // Actualizar actividad
          final mergedActivity = updatedActivity.copyWith(
            pendingTimes: newPendingTimes,
            isSynced: isSynced,
            localStatus: isSynced ? 0 : localActivity.localStatus,
          );

          await dbHelper.updateActivity(mergedActivity);
          print('[SYNC] Actividad local actualizada: $activityId');
        }
      }
    } catch (e) {
      print('[SYNC] Error actualizando actividad local: $e');
    }
  }

  Future<Activity?> _fetchUpdatedActivity(
      String activityId, String? token) async {
    print('[SYNC] Obteniendo actividad actualizada: $activityId');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/schedule-events?inspectionId=$activityId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'] as List;
        if (data.isNotEmpty) {
          return Activity.fromJson(data.first);
        }
      }
    } catch (e) {
      print('[SYNC] Error obteniendo actividad actualizada: $e');
    }
    return null;
  }

  Future<void> _syncActivities(String? token) async {
    print('[SYNC] Sincronizando lista de actividades');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/schedule-events'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'] as List;
        final onlineActivities =
            data.map((json) => Activity.fromJson(json)).toList();

        // Sincronizar manteniendo estados locales
        for (final onlineActivity in onlineActivities) {
          final localActivity =
              await dbHelper.getActivityById(onlineActivity.id);

          if (localActivity != null) {
            // Conservar estado local si existe
            final mergedActivity = onlineActivity.copyWith(
              localStatus: localActivity.localStatus,
              pendingTimes: localActivity.pendingTimes,
              isSynced: localActivity.pendingTimes.isEmpty,
            );

            await dbHelper.updateActivity(mergedActivity);
          } else {
            await dbHelper.insertActivity(onlineActivity);
          }
        }

        // Recargar actividades offline
        offlineService.loadActivities();
        print('[SYNC] ${onlineActivities.length} actividades sincronizadas');
      } else {
        print('[SYNC] Error al obtener actividades: ${response.statusCode}');
      }
    } catch (e) {
      print('[SYNC] Error sincronizando actividades: $e');
    }
  }
}
 */

import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:systemjvj/core/utils/urlBase.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/schedule/models/activity_model.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';

class SyncService with ChangeNotifier {
  final OfflineService offlineService;
  final DatabaseHelper dbHelper;
  final AuthService authService;
  String _baseUrl = BASE_URL;

  SyncService({
    required this.offlineService,
    required this.dbHelper,
    required this.authService,
  });

  Future<void> syncData() async {
    final user = authService.currentUser;
    if (user == null) {
      print('[SYNC] Usuario no autenticado, no se puede sincronizar');
      return;
    }
    // Verificar conexión antes de intentar sincronizar
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('[SYNC] Sin conexión, no se puede sincronizar');
      throw Exception('No hay conexión a internet');
    }
    print('[SYNC] Iniciando sincronización...');

    try {
      // 1. Sincronizar operaciones pendientes
      await _syncPendingOperations(user.token);

      // 2. Sincronizar actividades con el servidor
      await _syncActivities(user.token);

      print('[SYNC] Sincronización completada con éxito');

      // Notificar a todos los listeners que la sincronización ha terminado
      notifyListeners();
    } catch (e) {
      print('[SYNC] Error durante la sincronización: $e');
      rethrow;
    }
  }

  Future<void> _syncPendingOperations(String? token) async {
    print('[SYNC] Obteniendo operaciones pendientes');
    final operations = await dbHelper.getPendingOperations();
    print('[SYNC] ${operations.length} operaciones pendientes encontradas');

    for (final op in operations) {
      try {
        final operationType = op['operation'];
        print('[SYNC] Procesando operación: $operationType');

        final success = await _sendOperationToServer(op, token);
        if (success) {
          print(
              '[SYNC] Operación exitosa, eliminando de pendientes: ${op['id']}');
          await dbHelper.removePendingOperation(op['id']);

          // Actualizar actividad local con datos del servidor
          await _updateLocalActivityAfterSync(op, token);
        } else {
          print('[SYNC] La operación falló, se mantiene en pendientes');
        }
      } catch (e) {
        print('[SYNC] Error sincronizando operación: $e');
      }
    }
  }

  Future<bool> _sendOperationToServer(
      Map<String, dynamic> operation, String? token) async {
    final activityId = operation['activityId'];
    final operationType = operation['operation'];
    final timeValue = operation['timeValue'];

    String endpoint;
    Map<String, dynamic> body = {
      'inspectionId': activityId,
    };

    switch (operationType) {
      case 'base_out':
        endpoint = '$_baseUrl/api/schedule/register-base-out';
        body['hourBaseOut'] = timeValue;
        body['serviceScope'] = 2;
        break;
      case 'arrival':
        endpoint = '$_baseUrl/api/schedule/register-arrival';
        body['hourIn'] = timeValue;
        break;
      case 'start':
        endpoint = '$_baseUrl/api/schedule/register-start';
        body['hourStart'] = timeValue;
        break;
      case 'end':
        endpoint = '$_baseUrl/api/schedule/register-end';
        body['hourEnd'] = timeValue;
        break;
      case 'base_in':
        endpoint = '$_baseUrl/api/schedule/register-base-in';
        body['hourBaseIn'] = timeValue;
        break;
      case 'technicalSignature':
        endpoint = '$_baseUrl/api/schedule/register-technicalSignature';
        body['technicalSignature'] = timeValue;
        break;

      default:
        print('[SYNC] Tipo de operación no reconocida: $operationType');
        return false;
    }

    print('[SYNC] Enviando operación a $endpoint');

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      print('[SYNC] Respuesta: ${response.statusCode} - ${response.body}');

      return response.statusCode == 200;
    } catch (e) {
      print('[SYNC] Error en la solicitud: $e');
      return false;
    }
  }

  Future<void> _updateLocalActivityAfterSync(
      Map<String, dynamic> operation, String? token) async {
    final activityId = operation['activityId'];
    final operationType = operation['operation'];

    try {
      final updatedActivity = await _fetchUpdatedActivity(activityId, token);
      if (updatedActivity != null) {
        // Obtener actividad local actual
        final localActivity = await dbHelper.getActivityById(activityId);

        if (localActivity != null) {
          // Crear nuevo mapa de pendingTimes sin la operación sincronizada
          final newPendingTimes = {...localActivity.pendingTimes};
          newPendingTimes.remove(operationType);

          // Determinar si la actividad está completamente sincronizada
          final isSynced = newPendingTimes.isEmpty;

          // Actualizar actividad
          final mergedActivity = updatedActivity.copyWith(
            pendingTimes: newPendingTimes,
            isSynced: isSynced,
            localStatus: isSynced ? 0 : localActivity.localStatus,
          );

          await dbHelper.updateActivity(mergedActivity);
          print('[SYNC] Actividad local actualizada: $activityId');

          // Notificar al offlineService sobre el cambio
          await offlineService.loadActivities();
        }
      }
    } catch (e) {
      print('[SYNC] Error actualizando actividad local: $e');
    }
  }

  Future<Activity?> _fetchUpdatedActivity(
      String activityId, String? token) async {
    print('[SYNC] Obteniendo actividad actualizada: $activityId');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/schedule-events?inspectionId=$activityId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'] as List;
        if (data.isNotEmpty) {
          return Activity.fromJson(data.first);
        }
      }
    } catch (e) {
      print('[SYNC] Error obteniendo actividad actualizada: $e');
    }
    return null;
  }

  Future<void> _syncActivities(String? token) async {
    print('[SYNC] Sincronizando lista de actividades');

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/schedule-events'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'] as List;
        final onlineActivities =
            data.map((json) => Activity.fromJson(json)).toList();

        // Sincronizar manteniendo estados locales
        for (final onlineActivity in onlineActivities) {
          final localActivity =
              await dbHelper.getActivityById(onlineActivity.id);

          if (localActivity != null) {
            // Conservar estado local si existe
            final mergedActivity = onlineActivity.copyWith(
              localStatus: localActivity.localStatus,
              pendingTimes: localActivity.pendingTimes,
              isSynced: localActivity.pendingTimes.isEmpty,
            );

            await dbHelper.updateActivity(mergedActivity);
          } else {
            await dbHelper.insertActivity(onlineActivity);
          }
        }

        // Recargar actividades offline
        await offlineService.loadActivities();
        print('[SYNC] ${onlineActivities.length} actividades sincronizadas');
      } else {
        print('[SYNC] Error al obtener actividades: ${response.statusCode}');
      }
    } catch (e) {
      print('[SYNC] Error sincronizando actividades: $e');
    }
  }
}
