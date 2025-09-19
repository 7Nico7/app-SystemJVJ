import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systemjvj/core/utils/urlBase.dart';
import 'package:systemjvj/features/model/user.dart';

class AuthService {
  static const String _baseUrl = BASE_URL;
  final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  User? _currentUser;

  User? get currentUser => _currentUser;

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      log('Conectando a $_baseUrl/api/login');
      final response = await http
          .post(
            Uri.parse('$_baseUrl/api/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      log('Respuesta del servidor: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _currentUser = User(
          id: responseData['user']['id'].toString(),
          token: responseData['accessToken'],
          username: responseData['user']['name'],
          roles: List<String>.from(responseData['roles']),
          role: responseData['roles'][0], // Nuevo campo para el rol principal
        );

        // Guardar en FlutterSecureStorage (seguro)
        await _storage.write(key: 'access_token', value: _currentUser!.token);
        await _storage.write(
          key: 'user_data',
          value: json.encode({
            'id': _currentUser!.id,
            'username': _currentUser!.username,
            'roles': _currentUser!.roles,
            'role': _currentUser!.role,
          }),
        );

        // Guardar en SharedPreferences (para uso en background)
        await _saveTokenToSharedPreferences(_currentUser!.token);
        await _saveUserDataToSharedPreferences({
          'id': _currentUser!.id,
          'username': _currentUser!.username,
          'roles': _currentUser!.roles,
          'role': _currentUser!.role,
        });

        return responseData;
      } else {
        final errorBody =
            response.body.isNotEmpty ? json.decode(response.body) : {};
        throw Exception(errorBody['message'] ??
            'Error en el login: ${response.statusCode}');
      }
    } on SocketException {
      throw Exception('No hay conexión con el servidor');
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado. Verifica tu red');
    } catch (e) {
      log('Error crítico: $e');
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    // Eliminar de FlutterSecureStorage
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'user_data');

    // Eliminar de SharedPreferences
    await _removeTokenFromSharedPreferences();
    await _removeUserDataFromSharedPreferences();
  }

  Future<void> checkAuthStatus() async {
    // Primero intentar cargar desde FlutterSecureStorage (más seguro)
    final accessToken = await _storage.read(key: 'access_token');
    final userData = await _storage.read(key: 'user_data');

    if (accessToken != null && userData != null) {
      final data = json.decode(userData);
      _currentUser = User(
        token: accessToken,
        username: data['username'],
        roles: List<String>.from(data['roles']),
        role: data['role'],
        id: data['id'],
      );

      // Sincronizar con SharedPreferences para background
      await _saveTokenToSharedPreferences(accessToken);
      await _saveUserDataToSharedPreferences(data);
    } else {
      // Fallback a SharedPreferences si no hay datos en SecureStorage
      final sharedPrefsToken = await _getTokenFromSharedPreferences();
      final sharedPrefsUserData = await _getUserDataFromSharedPreferences();

      if (sharedPrefsToken != null && sharedPrefsUserData != null) {
        _currentUser = User(
          token: sharedPrefsToken,
          username: sharedPrefsUserData['username'],
          roles: List<String>.from(sharedPrefsUserData['roles']),
          role: sharedPrefsUserData['role'],
          id: sharedPrefsUserData['id'],
        );

        // Guardar en SecureStorage para mayor seguridad
        await _storage.write(key: 'access_token', value: sharedPrefsToken);
        await _storage.write(
          key: 'user_data',
          value: json.encode(sharedPrefsUserData),
        );
      }
    }
  }

  // Métodos para SharedPreferences (uso en background)
  Future<void> _saveTokenToSharedPreferences(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<String?> _getTokenFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _removeTokenFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<void> _saveUserDataToSharedPreferences(
      Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', json.encode(userData));
  }

  Future<Map<String, dynamic>?> _getUserDataFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');
    if (userDataString != null) {
      return json.decode(userDataString);
    }
    return null;
  }

  Future<void> _removeUserDataFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
  }

  // Método para establecer token desde fuera (útil para background sync)
  Future<void> setToken(String token) async {
    _currentUser = User(
      id: _currentUser?.id ?? '',
      token: token,
      username: _currentUser?.username ?? '',
      roles: _currentUser?.roles ?? [],
      role: _currentUser?.role ?? '',
    );

    await _saveTokenToSharedPreferences(token);
    await _storage.write(key: 'access_token', value: token);
  }

  // Método para obtener el token actual (útil para background sync)
  Future<String?> getToken() async {
    if (_currentUser != null) {
      return _currentUser!.token;
    }

    // Intentar cargar desde SecureStorage primero
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      return token;
    }

    // Fallback a SharedPreferences
    return await _getTokenFromSharedPreferences();
  }

  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
    String newPasswordConfirmation,
  ) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$BASE_URL/api/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'new_password_confirmation': newPasswordConfirmation,
        }),
      );

      final responseBody = json.decode(response.body);

      if (response.statusCode == 200) {
        return responseBody;
      } else if (response.statusCode == 422) {
        // Manejo específico de errores de validación
        if (responseBody['errors']?['current_password'] != null) {
          throw Exception(responseBody['errors']['current_password'][0]);
        }
        if (responseBody['errors']?['new_password'] != null) {
          throw Exception(responseBody['errors']['new_password'][0]);
        }
        throw Exception(responseBody['message'] ?? 'Error de validación');
      } else {
        throw Exception(
            responseBody['message'] ?? 'Error al cambiar contraseña');
      }
    } on SocketException {
      throw Exception('No hay conexión con el servidor');
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado. Verifica tu red');
    } catch (e) {
      throw Exception('Error al cambiar contraseña: ${e.toString()}');
    }
  }

// Método para cargar credenciales específicamente para background
  Future<void> loadCredentialsForBackground() async {
    try {
      // Primero intentar desde SharedPreferences (más confiable para background)
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userDataString = prefs.getString('user_data');

      if (token != null && userDataString != null) {
        final userData = json.decode(userDataString);
        _currentUser = User(
          id: userData['id'],
          token: token,
          username: userData['username'],
          roles: List<String>.from(userData['roles']),
          role: userData['role'],
        );
        return;
      }

      // Fallback a SecureStorage si no hay datos en SharedPreferences
      final secureToken = await _storage.read(key: 'access_token');
      final secureUserData = await _storage.read(key: 'user_data');

      if (secureToken != null && secureUserData != null) {
        final userData = json.decode(secureUserData);
        _currentUser = User(
          id: userData['id'],
          token: secureToken,
          username: userData['username'],
          roles: List<String>.from(userData['roles']),
          role: userData['role'],
        );

        // Guardar en SharedPreferences para próximas ejecuciones en background
        await _saveTokenToSharedPreferences(secureToken);
        await _saveUserDataToSharedPreferences(userData);
      }
    } catch (e) {
      print('❌ Error cargando credenciales para background: $e');
    }
  }
}
