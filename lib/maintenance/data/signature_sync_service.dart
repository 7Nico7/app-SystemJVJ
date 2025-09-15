import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:systemjvj/core/utils/urlBase.dart';
import 'package:systemjvj/maintenance/data/signatureDatabaseHelper.dart';

class SignatureSyncService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final SignatureDatabaseHelper _dbHelper = SignatureDatabaseHelper.instance;
  String baseUrl = BASE_URL;

  Future<bool> syncPendingSignatures() async {
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        print('❌ Token no encontrado para sincronización de firmas');
        return false;
      }

      // Verificar validez del token
/*       final isValid = await _validateToken(token);
      if (!isValid) {
        print('❌ Token inválido, no se pueden sincronizar firmas');
        return false;
      } */

      // Obtener firmas pendientes
      final pendingSignatures = await _dbHelper.getPendingSignatures();
      print('📋 Firmas pendientes encontradas: ${pendingSignatures.length}');

      if (pendingSignatures.isEmpty) {
        return true;
      }

      bool allSuccess = true;

      for (var signature in pendingSignatures) {
        final success = await _syncSingleSignature(signature, token);
        if (!success) {
          allSuccess = false;
        }
      }

      return allSuccess;
    } catch (e) {
      print('❌ Error en syncPendingSignatures: $e');
      return false;
    }
  }

/* 
  Future<bool> _validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/validate-token'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Error validando token: $e');
      return false;
    }
  }
 */
  Future<bool> _syncSingleSignature(
      Map<String, dynamic> signature, String token) async {
    int maintenanceId;
    try {
      maintenanceId = int.parse(signature['maintenanceId'].toString());

      // Obtener la firma en base64 sin prefijo
      String signatureBase64 = signature['signature'];

      // Agregar el prefijo para que el backend lo reconozca
      String signatureWithPrefix = 'data:image/png;base64,$signatureBase64';

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/maintenance/signature'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'id': maintenanceId,
              'service_rating': signature['rating'],
              'signature': signatureWithPrefix, // Enviamos con prefijo
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Marcar como sincronizado en la base de datos local
        await _dbHelper.markAsSynced(signature['id']);
        print('[SYNC] Respuesta: ${response.statusCode} - ${response.body}');

        print(
            '✅ Firma ${signature['maintenanceId']} sincronizada exitosamente');
        return true;
      } else {
        print('❌ Error del servidor: ${response.statusCode}');
        print('❌ Respuesta: ${response.body}');
        return false;
      }
    } on http.ClientException catch (e) {
      print('❌ Error de conexión: $e');
      return false;
    } on TimeoutException catch (e) {
      print('❌ Timeout sincronizando firma: $e');
      return false;
    } catch (e) {
      print('❌ Error sincronizando firma ${signature['maintenanceId']}: $e');
      return false;
    }
  }

  // Método para verificar el estado de sincronización de una firma específica
  Future<bool> isSignatureSynced(String maintenanceId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'signatures',
        where: 'maintenanceId = ? AND isSynced = ?',
        whereArgs: [maintenanceId, 1],
      );
      return result.isNotEmpty;
    } catch (e) {
      print('❌ Error verificando estado de firma: $e');
      return false;
    }
  }
}
