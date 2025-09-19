import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:systemjvj/schedule/models/activity_model.dart';
import 'package:systemjvj/schedule/services/api_service.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';
import 'package:systemjvj/schedule/services/syncService.dart';

class ScheduleProvider with ChangeNotifier {
  ApiService apiService;
  List<Activity> _activities = [];
  String _searchTerm = '';
  String? _typeService;
  String? _selectedTechnicianId;
  int? _status;
  DateTime? _startInDate;
  DateTime? _endInDate;
  bool _isAdmin = false;
  final Connectivity connectivity;
  String get searchTerm => _searchTerm;

  List<Activity> _localActivities = []; // Actividades con cambios locales
  SyncService syncService; // Añadir referencia al SyncService
  bool _isLoading = false;
  bool _isSyncing = false; // Nuevo estado para sincronización

  final Map<String, String> _technicianNames = {};

  ScheduleProvider({
    required this.apiService,
    required this.connectivity,
    required this.syncService,
  }) {
    _checkUserRole();
  }

  List<Activity> get activities => _isSyncing ? _localActivities : _activities;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing; // Nuevo getter

  int? get status => _status;
  DateTime? get startInDate => _startInDate;
  DateTime? get endInDate => _endInDate;
  String? get typeService => _typeService;
  String? get selectedTechnicianId => _selectedTechnicianId;
  bool get isAdmin => _isAdmin;

  String? getTechnicianName(String? id) {
    if (id == null) return null;
    return _technicianNames[id];
  }

  void _checkUserRole() {
    final user = apiService.authService.currentUser;
    final newIsAdmin = user?.role == 'ROLE_Admin';

    if (newIsAdmin != _isAdmin) {
      _isAdmin = newIsAdmin;
      notifyListeners();
    }
  }

  Future<void> refreshActivities() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dbHelper = DatabaseHelper.instance;

      // Siempre cargar actividades locales primero
      _localActivities = await dbHelper.getActivities();
      print(
          '[SCHEDULE] Actividades locales cargadas: ${_localActivities.length}');

      // Verificar conexión antes de intentar sincronizar
      final isConnected = await checkConnectivity();

      if (isConnected) {
        // Marcar que comenzó la sincronización
        _isSyncing = true;
        notifyListeners();

        try {
          // Sincronizar datos antes de cargar desde el servidor
          await syncService.syncData();
        } catch (e) {
          print('Error durante sincronización: $e');
        }

        try {
          // Ahora cargar actividades actualizadas del servidor
          _activities = await apiService.getActivities(
            search: _searchTerm,
            typeService: _typeService,
            technical: _isAdmin ? _selectedTechnicianId : null,
            status: _status,
            startInDate: _startInDate,
            endInDate: _endInDate,
          );

          // Actualizar nombres de técnicos
          _updateTechnicianNames();
        } catch (e) {
          print('Error obteniendo actividades del servidor: $e');
          // Usar datos locales si falla la obtención del servidor
          _activities = _localActivities;
        }
      } else {
        // Sin conexión, usar solo datos locales
        _activities = _localActivities;
        print(
            '[SCHEDULE] Usando datos locales (sin conexión): ${_activities.length}');
      }
    } catch (e) {
      print('Error refrescando actividades: $e');
      // En caso de error, usar datos locales
      _activities = _localActivities;
    } finally {
      _isSyncing = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> checkConnectivity() async {
    final connectivityResult = await connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  void updateApiService(ApiService newApiService) {
    apiService = newApiService;
    _checkUserRole();
  }

  void setSearchTerm(String term) {
    _searchTerm = term;
    fetchActivities();
  }

  void setTypeService(String? typeService) {
    _typeService = typeService;
    fetchActivities();
  }

  void setSelectedTechnician(String? technicianId) {
    _selectedTechnicianId = technicianId;
    fetchActivities();
  }

  void setStatus(int? status) {
    _status = status;
    fetchActivities();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startInDate = start;
    _endInDate = end;
    fetchActivities();
  }

  void addTechnicianName(String id, String name) {
    _technicianNames[id] = name;
  }

  Future<void> fetchActivities({bool forceRefresh = false}) async {
    _isLoading = true;
    // Usar microtask para evitar notificaciones durante el build
    Future.microtask(() => notifyListeners());

    final isConnected = await checkConnectivity();
    final dbHelper = DatabaseHelper.instance;

    try {
      // Siempre cargar actividades locales primero
      _localActivities = await dbHelper.getActivities();

      if (isConnected || forceRefresh) {
        // Marcar inicio de sincronización
        _isSyncing = true;
        notifyListeners();

        // Sincronizar antes de obtener datos del servidor
        await syncService.syncData();

        _activities = await apiService.getActivities(
          search: _searchTerm,
          typeService: _typeService,
          technical: _isAdmin ? _selectedTechnicianId : null,
          status: _status,
          startInDate: _startInDate,
          endInDate: _endInDate,
        );
        _updateTechnicianNames();

        // Marcar fin de sincronización
        _isSyncing = false;
      } else {
        // Sin conexión, usar solo datos locales
        _activities = _localActivities;
      }

      if (kDebugMode) {
        print('Actividades recibidas: ${_activities.length}');
        print('Técnicos encontrados: ${_technicianNames.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo actividades: $e');
      }
      // En caso de error, intentar cargar desde local
      _activities = await dbHelper.getActivities();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // En ScheduleProvider, añade estos métodos:
  void updateSyncService(SyncService newSyncService) {
    syncService = newSyncService;
  }

  void _updateTechnicianNames() {
    for (final activity in _activities) {
      if (activity.technical!.isNotEmpty) {
        _technicianNames[activity.technical!] = activity.technical!;
      }
    }
  }

  Future<void> authorizeActivity(String activityId) async {
    try {
      await apiService.authorizeActivity(activityId);
      final index = _activities.indexWhere((a) => a.id == activityId);
      if (index != -1) {
        _activities[index] = _activities[index].copyWith(status: 3);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error autorizando actividad: $e');
      }
      rethrow;
    }
  }

  Future<void> cancelActivity(String activityId) async {
    try {
      await apiService.cancelActivity(activityId);
      final index = _activities.indexWhere((a) => a.id == activityId);
      if (index != -1) {
        _activities[index] = _activities[index].copyWith(status: 2);
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cancelando actividad: $e');
      }
      rethrow;
    }
  }

  Future<void> exportToExcel() async {
    try {
      await apiService.exportToExcel(
        search: _searchTerm,
        typeService: _typeService,
        technical: _isAdmin ? _selectedTechnicianId : null,
        status: _status,
        startInDate: _startInDate,
        endInDate: _endInDate,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error exportando a Excel: $e');
      }
      rethrow;
    }
  }

  void resetFilters() {
    _searchTerm = '';
    _typeService = null;
    _selectedTechnicianId = null;
    _status = null;
    _startInDate = null;
    _endInDate = null;
    fetchActivities();
  }

  // Método para resetear completamente el estado del provider
  void reset() {
    _activities = [];
    _isLoading = false;
    _searchTerm = '';
    _typeService = null;
    _selectedTechnicianId = null;
    _status = null;
    _startInDate = null;
    _endInDate = null;
    _technicianNames.clear();
    _checkUserRole(); // Actualiza el rol según el usuario actual
  }

  // Método para refrescar el rol del usuario
  void refreshUserRole() {
    _checkUserRole();
  }
}
