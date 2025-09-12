import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:systemjvj/core/utils/urlBase.dart';
import 'package:systemjvj/maintenance/data/signatureDatabaseHelper.dart';

class SignatureSyncService {
  static const String _baseUrl = BASE_URL;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final SignatureDatabaseHelper _dbHelper = SignatureDatabaseHelper.instance;

  Future<bool> syncPendingSignatures() async {
    print(
        'SignatureSyncService: Iniciando sincronización de firmas pendientes.');
    final signatures = await _dbHelper.getPendingSignatures();
    if (signatures.isEmpty) {
      print('SignatureSyncService: No hay firmas pendientes para sincronizar.');
      return true;
    }
    print(
        'SignatureSyncService: Se encontraron ${signatures.length} firmas pendientes.');

    final token = await _storage.read(key: 'access_token');
    if (token == null) {
      print('SignatureSyncService: Error: Token de acceso no encontrado.');
      return false;
    }
    print('SignatureSyncService: Token de acceso obtenido.');

    final client = http.Client();
    try {
      bool allSuccess = true;

      for (var signature in signatures) {
        print(
            'SignatureSyncService: Procesando firma con id local: ${signature['id']}');
        try {
          // Asegúrate de que 'maintenanceId' es una cadena numérica
          final maintenanceId = signature['maintenanceId'];
          if (maintenanceId == null) {
            print(
                'SignatureSyncService: Error: maintenanceId es nulo para la firma ${signature['id']}');
            allSuccess = false;
            continue; // Salta a la siguiente firma
          }

          final int parsedMaintenanceId =
              int.tryParse(maintenanceId as String) ??
                  0; // Manejo seguro de la conversión
          if (parsedMaintenanceId == 0 &&
              (maintenanceId as String).isNotEmpty) {
            // Si falla la conversión y no es cadena vacía
            print(
                'SignatureSyncService: Error: maintenanceId no es un número válido: $maintenanceId para firma ${signature['id']}');
            allSuccess = false;
            continue; // Salta a la siguiente firma
          }

          final String base64Signature = signature['signature'];
          final String prefixedSignature =
              'data:image/png;base64,$base64Signature';

          final data = {
            'id': parsedMaintenanceId, // Usar el ID parseado
            'service_rating': signature['rating'],
            'signature': prefixedSignature,
          };
          print(
              'SignatureSyncService: Datos a enviar para la firma ${signature['id']}: $data');

          final response = await client.post(
            Uri.parse('$_baseUrl/api/maintenance/signature'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(data),
          );

          if (response.statusCode == 200) {
            print(
                'SignatureSyncService: Firma ${signature['id']} sincronizada exitosamente.');
            await _dbHelper.markAsSynced(signature['id'] as int);
          } else {
            print(
                'SignatureSyncService: Error sincronizando firma ${signature['id']}: ${response.statusCode}');
            print(
                'SignatureSyncService: Response body para firma ${signature['id']}: ${response.body}');
            allSuccess = false;
          }
        } catch (e) {
          print(
              'SignatureSyncService: Error en firma individual ${signature['id']}: $e');
          allSuccess = false;
        }
      }

      print(
          'SignatureSyncService: Sincronización finalizada. Éxito total: $allSuccess');
      return allSuccess;
    } catch (e) {
      print('SignatureSyncService: Error general en sincronización: $e');
      return false;
    } finally {
      client.close();
      print('SignatureSyncService: Cliente HTTP cerrado.');
    }
  }

  Future<bool> syncPendingTechnicianSignatures() async {
    print(
        'SignatureSyncService: Iniciando sincronización de firmas de técnicos.');
    final signatures = await _dbHelper.getPendingTechnicianSignatures();
    if (signatures.isEmpty) {
      print('SignatureSyncService: No hay firmas de técnicos pendientes.');
      return true;
    }
    print(
        'SignatureSyncService: Se encontraron ${signatures.length} firmas de técnicos pendientes.');

    final token = await _storage.read(key: 'access_token');
    if (token == null) {
      print('SignatureSyncService: Error: Token de acceso no encontrado.');
      return false;
    }

    final client = http.Client();
    try {
      bool allSuccess = true;

      for (var signature in signatures) {
        print(
            'SignatureSyncService: Procesando firma de técnico con id local: ${signature['id']}');
        try {
          final maintenanceId = signature['maintenanceId'];
          if (maintenanceId == null) {
            print('SignatureSyncService: Error: maintenanceId es nulo');
            allSuccess = false;
            continue;
          }

          final String base64Signature = signature['signature'];
          final String prefixedSignature =
              'data:image/png;base64,$base64Signature';

          final data = {
            'maintenance_id': int.parse(maintenanceId),
            'technician_signature': prefixedSignature,
          };
          print('SignatureSyncService: Datos a enviar: $data');

          final response = await client.post(
            Uri.parse('$_baseUrl/api/maintenance/technician-signature'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(data),
          );

          if (response.statusCode == 200) {
            print(
                'SignatureSyncService: Firma de técnico ${signature['id']} sincronizada.');
            await _dbHelper
                .markTechnicianSignatureAsSynced(signature['id'] as int);
          } else {
            print(
                'SignatureSyncService: Error ${response.statusCode}: ${response.body}');
            allSuccess = false;
          }
        } catch (e) {
          print('SignatureSyncService: Error en firma individual: $e');
          allSuccess = false;
        }
      }

      print(
          'SignatureSyncService: Sincronización de técnicos finalizada. Éxito: $allSuccess');
      return allSuccess;
    } catch (e) {
      print('SignatureSyncService: Error general: $e');
      return false;
    } finally {
      client.close();
    }
  }
}
