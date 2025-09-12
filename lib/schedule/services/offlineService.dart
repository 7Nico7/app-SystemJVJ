/* 

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
    required String scheduleId,
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
      case 'technicalSignature':
        newPendingTimes['technicalSignature'] = timeValue;
        newLocalStatus = 4; // Mantener finalizado
        break;
      case 'end':
        newPendingTimes['hourEnd'] = timeValue;
        newLocalStatus = 5; // Finalizado
        break;
      case 'base_in':
        newPendingTimes['hourBaseIn'] = timeValue;
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
    await _addPendingOperation(activityId, stepType, timeValue, scheduleId);

    // Guardar en base de datos
    await dbHelper.updateActivity(updatedActivity);

    // Actualizar UI
    await loadActivities();
// Notificar a los listeners sobre el cambio
    notifyListeners();
  }

  Future<void> _addPendingOperation(String activityId, String operationType,
      String timeValue, String scheduleId) async {
    await dbHelper.addPendingOperation({
      'activityId': activityId,
      'scheduleId': scheduleId,
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
 */

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:systemjvj/schedule/models/activity_model.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';
import 'package:systemjvj/schedule/services/syncService.dart';

class OfflineService with ChangeNotifier {
  final DatabaseHelper dbHelper;
  SyncService? syncService;
  final Connectivity connectivity;
  List<Activity> _activities = [];
  Timer? _syncTimer;
  OfflineService(this.dbHelper, this.syncService, this.connectivity) {
    _startSyncTimer();
    _setupConnectivityListener();
  }

  List<Activity> get activities => _activities;

  Future<void> loadActivities() async {
    _activities = await dbHelper.getActivities();
    notifyListeners();
  }

  void _startSyncTimer() {
    // Sincronizar cada 5 minutos
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _trySyncData();
    });
  }

  void _setupConnectivityListener() {
    connectivity.onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        await _trySyncData();
      }
    });
  }

  Future<void> _trySyncData() async {
    try {
      await syncService!.syncData();
      await loadActivities(); // Recargar actividades después de sincronizar
    } catch (e) {
      if (kDebugMode) {
        print('Error en sincronización automática: $e');
      }
    }
  }

  Future<void> registerActivityFlow({
    required String activityId,
    required String scheduleId,
    required String stepType,
    required String timeValue,
  }) async {
    final activity = await dbHelper.getActivityById(activityId);
    if (activity == null) return;

    final newPendingTimes = {...activity.pendingTimes};
    int newLocalStatus = activity.localStatus;

    switch (stepType) {
      case 'base_out':
        newPendingTimes['hourBaseOut'] = timeValue;
        newLocalStatus = 3;
        break;
      case 'arrival':
        newPendingTimes['hourIn'] = timeValue;
        newLocalStatus = 3;
        break;
      case 'start':
        newPendingTimes['hourStart'] = timeValue;
        newLocalStatus = 4;
        break;
      case 'technicalSignature':
        newPendingTimes['technicalSignature'] = timeValue;
        newLocalStatus = 4;
        break;
      case 'end':
        newPendingTimes['hourEnd'] = timeValue;
        newLocalStatus = 5;
        break;
      case 'base_in':
        newPendingTimes['hourBaseIn'] = timeValue;
        newLocalStatus = 5;
        break;
    }

    final updatedActivity = activity.copyWith(
      pendingTimes: newPendingTimes,
      isSynced: false,
      localStatus: newLocalStatus,
    );

    await _addPendingOperation(activityId, stepType, timeValue, scheduleId);
    await dbHelper.updateActivity(updatedActivity);
    await loadActivities();

    // Intentar sincronización inmediata
    await _trySyncData();
  }

  Future<void> _addPendingOperation(String activityId, String operationType,
      String timeValue, String scheduleId) async {
    await dbHelper.addPendingOperation({
      'activityId': activityId,
      'scheduleId': scheduleId,
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

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
