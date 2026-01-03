import 'package:flutter/material.dart';
import '../services/puntos_service.dart';
import '../services/supabase_service.dart';

class MisIntercambiosScreen extends StatefulWidget {
  const MisIntercambiosScreen({Key? key}) : super(key: key);

  @override
  State<MisIntercambiosScreen> createState() => _MisIntercambiosScreenState();
}

class _MisIntercambiosScreenState extends State<MisIntercambiosScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _intercambios = [];
  List<dynamic> _pendientes = [];
  bool _isLoading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userId = SupabaseService.getCurrentAuthUser()?.id;
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    // Cargar todos mis intercambios
    final intercambiosResult = await PuntosService.getMisIntercambios();
    if (intercambiosResult['success']) {
      _intercambios = intercambiosResult['data'];
    }

    // Cargar intercambios pendientes (propuestas recibidas)
    final pendientesResult = await PuntosService.getIntercambiosPendientes();
    if (pendientesResult['success']) {
      _pendientes = pendientesResult['data'];
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Intercambios'),
        backgroundColor: Colors.green,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.swap_horiz),
              text: 'Mis Intercambios (${_intercambios.length})',
            ),
            Tab(
              icon: const Icon(Icons.notifications),
              text: 'Pendientes (${_pendientes.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMisIntercambios(),
                _buildPendientes(),
              ],
            ),
    );
  }

  Widget _buildMisIntercambios() {
    if (_intercambios.isEmpty) {
      return _buildEmptyState(
        icon: Icons.swap_horiz,
        message: 'No tienes intercambios',
        subtitle: 'Propón un intercambio para comenzar',
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _intercambios.length,
        itemBuilder: (context, index) {
          final intercambio = _intercambios[index];
          return _buildIntercambioCard(intercambio);
        },
      ),
    );
  }

  Widget _buildPendientes() {
    if (_pendientes.isEmpty) {
      return _buildEmptyState(
        icon: Icons.inbox,
        message: 'No tienes propuestas pendientes',
        subtitle: 'Aquí aparecerán las propuestas que recibas',
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendientes.length,
        itemBuilder: (context, index) {
          final intercambio = _pendientes[index];
          return _buildPropuestaCard(intercambio);
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntercambioCard(Map<String, dynamic> intercambio) {
    final estado = intercambio['estado'] as String;
    final esOfertante = intercambio['usuario_ofertante_id'] == _userId;
    
    final productoMio = esOfertante
        ? intercambio['producto_ofertado']
        : intercambio['producto_solicitado'];
    final productoOtro = esOfertante
        ? intercambio['producto_solicitado']
        : intercambio['producto_ofertado'];
    
    final otroUsuario = esOfertante
        ? intercambio['usuario_receptor']
        : intercambio['usuario_ofertante'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado
            _buildEstadoChip(estado),
            const SizedBox(height: 12),
            
            // Productos
            Row(
              children: [
                Expanded(child: _buildProductoMini(productoMio, 'Tu producto')),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.swap_horiz, color: Colors.green, size: 32),
                ),
                Expanded(child: _buildProductoMini(productoOtro, 'Recibes')),
              ],
            ),
            
            const Divider(height: 24),
            
            // Usuario
            Row(
              children: [
                const Icon(Icons.person, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  otroUsuario['name'] ?? 'Usuario',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Acciones según estado
            _buildAcciones(intercambio, esOfertante),
          ],
        ),
      ),
    );
  }

  Widget _buildPropuestaCard(Map<String, dynamic> intercambio) {
    final productoOfertado = intercambio['producto_ofertado'];
    final productoSolicitado = intercambio['producto_solicitado'];
    final usuarioOfertante = intercambio['usuario_ofertante'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.shade300, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_active, 
                           size: 16, 
                           color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Nueva Propuesta',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Text(
              '${usuarioOfertante['name']} quiere intercambiar:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildProductoMini(productoOfertado, 'Te ofrece'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.swap_horiz, color: Colors.orange, size: 32),
                ),
                Expanded(
                  child: _buildProductoMini(productoSolicitado, 'Por tu'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rechazarIntercambio(intercambio['id']),
                    icon: const Icon(Icons.close),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _aceptarIntercambio(intercambio['id']),
                    icon: const Icon(Icons.check),
                    label: const Text('Aceptar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductoMini(Map<String, dynamic> producto, String label) {
    final imageUrls = producto['image_urls'] as List?;
    final imageUrl = (imageUrls != null && imageUrls.isNotEmpty)
        ? imageUrls[0]
        : null;

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            image: imageUrl != null
                ? DecorationImage(
                    image: NetworkImage(imageUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: imageUrl == null
              ? const Icon(Icons.image, size: 40, color: Colors.grey)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          producto['nombre'] ?? 'Producto',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          '${producto['puntos_necesarios']} pts',
          style: TextStyle(
            fontSize: 11,
            color: Colors.green.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEstadoChip(String estado) {
    Color color;
    String texto;
    IconData icon;

    switch (estado) {
      case 'propuesto':
        color = Colors.orange;
        texto = 'Propuesto';
        icon = Icons.schedule;
        break;
      case 'aceptado':
        color = Colors.blue;
        texto = 'Aceptado';
        icon = Icons.handshake;
        break;
      case 'completado':
        color = Colors.green;
        texto = 'Completado';
        icon = Icons.check_circle;
        break;
      case 'rechazado':
        color = Colors.red;
        texto = 'Rechazado';
        icon = Icons.cancel;
        break;
      case 'cancelado':
        color = Colors.grey;
        texto = 'Cancelado';
        icon = Icons.block;
        break;
      default:
        color = Colors.grey;
        texto = estado;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcciones(Map<String, dynamic> intercambio, bool esOfertante) {
    final estado = intercambio['estado'] as String;
    final intercambioId = intercambio['id'] as String;

    if (estado == 'aceptado') {
      final confirmado = esOfertante
          ? intercambio['confirmado_por_ofertante']
          : intercambio['confirmado_por_receptor'];

      if (confirmado == true) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Has confirmado el intercambio. Esperando confirmación del otro usuario.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      }

      return ElevatedButton.icon(
        onPressed: () => _confirmarIntercambio(intercambioId, esOfertante),
        icon: const Icon(Icons.check_circle),
        label: const Text('Confirmar Intercambio Realizado'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 44),
        ),
      );
    }

    if (estado == 'completado') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.celebration, color: Colors.green.shade700),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '¡Intercambio completado! Ambos recibieron 3 puntos bonus.',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _aceptarIntercambio(String intercambioId) async {
    final result = await PuntosService.aceptarIntercambio(intercambioId);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );

    if (result['success']) {
      _cargarDatos();
    }
  }

  Future<void> _rechazarIntercambio(String intercambioId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar Intercambio'),
        content: const Text('¿Estás seguro de que quieres rechazar esta propuesta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await PuntosService.rechazarIntercambio(intercambioId);
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
      ),
    );

    if (result['success']) {
      _cargarDatos();
    }
  }

  Future<void> _confirmarIntercambio(String intercambioId, bool esOfertante) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Intercambio'),
        content: const Text(
          '¿Confirmas que el intercambio se realizó exitosamente?\n\n'
          'Una vez que ambos usuarios confirmen, se otorgarán los puntos correspondientes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final result = await PuntosService.confirmarIntercambio(
      intercambioId: intercambioId,
      esOfertante: esOfertante,
    );
    
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']),
        backgroundColor: result['success'] ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );

    if (result['success']) {
      _cargarDatos();
    }
  }
}
