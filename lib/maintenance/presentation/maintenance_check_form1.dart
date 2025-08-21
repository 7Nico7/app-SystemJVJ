/* import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/maintenance/data/local_db.dart';
import 'package:systemjvj/maintenance/data/sync_service.dart';
import 'package:systemjvj/maintenance/domain/check_item.dart';
import 'package:systemjvj/maintenance/domain/photo_item.dart';
import 'package:systemjvj/maintenance/presentation/photo_type_dialog.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';
import 'package:uuid/uuid.dart';

// Modelo para Recomendaciones
class Recommendation {
  String id;
  String description;
  String? imagePath;

  Recommendation({
    required this.id,
    required this.description,
    this.imagePath,
  });
}

class MaintenanceCheckForm1 extends StatefulWidget {
  final int inspectionId;

  const MaintenanceCheckForm1({Key? key, required this.inspectionId})
      : super(key: key);

  @override
  _MaintenanceCheckFormState createState() => _MaintenanceCheckFormState();
}

class _MaintenanceCheckFormState extends State<MaintenanceCheckForm1>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final LocalDB localDB = LocalDB();
  late SyncService syncService;
  late String _localInspectionId;
  bool _isOnline = true;
  bool _isLoading = true;
  bool _isEditable = true;
  final ImagePicker _picker = ImagePicker();

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

  late TextEditingController _transportUnitController;
  late TextEditingController _horometerController;

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

  @override
  void initState() {
    super.initState();
    _transportUnitController = TextEditingController();
    _horometerController = TextEditingController();
    _otherServiceController = TextEditingController();
    _preventiveServiceController = TextEditingController();
    syncService = SyncService();

    // Inicializar el controlador de pestañas
    _tabController = TabController(
      length: 4, // Número de pestañas
      vsync: this,
    );

    // Listener para cambios en las pestañas
    _tabController.addListener(_handleTabSelection);

    _initializeApp();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });

      // Navegar a la sección correspondiente después de un breve delay
      // para permitir que la pestaña se renderice completamente
      Future.delayed(const Duration(milliseconds: 100), () {
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
    _otherServiceController.dispose();
    _preventiveServiceController.dispose();
    _recommendationController.dispose();

    // Dispose de todos los controladores de scroll
    _generalScrollController.dispose();
    _checksScrollController.dispose();
    _photosScrollController.dispose();
    _recommendationsScrollController.dispose();

    _tabController.dispose();
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

    // Validar servicio a realizar
    if (_maintenanceType == 'preventivo') {
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

    // Validar servicio a realizar
    if (_maintenanceType == 'preventivo') {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await _saveInBackground(LocalDB.STATUS_CONCLUDED);

    if (mounted) {
      setState(() {
        _isEditable = false;
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

  Future<void> _saveInBackground(int status) async {
    try {
      String? serviceValue;
      if (_maintenanceType == 'preventivo') {
        serviceValue = _preventiveServiceController.text;
      } else {
        serviceValue = _selectedServiceValue == 'otros'
            ? _otherServiceController.text
            : _selectedServiceValue;
      }

      final transportUnitValue = _transportUnitController.text;
      final horometerValue = double.tryParse(_horometerController.text);

      final inspectionData = {
        'local_id': _localInspectionId,
        'inspection_id': widget.inspectionId,
        'transport_unit': transportUnitValue,
        'maintenance_type': _maintenanceType,
        'horometer': horometerValue,
        'status': status,
        'service_to_perform': serviceValue,
      };

      final checksData = _checkItems
          .where((item) => item.status != 1)
          .map((item) => {
                'inspection_local_id': _localInspectionId,
                'maintenance_checks_id': item.id,
                'status': item.status,
                'comment': item.comment,
                'image_path': item.imagePath,
              })
          .toList();

      final photosData = _photos
          .map((photo) => {
                'inspection_local_id': _localInspectionId,
                'type': photo.type,
                'description': photo.description,
                'image_path': photo.imagePath,
              })
          .toList();

      final recommendationsData = _recommendations
          .map((recommendation) => {
                'inspection_local_id': _localInspectionId,
                'description': recommendation.description,
                'image_path': recommendation.imagePath,
              })
          .toList();

      await localDB.saveFullInspection(
        inspection: inspectionData,
        checks: checksData,
        photos: photosData,
        recommendations: recommendationsData,
      );

      // Si el estado es concluido, actualizar la actividad local
      if (status == LocalDB.STATUS_CONCLUDED) {
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
          _isEditable = status != LocalDB.STATUS_CONCLUDED &&
              status != LocalDB.STATUS_SYNCED;
        });
      }

      _transportUnitController.text =
          inspection['transport_unit']?.toString() ?? '';

      final serviceToPerform = inspection['service_to_perform'];
      if (serviceToPerform != null && serviceToPerform.isNotEmpty) {
        if (inspection['maintenance_type'] == 'preventivo') {
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
          ));
        }
      }

      final List<Recommendation> loadedRecommendations = [];
      for (var rec in recommendations) {
        final path = rec['image_path'] as String?;
        // Si hay una ruta de imagen, verificar que el archivo existe
        if (path == null || await File(path).exists()) {
          loadedRecommendations.add(Recommendation(
            id: rec['id'] != null ? rec['id'].toString() : Uuid().v4(),
            description: rec['description'] as String,
            imagePath: path,
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
                  status: 1,
                ))
            .toList();

        _photos = [];
        _recommendations = [];
        _transportUnitController.clear();
        _horometerController.clear();
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

  void _addPhoto() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    final permanentPath = await _saveImagePermanently(pickedFile.path);

    final photoType = await showDialog<String>(
      context: context,
      builder: (context) => PhotoTypeDialog(),
    );

    if (photoType == null) return;

    final descriptionController = TextEditingController();
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Descripción para $photoType'),
        content: TextField(
          controller: descriptionController,
          decoration: const InputDecoration(
            labelText: 'Descripción obligatoria',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, descriptionController.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _photos.add(PhotoItem(
          imagePath: permanentPath,
          type: photoType,
          description: result,
        ));
      });
    }
  }

  void _addRecommendation() async {
    final description = _recommendationController.text.trim();
    if (description.isEmpty) return;

    if (_editingRecommendationId != null) {
      setState(() {
        final index = _recommendations
            .indexWhere((r) => r.id == _editingRecommendationId);
        if (index != -1) {
          _recommendations[index] = Recommendation(
            id: _editingRecommendationId!,
            description: description,
            imagePath: _recommendations[index].imagePath,
          );
        }
        _editingRecommendationId = null;
      });
    } else {
      setState(() {
        _recommendations.add(Recommendation(
          id: const Uuid().v4(),
          description: description,
        ));
      });
    }

    _recommendationController.clear();
  }

  void _addPhotoToRecommendation(String recommendationId) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    final permanentPath = await _saveImagePermanently(pickedFile.path);

    setState(() {
      final index =
          _recommendations.indexWhere((r) => r.id == recommendationId);
      if (index != -1) {
        _recommendations[index].imagePath = permanentPath;
      }
    });
  }

  void _removeRecommendation(String recommendationId) {
    setState(() {
      _recommendations.removeWhere((r) => r.id == recommendationId);
    });
  }

  void _editRecommendation(Recommendation recommendation) {
    _recommendationController.text = recommendation.description;
    _editingRecommendationId = recommendation.id;
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
              text: 'Información General',
            ),
            Tab(
              icon: Icon(Icons.checklist, size: 20),
              text: 'Checks Mantenimiento',
            ),
            Tab(
              icon: Icon(Icons.photo_library, size: 20),
              text: 'Fotos',
            ),
            Tab(
              icon: Icon(Icons.recommend, size: 20),
              text: 'Recomendaciones',
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
        const Text(
          'Información General',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _transportUnitController,
          decoration: const InputDecoration(
            labelText: 'Unidad de transporte',
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
            labelText: 'Horómetro',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
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
        if (_maintenanceType == 'preventivo')
          TextFormField(
            controller: _preventiveServiceController,
            decoration: const InputDecoration(
              labelText: 'Descripción del servicio',
              border: OutlineInputBorder(),
            ),
          ),
        if (_maintenanceType == 'correctivo')
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
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildMaintenanceChecksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Checks de Mantenimiento',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Estado: BIEN (VERDE) | REGULAR (AMARILLO) | CORRECTIVA (ROJO)',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
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
                _buildStatusButton(item, 2, Colors.yellow, 'REGULAR'),
                _buildStatusButton(item, 3, Colors.red, 'CORRECTIVA'),
              ],
            ),
            if (item.status != 1) ...[
              const SizedBox(height: 12),
              TextFormField(
                textInputAction: TextInputAction.done,
                focusNode: commentFocusNode,
                decoration: InputDecoration(
                  labelText: item.status == 1
                      ? 'Comentario (opcional)'
                      : 'Comentario (obligatorio)',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (value) => item.comment = value,
                initialValue: item.comment,
                onFieldSubmitted: (_) {
                  commentFocusNode.unfocus();
                },
              ),
              const SizedBox(height: 8),
              if (_isEditable)
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: Text(item.imagePath == null
                      ? 'Agregar Imagen'
                      : 'Reemplazar Imagen'),
                  onPressed: () async {
                    final pickedFile =
                        await _picker.pickImage(source: ImageSource.camera);
                    if (pickedFile != null) {
                      final permanentPath =
                          await _saveImagePermanently(pickedFile.path);
                      if (mounted) {
                        setState(() {
                          item.imagePath = permanentPath;
                        });
                      }
                    }
                  },
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
      child: Text(label),
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recomendaciones',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Agregue recomendaciones con descripción y foto si es necesario',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),

        // Campo para agregar/editar recomendación
        if (_isEditable)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _recommendationController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción de la recomendación',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addRecommendation,
                child: Text(_editingRecommendationId != null
                    ? 'Actualizar'
                    : 'Agregar'),
              ),
            ],
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
                  const SizedBox(height: 8),
                ],
              ),

            if (_isEditable)
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: Text(recommendation.imagePath == null
                      ? 'Agregar Foto'
                      : 'Reemplazar Foto'),
                  onPressed: () => _addPhotoToRecommendation(recommendation.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fotos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tipos: Antes, Después, Placa, Horómetro, Falla, Reparación',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
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
              onPressed: _addPhoto,
            ),
          ),
      ],
    );
  }

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
          ],
        ),
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
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Guardar Borrador'),
          ),
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
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
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulario de Mantenimiento'),
        bottom: _buildTabBar(),
        actions: [
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
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
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
                        _isOnline ? 'Sincronizando...' : 'Esperando conexión',
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
    );
  }
}
 */

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/maintenance/data/local_db.dart';
import 'package:systemjvj/maintenance/data/sync_service.dart';
import 'package:systemjvj/maintenance/domain/check_item.dart';
import 'package:systemjvj/maintenance/domain/photo_item.dart';
import 'package:systemjvj/maintenance/presentation/photo_type_dialog.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';
import 'package:uuid/uuid.dart';

// Modelo para Recomendaciones
class Recommendation {
  String id;
  String description;
  String? imagePath;

  Recommendation({
    required this.id,
    required this.description,
    this.imagePath,
  });
}

class MaintenanceCheckForm1 extends StatefulWidget {
  final int inspectionId;

  const MaintenanceCheckForm1({Key? key, required this.inspectionId})
      : super(key: key);

  @override
  _MaintenanceCheckFormState createState() => _MaintenanceCheckFormState();
}

class _MaintenanceCheckFormState extends State<MaintenanceCheckForm1>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final LocalDB localDB = LocalDB();
  late SyncService syncService;
  late String _localInspectionId;
  bool _isOnline = true;
  bool _isLoading = true;
  bool _isEditable = true;
  final ImagePicker _picker = ImagePicker();

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

  @override
  void initState() {
    super.initState();
    _transportUnitController = TextEditingController();
    _horometerController = TextEditingController();
    _otherServiceController = TextEditingController();
    _preventiveServiceController = TextEditingController();
    syncService = SyncService();

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

    _initializeApp();
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

    // Validar servicio a realizar
    if (_maintenanceType == 'preventivo') {
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

    // Validar servicio a realizar
    if (_maintenanceType == 'preventivo') {
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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    await _saveInBackground(LocalDB.STATUS_CONCLUDED);

    if (mounted) {
      setState(() {
        _isEditable = false;
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

  Future<void> _saveInBackground(int status) async {
    try {
      String? serviceValue;
      if (_maintenanceType == 'preventivo') {
        serviceValue = _preventiveServiceController.text;
      } else {
        serviceValue = _selectedServiceValue == 'otros'
            ? _otherServiceController.text
            : _selectedServiceValue;
      }

      final transportUnitValue = _transportUnitController.text;
      final horometerValue = double.tryParse(_horometerController.text);

      final inspectionData = {
        'local_id': _localInspectionId,
        'inspection_id': widget.inspectionId,
        'transport_unit': transportUnitValue,
        'maintenance_type': _maintenanceType,
        'horometer': horometerValue,
        'status': status,
        'service_to_perform': serviceValue,
      };

      final checksData = _checkItems
          .where((item) => item.status != 1)
          .map((item) => {
                'inspection_local_id': _localInspectionId,
                'maintenance_checks_id': item.id,
                'status': item.status,
                'comment': item.comment,
                'image_path': item.imagePath,
              })
          .toList();

      final photosData = _photos
          .map((photo) => {
                'inspection_local_id': _localInspectionId,
                'type': photo.type,
                'description': photo.description,
                'image_path': photo.imagePath,
              })
          .toList();

      final recommendationsData = _recommendations
          .map((recommendation) => {
                'inspection_local_id': _localInspectionId,
                'description': recommendation.description,
                'image_path': recommendation.imagePath,
              })
          .toList();

      await localDB.saveFullInspection(
        inspection: inspectionData,
        checks: checksData,
        photos: photosData,
        recommendations: recommendationsData,
      );

      // Si el estado es concluido, actualizar la actividad local
      if (status == LocalDB.STATUS_CONCLUDED) {
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
          _isEditable = status != LocalDB.STATUS_CONCLUDED &&
              status != LocalDB.STATUS_SYNCED;
        });
      }

      _transportUnitController.text =
          inspection['transport_unit']?.toString() ?? '';

      final serviceToPerform = inspection['service_to_perform'];
      if (serviceToPerform != null && serviceToPerform.isNotEmpty) {
        if (inspection['maintenance_type'] == 'preventivo') {
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
          ));
        }
      }

      final List<Recommendation> loadedRecommendations = [];
      for (var rec in recommendations) {
        final path = rec['image_path'] as String?;
        // Si hay una ruta de imagen, verificar que el archivo existe
        if (path == null || await File(path).exists()) {
          loadedRecommendations.add(Recommendation(
            id: rec['id'] != null ? rec['id'].toString() : Uuid().v4(),
            description: rec['description'] as String,
            imagePath: path,
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
                  status: 1,
                ))
            .toList();

        _photos = [];
        _recommendations = [];
        _transportUnitController.clear();
        _horometerController.clear();
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

  void _addPhoto() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    final permanentPath = await _saveImagePermanently(pickedFile.path);

    final photoType = await showDialog<String>(
      context: context,
      builder: (context) => PhotoTypeDialog(),
    );

    if (photoType == null) return;

    final descriptionController = TextEditingController();
    final result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Descripción para $photoType'),
        content: TextField(
          controller: descriptionController,
          decoration: const InputDecoration(
            labelText: 'Descripción obligatoria',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, descriptionController.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _photos.add(PhotoItem(
          imagePath: permanentPath,
          type: photoType,
          description: result,
        ));
      });
    }
  }

  void _addRecommendation() async {
    final description = _recommendationController.text.trim();
    if (description.isEmpty) return;

    if (_editingRecommendationId != null) {
      setState(() {
        final index = _recommendations
            .indexWhere((r) => r.id == _editingRecommendationId);
        if (index != -1) {
          _recommendations[index] = Recommendation(
            id: _editingRecommendationId!,
            description: description,
            imagePath: _recommendations[index].imagePath,
          );
        }
        _editingRecommendationId = null;
      });
    } else {
      setState(() {
        _recommendations.add(Recommendation(
          id: const Uuid().v4(),
          description: description,
        ));
      });
    }

    _recommendationController.clear();
  }

  void _addPhotoToRecommendation(String recommendationId) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    final permanentPath = await _saveImagePermanently(pickedFile.path);

    setState(() {
      final index =
          _recommendations.indexWhere((r) => r.id == recommendationId);
      if (index != -1) {
        _recommendations[index].imagePath = permanentPath;
      }
    });
  }

  void _removeRecommendation(String recommendationId) {
    setState(() {
      _recommendations.removeWhere((r) => r.id == recommendationId);
    });
  }

  void _editRecommendation(Recommendation recommendation) {
    _recommendationController.text = recommendation.description;
    _editingRecommendationId = recommendation.id;
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
        const Text(
          'Información General',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _transportUnitController,
          decoration: const InputDecoration(
            labelText: 'Unidad de transporte',
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
            labelText: 'Horómetro',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
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
        if (_maintenanceType == 'preventivo')
          TextFormField(
            controller: _preventiveServiceController,
            decoration: const InputDecoration(
              labelText: 'Descripción del servicio',
              border: OutlineInputBorder(),
            ),
          ),
        if (_maintenanceType == 'correctivo')
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
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildMaintenanceChecksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Checks de Mantenimiento',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Estado: BIEN (VERDE) | REGULAR (AMARILLO) | CORRECTIVA (ROJO)',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
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
                _buildStatusButton(item, 2, Colors.yellow, 'REGULAR'),
                _buildStatusButton(item, 3, Colors.red, 'CORRECTIVA'),
              ],
            ),
            if (item.status != 1) ...[
              const SizedBox(height: 12),
              TextFormField(
                textInputAction: TextInputAction.done,
                focusNode: commentFocusNode,
                decoration: InputDecoration(
                  labelText: item.status == 1
                      ? 'Comentario (opcional)'
                      : 'Comentario (obligatorio)',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
                onChanged: (value) => item.comment = value,
                initialValue: item.comment,
                onFieldSubmitted: (_) {
                  commentFocusNode.unfocus();
                },
              ),
              const SizedBox(height: 8),
              if (_isEditable)
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: Text(item.imagePath == null
                      ? 'Agregar Imagen'
                      : 'Reemplazar Imagen'),
                  onPressed: () async {
                    final pickedFile =
                        await _picker.pickImage(source: ImageSource.camera);
                    if (pickedFile != null) {
                      final permanentPath =
                          await _saveImagePermanently(pickedFile.path);
                      if (mounted) {
                        setState(() {
                          item.imagePath = permanentPath;
                        });
                      }
                    }
                  },
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
      child: Text(label),
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recomendaciones',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Agregue recomendaciones con descripción y foto si es necesario',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),

        // Campo para agregar/editar recomendación
        if (_isEditable)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _recommendationController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción de la recomendación',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addRecommendation,
                child: Text(_editingRecommendationId != null
                    ? 'Actualizar'
                    : 'Agregar'),
              ),
            ],
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
                  const SizedBox(height: 8),
                ],
              ),

            if (_isEditable)
              Center(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: Text(recommendation.imagePath == null
                      ? 'Agregar Foto'
                      : 'Reemplazar Foto'),
                  onPressed: () => _addPhotoToRecommendation(recommendation.id),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fotos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tipos: Antes, Después, Placa, Horómetro, Falla, Reparación',
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
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
              onPressed: _addPhoto,
            ),
          ),
      ],
    );
  }

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
          ],
        ),
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
              backgroundColor: Colors.blueGrey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Guardar Borrador'),
          ),
          ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
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
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulario de Mantenimiento'),
        bottom: _buildTabBar(),
        actions: [
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
      body: GestureDetector(
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
                          _isOnline ? 'Sincronizando...' : 'Esperando conexión',
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
    );
  }
}
