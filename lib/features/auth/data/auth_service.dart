import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:systemjvj/core/utils/urlBase.dart';

class AuthService {
  static const String _baseUrl = BASE_URL;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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
        await _storage.write(key: 'access_token', value: _currentUser!.token);
        await _storage.write(
          key: 'user_data',
          value: json.encode({
            'id': _currentUser!.id,
            'username': _currentUser!.username,
            'roles': _currentUser!.roles,
            'role': _currentUser!.role, // Guardar el rol principal
          }),
        );
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
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'user_data');
  }

  Future<void> checkAuthStatus() async {
    final accessToken = await _storage.read(key: 'access_token');
    final userData = await _storage.read(key: 'user_data');

    if (accessToken != null && userData != null) {
      final data = json.decode(userData);
      _currentUser = User(
          token: accessToken,
          username: data['username'],
          roles: List<String>.from(data['roles']),
          role: data['role'], // Recuperar el rol principal
          id: data['id']);
    }
  }
}

class User {
  final String id;
  final String token;
  final String username;
  final List<String> roles;
  final String role; // Nuevo campo para el rol principal

  User({
    required this.id,
    required this.token,
    required this.username,
    required this.roles,
    required this.role,
  });
}
