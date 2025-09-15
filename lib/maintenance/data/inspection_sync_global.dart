import 'package:systemjvj/maintenance/data/maintenanceSyncService.dart';

@pragma('vm:entry-point')
Future<void> syncInspectionsGlobal() async {
  try {
    print('Iniciando sincronización global de inspecciones...');
    final syncService = MaintenanceSyncService();

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
