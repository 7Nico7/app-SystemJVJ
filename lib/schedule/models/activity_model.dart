/* import 'dart:convert';
import 'package:flutter/material.dart';

class Activity {
  final String scheduleId;
  final String id;
  final String? name;
  final String? title;
  final DateTime start;
  final DateTime end;
  final String? description;
  final String? location;
  final String? client;
  final String? technical;
  final String? equipment;
  final int? status;
  final String? folio;
  final String? maintenanceIdPdf;
  final String technicalId;
  final int maintenanceStatus;
  final int? serviceScope;
  final int inspectionId;
  final int maintenanceId;
  final String? hourStart;
  final String? hourEnd;
  final String? hourIn;
  final String? hourBaseIn;
  final String? hourBaseOut;
  final bool isSynced;
  final int localStatus;
  final String? transportUnit;
  final Map<String, String> pendingTimes;
  final bool inspectionConcluded; // Nuevo campo
  final int? serviceRating;
  final int? technicalSignature;
  final String? mileage;
  final String? comment;
  Activity({
    required this.scheduleId,
    required this.id,
    required this.maintenanceId,
    this.name,
    this.title,
    required this.start,
    required this.end,
    this.description,
    this.location,
    this.client,
    this.technical,
    this.equipment,
    this.status,
    this.folio,
    this.maintenanceIdPdf,
    required this.technicalId,
    required this.maintenanceStatus,
    this.serviceScope,
    required this.inspectionId,
    this.transportUnit,
    this.hourStart,
    this.hourEnd,
    this.hourIn,
    this.hourBaseIn,
    this.hourBaseOut,
    this.isSynced = true,
    this.localStatus = 0,
    this.pendingTimes = const {},
    this.inspectionConcluded = false, // Valor por defecto
    this.serviceRating, // Firmo el cliente = 1, si es null no ha firmado
    this.technicalSignature,
    this.mileage,
    this.comment,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    // Parsear la fecha y las horas
    final date = DateTime.parse(json['date']);
    final startTime = _parseTime(json['scheduledStartHour']);
    final endTime = _parseTime(json['scheduledEndHour']);

    final startDateTime = DateTime(
        date.year, date.month, date.day, startTime.hour, startTime.minute);
    final endDateTime =
        DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute);

    final hourStart =
        json['hourStart'] != null ? json['hourStart'] as String : null;
    final hourEnd = json['hourEnd'] != null ? json['hourEnd'] as String : null;
    final hourIn = json['hourIn'] != null ? json['hourIn'] as String : null;
    final hourBaseIn =
        json['hourBaseIn'] != null ? json['hourBaseIn'] as String : null;
    final hourBaseOut =
        json['hourBaseOut'] != null ? json['hourBaseOut'] as String : null;

    return Activity(
      scheduleId: json['id_schedule'].toString(),
      id: json['inspection_id'].toString(),
      maintenanceId: json['maintenanceId'],
      name: json['name'],
      title: json['folio'] ?? 'Sin título',
      start: startDateTime,
      end: endDateTime,
      description: json['description'] ?? '',
      location: json['location'] ?? 'BASE JCB AZTECA',
      client: json['client'] ?? 'JCB AZTECA',
      technical: _composeTechnicalName(json),
      equipment:
          '${json['equipmentTypeName'] ?? ''} ${json['model'] ?? ''}'.trim(),
      status: json['status'] ?? 0,
      folio: json['folio'] ?? 'N/A',
      maintenanceIdPdf: json['maintenanceIdpdf']?.toString() ?? '',
      technicalId: json['technicalId']?.toString() ?? '',
      maintenanceStatus: json['maintenance_status'] ?? 0,
      serviceScope: json['service_scope'] ?? 0,
      inspectionId: json['inspection_id'] ?? 0,
      transportUnit: json['transportUnit'] ?? '',
      hourStart: hourStart,
      hourEnd: hourEnd,
      hourIn: hourIn,
      hourBaseIn: hourBaseIn,
      hourBaseOut: hourBaseOut,
      inspectionConcluded: json['inspection_concluded'] ?? false, // Nuevo campo
      serviceRating: json['service_rating'],
      technicalSignature: json['technical_signature'],
      mileage: json['mileage'],
      comment: json['comment'],
    );
  }

  // Función auxiliar para componer el nombre del técnico
  static String _composeTechnicalName(Map<String, dynamic> json) {
    final parts = [
      json['technicalFirstname'],
      json['technicalLastname'],
      json['technicalLastname2'],
    ];
    return parts.where((part) => part != null).join(' ').trim();
  }

  // Función auxiliar para parsear el tiempo
  static TimeOfDay _parseTime(dynamic time) {
    if (time == null) return TimeOfDay.now();

    String timeString = time.toString();
    List<String> parts = timeString.split(':');

    int hour = int.parse(parts[0]);
    int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  Activity copyWith({
    String? scheduleId,
    String? id,
    int? maintenanceId,
    String? name,
    String? title,
    DateTime? start,
    DateTime? end,
    String? description,
    String? location,
    String? client,
    String? technical,
    String? equipment,
    int? status,
    String? folio,
    String? maintenanceIdPdf,
    String? technicalId,
    int? maintenanceStatus,
    int? serviceScope,
    int? inspectionId,
    String? transportUnit,
    String? hourStart,
    String? hourEnd,
    String? hourIn,
    String? hourBaseIn,
    String? hourBaseOut,
    bool? isSynced,
    int? localStatus,
    Map<String, String>? pendingTimes,
    bool? inspectionConcluded, // Nuevo campo
    int? serviceRating,
    int? technicalSignature,
    String? mileage,
    String? comment,
  }) {
    return Activity(
        scheduleId: scheduleId ?? this.scheduleId,
        id: id ?? this.id,
        maintenanceId: maintenanceId ?? this.maintenanceId,
        name: name ?? this.name,
        title: title ?? this.title,
        start: start ?? this.start,
        end: end ?? this.end,
        description: description ?? this.description,
        location: location ?? this.location,
        client: client ?? this.client,
        technical: technical ?? this.technical,
        equipment: equipment ?? this.equipment,
        status: status ?? this.status,
        folio: folio ?? this.folio,
        maintenanceIdPdf: maintenanceIdPdf ?? this.maintenanceIdPdf,
        technicalId: technicalId ?? this.technicalId,
        maintenanceStatus: maintenanceStatus ?? this.maintenanceStatus,
        serviceScope: serviceScope ?? this.serviceScope,
        inspectionId: inspectionId ?? this.inspectionId,
        transportUnit: transportUnit ?? this.transportUnit,
        hourStart: hourStart ?? this.hourStart,
        hourEnd: hourEnd ?? this.hourEnd,
        hourIn: hourIn ?? this.hourIn,
        hourBaseIn: hourBaseIn ?? this.hourBaseIn,
        hourBaseOut: hourBaseOut ?? this.hourBaseOut,
        isSynced: isSynced ?? this.isSynced,
        localStatus: localStatus ?? this.localStatus,
        pendingTimes: pendingTimes ?? this.pendingTimes,
        inspectionConcluded: inspectionConcluded ?? this.inspectionConcluded,
        serviceRating: serviceRating ?? this.serviceRating,
        technicalSignature: technicalSignature ?? this.technicalSignature,
        mileage: mileage ?? this.mileage,
        comment: comment ?? this.comment);
  }

  Map<String, dynamic> toMap() {
    return {
      'scheduleId': scheduleId,
      'id': id,
      'maintenanceId': maintenanceId,
      'name': name,
      'title': title,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'description': description,
      'location': location,
      'client': client,
      'technical': technical,
      'equipment': equipment,
      'status': status,
      'folio': folio,
      'maintenanceIdPdf': maintenanceIdPdf,
      'technicalId': technicalId,
      'maintenance_status': maintenanceStatus,
      'service_scope': serviceScope,
      'inspection_id': inspectionId,
      'hourStart': hourStart,
      'hourEnd': hourEnd,
      'hourIn': hourIn,
      'hourBaseIn': hourBaseIn,
      'hourBaseOut': hourBaseOut,
      'is_synced': isSynced ? 1 : 0,
      'local_status': localStatus,
      'pending_times': jsonEncode(pendingTimes),
      'inspection_concluded': inspectionConcluded ? 1 : 0,
      'transportUnit': transportUnit,
      'serviceRating': serviceRating,
      'technicalSignature': technicalSignature,
      'mileage': mileage,
      'comment': comment,
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
        scheduleId: map['scheduleId'],
        id: map['id'],
        maintenanceId: map['maintenanceId'],
        name: map['name'],
        title: map['title'],
        start: DateTime.parse(map['start']),
        end: DateTime.parse(map['end']),
        description: map['description'],
        location: map['location'],
        client: map['client'],
        technical: map['technical'],
        equipment: map['equipment'],
        status: map['status'],
        folio: map['folio'],
        maintenanceIdPdf: map['maintenanceIdPdf'],
        technicalId: map['technicalId'],
        maintenanceStatus: map['maintenance_status'],
        serviceScope: map['service_scope'],
        inspectionId: map['inspection_id'],
        hourStart: map['hourStart'],
        hourEnd: map['hourEnd'],
        hourIn: map['hourIn'],
        hourBaseIn: map['hourBaseIn'],
        hourBaseOut: map['hourBaseOut'],
        isSynced: map['is_synced'] == 1,
        localStatus: map['local_status'] ?? 0,
        pendingTimes: map['pending_times'] != null
            ? Map<String, String>.from(jsonDecode(map['pending_times']))
            : {},
        inspectionConcluded: map['inspection_concluded'] == 1,
        transportUnit: map['transportUnit'],
        serviceRating: map['serviceRating'],
        technicalSignature: map['technicalSignature'],
        mileage: map['mileage'],
        comment: map['comment']);
  }
}
 */
import 'dart:convert';
import 'package:flutter/material.dart';

class Activity {
  final String scheduleId;
  final String id;
  final String? name;
  final String? title;
  final DateTime start;
  final DateTime end;
  final String? description;
  final String? location;
  final String? client;
  final String? technical;
  final String? equipment;
  final int? status;
  final String? folio;
  final String? maintenanceIdPdf;
  final String technicalId;
  final int maintenanceStatus;
  final int? serviceScope;
  final int inspectionId;
  final int maintenanceId;
  final String? hourStart;
  final String? hourEnd;
  final String? hourIn;
  final String? hourBaseIn;
  final String? hourBaseOut;
  final bool isSynced;
  final int localStatus;
  final String? transportUnit;
  final Map<String, String> pendingTimes;
  final bool inspectionConcluded;
  final int? serviceRating;
  final int? technicalSignature;
  final String? mileage;
  final String? comment;

  Activity({
    required this.scheduleId,
    required this.id,
    required this.maintenanceId,
    this.name,
    this.title,
    required this.start,
    required this.end,
    this.description,
    this.location,
    this.client,
    this.technical,
    this.equipment,
    this.status,
    this.folio,
    this.maintenanceIdPdf,
    required this.technicalId,
    required this.maintenanceStatus,
    this.serviceScope,
    required this.inspectionId,
    this.transportUnit,
    this.hourStart,
    this.hourEnd,
    this.hourIn,
    this.hourBaseIn,
    this.hourBaseOut,
    this.isSynced = true,
    this.localStatus = 0,
    this.pendingTimes = const {},
    this.inspectionConcluded = false,
    this.serviceRating,
    this.technicalSignature,
    this.mileage,
    this.comment,
  });

  // -------------------- copyWith --------------------
  Activity copyWith({
    String? scheduleId,
    String? id,
    String? name,
    String? title,
    DateTime? start,
    DateTime? end,
    String? description,
    String? location,
    String? client,
    String? technical,
    String? equipment,
    int? status,
    String? folio,
    String? maintenanceIdPdf,
    String? technicalId,
    int? maintenanceStatus,
    int? serviceScope,
    int? inspectionId,
    int? maintenanceId,
    String? hourStart,
    String? hourEnd,
    String? hourIn,
    String? hourBaseIn,
    String? hourBaseOut,
    bool? isSynced,
    int? localStatus,
    String? transportUnit,
    Map<String, String>? pendingTimes,
    bool? inspectionConcluded,
    int? serviceRating,
    int? technicalSignature,
    String? mileage,
    String? comment,
  }) {
    return Activity(
      scheduleId: scheduleId ?? this.scheduleId,
      id: id ?? this.id,
      name: name ?? this.name,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      description: description ?? this.description,
      location: location ?? this.location,
      client: client ?? this.client,
      technical: technical ?? this.technical,
      equipment: equipment ?? this.equipment,
      status: status ?? this.status,
      folio: folio ?? this.folio,
      maintenanceIdPdf: maintenanceIdPdf ?? this.maintenanceIdPdf,
      technicalId: technicalId ?? this.technicalId,
      maintenanceStatus: maintenanceStatus ?? this.maintenanceStatus,
      serviceScope: serviceScope ?? this.serviceScope,
      inspectionId: inspectionId ?? this.inspectionId,
      maintenanceId: maintenanceId ?? this.maintenanceId,
      hourStart: hourStart ?? this.hourStart,
      hourEnd: hourEnd ?? this.hourEnd,
      hourIn: hourIn ?? this.hourIn,
      hourBaseIn: hourBaseIn ?? this.hourBaseIn,
      hourBaseOut: hourBaseOut ?? this.hourBaseOut,
      isSynced: isSynced ?? this.isSynced,
      localStatus: localStatus ?? this.localStatus,
      transportUnit: transportUnit ?? this.transportUnit,
      pendingTimes: pendingTimes ?? this.pendingTimes,
      inspectionConcluded: inspectionConcluded ?? this.inspectionConcluded,
      serviceRating: serviceRating ?? this.serviceRating,
      technicalSignature: technicalSignature ?? this.technicalSignature,
      mileage: mileage ?? this.mileage,
      comment: comment ?? this.comment,
    );
  }

  // -------------------- fromJson --------------------
  factory Activity.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date']);

    final startTime = _parseTime(json['scheduledStartHour']);
    final endTime =
        _parseTime(json['scheduledEndDate'] ?? json['scheduledEndHour']);

    final startDateTime = DateTime(
        date.year, date.month, date.day, startTime.hour, startTime.minute);
    final endDateTime =
        DateTime(date.year, date.month, date.day, endTime.hour, endTime.minute);

    return Activity(
      scheduleId: json['id_schedule'].toString(),
      id: json['inspection_id'].toString(),
      maintenanceId: json['maintenanceId'] ?? 0,
      name: json['name']?.toString(),
      title: json['folio']?.toString(),
      start: startDateTime,
      end: endDateTime,
      description: json['description']?.toString(),
      location: json['location']?.toString(),
      client: json['client']?.toString(),
      technical: _composeTechnicalName(json),
      equipment:
          '${json['equipmentTypeName'] ?? ''} ${json['model'] ?? ''}'.trim(),
      status: json['status'],
      folio: json['folio']?.toString(),
      maintenanceIdPdf: json['maintenanceIdpdf']?.toString(),
      technicalId: json['technicalId']?.toString() ?? '',
      maintenanceStatus: json['maintenance_status'] ?? 0,
      serviceScope: json['service_scope'],
      inspectionId: json['inspection_id'] ?? 0,
      transportUnit: json['transportUnit']?.toString(),
      hourStart: json['hourStart']?.toString(),
      hourEnd: json['hourEnd']?.toString(),
      hourIn: json['hourIn']?.toString(),
      hourBaseIn: json['hourBaseIn']?.toString(),
      hourBaseOut: json['hourBaseOut']?.toString(),
      inspectionConcluded: json['inspection_concluded'] ?? false,
      serviceRating: json['service_rating'],
      technicalSignature: json['technical_signature'],
      mileage: json['mileage']?.toString(),
      comment: json['comment']?.toString(),
    );
  }

  // -------------------- fromMap --------------------
  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      scheduleId: map['scheduleId']?.toString() ?? '',
      id: map['id']?.toString() ?? '',
      maintenanceId: map['maintenanceId'] ?? 0,
      name: map['name']?.toString(),
      title: map['title']?.toString(),
      start: DateTime.parse(map['start']),
      end: DateTime.parse(map['end']),
      description: map['description']?.toString(),
      location: map['location']?.toString(),
      client: map['client']?.toString(),
      technical: map['technical']?.toString(),
      equipment: map['equipment']?.toString(),
      status: map['status'],
      folio: map['folio']?.toString(),
      maintenanceIdPdf: map['maintenanceIdPdf']?.toString(),
      technicalId: map['technicalId']?.toString() ?? '',
      maintenanceStatus: map['maintenance_status'] ?? 0,
      serviceScope: map['service_scope'],
      inspectionId: map['inspection_id'] ?? 0,
      hourStart: map['hourStart']?.toString(),
      hourEnd: map['hourEnd']?.toString(),
      hourIn: map['hourIn']?.toString(),
      hourBaseIn: map['hourBaseIn']?.toString(),
      hourBaseOut: map['hourBaseOut']?.toString(),
      isSynced: map['is_synced'] == 1,
      localStatus: map['local_status'] ?? 0,
      pendingTimes: map['pending_times'] != null
          ? Map<String, String>.from(jsonDecode(map['pending_times']))
          : {},
      inspectionConcluded: map['inspection_concluded'] == 1,
      transportUnit: map['transportUnit']?.toString(),
      serviceRating: map['serviceRating'],
      technicalSignature: map['technicalSignature'],
      mileage: map['mileage']?.toString(),
      comment: map['comment']?.toString(),
    );
  }

  // -------------------- toMap --------------------
  Map<String, dynamic> toMap() {
    return {
      'scheduleId': scheduleId,
      'id': id,
      'maintenanceId': maintenanceId,
      'name': name,
      'title': title,
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'description': description,
      'location': location,
      'client': client,
      'technical': technical,
      'equipment': equipment,
      'status': status,
      'folio': folio,
      'maintenanceIdPdf': maintenanceIdPdf,
      'technicalId': technicalId,
      'maintenance_status': maintenanceStatus,
      'service_scope': serviceScope,
      'inspection_id': inspectionId,
      'hourStart': hourStart,
      'hourEnd': hourEnd,
      'hourIn': hourIn,
      'hourBaseIn': hourBaseIn,
      'hourBaseOut': hourBaseOut,
      'is_synced': isSynced ? 1 : 0,
      'local_status': localStatus,
      'pending_times': jsonEncode(pendingTimes),
      'inspection_concluded': inspectionConcluded ? 1 : 0,
      'transportUnit': transportUnit,
      'serviceRating': serviceRating,
      'technicalSignature': technicalSignature,
      'mileage': mileage,
      'comment': comment,
    };
  }

  // -------------------- Utils --------------------
  static String _composeTechnicalName(Map<String, dynamic> json) {
    final parts = [
      json['technicalFirstname'],
      json['technicalLastname'],
      json['technicalLastname2'],
    ];
    return parts.where((part) => part != null).join(' ').trim();
  }

  static TimeOfDay _parseTime(dynamic time) {
    if (time == null) return TimeOfDay(hour: 0, minute: 0);

    final timeString = time.toString();
    final parts = timeString.split(':');

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return TimeOfDay(hour: hour, minute: minute);
  }
}
