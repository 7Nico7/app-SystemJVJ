/* import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/maintenance/data/signatureDatabaseHelper.dart';
import 'package:systemjvj/maintenance/presentation/clientSignatureForm.dart';
import 'package:systemjvj/maintenance/presentation/maintenance_check_form.dart';
import 'package:systemjvj/maintenance/presentation/maintenance_check_form1.dart';
import 'package:systemjvj/maintenance/presentation/maintenance_check_form2.dart';
import 'package:systemjvj/schedule/models/activity_model.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';

class EventDetailDialog extends StatefulWidget {
  final Activity activity;
  final ScheduleProvider provider;

  const EventDetailDialog(
      {Key? key, required this.activity, required this.provider})
      : super(key: key);

  @override
  _EventDetailDialogState createState() => _EventDetailDialogState();
}

class _EventDetailDialogState extends State<EventDetailDialog> {
  late Activity _currentActivity;
  bool _hasLocalSignature = false;

  @override
  void initState() {
    super.initState();
    // Obtener la actividad actualizada del provider
    _currentActivity = widget.provider.activities.firstWhere(
      (a) => a.id == widget.activity.id,
      orElse: () => widget.activity,
    );
    widget.provider.addListener(_updateActivity);
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

  void _updateActivity() {
    // Buscar la actividad actualizada en la lista del provider
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

    // Estado efectivo considera primero el estado local
    final effectiveStatus = activity.localStatus > 0
        ? activity.localStatus
        : activity.maintenanceStatus;

    final isExternalService = activity.serviceScope == 2;
    final hasPendingBaseIn = activity.pendingTimes.containsKey('hourBaseIn');
    final hasSyncedBaseIn = activity.hourBaseIn != null;

    final hourEndLocal = activity.pendingTimes.containsKey('hourEnd');
    final hourEndBackend = activity.hourEnd != null;

    final hourbaseInLocal = activity.pendingTimes.containsKey('hourIn');
    final hourbaseInBackend = activity.hourBaseIn != null;

    // LÓGICA SIMPLIFICADA para detectar inspección concluida
    final isInspectionConcluded = activity.inspectionConcluded;
    final hasTransportUnit =
        activity.transportUnit != null && activity.transportUnit!.isNotEmpty;

    // Verificar si ya firmó (backend o local)
    final hasSigned = activity.serviceRating == 1 || _hasLocalSignature;

    // Para depuración
    print('DEBUG - Activity ID: ${activity.id}');
    print('DEBUG - InspectionConcluded: $isInspectionConcluded');
    print(
        'DEBUG - TransportUnit : ${activity.transportUnit} $hasTransportUnit');

    print('DEBUG - Raw transportUnit value: ${activity.transportUnit}');
    print(
        'DEBUG - LocalStatus: ${activity.localStatus}, MaintenanceStatus: ${activity.maintenanceStatus}');

    return AlertDialog(
      title: Text(
        activity.name == null || activity.name!.isEmpty
            ? 'Sin nombre'
            : activity.name!,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Folio:',
                '${activity.title} es: ${activity.inspectionId} ${activity.pendingTimes['hourBaseIn']}  :  ${activity.hourBaseIn}'),
            _buildDetailRow('Descripción:', activity.description),
            _buildDetailRow('Fecha:', '${_formatDate(activity.start)}'),
            _buildDetailRow('Hora:',
                '${_formatTime(activity.start)} - ${_formatTime(activity.end)}'),
            _buildDetailRow('Ubicación:', activity.location),
            _buildDetailRow('Cliente:', activity.client),
            _buildDetailRow('Técnico:', activity.technical),
            _buildDetailRow('Equipo:', activity.equipment),
            _buildDetailRow('Estado local:', '${activity.localStatus}'),
            _buildDetailRow(
                'Estado servidor:', '${activity.maintenanceStatus}'),
            _buildDetailRow('Hora base in (local):',
                activity.pendingTimes['hourBaseIn'] ?? 'N/A'),
            _buildDetailRow(
                'Hora base in (server):', activity.hourBaseIn ?? 'N/A'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estado: ', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                _buildStatusBadge(effectiveStatus),
                if (!activity.isSynced) ...[
                  SizedBox(width: 8),
                  Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text('Pendiente sincronizar',
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
                ]
              ],
            ),
            // Información de depuración
            SizedBox(height: 16),
            _buildDetailRow('inspección :', '$isInspectionConcluded'),
            _buildDetailRow(
                'Depuración - TransportUnit :', '${activity.transportUnit}'),
            _buildDetailRow(' hasSigned:', '${hasSigned}'),

            _buildDetailRow('transportUnit!.isEmpty :',
                '${activity.transportUnit!.isEmpty}')
          ],
        ),
      ),
      actions: [
        // Flujo para servicios externos
        if (isExternalService && effectiveStatus == 2)
          _buildActionButton(context, 'SALIDA DE BASE', 'base_out'),

        if (isExternalService &&
            effectiveStatus == 3 &&
            !activity.pendingTimes.containsKey('hourIn'))
          _buildActionButton(context, 'LLEGÓ AL ÁREA', 'arrival'),

        if (effectiveStatus == 3 && activity.pendingTimes.containsKey('hourIn'))
          _buildActionButton(context, 'INICIAR TRABAJO', 'start'),

        if ((!activity.pendingTimes.containsKey('hourIn') &&
                !isExternalService) &&
            (effectiveStatus == 2))
          _buildActionButton(context, 'INICIAR TRABAJO', 'start'),

        if (effectiveStatus == 4)
          _buildActionButton(context, 'FINALIZAR TRABAJO', 'end'),

        // INSPECCIÓN - Mostrar solo si NO está concluida
        if (isInspectionConcluded == false &&
            (activity.transportUnit?.isEmpty ?? true) &&
            (!hasPendingBaseIn && !hasSyncedBaseIn) &&
            (effectiveStatus == 4 || effectiveStatus == 5))
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MaintenanceCheckForm(
                    inspectionId: activity.inspectionId!,
                  ),
                ),
              );
            },
            child: Text(
                'Inspeccionar equipo ${hasPendingBaseIn} , ${hasSyncedBaseIn}'),
          ),

        if (isInspectionConcluded == false &&
            (activity.transportUnit?.isEmpty ?? true) &&
            (!hasPendingBaseIn && !hasSyncedBaseIn) &&
            (effectiveStatus == 4 || effectiveStatus == 5))
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MaintenanceCheckForm1(
                    inspectionId: activity.inspectionId!,
                  ),
                ),
              );
            },
            child: Text(
                'Inspeccionar equipo ${hasPendingBaseIn} , ${hasSyncedBaseIn}'),
          ),

        if (isInspectionConcluded == false &&
            (activity.transportUnit?.isEmpty ?? true) &&
            (!hasPendingBaseIn && !hasSyncedBaseIn) &&
            (effectiveStatus == 4 || effectiveStatus == 5))
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MaintenanceCheckForm2(
                    inspectionId: activity.inspectionId!,
                  ),
                ),
              );
            },
            child: Text(
                'Inspeccionar equipo ${hasPendingBaseIn} , ${hasSyncedBaseIn}'),
          ),

        // FIRMA DE CLIENTE - Mostrar solo si está concluida la inspección y no alla firmado
        if (!hasSigned &&
                ((isInspectionConcluded) || // inspección local concluida
                    (activity.transportUnit != null &&
                        activity
                            .transportUnit!.isNotEmpty)) // inspección backend
            )
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClientSignatureForm(
                    maintenanceId: activity.maintenanceId!.toString(),
                  ),
                ),
              );
            },
            child: Text('Firmar de cliente'),
          ),
        // REGRESO A BASE - Mostrar solo si está concluida y no tiene registro de base in
        if (hasSigned &&
            (!hourbaseInLocal && !hourbaseInBackend) &&
            isExternalService)
          _buildActionButton(context, 'REGRESAR A BASE', 'base_in'),
        /* _buildActionButtonWithConfirmation(context),
        */
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('CERRAR'),
        ),
      ],
    );
  }

  Widget _buildActionButtonWithConfirmation(BuildContext context) {
    return TextButton(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar regreso'),
            content:
                const Text('Ya no podra registrar o editar la inspección '),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        );

        if (confirm == true) {
          _registerFlowStep(context, 'base_in');
        }
      },
      child: const Text('REGRESO A BASE'),
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
        return 'PENDIENTE $status';
      case 2:
        return 'AUTORIZADO $status';
      case 3:
        return 'EN CAMINO $status';
      case 4:
        return 'EN PROCESO $status';
      case 5:
        return 'FINALIZADO $status';
      default:
        return 'DESCONOCIDO $status';
    }
  }

  Widget _buildStatusBadge(int status) {
    String statusText = _getStatusText(status);
    Color bgColor;
    Color textColor = Colors.white;

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
        bgColor = Colors.grey;
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
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, String text, String operationType) {
    return TextButton(
      onPressed: () => _registerFlowStep(context, operationType),
      child: Text(text),
    );
  }

  void _registerFlowStep(BuildContext context, String operationType) {
    final offlineService = Provider.of<OfflineService>(context, listen: false);
    final now = DateTime.now();
    final timeValue =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    offlineService.registerActivityFlow(
      activityId: _currentActivity.id,
      stepType: operationType,
      timeValue: timeValue,
    );

    // Actualizar el provider para reflejar los cambios
    widget.provider.refreshActivities();

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Paso registrado localmente')),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/maintenance/data/signatureDatabaseHelper.dart';
import 'package:systemjvj/maintenance/presentation/clientSignatureForm.dart';
import 'package:systemjvj/maintenance/presentation/maintenance_check_form.dart';
import 'package:systemjvj/maintenance/presentation/maintenance_check_form1.dart';
import 'package:systemjvj/maintenance/presentation/maintenance_check_form2.dart';
import 'package:systemjvj/schedule/models/activity_model.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';

class EventDetailDialog extends StatefulWidget {
  final Activity activity;
  final ScheduleProvider provider;

  const EventDetailDialog(
      {Key? key, required this.activity, required this.provider})
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
      title: Text(
        activity.name == null || activity.name!.isEmpty
            ? 'Sin nombre'
            : activity.name!,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(
                'Folio:', '${activity.title} es: ${activity.inspectionId}'),
            _buildDetailRow('Descripción:', activity.description),
            _buildDetailRow('Fecha:', '${_formatDate(activity.start)}'),
            _buildDetailRow('Hora:',
                '${_formatTime(activity.start)} - ${_formatTime(activity.end)}'),
            _buildDetailRow('Ubicación:', activity.location),
            _buildDetailRow('Cliente:', activity.client),
            _buildDetailRow('Técnico:', activity.technical),
            _buildDetailRow('Equipo:', activity.equipment),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estado ${effectiveStatus}: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(width: 4),
                _buildStatusBadge(effectiveStatus),
                if (!activity.isSynced) ...[
                  SizedBox(width: 8),
                  Icon(Icons.cloud_off, size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Text('Pendiente sincronizar',
                      style: TextStyle(color: Colors.orange, fontSize: 12)),
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
        _buildActionButton(context, 'SALIDA DE BASE', 'base_out'),
      if (isExternalService &&
          effectiveStatus == 3 &&
          !activity.pendingTimes.containsKey('hourIn'))
        _buildActionButton(context, 'LLEGÓ AL ÁREA', 'arrival'),
      if (effectiveStatus == 3 && activity.pendingTimes.containsKey('hourIn'))
        _buildActionButton(context, 'INICIAR TRABAJO', 'start'),
      if ((!activity.pendingTimes.containsKey('hourIn') &&
              !isExternalService) &&
          (effectiveStatus == 2))
        _buildActionButton(context, 'INICIAR TRABAJO', 'start'),
      if (effectiveStatus == 4)
        _buildActionButton(context, 'FINALIZAR TRABAJO', 'end'),
      if (isInspectionConcluded == false &&
          (activity.transportUnit?.isEmpty ?? true) &&
          (!hasPendingBaseIn && !hasSyncedBaseIn) &&
          (effectiveStatus == 4 || effectiveStatus == 5))
        TextButton(
          onPressed: () => _navigateToInspection(context, activity),
          child: Text('Inspeccionar equipo'),
        ),
      if (isInspectionConcluded == false &&
          (activity.transportUnit?.isEmpty ?? true) &&
          (!hasPendingBaseIn && !hasSyncedBaseIn) &&
          (effectiveStatus == 4 || effectiveStatus == 5))
        TextButton(
          onPressed: () => _navigateToInspection1(context, activity),
          child: Text('Inspeccionar equipo'),
        ),
      if (isInspectionConcluded == false &&
          (activity.transportUnit?.isEmpty ?? true) &&
          (!hasPendingBaseIn && !hasSyncedBaseIn) &&
          (effectiveStatus == 4 || effectiveStatus == 5))
        TextButton(
          onPressed: () => _navigateToInspection2(context, activity),
          child: Text('Inspeccionar equipo'),
        ),
      if (!hasSigned && (isInspectionConcluded || hasTransportUnit))
        TextButton(
          onPressed: () => _navigateToSignature(context, activity),
          child: Text('Firmar de cliente'),
        ),
      if (hasSigned &&
          (!hourbaseInLocal && !hourbaseInBackend) &&
          isExternalService)
        _buildActionButton(context, 'REGRESAR A BASE', 'base_in'),
      if (hasSigned &&
          (!technicalSignatureInLocal && !technicalSignatureInBackend) &&
          isExternalService)
        _buildActionButton(context, 'FIRMA DEL TECNICO', 'technicalSignature'),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
            'CERRAR ${technicalSignatureInLocal}, ${technicalSignatureInBackend}'),
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
    if (_isProcessing) return; // Evita múltiples clics

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
        stepType: operationType,
        timeValue: timeValue,
      );

      // Espera a que el provider se actualice
      await widget.provider.refreshActivities();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paso registrado localmente')),
        );
      }
    } catch (e) {
      // Maneja errores aquí
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

  void _navigateToInspection(BuildContext context, Activity activity) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaintenanceCheckForm(
          inspectionId: activity.inspectionId!,
        ),
      ),
    );
  }

  void _navigateToInspection1(BuildContext context, Activity activity) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaintenanceCheckForm1(
          inspectionId: activity.inspectionId!,
        ),
      ),
    );
  }

  void _navigateToInspection2(BuildContext context, Activity activity) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MaintenanceCheckForm2(
          inspectionId: activity.inspectionId!,
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
        ),
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
        bgColor = Colors.grey;
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
}
