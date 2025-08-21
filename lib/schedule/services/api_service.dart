import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systemjvj/core/utils/urlBase.dart';
import 'package:systemjvj/schedule/models/activity_model.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';

class ApiService {
  static const String _baseUrl = BASE_URL;
  static const int _timeoutSeconds = 30;

  final AuthService authService;
  final SharedPreferences prefs;
  final Connectivity connectivity;

  ApiService({
    required this.authService,
    required this.prefs,
    required this.connectivity,
  });

  Future<List<Activity>> getActivities({
    String? search,
    String? typeService,
    String? technical,
    int? status,
    DateTime? startInDate,
    DateTime? endInDate,
    DateTime? start,
    DateTime? end,
  }) async {
    final connectivityResult = await connectivity.checkConnectivity();
    final dbHelper = DatabaseHelper.instance;

    // Si no hay conexión, devolver datos locales
    if (connectivityResult == ConnectivityResult.none) {
      return await dbHelper.getActivities();
    }

    final user = authService.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final params = <String, String>{};

    // Manejo diferenciado por rol
    if (user.role == 'ROLE_Tecnico') {
      params['technicalId'] = user.id;
    } else if (user.role == 'ROLE_Admin' && technical != null) {
      params['technicalId'] = technical;
    }

    // Agregar otros filtros
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (typeService != null) params['typeService'] = typeService;
    if (status != null) params['status'] = status.toString();
    if (startInDate != null) params['startInDate'] = _formatDate(startInDate);
    if (endInDate != null) params['endInDate'] = _formatDate(endInDate);
    if (start != null) params['start'] = start.toIso8601String();
    if (end != null) params['end'] = end.toIso8601String();

    final uri = Uri.parse('$_baseUrl/api/schedule-events')
        .replace(queryParameters: params);
    debugPrint('Solicitando actividades /schedule-events: $uri');

    try {
      // Obtener token del AuthService
      final token = user.token;
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final activities = (data['data'] as List)
            .map((json) => Activity.fromJson(json))
            .toList();

        // Actualizar base de datos local
        await dbHelper.bulkInsertOrUpdateActivities(activities);

        return activities;
      } else {
        // Si falla, devolver datos locales
        return await dbHelper.getActivities();
      }
    } catch (e) {
      debugPrint('Error fetching activities: $e');
      // En caso de error, devolver datos locales
      return await dbHelper.getActivities();
    }
  }

  Future<void> authorizeActivity(String activityId) async {
    final uri = Uri.parse('$_baseUrl/api/schedule/autorize/$activityId');

    try {
      final token = authService.currentUser?.token;
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(uri, headers: headers)
          .timeout(const Duration(seconds: _timeoutSeconds));

      _handleResponse(response, (data) => null);
    } catch (e) {
      debugPrint('Error authorizing activity: $e');
      rethrow;
    }
  }

  Future<void> cancelActivity(String activityId) async {
    final uri = Uri.parse('$_baseUrl/api/schedule/down/$activityId');

    try {
      final token = authService.currentUser?.token;
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(uri, headers: headers)
          .timeout(const Duration(seconds: _timeoutSeconds));

      _handleResponse(response, (data) => null);
    } catch (e) {
      debugPrint('Error canceling activity: $e');
      rethrow;
    }
  }

  Future<void> exportToExcel({
    String? search,
    String? typeService,
    String? technical,
    int? status,
    DateTime? startInDate,
    DateTime? endInDate,
  }) async {
    final params = <String, String>{
      if (search != null && search.isNotEmpty) 'search': search,
      if (typeService != null) 'typeService': typeService,
      if (technical != null) 'technical': technical,
      if (status != null) 'status': status.toString(),
      if (startInDate != null) 'startInDate': _formatDate(startInDate),
      if (endInDate != null) 'endInDate': _formatDate(endInDate),
    };

    final uri = Uri.parse('$_baseUrl/api/schedule/export')
        .replace(queryParameters: params);

    try {
      final token = authService.currentUser?.token;
      final headers = {
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: _timeoutSeconds));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final filename = _getFilenameFromHeaders(response.headers) ??
            'actividades_${DateTime.now().toIso8601String()}.xlsx';

        final file = await _saveFile(filename, bytes);
        await OpenFile.open(file.path);
      } else {
        throw Exception(
            'Error ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('Error exporting to Excel: $e');
      rethrow;
    }
  }

  T _handleResponse<T>(http.Response response, T Function(dynamic) mapper) {
    if (response.statusCode == 200) {
      return mapper(json.decode(response.body));
    } else if (response.statusCode == 401) {
      throw Exception('No autorizado - Por favor inicie sesión nuevamente');
    } else if (response.statusCode >= 400 && response.statusCode < 500) {
      final error = json.decode(response.body);
      throw Exception(error['message'] ?? 'Error del cliente');
    } else if (response.statusCode >= 500) {
      throw Exception('Error del servidor: ${response.reasonPhrase}');
    } else {
      throw Exception('Error inesperado: ${response.statusCode}');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String? _getFilenameFromHeaders(Map<String, String> headers) {
    final contentDisposition = headers['content-disposition'];
    if (contentDisposition != null) {
      final filenameRegex = RegExp('filename=(["\']?)([^;"\']+)\\1');
      final match = filenameRegex.firstMatch(contentDisposition);
      return match?.group(2);
    }
    return null;
  }

  Future<File> _saveFile(String filename, List<int> bytes) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes);
    return file;
  }
}
