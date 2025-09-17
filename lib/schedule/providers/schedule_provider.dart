import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:systemjvj/schedule/models/activity_model.dart';
import 'package:systemjvj/schedule/services/api_service.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';

class ScheduleProvider with ChangeNotifier {
  ApiService apiService;
  List<Activity> _activities = [];
  bool _isLoading = false;
  String _searchTerm = '';
  String? _typeService;
  String? _selectedTechnicianId;
  int? _status;
  DateTime? _startInDate;
  DateTime? _endInDate;
  bool _isAdmin = false;
  final Connectivity connectivity;

  final Map<String, String> _technicianNames = {};

  ScheduleProvider({required this.apiService, required this.connectivity}) {
    _checkUserRole();
  }

  List<Activity> get activities => _activities;
  bool get isLoading => _isLoading;
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

  //refrescar actividades
  Future<void> refreshActivities() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dbHelper = DatabaseHelper.instance;
      _activities = await dbHelper.getActivities();

      if (kDebugMode) {
        print('Actividades refrescadas: ${_activities.length}');

        // Depuración detallada
        for (var activity in _activities) {
          print('Actividad ID: ${activity.id}');
          print(' - inspectionId: ${activity.inspectionId}');
          print(' - inspectionConcluded: ${activity.inspectionConcluded}');
          print(' - transportUnit: ${activity.transportUnit}');
          print(' - maintenanceStatus: ${activity.maintenanceStatus}');
          print(' - localStatus: ${activity.localStatus}');
          print('---');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refrescando actividades: $e');
      }
    } finally {
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
      if (isConnected || forceRefresh) {
        _activities = await apiService.getActivities(
          search: _searchTerm,
          typeService: _typeService,
          technical: _isAdmin ? _selectedTechnicianId : null,
          status: _status,
          startInDate: _startInDate,
          endInDate: _endInDate,
        );
        _updateTechnicianNames();
      } else {
        _activities = await dbHelper.getActivities();
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
