import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/maintenance/data/maintenanceSyncService.dart';

@pragma('vm:entry-point')
Future<void> syncInspectionsGlobal(AuthService authService) async {
  try {
    print('Iniciando sincronización global de inspecciones...');
    final syncService = MaintenanceSyncService(authService: authService);

    // Forzar una nueva verificación de conectividad
    final isOnline = await syncService.checkConnectivity();
    if (!isOnline) {
      print('No hay conexión a internet, omitiendo sincronización');
      return;
    }

    await syncService.syncPendingInspections();
    print('Sincronización global completada');
  } catch (e) {
    print('Error en sincronización de inspecciones: $e');
  }
}
