import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/maintenance/data/local_db.dart';
import 'package:systemjvj/maintenance/data/maintenanceSyncService.dart';
import 'package:systemjvj/maintenance/domain/check_item.dart';
import 'package:systemjvj/maintenance/domain/photo_item.dart';
import 'package:systemjvj/maintenance/domain/recommendation.dart';
import 'package:systemjvj/maintenance/presentation/photo_type_dialog.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';
import 'package:systemjvj/schedule/services/location_services.dart';
import 'package:uuid/uuid.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class MaintenanceCheckForm1 extends StatefulWidget {
  final int inspectionId;
  final AuthService authService;
  const MaintenanceCheckForm1(
      {Key? key, required this.inspectionId, required this.authService})
      : super(key: key);

  @override
  _MaintenanceCheckFormState createState() => _MaintenanceCheckFormState();
}

class _MaintenanceCheckFormState extends State<MaintenanceCheckForm1>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final LocalDB localDB = LocalDB();
  late MaintenanceSyncService syncService;

  late String _localInspectionId;
  bool _isOnline = true;
  bool _isLoading = true;
  bool _isEditable = true;
  final ImagePicker _picker = ImagePicker();
  final GlobalKey _shareButtonKey = GlobalKey();

  // Controladores separados para cada pestaña
  final ScrollController _generalScrollController = ScrollController();
  final ScrollController _checksScrollController = ScrollController();
  final ScrollController _photosScrollController = ScrollController();
  final ScrollController _recommendationsScrollController = ScrollController();

  final Map<String, GlobalKey> _sectionKeys = {
    'general': GlobalKey(),
    'checks': GlobalKey(),
    'photos': GlobalKey(),
    'recommendations': GlobalKey(),
  };

  // Controlador para las pestañas
  late TabController _tabController;
  int _currentTabIndex = 0;

  // Controlador para el PageView optimizado
  late PageController _pageController;

  late TextEditingController _transportUnitController;
  late TextEditingController _horometerController;

  late TextEditingController _mileageController;
  late TextEditingController _commentController;

  String? _selectedServiceValue;
  bool _showOtherServiceField = false;
  late TextEditingController _otherServiceController;
  late TextEditingController _preventiveServiceController;

  String? _maintenanceType = 'preventivo';
  List<CheckItem> _checkItems = [];
  List<PhotoItem> _photos = [];
  List<Recommendation> _recommendations = [];
  final TextEditingController _recommendationController =
      TextEditingController();
  String? _editingRecommendationId;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;

  final List<Map<String, dynamic>> maintenanceItems = [
    {"id": 1, "name": "CUCHILLAS DELANTERAS"},
    {"id": 2, "name": "CILINDROS BOTE DELANTERO SUPERIORES"},
    {"id": 3, "name": "CILINDRO BOTE DELANTERO INFERIOR"},
    {"id": 4, "name": "TERMINALES DE DIRECCION IZQ. Y DER."},
    {"id": 5, "name": "MAZAS (FUGAS) VERIFICAR TORQUE"},
    {"id": 6, "name": "CRISTALES (PARABRISAS, MEDALLON, LATERALES)"},
    {"id": 7, "name": "NIVEL DE ACEITE HIDRAULICO (TANQUE)"},
    {"id": 8, "name": "TAPON HIDRAULICO"},
    {"id": 9, "name": "CILINDRO DE ESTABILIZADORES"},
    {"id": 10, "name": "CILINDRO SWING"},
    {"id": 11, "name": "BANCO DE VALVULAS"},
    {"id": 12, "name": "MANAGUERAS DE BANCO DE VALVULAS"},
    {"id": 13, "name": "CILINDRO LEVANTE BRAZO TRASERO"},
    {"id": 14, "name": "CILINDRO DE DIPPER O ARRASTRE"},
    {"id": 15, "name": "CILINDRO DE EXTENSION"},
    {"id": 16, "name": "CILINDRO DE BOTE TRASERO"},
    {"id": 17, "name": "PUNTAS Y GAVILANTES DE BOTE TRASERO"},
    {"id": 18, "name": "BUJES Y PERNOS DE BOTE TRASERO"},
    {"id": 19, "name": "LUCES TRASERAS"},
    {"id": 20, "name": "TAPON DE DIESEL"},
    {"id": 21, "name": "LUCES DELANTERAS"},
    {"id": 22, "name": "ESPEJOS"},
    {"id": 23, "name": "FILTROS DE AIRE (CONDICION)"},
    {"id": 24, "name": "HOROMETRO (PANEL)"},
    {"id": 25, "name": "ASIENTO"},
    {"id": 26, "name": "PALANCAS DE MANDO"},
    {"id": 27, "name": "PALANCA DE AVANCE Y REVERSA"},
    {"id": 28, "name": "CLIMA (FILTROS)"},
    {"id": 29, "name": "CRUCETAS"},
    {"id": 30, "name": "FALLO MOTOR"},
    {"id": 31, "name": "NIVELES MOTOR Y TRANSMISION"},
    {"id": 32, "name": "FILTRO SEPARADOR (CON AGUA)"},
    {"id": 33, "name": "BRAZO EXTENCION (VAQUELAS)"},
    {"id": 34, "name": "TREN DE RODAJE"},
    {"id": 35, "name": "LIVELINK"},
    {"id": 36, "name": "MOTOR DE ARRANQUE"},
    {"id": 37, "name": "MARTILLLO HIDRAULICO EN CONDICIONES OPERATIVAS"},
  ];

  // Agregar esta lista al inicio de la clase
  final List<String> _requiredPhotoTypes = [
    'Evidencias',
    'Antes de mantenimiento',
    'Después de mantenimiento',
    'Placa serie',
    'Horómetro',
    'Falla',
    'Reparación'
  ];

  @override
  void initState() {
    super.initState();
    _transportUnitController = TextEditingController();
    _horometerController = TextEditingController();
    _mileageController = TextEditingController();
    _commentController = TextEditingController();
    _otherServiceController = TextEditingController();
    _preventiveServiceController = TextEditingController();
    syncService = MaintenanceSyncService(authService: widget.authService);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _registerBackgroundSync();
    });

    // Inicializar el controlador de pestañas
    _tabController = TabController(
      length: 4, // Número de pestañas
      vsync: this,
    );

    // Inicializar el controlador del PageView con configuración optimizada
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.999, // Para evitar solapamiento visual
    );

    // Listener para cambios en las pestañas
    _tabController.addListener(_handleTabSelection);

    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      // Tomamos el primer resultado de la lista
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        _retryAddressLookups();
      }
    });

    _transportUnitController.addListener(_markAsUnsaved);
    _horometerController.addListener(_markAsUnsaved);
    _mileageController.addListener(_markAsUnsaved);
    _commentController.addListener(_markAsUnsaved);
    _otherServiceController.addListener(_markAsUnsaved);
    _preventiveServiceController.addListener(_markAsUnsaved);
    //MaintenanceSyncService.registerBackgroundSync();
    _initializeApp();
  }

  void _markAsUnsaved() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  // Método para verificar si hay cambios sin guardar
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges || !_isEditable) return true;

    return await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(
              '¿SALIR SIN GUARDAR BORRADOR?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: Text(
              'TIENES CAMBIOS SIN GUARDAR. ¿DESEAS GUARDAR UN BORRADOR ANTES DE SALIR?',
              textAlign: TextAlign.justify,
            ),
            actions: [
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'CANCELAR',
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('SALIR SIN GUARDAR',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () async {
                    setState(() => _isSaving = true);
                    await _saveDraft();
                    setState(() => _isSaving = false);
                    Navigator.of(context).pop(true);
                  },
                  child: Text('GUARDAR BORRADOR',
                      style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _registerBackgroundSync() {
    try {
      MaintenanceSyncService.registerBackgroundSync();
      print('Sincronización en segundo plano registrada');
    } catch (e) {
      print('Error al registrar sincronización en segundo plano: $e');
    }
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });

      // Animar el PageView a la página correspondiente
      _pageController.animateToPage(
        _tabController.index,
        duration: const Duration(milliseconds: 150), // Más rápido
        curve: Curves.easeInOut,
      );

      // Navegar a la sección correspondiente
      Future.delayed(const Duration(milliseconds: 50), () {
        final List<String> sectionKeys = [
          'general',
          'checks',
          'photos',
          'recommendations'
        ];
        _scrollToSection(sectionKeys[_tabController.index]);
      });
    }
  }

  @override
  void dispose() {
    _transportUnitController.dispose();
    _horometerController.dispose();
    _mileageController.dispose();
    _commentController.dispose();
    _otherServiceController.dispose();
    _preventiveServiceController.dispose();
    _recommendationController.dispose();

    // Dispose de todos los controladores de scroll
    _generalScrollController.dispose();
    _checksScrollController.dispose();
    _photosScrollController.dispose();
    _recommendationsScrollController.dispose();

    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      final existing =
          await localDB.getInspectionsByOriginalId(widget.inspectionId);

      setState(() {
        _localInspectionId = existing.isNotEmpty
            ? existing.first['local_id'] as String
            : const Uuid().v4();
      });

      await _checkConnectivity();
      await _loadDraft();
    } catch (e) {
      print('Error en _initializeApp: $e');
      setState(() {
        _localInspectionId = const Uuid().v4();
        _initializeNewForm();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await syncService.checkConnectivity();
    if (mounted) {
      setState(() => _isOnline = isOnline);
    }
  }

  Future<String> _saveImagePermanently(String tempPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final permanentPath = path_lib.join(appDir.path, fileName);
    await File(tempPath).copy(permanentPath);
    return permanentPath;
  }

  Future<void> _saveDraft() async {
    // Validar solo los campos del formulario principal
    bool isValid = true;

    // Validar unidad de transporte
    if (_transportUnitController.text.isEmpty) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unidad de transporte es obligatoria')),
      );
    }

    // Validar horómetro
    if (_horometerController.text.isEmpty) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horómetro es obligatorio')),
      );
    } else if (double.tryParse(_horometerController.text) == null) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horómetro debe ser un número válido')),
      );
    }

    if (_mileageController.text.isEmpty) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kilometraje es obligatorio')),
      );
    } else if (double.tryParse(_mileageController.text) == null) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kilometraje debe ser un número válido')),
      );
    }

    if (_commentController.text.isEmpty) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detalles del servicio es obligatorio')),
      );
    }

    // Validar checks: si el status no es 1, debe tener comentario y foto
    for (var checkItem in _checkItems) {
      if (checkItem.status > 1) {
        if (checkItem.comment == null || checkItem.comment!.isEmpty) {
          isValid = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Comentario obligatorio para: ${checkItem.name}')),
          );
        }
        if (checkItem.imagePath == null) {
          isValid = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Foto obligatoria para: ${checkItem.name}')),
          );
        }
      }
    }

    // Validar servicio a realizar
    if (_maintenanceType == 'correctivo') {
      if (_preventiveServiceController.text.isEmpty) {
        isValid = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Descripción del servicio es obligatoria')),
        );
      }
    } else {
      if (_selectedServiceValue == null) {
        isValid = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione un servicio')),
        );
      } else if (_selectedServiceValue == 'otros' &&
          _otherServiceController.text.isEmpty) {
        isValid = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Especificación de servicio es obligatoria')),
        );
      }
    }

    if (!isValid) return;
    setState(() => _isSaving = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await _saveInBackground(LocalDB.STATUS_DRAFT);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrador guardado exitosamente')),
      );

      setState(() {
        _hasUnsavedChanges = false;
        _isSaving = false;
      });
    }
  }

  Future<void> _submitForm() async {
    // Validar solo los campos del formulario principal
    bool isValid = true;

    // Validar unidad de transporte
    if (_transportUnitController.text.isEmpty) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unidad de transporte es obligatoria')),
      );
    }

    // Validar horómetro
    if (_horometerController.text.isEmpty) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horómetro es obligatorio')),
      );
    } else if (double.tryParse(_horometerController.text) == null) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horómetro debe ser un número válido')),
      );
    }

    if (_mileageController.text.isEmpty) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kilometraje es obligatorio')),
      );
    } else if (double.tryParse(_mileageController.text) == null) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kilometraje debe ser un número válido')),
      );
    }

    if (_commentController.text.isEmpty) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detalle del servicio es obligatorio')),
      );
    }

    // Validar servicio a realizar
    if (_maintenanceType == 'correctivo') {
      if (_preventiveServiceController.text.isEmpty) {
        isValid = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Descripción del servicio es obligatoria')),
        );
      }
    } else {
      if (_selectedServiceValue == null) {
        isValid = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleccione un servicio')),
        );
      } else if (_selectedServiceValue == 'otros' &&
          _otherServiceController.text.isEmpty) {
        isValid = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Especificación de servicio es obligatoria')),
        );
      }
    }

    for (var checkItem in _checkItems) {
      if (checkItem.status != 1) {
        if (checkItem.comment == null || checkItem.comment!.isEmpty) {
          isValid = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text('Comentario obligatorio para: ${checkItem.name}')),
          );
        }
        if (checkItem.imagePath == null) {
          isValid = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Foto obligatoria para: ${checkItem.name}')),
          );
        }
      }
    }

    if (!_validateRequiredPhotos()) {
      isValid = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe tomar al menos una foto de cada tipo requerido'),
        ),
      );
      return;
    }

    if (!isValid) return;

    setState(() => _isSaving = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await _saveInBackground(LocalDB.STATUS_CONCLUDED_OFFLINE);

    if (mounted) {
      setState(() {
        _isEditable = false;
        _hasUnsavedChanges = false;
        _isSaving = false;
      });
      Navigator.pop(context);
    }

    try {
      final scheduleProvider =
          Provider.of<ScheduleProvider>(context, listen: false);
      await scheduleProvider.refreshActivities();
    } catch (e) {
      print("Error updating provider: $e");
    }

    if (_isOnline) {
      try {
        final success = await syncService.syncInspection(_localInspectionId);
        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Inspección sincronizada con éxito')),
            );
            try {
              final scheduleProvider =
                  Provider.of<ScheduleProvider>(context, listen: false);
              await scheduleProvider.refreshActivities();
            } catch (e) {
              print("Error updating provider after sync: $e");
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Error al sincronizar. Se reintentará automáticamente')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error de sincronización: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Inspección concluida. Se sincronizará cuando haya conexión')),
        );
      }
    }
  }

// Método para validar fotos requeridas
  bool _validateRequiredPhotos() {
    for (String type in _requiredPhotoTypes) {
      if (!_photos.any((photo) => photo.type == type)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveInBackground(int status) async {
    try {
      String? serviceValue;
      if (_maintenanceType == 'correctivo') {
        serviceValue = _preventiveServiceController.text;
      } else {
        serviceValue = _selectedServiceValue == 'otros'
            ? _otherServiceController.text
            : _selectedServiceValue;
      }

      final transportUnitValue = _transportUnitController.text;
      final horometerValue = double.tryParse(_horometerController.text);

      final mileage = _mileageController.text;
      final comment = _commentController.text;

      final inspectionData = {
        'local_id': _localInspectionId,
        'inspection_id': widget.inspectionId,
        'transport_unit': transportUnitValue,
        'maintenance_type': _maintenanceType,
        'horometer': horometerValue,
        'status': status,
        'service_to_perform': serviceValue,
        'mileage': mileage,
        'comment': comment,
      };

      final checksData = _checkItems
          .where((item) => item.status != 1)
          .map((item) => {
                'inspection_local_id': _localInspectionId,
                'maintenance_checks_id': item.id,
                'status': item.status,
                'comment': item.comment,
                'image_path': item.imagePath,
                'latitude': item.latitude?.toString(),
                'longitude': item.longitude?.toString(),
                'address': item.address,
              })
          .toList();

      final photosData = _photos
          .map((photo) => {
                'inspection_local_id': _localInspectionId,
                'type': photo.type,
                'description': photo.description,
                'image_path': photo.imagePath,
                'latitude': photo.latitude?.toString(),
                'longitude': photo.longitude?.toString(),
                'address': photo.address,
              })
          .toList();

      final recommendationsData = _recommendations
          .map((recommendation) => {
                'inspection_local_id': _localInspectionId,
                'description': recommendation.description,
                'image_path': recommendation.imagePath,
                'latitude': recommendation.latitude?.toString(),
                'longitude': recommendation.longitude?.toString(),
                'address': recommendation.address,
              })
          .toList();
// En saveFullInspection

      await localDB.saveFullInspection(
        inspection: inspectionData,
        checks: checksData,
        photos: photosData,
        recommendations: recommendationsData,
      );

      // Si el estado es concluido, actualizar la actividad local
      if (status == LocalDB.STATUS_CONCLUDED_OFFLINE) {
        try {
          final dbHelper = DatabaseHelper.instance;
          await dbHelper.updateActivityInspectionStatus(
            widget.inspectionId,
            true,
            transportUnitValue,
          );
          print('Actividad actualizada localmente como concluida');
        } catch (e) {
          print('Error actualizando actividad local: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(status == LocalDB.STATUS_DRAFT
                  ? 'Borrador guardado offline'
                  : 'Inspección concluida')),
        );
      }
    } catch (e) {
      print('Error al guardar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  Future<void> _loadDraft() async {
    try {
      final inspection = await localDB.getInspection(_localInspectionId);

      if (inspection == null) {
        _initializeNewForm();
        return;
      }

      final status = inspection['status'] as int;
      if (mounted) {
        setState(() {
          _isEditable = status != LocalDB.STATUS_CONCLUDED_OFFLINE &&
              status != LocalDB.STATUS_SYNCED;
        });
      }

      _transportUnitController.text =
          inspection['transport_unit']?.toString() ?? '';
      final serviceToPerform = inspection['service_to_perform'];
      if (serviceToPerform != null && serviceToPerform.isNotEmpty) {
        if (inspection['maintenance_type'] == 'correctivo') {
          // Cambiado de preventivo
          _preventiveServiceController.text = serviceToPerform;
        } else {
          final predefined = [
            '100',
            '250',
            '500',
            '750',
            '1000',
            '1250',
            '1500',
            '1750',
            '2000'
          ];

          if (predefined.contains(serviceToPerform)) {
            _selectedServiceValue = serviceToPerform;
          } else {
            _selectedServiceValue = 'otros';
            _otherServiceController.text = serviceToPerform;
            _showOtherServiceField = true;
          }
        }
      }

      if (inspection['horometer'] != null) {
        _horometerController.text = inspection['horometer'].toString();
      }

      if (inspection['mileage'] != null) {
        _mileageController.text = inspection['mileage'].toString();
      }

      if (inspection['comment'] != null) {
        _commentController.text = inspection['comment'].toString();
      }

      if (mounted) {
        setState(() {
          _maintenanceType =
              inspection['maintenance_type'] as String? ?? 'preventivo';
        });
      }

      final checks = await localDB.getChecksForInspection(_localInspectionId);
      final photos = await localDB.getPhotosForInspection(_localInspectionId);
      final recommendations =
          await localDB.getRecommendationsForInspection(_localInspectionId);

      final List<CheckItem> updatedCheckItems = [];
      for (var item in maintenanceItems) {
        final savedCheck = checks.firstWhere(
          (c) => c['maintenance_checks_id'] == item['id'],
          orElse: () => {},
        );

        updatedCheckItems.add(CheckItem(
          id: item['id'],
          name: item['name'],
          status: savedCheck['status'] ?? 1,
          comment: savedCheck['comment'],
          imagePath: savedCheck['image_path'],
          // Usar los valores ya convertidos
          latitude: savedCheck['latitude'] as double?,
          longitude: savedCheck['longitude'] as double?,
          address: savedCheck['address'] as String?,
        ));
      }

      final List<PhotoItem> validPhotos = [];
      for (var photo in photos) {
        final path = photo['image_path'] as String;
        if (await File(path).exists()) {
          validPhotos.add(PhotoItem(
            imagePath: path,
            type: photo['type'] as String,
            description: photo['description'] as String,
            // Usar los valores ya convertidos
            latitude: photo['latitude'] as double?,
            longitude: photo['longitude'] as double?,
            address: photo['address'] as String,
          ));
        }
      }

      final List<Recommendation> loadedRecommendations = [];
      for (var rec in recommendations) {
        final path = rec['image_path'] as String?;
        if (path == null || await File(path).exists()) {
          loadedRecommendations.add(Recommendation(
            id: rec['id'] != null ? rec['id'].toString() : Uuid().v4(),
            description: rec['description'] as String,
            imagePath: path,
            // Usar los valores ya convertidos
            latitude: rec['latitude'] as double?,
            longitude: rec['longitude'] as double?,
            address: rec['address'] as String?,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _checkItems = updatedCheckItems;
          _photos = validPhotos;
          _recommendations = loadedRecommendations;
        });
      }
    } catch (e) {
      print('Error cargando borrador: $e');
      _initializeNewForm();
    }
  }

  void _initializeNewForm() {
    if (mounted) {
      setState(() {
        _checkItems = maintenanceItems
            .map((item) => CheckItem(
                  id: item['id'],
                  name: item['name'],
                  status: 0, //Cambia el check a por defecto sin revisar
                ))
            .toList();

        _photos = [];
        _recommendations = [];
        _transportUnitController.clear();
        _horometerController.clear();
        _mileageController.clear();
        _commentController.clear();
        _maintenanceType = 'preventivo';

        _selectedServiceValue = null;
        _showOtherServiceField = false;
        _preventiveServiceController.clear();
        _otherServiceController.clear();
        _recommendationController.clear();
        _editingRecommendationId = null;
      });
    }
  }

  bool _isTakingPhoto = false;
  bool _isProcessingImage = false;

  void _addPhoto() async {
    // Verificar si ya se está procesando una foto
    if (_isTakingPhoto || _isProcessingImage) return;

    setState(() {
      _isTakingPhoto = true;
    });

    try {
      // Mostrar primero el diálogo de selección de tipo
      final photoType = await showDialog<String>(
        context: context,
        builder: (context) => PhotoTypeDialog(
          missingTypes: _getMissingPhotoTypes(),
        ),
      );

      if (photoType == null) {
        setState(() => _isTakingPhoto = false);
        return;
      }

      // Obtener ubicación
      final locationData = await LocationService.getCurrentLocation();

      // Mostrar indicador de procesamiento
      setState(() {
        _isProcessingImage = true;
        _isTakingPhoto = false;
      });

      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024, // Reducir resolución para mejorar rendimiento
        maxHeight: 1024,
        imageQuality: 85, // Calidad balanceada
      );

      if (pickedFile == null) {
        setState(() => _isProcessingImage = false);
        return;
      }

      final permanentPath = await _saveImagePermanently(pickedFile.path);

      // Ocultar indicador de procesamiento antes del diálogo
      setState(() => _isProcessingImage = false);

      // Ahora pedir la descripción
      final descriptionController = TextEditingController();
      final result = await showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => /* WillPopScope( //
          onWillPop: () async => false, */
                PopScope(
          canPop:
              false, // Bloquea el botón de retroceso (equivalente a onWillPop: () async => false)
          child: AlertDialog(
            title: Text('Descripción para $photoType',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            content: TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'CANCELAR',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, descriptionController.text),
                child: const Text(
                  'GUARDAR',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );

      if (result != null && mounted) {
        setState(() {
          _photos.add(PhotoItem(
            imagePath: permanentPath,
            type: photoType,
            description: result,
            latitude: locationData['latitude'],
            longitude: locationData['longitude'],
            address: locationData['address'],
            needsAddressLookup: locationData['needsAddressLookup'],
          ));
        });

        // Intentar obtener la dirección si hay conexión
        if (locationData['needsAddressLookup'] == true &&
            locationData['latitude'] != null &&
            locationData['longitude'] != null) {
          _updatePhotoAddress(_photos.last, locationData['latitude'],
              locationData['longitude']);
        }
      }
    } catch (e) {
      print('Error al tomar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al procesar la imagen')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPhoto = false;
          _isProcessingImage = false;
        });
      }
    }
  }

  // método similar para las fotos de los checks
  Future<void> _addPhotoToCheck(CheckItem item) async {
    if (_isTakingPhoto || _isProcessingImage) return;

    setState(() {
      _isTakingPhoto = true;
    });

    try {
      final locationData = await LocationService.getCurrentLocation();

      setState(() {
        _isProcessingImage = true;
        _isTakingPhoto = false;
      });

      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() => _isProcessingImage = false);
        return;
      }

      final permanentPath = await _saveImagePermanently(pickedFile.path);

      if (mounted) {
        setState(() {
          item.imagePath = permanentPath;
          item.latitude = locationData['latitude'];
          item.longitude = locationData['longitude'];
          item.address = locationData['address'];
          _isProcessingImage = false;
        });
      }
    } catch (e) {
      print('Error al tomar foto para check: $e');
      if (mounted) {
        setState(() => _isProcessingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al procesar la imagen')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTakingPhoto = false);
      }
    }
  }

// Método auxiliar para obtener los tipos de foto que faltan
  List<String> _getMissingPhotoTypes() {
    return _requiredPhotoTypes.where((type) {
      return !_photos.any((photo) => photo.type == type);
    }).toList();
  }

// Método para actualizar la dirección cuando haya conexión
  void _updatePhotoAddress(PhotoItem photo, double lat, double lng) async {
    final address = await LocationService.getAddressFromCoordinates(lat, lng);

    if (mounted) {
      setState(() {
        photo.address = address;
      });

      // Actualizar en la base de datos local
      await _updatePhotoAddressInLocalDB(photo);
    }
  }

  void _addRecommendation() async {
    // Verificar si ya se está procesando una foto
    if (_isTakingPhoto || _isProcessingImage) return;

    setState(() {
      _isTakingPhoto = true;
    });

    try {
      // Obtener ubicación
      final locationData = await LocationService.getCurrentLocation();

      setState(() {
        _isProcessingImage = true;
        _isTakingPhoto = false;
      });

      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        setState(() => _isProcessingImage = false);
        return;
      }

      final permanentPath = await _saveImagePermanently(pickedFile.path);

      // Ocultar indicador de procesamiento antes del diálogo
      setState(() => _isProcessingImage = false);

      // Luego pedir el texto
      final descriptionController = TextEditingController();
      final result = await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          String currentText = '';
/*           return WillPopScope(
            onWillPop: () async => false, // Bloquea el botón de retroceso */
          return PopScope(
            canPop:
                false, // Bloquea el botón de retroceso (equivalente a onWillPop: () async => false)
            child: StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text(
                    'Descripción de la recomendación',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  content: TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descripción obligatoria',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      setState(() {
                        currentText = value;
                      });
                    },
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        // Eliminar la foto si se cancela
                        File(permanentPath).delete();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    TextButton(
                      onPressed: currentText.trim().isEmpty
                          ? null
                          : () {
                              Navigator.pop(
                                  context, descriptionController.text);
                            },
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            // Cuando está deshabilitado
                            if (states.contains(WidgetState.disabled)) {
                              return Colors.grey;
                            }
                            // Cuando está habilitado
                            return Colors.green;
                          },
                        ),
                      ),
                      child: const Text('GUARDAR'),
                    )
                  ],
                );
              },
            ),
          );
        },
      );

      if (result != null && mounted) {
        setState(() {
          _recommendations.add(Recommendation(
            id: const Uuid().v4(),
            description: result,
            imagePath: permanentPath,
            latitude: locationData['latitude'],
            longitude: locationData['longitude'],
            address: locationData['address'],
          ));
        });
      }
    } catch (e) {
      print('Error al tomar foto para recomendación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al procesar la imagen')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPhoto = false;
          _isProcessingImage = false;
        });
      }
    }
  }

  void _removeRecommendation(String recommendationId) {
    setState(() {
      _recommendations.removeWhere((r) => r.id == recommendationId);
    });
  }

  void _editRecommendation(Recommendation recommendation) {
    final descriptionController =
        TextEditingController(text: recommendation.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar descripción de la recomendación'),
        content: TextField(
          controller: descriptionController,
          decoration: const InputDecoration(
            labelText: 'Descripción',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (descriptionController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('La descripción es obligatoria'),
                  ),
                );
                return;
              }

              setState(() {
                recommendation.description = descriptionController.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // Método para navegar a una sección específica
  void _scrollToSection(String sectionKey) {
    final context = _sectionKeys[sectionKey]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // Barra de pestañas superior siempre visible
  PreferredSizeWidget _buildTabBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: Container(
        color: Theme.of(context).primaryColor,
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3.0,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: const [
            Tab(
              icon: Icon(Icons.info, size: 20),
              text: 'General',
            ),
            Tab(
              icon: Icon(Icons.checklist, size: 20),
              text: 'Checks',
            ),
            Tab(
              icon: Icon(Icons.photo_library, size: 20),
              text: 'Fotos',
            ),
            Tab(
              icon: Icon(Icons.recommend, size: 20),
              text: 'Recomend.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
/*         const Text(
          'Información General',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),*/
        const SizedBox(height: 16),
        TextFormField(
          controller: _transportUnitController,
          decoration: const InputDecoration(
            labelText: 'UNIDAD DE TRANSPORTE',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _maintenanceType,
          decoration: const InputDecoration(
            labelText: 'Tipo de mantenimiento',
            border: OutlineInputBorder(),
          ),
          items: ['preventivo', 'correctivo'].map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type.toUpperCase()),
            );
          }).toList(),
          onChanged: _isEditable
              ? (value) {
                  if (mounted) {
                    setState(() {
                      _maintenanceType = value;
                      _selectedServiceValue = null;
                      _showOtherServiceField = false;
                      _otherServiceController.clear();
                    });
                  }
                }
              : null,
        ),
        const SizedBox(height: 16),
        _buildServiceField(),
        const SizedBox(height: 16),
        TextFormField(
          controller: _horometerController,
          decoration: const InputDecoration(
            labelText: 'HORÓMETRO',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _mileageController,
          decoration: const InputDecoration(
            labelText: 'KILOMETRAJE DE UNIDAD DE TRANSPORTE',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _commentController,
          decoration: const InputDecoration(
            labelText: 'DETALLES DEL SERVICIO',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.text,
        ),
      ],
    );
  }

  Widget _buildServiceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Servicio a Realizar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_maintenanceType == 'correctivo') // Cambiado de preventivo
          TextFormField(
            controller: _preventiveServiceController,
            decoration: const InputDecoration(
              labelText: 'Servicio',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
          ),
        if (_maintenanceType == 'preventivo') // Cambiado de correctivo
          Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedServiceValue,
                decoration: const InputDecoration(
                  labelText: 'Seleccione el servicio',
                  border: OutlineInputBorder(),
                ),
                items: [
                  '100',
                  '250',
                  '500',
                  '750',
                  '1000',
                  '1250',
                  '1500',
                  '1750',
                  '2000',
                  'otros'
                ].map((value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: _isEditable
                    ? (value) {
                        if (mounted) {
                          setState(() {
                            _selectedServiceValue = value;
                            _showOtherServiceField = (value == 'otros');
                          });
                        }
                      }
                    : null,
              ),
              if (_showOtherServiceField)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: TextFormField(
                    controller: _otherServiceController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Especificar servicio',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _addGeneralPhotosFromGallery() async {
    if (_isTakingPhoto || _isProcessingImage) return;

    setState(() {
      _isTakingPhoto = true;
    });

    try {
      final pickedFiles = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFiles == null || pickedFiles.isEmpty) {
        setState(() => _isTakingPhoto = false);
        return;
      }

      setState(() {
        _isProcessingImage = true;
        _isTakingPhoto = false;
      });

      final locationData = await LocationService.getCurrentLocation();

      for (final pickedFile in pickedFiles) {
        final permanentPath = await _saveImagePermanently(pickedFile.path);

        setState(() {
          _photos.add(PhotoItem(
            imagePath: permanentPath,
            type: 'Evidencias',
            description: 'Foto de evidencia general',
            latitude: locationData['latitude'],
            longitude: locationData['longitude'],
            address: locationData['address'],
            needsAddressLookup: locationData['needsAddressLookup'],
          ));
        });

        if (locationData['needsAddressLookup'] == true &&
            locationData['latitude'] != null &&
            locationData['longitude'] != null) {
          _updatePhotoAddress(_photos.last, locationData['latitude'],
              locationData['longitude']);
        }
      }
    } catch (e) {
      print('Error al seleccionar fotos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al procesar las imágenes')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTakingPhoto = false;
          _isProcessingImage = false;
        });
      }
    }
  }

  Widget _buildMaintenanceChecksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
/*         const Text(
          'Checks de Mantenimiento',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Estado: BIEN (VERDE) | REGULAR (AMARILLO) | CORRECTIVA (ROJO)',
          style: TextStyle(fontStyle: FontStyle.italic),
        ), */
        const SizedBox(height: 2),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _checkItems.length,
          itemBuilder: (context, index) {
            final item = _checkItems[index];
            return _buildCheckItem(item);
          },
        ),
      ],
    );
  }

  Widget _buildCheckItem(CheckItem item) {
    final commentFocusNode = FocusNode();
    final isStatusNotGood = item.status != 1;

    // Crear un controlador de texto para este campo específico
    final commentController = TextEditingController(text: item.comment);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusButton(item, 1, Colors.green, 'BIEN'),
                _buildStatusButton(item, 2, Colors.amber, 'REGULAR'),
                _buildStatusButton(item, 3, Colors.red, 'CORRECTIVA'),
              ],
            ),
/*             if (isStatusNotGood) ...[
              const SizedBox(height: 12),
              Text(
                'Campos obligatorios para este estado:',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ], */
            if (item.status > 1) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller:
                    commentController, // Usar el controlador en lugar de initialValue
                textInputAction: TextInputAction.done,
                focusNode: commentFocusNode,
                decoration: InputDecoration(
                  labelText: isStatusNotGood
                      ? 'Comentario (obligatorio) *'
                      : 'Comentario (opcional)',
                  border: const OutlineInputBorder(),
                  errorText: isStatusNotGood && (commentController.text.isEmpty)
                      ? 'Este campo es obligatorio'
                      : null,
                ),
                maxLines: 2,
                onChanged: (value) {
                  // Actualizar directamente el comentario del ítem
                  item.comment = value;
                },
                onFieldSubmitted: (_) {
                  commentFocusNode.unfocus();
                },
              ),
              const SizedBox(height: 8),
              if (_isEditable)
                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: Text(
                      item.imagePath == null
                          ? isStatusNotGood
                              ? 'Agregar Imagen'
                              : 'Agregar Imagen (opcional)'
                          : 'Reemplazar Imagen',
                      style: TextStyle(
                        color: isStatusNotGood && item.imagePath == null
                            ? Colors.red
                            : null,
                      ),
                    ),
                    onPressed: (_isTakingPhoto || _isProcessingImage)
                        ? null
                        : () => _addPhotoToCheck(item),
                  ),
                ),
              if (item.imagePath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Image.file(
                    File(item.imagePath!),
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              if (isStatusNotGood && item.imagePath == null)
                Text(
                  'Foto obligatoria *',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              if (item.latitude != null && item.longitude != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Coordenadas: ${item.latitude!.toStringAsFixed(6)}, ${item.longitude!.toStringAsFixed(6)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              if (item.address != null && item.address!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Dirección: ${item.address}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(
      CheckItem item, int status, Color color, String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: item.status == status ? color : Colors.grey[300],
        foregroundColor: item.status == status ? Colors.white : Colors.black,
      ),
      onPressed: _isEditable
          ? () {
              if (mounted) {
                setState(() {
                  item.status = status;
                });
              }
            }
          : null,
      child: Text(
        label,
        style: TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
/*         const Text(
          'Recomendaciones',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ), */
        const SizedBox(height: 8),
        const Text(
          'Agregue recomendaciones con foto y descripción',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),

        if (_isEditable)
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Agregar Recomendación'),
              onPressed: (_isTakingPhoto || _isProcessingImage)
                  ? null
                  : _addRecommendation,
            ),
          ),
        const SizedBox(height: 16),
        if (_recommendations.isNotEmpty)
          Center(
            child: ElevatedButton.icon(
              key: _shareButtonKey, // Agrega esta línea
              icon: Icon(Icons.share),
              label: Text('Compartir Recomendaciones por WhatsApp'),
              onPressed: _shareRecommendations,
            ),
          ),
        if (_isEditable) const SizedBox(height: 16),

        // Lista de recomendaciones
        if (_recommendations.isEmpty)
          const Center(child: Text('No hay recomendaciones agregadas')),

        ..._recommendations
            .map((recommendation) => _buildRecommendationItem(recommendation))
            .toList(),
      ],
    );
  }

  void _shareRecommendations() async {
    if (_recommendations.isEmpty) return;

    for (int i = 0; i < _recommendations.length; i++) {
      var rec = _recommendations[i];

      // Si no es la primera, preguntar si continuar
      if (i > 0) {
        final continueSharing = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Continuar con recomendación ${i + 1}?'),
            content: Text(
                '¿Has terminado de enviar la recomendación anterior?\n\nContinuemos con: ${rec.description}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar proceso'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Continuar'),
              ),
            ],
          ),
        );

        if (continueSharing != true) break;
      }

      // Enviar la recomendación actual
      String message =
          "🔧 RECOMENDACIÓN ${i + 1} de ${_recommendations.length}\n\n";
      message += "${rec.description}\n";

      if (rec.latitude != null && rec.longitude != null) {
        message +=
            "\n📍 ${rec.latitude!.toStringAsFixed(6)}, ${rec.longitude!.toStringAsFixed(6)}";
      }

      if (rec.address != null && rec.address!.isNotEmpty) {
        message += "\n🏠 ${rec.address}";
      }

      List<XFile> files = [];
      if (rec.imagePath != null && File(rec.imagePath!).existsSync()) {
        files.add(XFile(rec.imagePath!));
      }

      try {
        await SharePlus.instance.share(
          ShareParams(
            text: message,
            files: files.isNotEmpty ? files : null,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        break;
      }
    }
  }

/* 
  void _shareRecommendations() async {
    if (_recommendations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay recomendaciones para compartir')),
      );
      return;
    }

    try {
      // Construir UN SOLO mensaje con TODAS las recomendaciones
      String message = "🔧 *RECOMENDACIONES DE MANTENIMIENTO*\n\n";
      message += "Total de recomendaciones: ${_recommendations.length}\n\n";

      for (int i = 0; i < _recommendations.length; i++) {
        var rec = _recommendations[i];
        message += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
        message += "📋 *RECOMENDACIÓN ${i + 1}*\n";
        message += "${rec.description}\n\n";

        if (rec.latitude != null && rec.longitude != null) {
          message +=
              "📍 Coordenadas: ${rec.latitude!.toStringAsFixed(6)}, ${rec.longitude!.toStringAsFixed(6)}\n";
        }

        if (rec.address != null && rec.address!.isNotEmpty) {
          message += "🏠 Dirección: ${rec.address}\n";
        }

        message += "\n"; // Espacio entre recomendaciones
      }

      message += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
      message +=
          "📅 Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}\n";
      message +=
          "⏰ Hora: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";

      // Recopilar TODAS las imágenes en una sola lista
      List<XFile> allImages = [];
      for (var rec in _recommendations) {
        if (rec.imagePath != null && File(rec.imagePath!).existsSync()) {
          allImages.add(XFile(rec.imagePath!));
        }
      }

      // Obtener la posición del botón para el popup de compartir
      final box =
          _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final sharePositionOrigin =
          box != null ? box.localToGlobal(Offset.zero) & box.size : null;

      // UNA SOLA llamada a share con TODO el contenido
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject:
              'Recomendaciones de Mantenimiento - ${_recommendations.length} items',
          files: allImages.isNotEmpty ? allImages : null,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${_recommendations.length} recomendaciones compartidas exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al compartir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
 */
  Widget _buildRecommendationItem(Recommendation recommendation) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    recommendation.description,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isEditable) ...[
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editRecommendation(recommendation),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeRecommendation(recommendation.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.green),
                    onPressed: () => _shareSingleRecommendation(recommendation),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Foto de la recomendación
            if (recommendation.imagePath != null)
              Column(
                children: [
                  Image.file(
                    File(recommendation.imagePath!),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  // Información de ubicación para Recommendation
                  if (recommendation.latitude != null &&
                      recommendation.longitude != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Coordenadas: ${recommendation.latitude!.toStringAsFixed(6)}, ${recommendation.longitude!.toStringAsFixed(6)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                  if (recommendation.address != null &&
                      recommendation.address!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Dirección: ${recommendation.address}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Función para compartir una sola recomendación
  void _shareSingleRecommendation(Recommendation rec) async {
    // Construir el mensaje para esta recomendación específica
    String message = "🔧 *RECOMENDACIÓN DE MANTENIMIENTO*\n\n";
    message += "${rec.description}\n";

    if (rec.latitude != null && rec.longitude != null) {
      message +=
          "📍 Coordenadas: ${rec.latitude!.toStringAsFixed(6)}, ${rec.longitude!.toStringAsFixed(6)}\n";
    }

    if (rec.address != null && rec.address!.isNotEmpty) {
      message += "🏠 Dirección: ${rec.address}\n";
    }

    // Preparar archivo para compartir
    List<XFile> files = [];

    if (rec.imagePath != null && File(rec.imagePath!).existsSync()) {
      files.add(XFile(rec.imagePath!));
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Recomendación de Mantenimiento',
          files: files.isNotEmpty ? files : null,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e')),
      );
    }
  }

  Widget _buildPhotosSection() {
    final missingTypes = _getMissingPhotoTypes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
/*         const Text(
          'Fotos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ), */
/*         const SizedBox(height: 8),
        const Text(
          'Tipos: Antes, Después, Placa, Horómetro, Falla, Reparación',
          style: TextStyle(fontStyle: FontStyle.italic),
        ), */

        // Indicador de tipos faltantes
        if (missingTypes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Faltan: ${missingTypes.join(', ')}',
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],

        const SizedBox(height: 16),

        if (_photos.isEmpty)
          const Center(
            child: Text(
              'No hay fotos agregadas',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),

        ..._photos.map((photo) => _buildPhotoItem(photo)).toList(),

        const SizedBox(height: 16),

        if (_isEditable)
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Agregar Foto'),
              onPressed:
                  (_isTakingPhoto || _isProcessingImage) ? null : _addPhoto,
            ),
          ),
        if (_isEditable)
          Center(
            child: Column(
              children: [
/*                 ElevatedButton.icon(
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Agregar Foto (Cámara)'),
                  onPressed:
                      (_isTakingPhoto || _isProcessingImage) ? null : _addPhoto,
                ),
                const SizedBox(height: 10), */
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Agregar Fotos Generales (Galería)'),
                  onPressed: (_isTakingPhoto || _isProcessingImage)
                      ? null
                      : _addGeneralPhotosFromGallery,
                ),
              ],
            ),
          ),
      ],
    );
  }

//corr
  Widget _buildPhotoItem(PhotoItem photo) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(photo.type),
                  backgroundColor: Colors.blue[100],
                ),
                const Spacer(),
                if (_isEditable)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          _photos.remove(photo);
                        });
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              photo.description,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Image.file(
              File(photo.imagePath),
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 8),
            if (photo.latitude != null && photo.longitude != null) ...[
              const SizedBox(height: 8),
              Text(
                'Coordenadas: ${photo.latitude!.toStringAsFixed(6)}, ${photo.longitude!.toStringAsFixed(6)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (photo.address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Dirección: ${photo.address}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoTypeSection(String type, List<PhotoItem> photos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$type (${photos.length})',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: photos.isEmpty ? Colors.red : Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        if (photos.isEmpty)
          Text(
            'No hay fotos de tipo $type',
            style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        if (photos.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              itemBuilder: (context, index) {
                return _buildPhotoThumbnail(photos[index]);
              },
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPhotoThumbnail(PhotoItem photo) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      width: 100,
      child: Stack(
        children: [
          Image.file(
            File(photo.imagePath),
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
          if (_isEditable)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _photos.remove(photo);
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
            onPressed: _saveDraft,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Guardar Borrador'),
          ),
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Concluir Inspección'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      {required Key key, required String title, required IconData icon}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColorDark,
            ),
          ),
        ],
      ),
    );
  }

  // En tu _MaintenanceCheckFormState
  void _retryAddressLookups() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return; // No hay conexión, no intentar nada
    }

    // Para fotos
    for (var photo in _photos) {
      if ((photo.address.isEmpty || photo.needsAddressLookup) &&
          photo.latitude != null &&
          photo.longitude != null) {
        final newAddress = await LocationService.getAddressFromCoordinates(
            photo.latitude!, photo.longitude!);

        if (mounted && newAddress.isNotEmpty) {
          setState(() {
            photo.address = newAddress;
            photo.needsAddressLookup = false;
          });

          // Actualizar en base de datos local
          await _updatePhotoAddressInLocalDB(photo);
        }
      }
    }

    // Para checkItems
    for (var checkItem in _checkItems) {
      if ((checkItem.address == null ||
              checkItem.address!.isEmpty ||
              checkItem.needsAddressLookup) &&
          checkItem.latitude != null &&
          checkItem.longitude != null) {
        final newAddress = await LocationService.getAddressFromCoordinates(
            checkItem.latitude!, checkItem.longitude!);

        if (mounted && newAddress.isNotEmpty) {
          setState(() {
            checkItem.address = newAddress;
            checkItem.needsAddressLookup = false;
          });

          // Actualizar en base de datos local
          await _updateCheckItemAddressInLocalDB(checkItem);
        }
      }
    }

    // Para recomendaciones
    for (var recommendation in _recommendations) {
      if ((recommendation.address == null ||
              recommendation.address!.isEmpty ||
              recommendation.needsAddressLookup) &&
          recommendation.latitude != null &&
          recommendation.longitude != null) {
        final newAddress = await LocationService.getAddressFromCoordinates(
            recommendation.latitude!, recommendation.longitude!);

        if (mounted && newAddress.isNotEmpty) {
          setState(() {
            recommendation.address = newAddress;
            recommendation.needsAddressLookup = false;
          });

          // Actualizar en base de datos local
          await _updateRecommendationAddressInLocalDB(recommendation);
        }
      }
    }

    // Mostrar mensaje de éxito
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Direcciones actualizadas con conexión disponible')),
      );
    }
  }

// Métodos auxiliares para actualizar en la base de datos local
  Future<void> _updatePhotoAddressInLocalDB(PhotoItem photo) async {
    try {
      await localDB.updatePhotoAddress(
          photo.imagePath, // O usar un ID si tienes uno
          photo.address);
    } catch (e) {
      print('Error actualizando dirección de foto en BD: $e');
    }
  }

  Future<void> _updateCheckItemAddressInLocalDB(CheckItem checkItem) async {
    try {
      await localDB.updateCheckItemAddress(
          checkItem.id.toString(), // O el identificador que uses
          checkItem.address ?? '');
    } catch (e) {
      print('Error actualizando dirección de checkItem en BD: $e');
    }
  }

  Future<void> _updateRecommendationAddressInLocalDB(
      Recommendation recommendation) async {
    try {
      await localDB.updateRecommendationAddress(
          recommendation.id, recommendation.address ?? '');
    } catch (e) {
      print('Error actualizando dirección de recomendación en BD: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Formulario de Mantenimiento'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
          bottom: _buildTabBar(),
          actions: [
            // Indicador de carga global para operaciones de cámara
            if (_isTakingPhoto || _isProcessingImage)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: Icon(_isOnline ? Icons.cloud_done : Icons.cloud_off),
              onPressed: () async {
                await _checkConnectivity();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(_isOnline
                            ? 'Ahora estás en línea'
                            : 'Modo offline activado')),
                  );
                }
              },
              tooltip: _isOnline ? 'En línea' : 'Sin conexión',
            ),
          ],
        ),
        body: Stack(
          children: [
            GestureDetector(
              onHorizontalDragEnd: (details) {
                // Detectar deslizamiento rápido para cambiar de página
                if (details.primaryVelocity! > 100) {
                  // Deslizamiento rápido a la izquierda
                  if (_currentTabIndex > 0) {
                    _tabController.animateTo(_currentTabIndex - 1);
                  }
                } else if (details.primaryVelocity! < -100) {
                  // Deslizamiento rápido a la derecha
                  if (_currentTabIndex < 3) {
                    _tabController.animateTo(_currentTabIndex + 1);
                  }
                }
              },
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  _tabController.animateTo(index);
                  setState(() {
                    _currentTabIndex = index;
                  });
                },
                // Física personalizada para un deslizamiento más sensible
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  // Contenido de la pestaña Información General
                  SingleChildScrollView(
                    controller: _generalScrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSectionHeader(
                          key: _sectionKeys['general']!,
                          title: 'Información General',
                          icon: Icons.info,
                        ),
                        AbsorbPointer(
                          absorbing: !_isEditable,
                          child: Opacity(
                            opacity: _isEditable ? 1.0 : 0.6,
                            child: _buildGeneralSection(),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),

                  // Contenido de la pestaña Checks de Mantenimiento
                  SingleChildScrollView(
                    controller: _checksScrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSectionHeader(
                          key: _sectionKeys['checks']!,
                          title: 'Checks de Mantenimiento',
                          icon: Icons.checklist,
                        ),
                        AbsorbPointer(
                          absorbing: !_isEditable,
                          child: Opacity(
                            opacity: _isEditable ? 1.0 : 0.6,
                            child: _buildMaintenanceChecksSection(),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),

                  // Contenido de la pestaña Fotos
                  SingleChildScrollView(
                    controller: _photosScrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSectionHeader(
                          key: _sectionKeys['photos']!,
                          title: 'Fotos',
                          icon: Icons.photo_library,
                        ),
                        AbsorbPointer(
                          absorbing: !_isEditable,
                          child: Opacity(
                            opacity: _isEditable ? 1.0 : 0.6,
                            child: _buildPhotosSection(),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),

                  // Contenido de la pestaña Recomendaciones
                  SingleChildScrollView(
                    controller: _recommendationsScrollController,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildSectionHeader(
                          key: _sectionKeys['recommendations']!,
                          title: 'Recomendaciones',
                          icon: Icons.recommend,
                        ),
                        AbsorbPointer(
                          absorbing: !_isEditable,
                          child: Opacity(
                            opacity: _isEditable ? 1.0 : 0.6,
                            child: _buildRecommendationsSection(),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Botones de acción en la última pestaña
                        if (_isEditable) _buildActionButtons(),
                        if (!_isEditable)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _isOnline
                                    ? 'Sincronizando...'
                                    : 'Esperando conexión',
                                style: TextStyle(
                                    fontSize: 18,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Overlay para bloquear la interfaz durante operaciones de cámara
/*             if (_isTakingPhoto || _isProcessingImage)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Procesando imagen...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ), */
            if (_isSaving)
              Container(
                color: Color.fromRGBO(0, 0, 0, 0.5),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Guardando...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
