/* import 'package:flutter/material.dart';

class PhotoTypeDialog extends StatelessWidget {
  final List<String> types = [
    'Antes de mantenimiento', //1
    'Después de mantenimiento', //2
    'Placa serie', //3
    'Horometro', //4
    'Falla especifica' //5,
        'Reparación' //6
  ];

  PhotoTypeDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar tipo de foto'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: types.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(types[index]),
              onTap: () => Navigator.pop(context, types[index]),
            );
          },
        ),
      ),
    );
  }
}
 */
import 'package:flutter/material.dart';

class PhotoTypeDialog extends StatelessWidget {
  final List<String> types = [
    'Antes de mantenimiento', //1
    'Después de mantenimiento', //2
    'Placa serie', //3
    'Horometro', //4
    'Falla especifica', //5
    'Reparación' //6
  ];

  PhotoTypeDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0), // Bordes redondeados
      ),
      child: WillPopScope(
        onWillPop: () async {
          // Evita que se cierre al presionar el botón de retroceso
          return false;
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.photo_library, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'Seleccionar tipo de foto',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 350, // Altura fija para la lista
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: types.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(types[index]),
                    onTap: () => Navigator.pop(context, types[index]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // Cierra sin seleccionar
                },
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
