// ARCHIVO FINAL CON LÓGICA DE NEGOCIO REAL
import 'package:flutter/material.dart';
import 'package:trueque/modelo/producto_unificado_model.dart';
import 'package:trueque/modelo/user.model.dart';
import 'package:trueque/services/puntos_service.dart';

class ProponerIntercambioDialog extends StatefulWidget {
  final ProductoUnificado productoSolicitado;
  final UserModel usuarioActual;

  const ProponerIntercambioDialog({
    Key? key,
    required this.productoSolicitado,
    required this.usuarioActual,
  }) : super(key: key);

  @override
  State<ProponerIntercambioDialog> createState() =>
      _ProponerIntercambioDialogState();
}

class _ProponerIntercambioDialogState extends State<ProponerIntercambioDialog> {
  bool _isLoading = true;
  int _puntosUsuario = 0;

  @override
  void initState() {
    super.initState();
    _cargarPuntosUsuario();
  }

  Future<void> _cargarPuntosUsuario() async {
    setState(() => _isLoading = true);
    final puntosResult = await PuntosService.getPuntosUsuario(widget.usuarioActual.id);
    if (mounted && puntosResult['success'] == true) {
      setState(() {
        _puntosUsuario = puntosResult['puntos'] as int;
        _isLoading = false;
      });
    }
  }

  Future<void> _enviarSolicitudYRedirigir() async {
    setState(() => _isLoading = true);

    // LLAMADA REAL AL SERVICIO PARA CREAR LA PROPUESTA
    final result = await PuntosService.proponerIntercambio(
      usuarioReceptorId: widget.productoSolicitado.usuarioId,
      productoSolicitadoId: widget.productoSolicitado.id,
      // Como es un intercambio solo por puntos, no se envía un producto ofrecido.
      // El servicio debe estar preparado para manejar `productoOfertadoId` como nulo.
      productoOfertadoId: null, 
    );

    if (!mounted) return;

    final success = result['success'] as bool? ?? false;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Propuesta enviada con éxito!'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(); // Cierra el diálogo
      Navigator.of(context).pushNamed('/intercambios'); // Redirige a Mis Intercambios
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Error al enviar la propuesta'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tienePuntosSuficientes = _puntosUsuario >= widget.productoSolicitado.puntosNecesarios;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Proponer Intercambio', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPuntosCard(context, tienePuntosSuficientes),
                          const SizedBox(height: 16),
                          const Text('Producto que solicitas:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _buildProductoCard(widget.productoSolicitado),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.send_rounded),
                              label: Text('Solicitar por ${widget.productoSolicitado.puntosNecesarios} puntos'),
                              onPressed: tienePuntosSuficientes ? _enviarSolicitudYRedirigir : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                disabledBackgroundColor: Colors.grey.shade300,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              tienePuntosSuficientes
                                ? "Se notificará al propietario. Podrás ver el estado en \"Mis Intercambios\"."
                                : "No tienes puntos suficientes para realizar esta solicitud.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          )
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPuntosCard(BuildContext context, bool tieneSuficientes) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tieneSuficientes ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tieneSuficientes ? Colors.green : Colors.red),
      ),
      child: Row(children: [
        Icon(tieneSuficientes ? Icons.check_circle : Icons.warning, color: tieneSuficientes ? Colors.green : Colors.red),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tus puntos: $_puntosUsuario', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text(tieneSuficientes ? '¡Tienes puntos suficientes!' : 'Necesitas ${widget.productoSolicitado.puntosNecesarios} puntos', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ])),
        TextButton(onPressed: () => Navigator.pushNamed(context, '/intercambios'), child: const Text('Ver mis intercambios')),
      ]),
    );
  }

  Widget _buildProductoCard(ProductoUnificado producto) {
    final imageUrl = (producto.imageUrls.isNotEmpty) ? producto.imageUrls[0] : null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8), image: imageUrl != null ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null), child: imageUrl == null ? const Icon(Icons.image, color: Colors.grey) : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(producto.nombre, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(producto.categoria, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)), child: Text('${producto.puntosNecesarios} pts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
      ]),
    );
  }
}
