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

  OfflineService(
      {required this.dbHelper, this.syncService, required this.connectivity}) {
    _loadInitialActivities();
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

  Future<void> _loadInitialActivities() async {
    try {
      _activities = await dbHelper.getActivities();
      notifyListeners();
      print(
          '[OFFLINE] Actividades cargadas inicialmente: ${_activities.length}');
    } catch (e) {
      print('[OFFLINE] Error cargando actividades iniciales: $e');
    }
  }

  Future<void> _trySyncData() async {
    try {
      // Verificar si hay operaciones pendientes antes de sincronizar
      final dbHelper = DatabaseHelper.instance;
      final pendingOps = await dbHelper.getPendingOperations();

      if (pendingOps.isNotEmpty) {
        await syncService!.syncData();
        await loadActivities(); // Recargar actividades después de sincronizar
      }
    } catch (e) {
      print('Error en sincronización automática: $e');
    }
  }

// En OfflineService, modificar registerActivityFlow
  Future<void> registerActivityFlow({
    required String activityId,
    required String scheduleId,
    required String stepType,
    required String timeValue,
  }) async {
    try {
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

      // Intentar sincronización inmediata PERO no bloquear el flujo si falla
      try {
        await _trySyncData();
      } catch (e) {
        print('Error en sincronización inmediata: $e');
        // No hacemos nada aquí porque el registro local ya se completó
      }
    } catch (e) {
      print('Error en registerActivityFlow: $e');
      rethrow; // Relanzar el error para que el caller sepa que falló el registro local
    }
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
