/* import 'package:flutter/foundation.dart';
import 'package:systemjvj/schedule/models/activity_model.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';

class OfflineService with ChangeNotifier {
  final DatabaseHelper dbHelper;
  List<Activity> _activities = [];

  OfflineService(this.dbHelper);

  List<Activity> get activities => _activities;

  Future<void> loadActivities() async {
    _activities = await dbHelper.getActivities();
    notifyListeners();
  }

  Future<void> registerActivityFlow({
    required String activityId,
    required String stepType,
    required String timeValue,
  }) async {
    final activity = await dbHelper.getActivityById(activityId);
    if (activity == null) return;

    // Crear nuevo mapa preservando existentes
    final newPendingTimes = {...activity.pendingTimes};
    int newLocalStatus = activity.localStatus;

    // Actualizar estado local según el paso
    switch (stepType) {
      case 'base_out':
        newPendingTimes['hourBaseOut'] = timeValue;
        newLocalStatus = 3; // En camino
        break;
      case 'arrival':
        newPendingTimes['hourIn'] = timeValue;
        newLocalStatus = 3; // Mantener en camino
        break;
      case 'start':
        newPendingTimes['hourStart'] = timeValue;
        newLocalStatus = 4; // En proceso
        break;
      case 'end':
        newPendingTimes['hourEnd'] = timeValue;
        newLocalStatus = 5; // Finalizado
        break;
      case 'base_in':
        newPendingTimes['hourBaseIn'] = timeValue;
        newLocalStatus = 5; // Mantener finalizado
        break;
      case 'technicalSignature':
        newPendingTimes['technicalSignature'] = timeValue;
        newLocalStatus = 5; // Mantener finalizado
        break;
    }

    // Actualizar actividad con nuevos valores
    final updatedActivity = activity.copyWith(
      pendingTimes: newPendingTimes,
      isSynced: false,
      localStatus: newLocalStatus,
    );

    // Registrar operación pendiente
    await _addPendingOperation(activityId, stepType, timeValue);

    // Guardar en base de datos
    await dbHelper.updateActivity(updatedActivity);

    // Actualizar UI
    await loadActivities();
    notifyListeners();
  }

  Future<void> _addPendingOperation(
      String activityId, String operationType, String timeValue) async {
    await dbHelper.addPendingOperation({
      'activityId': activityId,
      'operation': operationType,
      'timeValue': timeValue,
    });
  }
}
 */

import 'package:flutter/foundation.dart';
import 'package:systemjvj/schedule/models/activity_model.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';

class OfflineService with ChangeNotifier {
  final DatabaseHelper dbHelper;
  List<Activity> _activities = [];

  OfflineService(this.dbHelper);

  List<Activity> get activities => _activities;

  Future<void> loadActivities() async {
    _activities = await dbHelper.getActivities();
    notifyListeners();
  }

  Future<void> registerActivityFlow({
    required String activityId,
    required String stepType,
    required String timeValue,
  }) async {
    final activity = await dbHelper.getActivityById(activityId);
    if (activity == null) return;

    // Crear nuevo mapa preservando existentes
    final newPendingTimes = {...activity.pendingTimes};
    int newLocalStatus = activity.localStatus;

    // Actualizar estado local según el paso
    switch (stepType) {
      case 'base_out':
        newPendingTimes['hourBaseOut'] = timeValue;
        newLocalStatus = 3; // En camino
        break;
      case 'arrival':
        newPendingTimes['hourIn'] = timeValue;
        newLocalStatus = 3; // Mantener en camino
        break;
      case 'start':
        newPendingTimes['hourStart'] = timeValue;
        newLocalStatus = 4; // En proceso
        break;
      case 'end':
        newPendingTimes['hourEnd'] = timeValue;
        newLocalStatus = 5; // Finalizado
        break;
      case 'base_in':
        newPendingTimes['hourBaseIn'] = timeValue;
        newLocalStatus = 5; // Mantener finalizado
        break;
      case 'technicalSignature':
        newPendingTimes['technicalSignature'] = timeValue;
        newLocalStatus = 5; // Mantener finalizado
        break;
    }

    // Actualizar actividad con nuevos valores
    final updatedActivity = activity.copyWith(
      pendingTimes: newPendingTimes,
      isSynced: false,
      localStatus: newLocalStatus,
    );

    // Registrar operación pendiente
    await _addPendingOperation(activityId, stepType, timeValue);

    // Guardar en base de datos
    await dbHelper.updateActivity(updatedActivity);

    // Actualizar UI
    await loadActivities();
// Notificar a los listeners sobre el cambio
    notifyListeners();
  }

  Future<void> _addPendingOperation(
      String activityId, String operationType, String timeValue) async {
    await dbHelper.addPendingOperation({
      'activityId': activityId,
      'operation': operationType,
      'timeValue': timeValue,
    });
  }

  Future<void> markAllAsSynced() async {
    for (int i = 0; i < _activities.length; i++) {
      if (!_activities[i].isSynced) {
        _activities[i] = _activities[i].copyWith(isSynced: true);
        await dbHelper.updateActivity(_activities[i]);
      }
    }
    notifyListeners();
  }

  Future<void> updateActivitySyncStatus(
      String activityId, bool isSynced) async {
    final index = _activities.indexWhere((a) => a.id == activityId);
    if (index != -1) {
      _activities[index] = _activities[index].copyWith(isSynced: isSynced);
      await dbHelper.updateActivity(_activities[index]);
      notifyListeners();
    }
  }
}
