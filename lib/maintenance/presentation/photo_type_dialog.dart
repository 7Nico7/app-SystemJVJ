import 'package:flutter/material.dart';

class PhotoTypeDialog extends StatelessWidget {
  final List<String> missingTypes;

  const PhotoTypeDialog({Key? key, this.missingTypes = const []})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final photoTypes = [
      'Evidencias',
      'Antes de mantenimiento',
      'Después de mantenimiento',
      'Placa serie',
      'Horómetro',
      'Falla',
      'Reparación'
    ];

    return AlertDialog(
      title: const Text('Seleccionar tipo de foto'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: photoTypes.length,
          itemBuilder: (context, index) {
            final type = photoTypes[index];
            final isMissing = missingTypes.contains(type);

            return ListTile(
              title: Text(
                type,
                style: TextStyle(
                  fontWeight: isMissing ? FontWeight.bold : FontWeight.normal,
                  color: isMissing ? Colors.red : Colors.black,
                ),
              ),
              onTap: () => Navigator.pop(context, type),
            );
          },
        ),
      ),
    );
  }
}
