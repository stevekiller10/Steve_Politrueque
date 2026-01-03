import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trueque/modelo/user.model.dart';
import '../modelo/producto_unificado_model.dart';
import '../services/productos_unificados_service.dart';

class ApprovalScreen extends StatefulWidget {
  final UserModel currentUser;
  const ApprovalScreen({super.key, required this.currentUser});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ProductoUnificado> _productosPendientes = [];
  List<ProductoUnificado> _productosRechazados = [];
  List<ProductoUnificado> _productosEliminados = [];
  bool _isLoading = true;
  int _tabCount = 2;

  @override
  void initState() {
    super.initState();
    _setupTabs();
    _loadAllData();
  }

  void _setupTabs() {
    // Determinar número de tabs según el rol del usuario
    if (_isAdmin()) {
      _tabCount = 3; // Pendientes, Rechazados, Eliminados
    } else if (_isAdminOrModerator()) {
      _tabCount = 2; // Pendientes, Rechazados
    } else {
      _tabCount = 1; // Solo Pendientes (aunque no debería llegar aquí)
    }
    _tabController = TabController(length: _tabCount, vsync: this);
  }

  bool _isAdminOrModerator() {
    final role = widget.currentUser.rol.toLowerCase();
    return role == 'admin' || role == 'administrador' || role == 'moderador';
  }

  bool _isAdmin() {
    final role = widget.currentUser.rol.toLowerCase();
    return role == 'admin' || role == 'administrador';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    try {
      // Cargar productos pendientes
      final pendientesResult = await ProductosUnificadosService.getProductosPendientes();
      
      // Cargar productos rechazados si es moderador o admin
      Map<String, dynamic>? rechazadosResult;
      if (_isAdminOrModerator()) {
        rechazadosResult = await _getProductosPorEstado('rechazado');
      }
      
      // Cargar productos eliminados si es admin
      Map<String, dynamic>? eliminadosResult;
      if (_isAdmin()) {
        eliminadosResult = await _getProductosEliminados();
      }
      
      if (mounted) {
        setState(() {
          // Productos pendientes
          if (pendientesResult['success']) {
            final data = pendientesResult['data'] as List;
            _productosPendientes = data.map((item) => ProductoUnificado.fromJson(item)).toList();
          }
          
          // Productos rechazados
          if (rechazadosResult != null && rechazadosResult['success']) {
            final data = rechazadosResult['data'] as List;
            _productosRechazados = data.map((item) {
              // Convertir Map a ProductoUnificado
              if (item is Map<String, dynamic>) {
                return ProductoUnificado.fromJson(item);
              }
              return item as ProductoUnificado;
            }).toList();
          }
          
          // Productos eliminados
          if (eliminadosResult != null && eliminadosResult['success']) {
            final data = eliminadosResult['data'] as List;
            _productosEliminados = data.map((item) {
              // Convertir Map a ProductoUnificado
              if (item is Map<String, dynamic>) {
                return ProductoUnificado.fromJson(item);
              }
              return item as ProductoUnificado;
            }).toList();
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _getProductosPorEstado(String estado) async {
    try {
      // Usar Supabase directamente como en objects_screen.dart
      final response = await Supabase.instance.client
          .from('productos_unificados')
          .select()
          .eq('estado_aprobacion', estado)
          .order('creado_en', ascending: false);
      
      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al obtener productos $estado: $e',
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> _getProductosEliminados() async {
    try {
      // Usar Supabase directamente como en objects_screen.dart
      final response = await Supabase.instance.client
          .from('productos_unificados')
          .select()
          .eq('eliminado', true)
          .order('updated_at', ascending: false);
      
      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al obtener productos eliminados: $e',
        'data': [],
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[100]!,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              
              // TabBar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFFEF233C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFFEF233C),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  isScrollable: false,
                  tabAlignment: TabAlignment.fill,
                  tabs: _buildTabs(),
                ),
              ),
              
              // Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          margin: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  shape: BoxShape.circle,
                                ),
                                child: const CircularProgressIndicator(
                                  color: Colors.blue,
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Cargando datos de moderación...',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Por favor espera un momento',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: _buildTabViews(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTabs() {
    List<Widget> tabs = [
      Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pending, size: 16),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'Pendientes (${_productosPendientes.length})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ];

    if (_isAdminOrModerator()) {
      tabs.add(
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cancel, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Rechazados (${_productosRechazados.length})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isAdmin()) {
      tabs.add(
        Tab(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Eliminados (${_productosEliminados.length})',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return tabs;
  }

  List<Widget> _buildTabViews() {
    List<Widget> views = [
      _buildProductosPendientes(),
    ];

    if (_isAdminOrModerator()) {
      views.add(_buildProductosRechazados());
    }

    if (_isAdmin()) {
      views.add(_buildProductosEliminados());
    }

    return views;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.5),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 4,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.arrow_back, color: Color(0xFFEF233C)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, color: Color(0xFFEF233C), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Revisión de Objetos',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: const Color(0xFFEF233C),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (_productosPendientes.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF233C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_productosPendientes.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductosPendientes() {
    if (_productosPendientes.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'No hay objetos pendientes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Todos los objetos han sido revisados',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _productosPendientes.length,
        itemBuilder: (context, index) {
          final producto = _productosPendientes[index];
          return _buildProductoCard(producto, showActions: true);
        },
      ),
    );
  }

  Widget _buildProductosRechazados() {
    if (_productosRechazados.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'No hay objetos rechazados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Los objetos rechazados aparecerán aquí',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _productosRechazados.length,
        itemBuilder: (context, index) {
          final producto = _productosRechazados[index];
          return _buildProductoCard(producto, showActions: false, isRejected: true);
        },
      ),
    );
  }

  Widget _buildProductosEliminados() {
    if (_productosEliminados.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'No hay objetos eliminados',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Los objetos eliminados aparecerán aquí',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _productosEliminados.length,
        itemBuilder: (context, index) {
          final producto = _productosEliminados[index];
          return _buildProductoCard(producto, showActions: false, isDeleted: true);
        },
      ),
    );
  }

  Widget _buildProductoCard(ProductoUnificado producto, {bool showActions = false, bool isRejected = false, bool isDeleted = false}) {
    final primeraImagen = producto.imageUrls.isNotEmpty ? producto.imageUrls.first : null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
          if (primeraImagen != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                primeraImagen,
                height: 200,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported, size: 64, color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(Icons.image, size: 64, color: Colors.grey),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre y Estado Físico
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        producto.nombre,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getEstadoColor(producto.estadoFisico).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        producto.getEstadoFisicoLabel(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getEstadoColor(producto.estadoFisico),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Descripción
                Text(
                  producto.descripcion,
                  style: TextStyle(color: Colors.grey[700]),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 12),

                // Información del producto
                Row(
                  children: [
                    _buildInfoChip(
                      Icons.category,
                      producto.categoria,
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildInfoChip(
                      Icons.stars,
                      producto.getPuntosLabel(),
                      Colors.orange,
                    ),
                  ],
                ),

                if (producto.ubicacion != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          producto.ubicacion!,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Número de imágenes
                if (producto.imageUrls.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library, size: 16, color: Colors.purple),
                        const SizedBox(width: 4),
                        Text(
                          '${producto.imageUrls.length} imágenes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Fecha
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Enviado: ${_formatDate(producto.creadoEn)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Botones de acción (solo para productos pendientes)
                if (showActions) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRejectDialog(producto),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.cancel, color: Colors.white, size: 18),
                          label: const Text(
                            'Rechazar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showApproveDialog(producto),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                          label: const Text(
                            'Aprobar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Badge de estado para productos rechazados o eliminados
                if (isRejected) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cancel, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Producto Rechazado',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (isDeleted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.delete, color: Colors.grey, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Producto Eliminado',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'nuevo':
        return Colors.green;
      case 'como_nuevo':
        return Colors.lightGreen;
      case 'buen_estado':
        return Colors.blue;
      case 'usado':
        return Colors.orange;
      case 'para_reparar':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showApproveDialog(ProductoUnificado producto) {
    int puntosFinales = producto.puntosNecesarios;
    bool puntosConfirmados = false;
    String categoriaFinal = producto.categoria;
    bool categoriaConfirmada = false;
    final screenContext = context; // Guardar referencia al contexto de la pantalla

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Aprobar producto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Producto: "${producto.nombre}"',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Categoría: ${producto.categoria}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estado físico: ${producto.getEstadoFisicoLabel()}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                
                // Puntos actuales/finales
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: puntosConfirmados 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: puntosConfirmados 
                        ? Border.all(color: Colors.green, width: 2)
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        puntosConfirmados ? Icons.check_circle : Icons.stars, 
                        color: puntosConfirmados ? Colors.green : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          puntosConfirmados 
                              ? 'Puntos confirmados: $puntosFinales'
                              : 'Puntos asignados: ${producto.puntosNecesarios}',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  '¿Ajustar puntos? (opcional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Si los puntos no coinciden con el estado del producto, puedes ajustarlos:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                
                // Opciones de puntos
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OpcionesPuntos.opciones.map((opcion) {
                    final puntos = opcion['value'] as int;
                    final isSelected = puntosFinales == puntos;
                    
                    return ChoiceChip(
                      label: Text(
                        '$puntos pts',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: Colors.orange,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            puntosFinales = puntos;
                            puntosConfirmados = false; // Resetear confirmación al cambiar
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                
                // Mostrar cambio de puntos
                if (puntosFinales != producto.puntosNecesarios) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cambio de puntos: ${producto.puntosNecesarios} → $puntosFinales',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[900],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!puntosConfirmados) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  puntosConfirmados = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(Icons.check, color: Colors.white, size: 18),
                              label: Text(
                                'Confirmar cambio de puntos',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                
                // Separador
                const SizedBox(height: 24),
                Divider(color: Colors.grey[300]),
                const SizedBox(height: 16),
                
                // Sección de Categoría
                Text(
                  '¿Ajustar categoría? (opcional)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Si la categoría no es correcta, puedes cambiarla:',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                
                // Opciones de categoría
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: Categorias.lista.map((cat) {
                    final isSelected = categoriaFinal == cat;
                    
                    return ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: Colors.purple,
                      onSelected: (selected) {
                        setDialogState(() {
                          if (selected) {
                            categoriaFinal = cat;
                            categoriaConfirmada = false; // Resetear confirmación al cambiar
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                
                // Mostrar cambio de categoría
                if (categoriaFinal != producto.categoria) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.purple, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cambio de categoría: ${producto.categoria} → $categoriaFinal',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple[900],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!categoriaConfirmada) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  categoriaConfirmada = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(Icons.check, color: Colors.white, size: 18),
                              label: Text(
                                'Confirmar cambio de categoría',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: ((puntosFinales != producto.puntosNecesarios && !puntosConfirmados) ||
                         (categoriaFinal != producto.categoria && !categoriaConfirmada))
                  ? null // Deshabilitar si hay cambios sin confirmar
                  : () async {
                      Navigator.pop(dialogContext);
                      
                      final puntosAjustados = puntosFinales != producto.puntosNecesarios 
                          ? puntosFinales 
                          : null;
                      
                      final categoriaAjustada = categoriaFinal != producto.categoria
                          ? categoriaFinal
                          : null;
                      
                      print('🔍 DEBUG: Aprobando producto ${producto.id}');
                      print('🔍 DEBUG: Puntos originales: ${producto.puntosNecesarios}');
                      print('🔍 DEBUG: Puntos finales: $puntosFinales');
                      print('🔍 DEBUG: Puntos ajustados a enviar: $puntosAjustados');
                      print('🔍 DEBUG: Categoría original: ${producto.categoria}');
                      print('🔍 DEBUG: Categoría final: $categoriaFinal');
                      print('🔍 DEBUG: Categoría ajustada a enviar: $categoriaAjustada');
                      
                      final result = await ProductosUnificadosService.aprobarProducto(
                        producto.id,
                        puntosAjustados: puntosAjustados,
                        categoriaAjustada: categoriaAjustada,
                      );
                      
                      print('🔍 DEBUG: Resultado: ${result['success']}');
                      
                      if (!mounted) {
                        print('🔍 DEBUG: Widget no montado, no se puede actualizar');
                        return;
                      }
                      
                      print('🔍 DEBUG: Mostrando SnackBar');
                      
                      String mensaje = '✅ Producto aprobado';
                      if (result['success']) {
                        List<String> cambios = [];
                        if (puntosAjustados != null) {
                          cambios.add('$puntosFinales puntos');
                        }
                        if (categoriaAjustada != null) {
                          cambios.add('categoría: $categoriaFinal');
                        }
                        if (cambios.isNotEmpty) {
                          mensaje = '✅ Producto aprobado con ${cambios.join(', ')}';
                        }
                      } else {
                        mensaje = '❌ ${result['message']}';
                      }
                      
                      ScaffoldMessenger.of(screenContext).showSnackBar(
                        SnackBar(
                          content: Text(mensaje),
                          backgroundColor: result['success'] ? Colors.green : const Color(0xFFEF233C),
                          duration: Duration(seconds: 3),
                        ),
                      );
                      
                      if (result['success']) {
                        print('🔍 DEBUG: Removiendo producto ${producto.id} de la lista');
                        print('🔍 DEBUG: Lista antes: ${_productosPendientes.length} productos');
                        
                        // Remover el producto de la lista inmediatamente
                        setState(() {
                          _productosPendientes.removeWhere((p) => p.id == producto.id);
                        });
                        
                        print('🔍 DEBUG: Lista después: ${_productosPendientes.length} productos');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Aprobar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(ProductoUnificado producto) {
    final motivoController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final screenContext = context; // Guardar referencia al contexto de la pantalla

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Rechazar producto',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Producto: "${producto.nombre}"',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Text(
                'Motivo del rechazo:',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: motivoController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Explica por qué rechazas este producto...',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => v == null || v.trim().isEmpty 
                    ? 'Debes proporcionar un motivo' 
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Motivos comunes:',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMotivoChip('Imágenes de baja calidad', motivoController),
                  _buildMotivoChip('Descripción incompleta', motivoController),
                  _buildMotivoChip('Estado no coincide', motivoController),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext);
                
                final result = await ProductosUnificadosService.rechazarProducto(
                  producto.id,
                  motivoController.text.trim(),
                );
                
                if (!mounted) {
                  print('🔍 DEBUG: Widget no montado, no se puede actualizar');
                  return;
                }
                
                print('🔍 DEBUG: Mostrando SnackBar de rechazo');
                ScaffoldMessenger.of(screenContext).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['success'] ? '✅ Producto rechazado' : '❌ ${result['message']}',
                    ),
                    backgroundColor: result['success'] ? Colors.orange : const Color(0xFFEF233C),
                    duration: Duration(seconds: 2),
                  ),
                );
                
                if (result['success']) {
                  print('🔍 DEBUG: Removiendo producto rechazado ${producto.id}');
                  print('🔍 DEBUG: Lista antes: ${_productosPendientes.length} productos');
                  
                  // Remover el producto de la lista inmediatamente
                  setState(() {
                    _productosPendientes.removeWhere((p) => p.id == producto.id);
                  });
                  
                  print('🔍 DEBUG: Lista después: ${_productosPendientes.length} productos');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Rechazar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivoChip(String motivo, TextEditingController controller) {
    return InkWell(
      onTap: () => controller.text = motivo,
      child: Chip(
        label: Text(
          motivo,
          style: TextStyle(fontSize: 11),
        ),
        backgroundColor: Colors.grey[200],
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
