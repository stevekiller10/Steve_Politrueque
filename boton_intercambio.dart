// ARCHIVO CORREGIDO: Se ha cambiado el nombre del parámetro a 'idUsuarioRecibido'.
import 'package:flutter/material.dart';
import 'package:trueque/services/intercambio_service.dart';

class BotonIntercambio extends StatelessWidget {
  final String idUsuarioRecibido;
  final String? idProductoOfertado;
  final String? idProductoSolicitado;

  const BotonIntercambio({
    super.key,
    required this.idUsuarioRecibido,
    this.idProductoOfertado,
    this.idProductoSolicitado,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        try {
          await IntercambioService().crearIntercambio(
            idUsuarioRecibido: idUsuarioRecibido,
            idProductoOfertado: idProductoOfertado,
            idProductoSolicitado: idProductoSolicitado,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Propuesta de intercambio enviada!'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al proponer intercambio: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: const Text('Proponer Intercambio'),
    );
  }
}
