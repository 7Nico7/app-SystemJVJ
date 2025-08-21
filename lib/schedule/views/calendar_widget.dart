import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:systemjvj/schedule/models/activity_model.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';
import 'package:systemjvj/schedule/views/event_detail_dialog.dart';

class CalendarWidget extends StatefulWidget {
  @override
  _CalendarWidgetState createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  bool _showWeekView = true;
  bool _showCalendarView =
      false; // Coloca la vista en calendario en forma de lista primero
  final CalendarController _calendarController = CalendarController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ScheduleProvider>(context);
    final offlineService = Provider.of<OfflineService>(context);
    final connectivityResults = Provider.of<List<ConnectivityResult>>(context);
    final isConnected = !connectivityResults.contains(ConnectivityResult.none);

    return Consumer<ScheduleProvider>(
      builder: (context, provider, child) {
        // Combinar actividades online y offline
        List<Activity> activitiesToShow = provider.activities;
        if (provider.isLoading && offlineService.activities.isNotEmpty) {
          activitiesToShow = offlineService.activities;
        } else if (!provider.isLoading) {
          // Combinar manteniendo los cambios locales
          activitiesToShow = [...provider.activities];
          for (final offlineActivity in offlineService.activities) {
            final index =
                activitiesToShow.indexWhere((a) => a.id == offlineActivity.id);
            if (index != -1) {
              activitiesToShow[index] = offlineActivity;
            } else {
              activitiesToShow.add(offlineActivity);
            }
          }
        }

        // Agrupar actividades por técnico
        final activitiesByTechnician =
            _groupActivitiesByTechnician(activitiesToShow);
        final technicianIds = activitiesByTechnician.keys.toList();

        // Actividades a mostrar (filtradas si hay técnico seleccionado)
        final filteredActivities = provider.selectedTechnicianId != null
            ? activitiesByTechnician[provider.selectedTechnicianId] ?? []
            : activitiesToShow;

        return Column(
          children: [
            // Mostrar estado de conexión
            if (!isConnected)
              Container(
                padding: EdgeInsets.symmetric(vertical: 4),
                color: Colors.orange[100],
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.wifi_off, size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Text(
                        "Modo offline - Usando datos locales",
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ),

            // Selector de técnico (solo para admins con múltiples técnicos)
            if (provider.isAdmin && technicianIds.length > 1)
              _buildTechnicianSelector(provider, technicianIds),

            // Controles de vista
            _buildViewControls(context),

            // Contenido principal
            Expanded(
                child: _showCalendarView
                    ? _buildCalendarView(filteredActivities, provider)
                    : _buildListView(filteredActivities, provider)),
          ],
        );
      },
    );
  }

  Widget _buildTechnicianSelector(
      ScheduleProvider provider, List<String> technicianIds) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: Text('Todos'),
            selected: provider.selectedTechnicianId == null,
            selectedColor: Theme.of(context).primaryColor.withOpacity(0.3),
            onSelected: (_) => provider.setSelectedTechnician(null),
          ),
          ...technicianIds.map((techId) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(
                    provider.getTechnicianName(techId) ?? 'Técnico $techId',
                    style: TextStyle(fontSize: 12),
                  ),
                  selected: provider.selectedTechnicianId == techId,
                  selectedColor:
                      Theme.of(context).primaryColor.withOpacity(0.3),
                  onSelected: (_) => provider.setSelectedTechnician(techId),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildViewControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Selector de vista (Calendario/Lista)
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.calendar_today, size: 20),
                color: _showCalendarView
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                onPressed: () => setState(() => _showCalendarView = true),
              ),
              IconButton(
                icon: Icon(Icons.list, size: 20),
                color: !_showCalendarView
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
                onPressed: () => setState(() => _showCalendarView = false),
              ),
            ],
          ),

          // Selector de periodo (Semana/Día) - Solo visible en vista calendario
          if (_showCalendarView)
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.view_day, size: 20),
                  color: !_showWeekView
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                  onPressed: () {
                    setState(() {
                      _showWeekView = false;
                      _calendarController.view = CalendarView.day;
                      _calendarController.displayDate = DateTime.now();
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.view_week, size: 20),
                  color: _showWeekView
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                  onPressed: () {
                    setState(() {
                      _showWeekView = true;
                      _calendarController.view = CalendarView.week;
                    });
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(
      List<Activity> activities, ScheduleProvider provider) {
    return SfCalendar(
      controller: _calendarController,
      view: _showWeekView ? CalendarView.week : CalendarView.day,
      dataSource: _CalendarDataSource(activities),
      timeSlotViewSettings: TimeSlotViewSettings(
        startHour: 7,
        endHour: 21,
      ),
      onTap: (CalendarTapDetails details) {
        if (details.targetElement == CalendarElement.appointment) {
          final activity = details.appointments!.first as Activity;
          _showEventDetails(context, activity, provider);
        }
      },
      appointmentBuilder: (context, details) {
        final activity = details.appointments.first as Activity;
        return _buildEventWidget(activity, provider);
      },
    );
  }

  Widget _buildListView(List<Activity> activities, ScheduleProvider provider) {
    if (activities.isEmpty) {
      return Center(
        child: Text(
          'No hay actividades disponibles',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildListActivityItem(activity, provider);
      },
    );
  }

  Widget _buildEventWidget(Activity activity, ScheduleProvider provider) {
    final offlineService = Provider.of<OfflineService>(context, listen: false);
    final effectiveStatus = activity.localStatus > 0
        ? activity.localStatus
        : activity.maintenanceStatus;
    final statusColor = _getStatusColor(effectiveStatus);
    final isAdmin = provider.isAdmin;

    final hasPendingChanges = !activity.isSynced;

    // Calcular duración en minutos
    final duration = activity.end.difference(activity.start).inMinutes;
    final isVeryShortEvent = duration < 15;
    final isShortEvent = duration < 30;

    return Container(
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      padding: EdgeInsets.all(isVeryShortEvent ? 0 : (isShortEvent ? 1 : 2)),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isVeryShortEvent) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      //  _getStatusIcon(activity.status),
                      _getStatusIcon(effectiveStatus),

                      size: 10,
                      color: statusColor,
                    ),
                    SizedBox(width: 2),
                    Text(
                      '${_formatTime(activity.start)}',
                      style: TextStyle(fontSize: 7, height: 1.0),
                    ),
                  ],
                ),
              ] else if (isShortEvent) ...[
                Text(
                  activity.folio,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                    color: statusColor,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${_formatTime(activity.start)}',
                  style: TextStyle(fontSize: 7, height: 1.0),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      //_getStatusIcon(activity.status),
                      _getStatusIcon(effectiveStatus),
                      size: 10,
                      color: statusColor,
                    ),
                    SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        activity.folio,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                          color: statusColor,
                          height: 1.0,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 1),
                Text(
                  '${_formatTime(activity.start)}',
                  style: TextStyle(fontSize: 8, height: 1.0),
                ),
                if (isAdmin)
                  SizedBox(
                    height: 12,
                    child: Text(
                      activity.technical.split(' ').take(1).join(' '),
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.w500,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ],
          ),
          if (hasPendingChanges)
            Positioned(
              top: 2,
              right: 2,
              child: Icon(Icons.cloud_off, size: 10, color: Colors.orange),
            ),
        ],
      ),
    );
  }

  Widget _buildListActivityItem(Activity activity, ScheduleProvider provider) {
    final offlineService = Provider.of<OfflineService>(context, listen: false);
    final effectiveStatus = activity.localStatus > 0
        ? activity.localStatus
        : activity.maintenanceStatus;
    final statusColor = _getStatusColor(effectiveStatus);
    final firstChar = _getStatusIcon(effectiveStatus);
    final hasPendingChanges = !activity.isSynced;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.2),
        child: Icon(
          firstChar,
          color: statusColor,
        ),
      ),
      title: Text(
        activity.folio,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_formatDateTime(activity.start)} - ${_formatTime(activity.end)}',
            style: TextStyle(fontSize: 12),
          ),
          Text(
            activity.technical,
            style: TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: hasPendingChanges
          ? Icon(Icons.cloud_off, color: Colors.orange)
          : Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => _showEventDetails(context, activity, provider),
    );
  }

  Map<String, List<Activity>> _groupActivitiesByTechnician(
      List<Activity> activities) {
    final map = <String, List<Activity>>{};
    for (final activity in activities) {
      final techId = activity.technical;
      map.putIfAbsent(techId, () => []).add(activity);
    }
    return map;
  }

  void _showEventDetails(
      BuildContext context, Activity activity, ScheduleProvider provider) {
    final updatedActivity = provider.activities.firstWhere(
      (a) => a.id == activity.id,
      orElse: () => activity,
    );

    showDialog(
      context: context,
      builder: (context) => EventDetailDialog(
        activity: updatedActivity,
        provider: provider,
      ),
    );
  }

  IconData _getStatusIcon(int status) {
    switch (status) {
      case 1:
        return Icons.access_time;
      case 2:
        return Icons.verified;
      case 3:
        return Icons.route_outlined;
      case 4:
        return Icons.timer_outlined;
      case 5:
        return Icons.check_circle_outline;
      default:
        return Icons.verified_user_outlined;
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.deepPurple;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _CalendarDataSource extends CalendarDataSource {
  _CalendarDataSource(List<Activity> activities) {
    appointments = activities;
  }

  @override
  DateTime getStartTime(int index) => appointments![index].start;

  @override
  DateTime getEndTime(int index) => appointments![index].end;

  @override
  String getSubject(int index) => appointments![index].title;

  @override
  Color getColor(int index) => Colors.transparent;
}
