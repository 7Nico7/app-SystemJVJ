/* import 'package:flutter/material.dart';
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
              style: TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar actividades...',
                prefixIcon: Icon(Icons.search),
                isDense: true, // ← Agregar esto

                contentPadding: EdgeInsets.symmetric(vertical: 12),
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
          Consumer<SyncService>(
            builder: (context, syncService, child) {
/*               return IconButton(
                icon: syncService.isSyncing
                    ? CircularProgressIndicator()
                    : Icon(Icons.sync),
                onPressed:
                    syncService.isSyncing ? null : () => _syncData(context),
                tooltip: 'Sincronizar datos',
              ); */

              return IconButton(
                icon: syncService.isSyncing
                    ? SizedBox(
                        // ← Mejorar indicador de progreso
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.sync),
                onPressed:
                    syncService.isSyncing ? null : () => _syncData(context),
                tooltip: 'Sincronizar datos',
              );
            },
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
    final scheduleProvider =
        Provider.of<ScheduleProvider>(context, listen: false);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sincronizando datos...')),
      );

      await syncService.syncData();
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
 */
/* 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/syncService.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';

class TopActionBar extends StatefulWidget {
  @override
  _TopActionBarState createState() => _TopActionBarState();
}

class _TopActionBarState extends State<TopActionBar> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == stt.SpeechToText.listeningStatus) {
          setState(() => _isListening = true);
        }
      },
      onError: (error) => print('Error: $error'),
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
            // Actualizar el término de búsqueda directamente
            Provider.of<ScheduleProvider>(context, listen: false)
                .setSearchTerm(_lastWords);
          });
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 5),
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    return Padding(
      padding: EdgeInsets.all(isLargeScreen ? 16.0 : 8.0),
      child: Center(
        child: Container(
          constraints: isLargeScreen
              ? BoxConstraints(
                  maxWidth: 800) // Limitar ancho en pantallas grandes
              : null,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(fontSize: isLargeScreen ? 16 : 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar actividades...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                      onPressed: () {
                        if (_isListening) {
                          _stopListening();
                        } else {
                          _startListening();
                        }
                      },
                      color: _isListening ? Colors.red : null,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isLargeScreen ? 16 : 12,
                      horizontal: isLargeScreen ? 16 : 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(isLargeScreen ? 12 : 8),
                    ),
                  ),
                  onChanged: (value) =>
                      Provider.of<ScheduleProvider>(context, listen: false)
                          .setSearchTerm(value),
                ),
              ),
              if (isLargeScreen)
                SizedBox(width: 16), // Más espacio en pantallas grandes
              IconButton(
                icon: Icon(Icons.filter_list, size: isLargeScreen ? 28 : 24),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
              if (isLargeScreen) SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh, size: isLargeScreen ? 28 : 24),
                onPressed: () async {
                  final provider =
                      Provider.of<ScheduleProvider>(context, listen: false);
                  final connectivityResult =
                      await Connectivity().checkConnectivity();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          connectivityResult != ConnectivityResult.none
                              ? "Actualizando actividades..."
                              : "Sin conexión, mostrando datos locales"),
                    ),
                  );

                  provider.fetchActivities(forceRefresh: true);
                },
              ),
              if (isLargeScreen) SizedBox(width: 8),
              Consumer<SyncService>(
                builder: (context, syncService, child) {
                  return IconButton(
                    icon: syncService.isSyncing
                        ? SizedBox(
                            width: isLargeScreen ? 24 : 20,
                            height: isLargeScreen ? 24 : 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.sync, size: isLargeScreen ? 28 : 24),
                    onPressed:
                        syncService.isSyncing ? null : () => _syncData(context),
                    tooltip: 'Sincronizar datos',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _speech.stop();
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
    final scheduleProvider =
        Provider.of<ScheduleProvider>(context, listen: false);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sincronizando datos...')),
      );

      await syncService.syncData();
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
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/syncService.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';

class TopActionBar extends StatefulWidget {
  @override
  _TopActionBarState createState() => _TopActionBarState();
}

class _TopActionBarState extends State<TopActionBar> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _searchController = TextEditingController();

    // Establecer el texto inicial si ya hay un término de búsqueda
    final provider = Provider.of<ScheduleProvider>(context, listen: false);
    _searchController.text = provider.searchTerm;
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == stt.SpeechToText.listeningStatus) {
          setState(() => _isListening = true);
        } else if (status == stt.SpeechToText.notListeningStatus) {
          setState(() => _isListening = false);
        }
      },
      onError: (error) => print('Error: $error'),
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _searchController.text = result.recognizedWords;
            // Actualizar el término de búsqueda en el provider
            Provider.of<ScheduleProvider>(context, listen: false)
                .setSearchTerm(result.recognizedWords);
          });
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 5),
        partialResults: true, // Para ver resultados parciales mientras se habla
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('El reconocimiento de voz no está disponible')),
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;

    return Padding(
      padding: EdgeInsets.all(isLargeScreen ? 16.0 : 8.0),
      child: Center(
        child: Container(
          constraints: isLargeScreen ? BoxConstraints(maxWidth: 800) : null,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController, // Controlador agregado
                  style: TextStyle(fontSize: isLargeScreen ? 16 : 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar actividades...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _isListening
                        ? IconButton(
                            icon: Icon(Icons.stop, color: Colors.red),
                            onPressed: _stopListening,
                          )
                        : IconButton(
                            icon: Icon(Icons.mic),
                            onPressed: _startListening,
                          ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isLargeScreen ? 16 : 12,
                      horizontal: isLargeScreen ? 16 : 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(isLargeScreen ? 12 : 8),
                    ),
                  ),
                  onChanged: (value) =>
                      Provider.of<ScheduleProvider>(context, listen: false)
                          .setSearchTerm(value),
                ),
              ),
              if (isLargeScreen) SizedBox(width: 16),
              IconButton(
                icon: Icon(Icons.filter_list, size: isLargeScreen ? 28 : 24),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
              if (isLargeScreen) SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh, size: isLargeScreen ? 28 : 24),
                onPressed: () async {
                  final provider =
                      Provider.of<ScheduleProvider>(context, listen: false);
                  final connectivityResult =
                      await Connectivity().checkConnectivity();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          connectivityResult != ConnectivityResult.none
                              ? "Actualizando actividades..."
                              : "Sin conexión, mostrando datos locales"),
                    ),
                  );

                  provider.fetchActivities(forceRefresh: true);
                },
              ),
              if (isLargeScreen) SizedBox(width: 8),
              Consumer<SyncService>(
                builder: (context, syncService, child) {
                  return IconButton(
                    icon: syncService.isSyncing
                        ? SizedBox(
                            width: isLargeScreen ? 24 : 20,
                            height: isLargeScreen ? 24 : 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.sync, size: isLargeScreen ? 28 : 24),
                    onPressed:
                        syncService.isSyncing ? null : () => _syncData(context),
                    tooltip: 'Sincronizar datos',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _speech.stop();
    super.dispose();
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
    final scheduleProvider =
        Provider.of<ScheduleProvider>(context, listen: false);

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sincronizando datos...')),
      );

      await syncService.syncData();
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
