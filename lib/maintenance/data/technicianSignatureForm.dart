/* import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:systemjvj/maintenance/data/signatureDatabaseHelper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:systemjvj/maintenance/data/signature_sync_service.dart';

class TechnicianSignatureForm extends StatefulWidget {
  final String maintenanceId;

  const TechnicianSignatureForm({super.key, required this.maintenanceId});

  @override
  _TechnicianSignatureFormState createState() =>
      _TechnicianSignatureFormState();
}

class _TechnicianSignatureFormState extends State<TechnicianSignatureForm> {
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 4,
    penColor: Colors.black,
  );
  Uint8List? _signatureImage;
  bool _isSaved = false;
  bool _isLoading = false;
  Map<String, dynamic>? _storedData;

  @override
  void initState() {
    super.initState();
    _loadStoredSignature();
  }

  Future<void> _loadStoredSignature() async {
    setState(() => _isLoading = true);
    try {
      final db = await SignatureDatabaseHelper.instance.database;
      final results = await db.query(
        'technician_signatures',
        where: 'maintenanceId = ?',
        whereArgs: [widget.maintenanceId],
        limit: 1,
      );

      if (results.isNotEmpty) {
        setState(() {
          _storedData = results[0];
          final signatureString = _storedData!['signature'] as String?;
          if (signatureString != null) {
            _signatureImage = base64Decode(signatureString);
          }
          _isSaved = true;
        });
      }
    } catch (e) {
      print('Error loading signature: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    if (_signatureController.isEmpty && _signatureImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor capture o suba una firma')),
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
        'technician_signatures',
        {
          'maintenanceId': widget.maintenanceId,
          'signature': signatureBase64,
          'isSynced': 0,
          'createdAt': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      setState(() => _isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firma guardada localmente')),
      );

      _trySyncSignature();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _trySyncSignature() async {
    setState(() => _isLoading = true);
    try {
      final syncService = SignatureSyncService();
      final success = await syncService.syncPendingTechnicianSignatures();

      if (success) {
        final db = await SignatureDatabaseHelper.instance.database;
        final result = await db.query(
          'technician_signatures',
          where: 'maintenanceId = ? AND isSynced = ?',
          whereArgs: [widget.maintenanceId, 1],
        );

        if (result.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Firma sincronizada con éxito!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Firma pendiente de sincronización')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error en sincronización')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
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

  Widget _buildSignatureArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Firma del técnico:', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _signatureImage != null
              ? Image.memory(_signatureImage!, height: 200)
              : Signature(
                  controller: _signatureController,
                  height: 200,
                  backgroundColor: Colors.white,
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
                label: const Text('Limpiar'),
              ),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.upload),
                label: const Text('Subir imagen'),
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
          Text('Sincronizar ahora', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firma del Técnico'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Orden: ${widget.maintenanceId}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 20),
                  _buildSignatureArea(),
                  const SizedBox(height: 30),
                  if (!_isSaved)
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveSignature,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 15),
                        ),
                        child: const Text('Guardar Firma',
                            style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  if (_isSaved) ...[
                    const Center(
                      child: Column(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 50),
                          SizedBox(height: 10),
                          Text('Firma guardada exitosamente',
                              style:
                                  TextStyle(color: Colors.green, fontSize: 18)),
                          SizedBox(height: 5),
                          Text('Se sincronizará cuando haya conexión',
                              style: TextStyle(fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(child: _buildSyncButton()),
                  ],
                ],
              ),
            ),
    );
  }
}
 */
