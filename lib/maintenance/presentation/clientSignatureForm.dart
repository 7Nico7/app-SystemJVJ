import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/maintenance/data/signatureDatabaseHelper.dart';

import 'package:systemjvj/maintenance/data/signature_sync_service.dart';

class ClientSignatureForm extends StatefulWidget {
  final String maintenanceId;
  final String client;
  final AuthService authService;
  const ClientSignatureForm(
      {super.key,
      required this.maintenanceId,
      required this.authService,
      required this.client});

  @override
  _ClientSignatureFormState createState() => _ClientSignatureFormState();
}

class _ClientSignatureFormState extends State<ClientSignatureForm> {
  bool _isSynced = false;
  late SignatureSyncService _syncService;
  int? _selectedRating;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 4,
    penColor: Colors.black,
  );
  StreamSubscription<List<ConnectivityResult>>?
      _connectivitySubscription; // Añade esta línea

  Uint8List? _signatureImage;
  bool _isSaved = false;
  bool _isLoading = false;
  Map<String, dynamic>? _storedData;

  @override
  void initState() {
    super.initState();
    _loadStoredSignature();
    _setupConnectivityListener();
    _syncService = SignatureSyncService(authService: widget.authService);
  }

  void _setupConnectivityListener() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) async {
      // Modifica esta línea
      if (result != ConnectivityResult.none && mounted) {
        // Añade verificación mounted
        print('🌐 Conexión detectada, verificando estado de firma...');

        // Pequeña demora para asegurar que la conexión esté estable
        await Future.delayed(const Duration(seconds: 2));

        if (!mounted) return; // Verificar nuevamente después del delay

        // Recargar el estado actual desde la base de datos
        await _loadStoredSignature();

        // Intentar sincronizar automáticamente cuando hay conexión
        if (_isSaved && !_isSynced) {
          print('🔄 Intentando sincronización automática...');
          await _trySyncSignature();
        }
      }
    });
  }

  Future<void> _tryAutoSync() async {
    if (_isSaved && !_isSynced) {
      print('Intentando sincronización automática...');
      await _trySyncSignature();
    }
  }

  Future<void> _loadStoredSignature() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final db = await SignatureDatabaseHelper.instance.database;
      final results = await db.query(
        'signatures',
        where: 'maintenanceId = ?',
        whereArgs: [widget.maintenanceId],
        limit: 1,
      );

      if (results.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _storedData = results[0];
          _selectedRating = _storedData!['rating'] as int?;
          // CORRECIÓN: Verificar correctamente el valor de isSynced
          _isSynced = (_storedData!['isSynced'] as int) == 1;

          final signatureString = _storedData!['signature'] as String?;
          if (signatureString != null) {
            _signatureImage = base64Decode(signatureString);
          }

          _isSaved = true;
        });
      } else {
        // Asegurarse de resetear el estado si no hay firma guardada
        setState(() {
          _isSaved = false;
          _isSynced = false;
        });
      }
    } catch (e) {
      print('Error loading signature: $e');
      setState(() {
        _isSaved = false;
        _isSynced = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription
        ?.cancel(); // Añade esta línea para cancelar la suscripción
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    if (_selectedRating == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('POR FAVOR SELECCIONE UNA CALIFICACIÓN')),
      );
      return;
    }

    if (_signatureController.isEmpty && _signatureImage == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('POR FAVOR CAPTURE O SUBA UNA FIRMA')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? signatureBase64;

      if (_signatureController.isNotEmpty) {
        final signatureData = await _signatureController.toPngBytes();
        if (signatureData != null) {
          signatureBase64 = base64Encode(signatureData);
        }
      } else if (_signatureImage != null) {
        signatureBase64 = base64Encode(_signatureImage!);
      }

      if (signatureBase64 == null) {
        throw Exception('Error al procesar la firma');
      }

      final db = await SignatureDatabaseHelper.instance.database;
      await db.insert(
        'signatures',
        {
          'maintenanceId': widget.maintenanceId,
          'rating': _selectedRating,
          'signature': signatureBase64,
          'isSynced': 0,
          'createdAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (!mounted) return;
      setState(() => _isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FIRMA GUARDADA LOCALMENTE')),
      );

      _trySyncSignature();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _trySyncSignature() async {
    // Verificar conectividad antes de intentar sincronizar
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SIN CONEXIÓN A INTERNET')),
        );
      }
      return;
    }

    if (!mounted) return; // Verificar antes de setState
    setState(() => _isLoading = true);

    try {
      final success = await _syncService.syncPendingSignatures();

      if (!mounted) return;

      // Recargar el estado después de la sincronización
      await _loadStoredSignature();

      if (success && _isSynced && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('FIRMA SINCRONIZADA CON ÉXITO!')),
        );
      } else if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'ERROR EN SINCRONIZACIÓN. SE REINTENTARÁ AUTOMÁTICAMENTE.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Modificar la UI para reflejar el estado de sincronización
  Widget _buildSyncStatus() {
    if (_isSaved) {
      return Column(
        children: [
          Icon(
            _isSynced ? Icons.cloud_done : Icons.cloud_upload,
            color: _isSynced ? Colors.green : Colors.orange,
            size: 50,
          ),
          const SizedBox(height: 10),
          Text(
            _isSynced ? 'FIRMA SINCRONIZADA' : 'FIRMA GUARDADA LOCALMENTE',
            style: TextStyle(
              color: _isSynced ? Colors.green : Colors.orange,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _isSynced
                ? 'SINCRONIZADO CON EL SERVIDOR'
                : 'SE SINCRONIZARÁ AUTOMÁTICAMENTE CUANDO HAYA CONEXIÓN',
            style: const TextStyle(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      return const SizedBox();
    }
  }

  Future<void> _pickImage() async {
    if (_isSaved) return;

    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _signatureImage = bytes;
        _signatureController.clear();
      });
    }
  }

  Widget _buildRatingSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CALIFICACIÓN DEL SERVICIO:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildRatingButton(3, 'MALO', Icons.sentiment_very_dissatisfied),
            _buildRatingButton(2, 'REGULAR', Icons.sentiment_neutral),
            _buildRatingButton(1, 'BUENO', Icons.sentiment_very_satisfied),
          ],
        ),
      ],
    );
  }

  Widget _buildRatingButton(int rating, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon,
            size: 36,
            color: (_selectedRating == rating && rating == 1)
                ? Colors.blue
                : (_selectedRating == rating && rating == 2)
                    ? Colors.amber
                    : (_selectedRating == rating && rating == 3)
                        ? Colors.red
                        : Colors.grey),
        const SizedBox(height: 5),
        ElevatedButton(
          onPressed:
              _isSaved ? null : () => setState(() => _selectedRating = rating),
          style: ElevatedButton.styleFrom(
            backgroundColor: (_selectedRating == rating && rating == 1)
                ? Colors.blue
                : (_selectedRating == rating && rating == 2)
                    ? Colors.amber
                    : (_selectedRating == rating && rating == 3)
                        ? Colors.red
                        : null,
          ),
          child: Text(label),
        ),
      ],
    );
  }

  Widget _buildSignatureArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FIRMA DEL CLIENTE:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: _signatureImage != null
                ? Image.memory(_signatureImage!, height: 200)
                : Signature(
                    controller: _signatureController,
                    height: 200,
                    backgroundColor: Colors.white,
                  ),
          ),
        ),
        if (!_isSaved && _signatureImage == null) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton.icon(
                onPressed: () => _signatureController.clear(),
                icon: const Icon(Icons.delete),
                label: const Text('LIMPIAR'),
              ),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.upload),
                label: const Text('SUBIR IMAGEN'),
              ),
            ],
          ),
        ]
      ],
    );
  }

  Widget _buildSyncButton() {
    return ElevatedButton(
      onPressed: _trySyncSignature,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync),
          SizedBox(width: 10),
          Text('SINCRONIZAR AHORA', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FIRMA DE CLIENTE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CLIENTE: ${widget.client}',
                      textAlign: TextAlign.justify,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      )),
                  const SizedBox(height: 20),
                  _buildRatingSelector(),
                  const SizedBox(height: 30),
                  _buildSignatureArea(),
                  const SizedBox(height: 30),

                  // Mostrar estado de sincronización
                  Center(child: _buildSyncStatus()),
                  const SizedBox(height: 20),

                  if (!_isSaved)
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveSignature,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 15),
                        ),
                        child: const Text('GUARDAR FIRMA',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  /*  if (_isSaved && !_isSynced) Center(child: _buildSyncButton()), */
                ],
              ),
            ),
    );
  }
}
