import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../modelo/intercambio.dart';
import '../services/intercambio_service.dart';

class IntercambioCard extends StatefulWidget {
  final Intercambio intercambio;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;
  final bool showActions;

  const IntercambioCard({
    super.key,
    required this.intercambio,
    this.onTap,
    this.onRefresh,
    this.showActions = false,
  });

  @override
  State<IntercambioCard> createState() => _IntercambioCardState();
}

class _IntercambioCardState extends State<IntercambioCard> {
  final IntercambioService _intercambioService = IntercambioService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('es', timeago.EsMessages());
  }

  Future<void> _aceptarIntercambio() async {
    setState(() => _isLoading = true);
    
    try {
      await _intercambioService.aceptarIntercambio(widget.intercambio.idIntercambio);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Intercambio aceptado'),
          backgroundColor: Colors.green,
        ),
      );
      
      widget.onRefresh?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _rechazarIntercambio() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar Intercambio'),
        content: const Text('¿Estás seguro de que quieres rechazar esta propuesta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    setState(() => _isLoading = true);
    
    try {
      await _intercambioService.rechazarIntercambio(widget.intercambio.idIntercambio);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Intercambio rechazado'),
          backgroundColor: Colors.orange,
        ),
      );
      
      widget.onRefresh?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getEstadoColor() {
    switch (widget.intercambio.estado) {
      case EstadoIntercambio.pendiente:
        return Colors.orange;
      case EstadoIntercambio.aceptado:
        return Colors.blue;
      case EstadoIntercambio.completado:
        return Colors.green;
      case EstadoIntercambio.rechazado:
        return Colors.red;
      case EstadoIntercambio.cancelado:
        return Colors.grey;
    }
  }

  IconData _getEstadoIcon() {
    switch (widget.intercambio.estado) {
      case EstadoIntercambio.pendiente:
        return Icons.pending;
      case EstadoIntercambio.aceptado:
        return Icons.check_circle;
      case EstadoIntercambio.completado:
        return Icons.done_all;
      case EstadoIntercambio.rechazado:
        return Icons.cancel;
      case EstadoIntercambio.cancelado:
        return Icons.block;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoColor = _getEstadoColor();
    final estadoIcon = _getEstadoIcon();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con estado e ID
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: estadoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: estadoColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(estadoIcon, size: 16, color: estadoColor),
                        const SizedBox(width: 4),
                        Text(
                          widget.intercambio.estado.value.toUpperCase(),
                          style: TextStyle(
                            color: estadoColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '#${widget.intercambio.idIntercambio}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Información principal
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Artículo: ${widget.intercambio.idArticuloOld}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Con: ${widget.intercambio.idUsuarioRecibido.substring(0, 8)}...',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        timeago.format(widget.intercambio.fechaIntercambio, locale: 'es'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      if (widget.intercambio.codigoVerificacion != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.intercambio.codigoVerificacion!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              // Detalles del intercambio
              if (widget.intercambio.idProductoOfertado != null ||
                  widget.intercambio.puntosProductoOfertado != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.intercambio.idProductoOfertado != null)
                              Text(
                                'Producto: ${widget.intercambio.idProductoOfertado!.substring(0, 8)}...',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (widget.intercambio.puntosProductoOfertado != null)
                              Text(
                                'Puntos: ${widget.intercambio.puntosProductoOfertado}',
                                style: const TextStyle(fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Progreso de confirmaciones
              if (widget.intercambio.estaAceptado) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildConfirmacionIndicador(
                        'Ofertante',
                        widget.intercambio.confirmadoPorOfertante ?? false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildConfirmacionIndicador(
                        'Receptor',
                        widget.intercambio.confirmadoPorReceptor ?? false,
                      ),
                    ),
                  ],
                ),
              ],
              
              // Acciones rápidas
              if (widget.showActions && widget.intercambio.estaPendiente) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _aceptarIntercambio,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Aceptar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _rechazarIntercambio,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Rechazar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              
              // Indicador de carga
              if (_isLoading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmacionIndicador(String label, bool confirmado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: confirmado ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: confirmado ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confirmado ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: confirmado ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: confirmado ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}