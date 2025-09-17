import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';

import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';

import 'package:systemjvj/schedule/views/calendar_widget.dart';
import 'package:systemjvj/schedule/views/filter_drawer.dart';
import 'package:systemjvj/schedule/views/top_action_bar.dart';

class ScheduleScreen extends StatefulWidget {
  final AuthService authService;
  const ScheduleScreen({super.key, required this.authService});

  @override
  _ScheduleScreenState createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late Future<void> _loadFuture;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ScheduleProvider>(context, listen: false);
    final offlineService = Provider.of<OfflineService>(context, listen: false);
    _loadFuture = _loadInitialData(provider, offlineService);
  }

  Future<void> _loadInitialData(
      ScheduleProvider provider, OfflineService offlineService) async {
    try {
      // Verificar conexión solo en la primera carga
      if (_isInitialLoad) {
        final isConnected = await provider.checkConnectivity();

        if (isConnected) {
          await provider.fetchActivities();
        } else {
          await offlineService.loadActivities();
        }
        _isInitialLoad = false;
      } else {
        await offlineService.loadActivities();
      }
    } catch (e) {
      await offlineService.loadActivities();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheduleProvider = Provider.of<ScheduleProvider>(context);
    final offlineService = Provider.of<OfflineService>(context);

    return Scaffold(
      endDrawer: FilterDrawer(),
      body: Column(
        children: [
          TopActionBar(),
          Expanded(
            child: FutureBuilder(
              future: _loadFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    offlineService.activities.isEmpty) {
                  return Center(child: CircularProgressIndicator());
                }
                return Consumer<ScheduleProvider>(
                  builder: (context, provider, child) {
                    if (provider.isLoading &&
                        offlineService.activities.isEmpty) {
                      return Center(child: CircularProgressIndicator());
                    }
                    return CalendarWidget(authService: widget.authService);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: scheduleProvider.isAdmin
          ? FloatingActionButton(
              onPressed: () => _navigateToAddActivity(context),
              child: Icon(Icons.add),
              tooltip: 'Agregar Actividad',
            )
          : null,
    );
  }

  void _navigateToAddActivity(BuildContext context) {
    // Implementar navegación a pantalla de agregar actividad
  }
}
