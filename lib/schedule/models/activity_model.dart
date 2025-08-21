import 'dart:convert';
import 'package:flutter/material.dart';

class Activity {
  final String id;
  final String? name;
  final String title;
  final DateTime start;
  final DateTime end;
  final String description;
  final String location;
  final String client;
  final String technical;
  final String equipment;
  final int status;
  final String folio;
  final String maintenanceIdPdf;
  final String technicalId;
  final int maintenanceStatus;
  final int serviceScope;
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
  Activity({
    required this.id,
    required this.maintenanceId,
    this.name,
    required this.title,
    required this.start,
    required this.end,
    required this.description,
    required this.location,
    required this.client,
    required this.technical,
    required this.equipment,
    required this.status,
    required this.folio,
    required this.maintenanceIdPdf,
    required this.technicalId,
    required this.maintenanceStatus,
    required this.serviceScope,
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

  Activity copyWith(
      {String? id,
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
      int? technicalSignature}) {
    return Activity(
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
        inspectionConcluded:
            inspectionConcluded ?? this.inspectionConcluded, // Nuevo campo
        serviceRating: serviceRating ?? this.serviceRating,
        technicalSignature: technicalSignature ?? this.technicalSignature);
  }

  Map<String, dynamic> toMap() {
    return {
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
      'technicalSignature': technicalSignature
    };
  }

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
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
        technicalSignature: map['technicalSignature']);
  }
}
