import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class LocationService {
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      // Verificar permisos
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return _handleLocationError('Servicios de ubicación desactivados');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return _handleLocationError('Permisos de ubicación denegados');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return _handleLocationError(
            'Permisos de ubicación permanentemente denegados');
      }

      // Verificar conectividad
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline = connectivityResult != ConnectivityResult.none;

      // Obtener ubicación
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            isOnline ? LocationAccuracy.high : LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      // Solo obtener dirección si hay conexión
      String address = '';

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address':
            address, // Siempre vacío, se obtendrá después si hay conexión
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'needsAddressLookup':
            isOnline, // Bandera para indicar si necesita obtener dirección
      };
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      return _handleLocationError(e.toString());
    }
  }

  static Map<String, dynamic> _handleLocationError(String error) {
    return {
      'latitude': null,
      'longitude': null,
      'address': '',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'needsAddressLookup': false,
    };
  }

  // Método separado para obtener dirección solo cuando hay conexión
  static Future<String> getAddressFromCoordinates(
      double lat, double lng) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return ''; // Sin conexión, retornar vacío
      }

      // Usar geocoding directamente ya que el paquete está importado
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 10));

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        String address = '';

        if (placemark.street != null) address += placemark.street!;
        if (placemark.locality != null) address += ', ${placemark.locality!}';
        if (placemark.country != null) address += ', ${placemark.country!}';

        return address.trim();
      }

      return '';
    } on TimeoutException {
      print('Timeout al obtener dirección');
      return '';
    } catch (e) {
      print('Error obteniendo dirección: $e');
      return '';
    }
  }
}
