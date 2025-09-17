import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/maintenance/data/signatureDatabaseHelper.dart';
import 'package:systemjvj/maintenance/presentation/clientSignatureForm.dart';

import 'package:systemjvj/maintenance/presentation/maintenance_check_form1.dart';

import 'package:systemjvj/schedule/models/activity_model.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';
import 'package:systemjvj/schedule/services/syncService.dart';

class EventDetailDialog extends StatefulWidget {
  final Activity activity;
  final ScheduleProvider provider;
  final AuthService authService;

  const EventDetailDialog(
      {Key? key,
      required this.activity,
      required this.provider,
      required this.authService})
      : super(key: key);

  @override
  _EventDetailDialogState createState() => _EventDetailDialogState();
}

class _EventDetailDialogState extends State<EventDetailDialog> {
  late Activity _currentActivity;
  bool _hasLocalSignature = false;
  bool _isProcessing = false; // Bandera para controlar procesos en curso

  @override
  void initState() {
    super.initState();
    _currentActivity = widget.provider.activities.firstWhere(
      (a) => a.id == widget.activity.id,
      orElse: () => widget.activity,
    );
    widget.provider.addListener(_updateActivity);
    _checkLocalSignature();
  }

  void _checkLocalSignature() async {
    final signatureHelper = SignatureDatabaseHelper.instance;
    final hasLocal = await signatureHelper.hasSignature(
      _currentActivity.maintenanceId.toString(),
    );
    if (mounted) {
      setState(() {
        _hasLocalSignature = hasLocal;
      });
    }
  }

  @override
  void dispose() {
    widget.provider.removeListener(_updateActivity);
    super.dispose();
  }

  Future<bool> _hasPendingExternalActivity(BuildContext context) async {
    final offlineService = Provider.of<OfflineService>(context, listen: false);
    final provider = Provider.of<ScheduleProvider>(context, listen: false);

    // Combinar todas las actividades
    List<Activity> allActivities = [...provider.activities];
    for (final offlineActivity in offlineService.activities) {
      if (!allActivities.any((a) => a.id == offlineActivity.id)) {
        allActivities.add(offlineActivity);
      }
    }

    // Filtrar actividades del mismo técnico
    final technicianActivities = allActivities
        .where((a) => a.technical == _currentActivity.technical)
        .toList();

    for (final activity in technicianActivities) {
      // Saltar la actividad actual
      if (activity.id == _currentActivity.id) continue;

      final effectiveStatus = activity.localStatus > 0
          ? activity.localStatus
          : activity.maintenanceStatus;

      // Verificar si es una actividad externa pendiente
      if (activity.serviceScope == 2 && // Externa
          effectiveStatus >= 3 && // Estado 3 (en camino) o superior
          activity.hourBaseIn == null && // No ha regresado a base
          activity.technicalSignature == null) {
        // No ha firmado

        // Verificar si tiene registro local pendiente de base_in
        final hasPendingBaseIn =
            activity.pendingTimes.containsKey('hourBaseIn');
        if (!hasPendingBaseIn) {
          return true;
        }
      }
    }

    return false;
  }

  Widget _buildActionButtonWithValidation(
      BuildContext context, String text, String operationType) {
    return TextButton(
      onPressed: () async {
        // Validar para actividades de salida de base o inicio de trabajo interno
        if (operationType == 'base_out' ||
            (operationType == 'start' && _currentActivity.serviceScope == 1)) {
          final hasPending = await _hasPendingExternalActivity(context);
          if (hasPending) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('No puede iniciar una nueva actividad. '
                    'Tiene una actividad externa pendiente de regresar a base y firmar.'),
              ),
            );
            return;
          }
        }
        _registerFlowStep(context, operationType);
      },
      child: Text(text),
    );
  }

  void _updateActivity() {
    final updatedActivity = widget.provider.activities.firstWhere(
      (a) => a.id == _currentActivity.id,
      orElse: () => _currentActivity,
    );

    if (updatedActivity != _currentActivity) {
      if (mounted) {
        setState(() {
          _currentActivity = updatedActivity;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = _currentActivity;
    final offlineService = Provider.of<OfflineService>(context, listen: false);

    final effectiveStatus = activity.localStatus > 0
        ? activity.localStatus
        : activity.maintenanceStatus;

    final isExternalService = activity.serviceScope == 2;
    final hasPendingBaseIn = activity.pendingTimes.containsKey('hourBaseIn');
    final hasSyncedBaseIn = activity.hourBaseIn != null;

    final hourbaseInLocal = activity.pendingTimes.containsKey('hourBaseIn');
    final hourbaseInBackend = activity.hourBaseIn != null;

    final technicalSignatureInLocal =
        activity.pendingTimes.containsKey('technicalSignature');
    final technicalSignatureInBackend = activity.technicalSignature != null;

    final isInspectionConcluded = activity.inspectionConcluded;
    final hasTransportUnit =
        activity.transportUnit != null && activity.transportUnit!.isNotEmpty;

    final hasSigned = activity.serviceRating == 1 || _hasLocalSignature;

    return AlertDialog(
/*       title: Text(
        activity.name == null || activity.name!.isEmpty
            ? 'Sin nombre'
            : activity.name!,
        style: TextStyle(fontWeight: FontWeight.bold),
      ), */
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('FOLIO:', '${activity.title}'),
            _buildDetailRow('DESCRIPCIÓN:', activity.description!),
            _buildDetailRow('SERVICIO:',
                activity.serviceScope == 2 ? "EXTERNO" : "INTERNO"),
            _buildDetailRow('FECHA:', '${_formatDate(activity.start)}'),
            _buildDetailRow('HORA:',
                '${_formatTime(activity.start)} - ${_formatTime(activity.end)}'),
            _buildDetailRow(
                'UBICACIÓN:',
                activity.location != null
                    ? activity.location!
                    : "Sin ubicación"),
            _buildDetailRow('CLIENTE:',
                activity.client != null ? activity.client! : "Sin cliente"),
            _buildDetailRow(
                'TÉCNICO:',
                activity.technical != null
                    ? activity.technical!
                    : "Sin técnico"),
            _buildDetailRow(
                'EQUIPO:',
                activity.equipment != null
                    ? activity.equipment!
                    : "Sin equipo"),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ESTADO:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                _buildStatusBadge(effectiveStatus),
                if (!activity.isSynced) ...[
                  SizedBox(width: 4),
                  Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                  SizedBox(width: 3),
                  Text('Pendiente',
                      style: TextStyle(color: Colors.orange, fontSize: 10)),
                ]
              ],
            ),
          ],
        ),
      ),
      actions: _isProcessing
          ? [
              CircularProgressIndicator()
            ] // Muestra un indicador si está procesando
          : _buildActions(
              context,
              activity,
              effectiveStatus,
              isExternalService,
              hasPendingBaseIn,
              hasSyncedBaseIn,
              hourbaseInLocal,
              hourbaseInBackend,
              isInspectionConcluded,
              hasTransportUnit,
              hasSigned,
              technicalSignatureInLocal,
              technicalSignatureInBackend,
            ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    Activity activity,
    int effectiveStatus,
    bool isExternalService,
    bool hasPendingBaseIn,
    bool hasSyncedBaseIn,
    bool hourbaseInLocal,
    bool hourbaseInBackend,
    bool isInspectionConcluded,
    bool hasTransportUnit,
    bool hasSigned,
    bool technicalSignatureInLocal,
    bool technicalSignatureInBackend,
  ) {
    return [
      if (isExternalService && effectiveStatus == 2)
        // _buildActionButton(context, 'SALIDA DE BASE', 'base_out'),
        _buildActionButtonWithValidation(context, 'SALIDA DE BASE', 'base_out'),
      if (isExternalService &&
          effectiveStatus == 3 &&
          !activity.pendingTimes.containsKey('hourIn'))
        _buildActionButton(context, 'LLEGÓ AL ÁREA', 'arrival'),
      if (effectiveStatus == 3 && activity.pendingTimes.containsKey('hourIn'))
        _buildActionButtonWithValidation(context, 'INICIAR TRABAJO', 'start'),
      if ((!activity.pendingTimes.containsKey('hourIn') &&
              !isExternalService) &&
          (effectiveStatus == 2))
        //  _buildActionButton(context, 'INICIAR TRABAJO', 'start'),
        _buildActionButtonWithValidation(context, 'INICIAR TRABAJO', 'start'),
      if (isInspectionConcluded == false &&
          (activity.transportUnit?.isEmpty ?? true) &&
          (!hasPendingBaseIn && !hasSyncedBaseIn) &&
          (effectiveStatus == 4 || effectiveStatus == 5))
        TextButton(
          onPressed: () =>
              _navigateToInspection1(context, activity, widget.authService),
          child: Text('Inspeccionar equipo'),
        ),
      if (!hasSigned && (isInspectionConcluded || hasTransportUnit))
        TextButton(
          onPressed: () => _navigateToSignature(context, activity),
          child: Text('Firmar de cliente'),
        ),
      if (hasSigned &&
          (isInspectionConcluded || hasTransportUnit) &&
          (!technicalSignatureInLocal && !technicalSignatureInBackend))
        _buildActionButton(context, 'FIRMA DEL TECNICO', 'technicalSignature'),
      if (effectiveStatus == 4 &&
          hasTransportUnit == true &&
          hasSigned &&
          (technicalSignatureInLocal || technicalSignatureInBackend))
        _buildActionButton(context, 'FINALIZAR TRABAJO', 'end'),
      if (isExternalService &&
          effectiveStatus == 5 &&
          hasTransportUnit == true &&
          hasSigned &&
          (technicalSignatureInLocal || technicalSignatureInBackend) &&
          (!hourbaseInLocal && !hourbaseInBackend))
        _buildActionButton(context, 'LLEGO A BASE ', 'base_in'),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('CERRAR'),
      ),
    ];
  }

  Widget _buildActionButton(
      BuildContext context, String text, String operationType) {
    return TextButton(
      onPressed: () => _registerFlowStep(context, operationType),
      child: Text(text),
    );
  }

  Future<void> _registerFlowStep(
      BuildContext context, String operationType) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final offlineService = Provider.of<OfflineService>(context, listen: false);
    final now = DateTime.now();
    final timeValue =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    try {
      await offlineService.registerActivityFlow(
        activityId: _currentActivity.id,
        scheduleId: _currentActivity.scheduleId,
        stepType: operationType,
        timeValue: timeValue,
      );

      // La sincronización ahora se maneja automáticamente en OfflineService
      await widget.provider.refreshActivities();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paso registrado y sincronizando...')),
        );
      }
    } catch (e) {
      print('Error registrando paso: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar paso')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _navigateToInspection1(
      BuildContext context, Activity activity, AuthService authService) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaintenanceCheckForm1(
          inspectionId: activity.inspectionId!,
          authService: authService,
        ),
      ),
    );
  }

  void _navigateToSignature(BuildContext context, Activity activity) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClientSignatureForm(
            maintenanceId: activity.maintenanceId!.toString(),
            authService: widget.authService),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _getStatusText(int status) {
    switch (status) {
      case 1:
        return 'PENDIENTE';
      case 2:
        return 'AUTORIZADO';
      case 3:
        return 'EN CAMINO';
      case 4:
        return 'EN PROCESO';
      case 5:
        return 'FINALIZADO';
      default:
        return 'DESCONOCIDO';
    }
  }

  Widget _buildStatusBadge(int status) {
    String statusText = _getStatusText(status);
    Color bgColor;

    switch (status) {
      case 1:
        bgColor = Colors.blue;
        break;
      case 2:
        bgColor = Colors.amber;
        break;
      case 3:
        bgColor = Colors.orange;
        break;
      case 4:
        bgColor = Colors.deepPurple;
        break;
      case 5:
        bgColor = Colors.green;
        break;
      default:
        bgColor = Colors.red;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleSync() async {
    final syncService = Provider.of<SyncService>(context, listen: false);
    final connectivity = Provider.of<Connectivity>(context, listen: false);

    setState(() {
      _isProcessing = true;
    });

    try {
      // Verificar conexión
      final connectivityResult = await connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay conexión a internet')),
        );
        return;
      }

      // Intentar sincronización
      await syncService.syncData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Datos sincronizados correctamente')),
      );

      // Actualizar la actividad después de la sincronización
      await widget.provider.refreshActivities();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al sincronizar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
