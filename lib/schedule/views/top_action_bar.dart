/* import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/syncService.dart';

class TopActionBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  Provider.of<ScheduleProvider>(context, listen: false)
                      .setSearchTerm(value),
            ),
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              final provider =
                  Provider.of<ScheduleProvider>(context, listen: false);
              final connectivityResult =
                  await Connectivity().checkConnectivity();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(connectivityResult != ConnectivityResult.none
                      ? "Actualizando actividades..."
                      : "Sin conexión, mostrando datos locales"),
                ),
              );

              provider.fetchActivities(forceRefresh: true);
            },
          ),
          /*     IconButton(
            icon: Icon(Icons.file_download),
            onPressed: () => _exportToExcel(context),
          ), */
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: () => _syncData(context),
            tooltip: 'Sincronizar datos',
          ),
        ],
      ),
    );
  }

  void _exportToExcel(BuildContext context) async {
    final provider = Provider.of<ScheduleProvider>(context, listen: false);
    try {
      await provider.exportToExcel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exportado exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }

  void _syncData(BuildContext context) async {
    final syncService = Provider.of<SyncService>(context, listen: false);
    try {
      await syncService.syncData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Datos sincronizados con éxito')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en sincronización: $e')),
      );
    }
  }
}
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/syncService.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';

class TopActionBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  Provider.of<ScheduleProvider>(context, listen: false)
                      .setSearchTerm(value),
            ),
          ),
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () async {
              final provider =
                  Provider.of<ScheduleProvider>(context, listen: false);
              final connectivityResult =
                  await Connectivity().checkConnectivity();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(connectivityResult != ConnectivityResult.none
                      ? "Actualizando actividades..."
                      : "Sin conexión, mostrando datos locales"),
                ),
              );

              provider.fetchActivities(forceRefresh: true);
            },
          ),
          /*     IconButton(
            icon: Icon(Icons.file_download),
            onPressed: () => _exportToExcel(context),
          ), */
          IconButton(
            icon: Icon(Icons.sync),
            onPressed: () => _syncData(context),
            tooltip: 'Sincronizar datos',
          ),
        ],
      ),
    );
  }

  void _exportToExcel(BuildContext context) async {
    final provider = Provider.of<ScheduleProvider>(context, listen: false);
    try {
      await provider.exportToExcel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exportado exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }

  void _syncData(BuildContext context) async {
    final syncService = Provider.of<SyncService>(context, listen: false);
    final offlineService = Provider.of<OfflineService>(context, listen: false);
    final scheduleProvider =
        Provider.of<ScheduleProvider>(context, listen: false);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sincronizando datos...')),
      );

      await syncService.syncData();

      // Actualizar el estado de sincronización de las actividades
      await offlineService.markAllAsSynced();

      // Forzar la actualización del proveedor de horarios
      await scheduleProvider.fetchActivities(forceRefresh: true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Datos sincronizados con éxito')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en sincronización: $e')),
      );
    }
  }
}
