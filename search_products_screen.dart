import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/chat_service.dart';
import '../services/notificaciones_service.dart';
import '../screens/chat_screen.dart';

class SearchProductsScreen extends StatefulWidget {
  const SearchProductsScreen({super.key});

  @override
  State<SearchProductsScreen> createState() => _SearchProductsScreenState();
}

class _SearchProductsScreenState extends State<SearchProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _productos = [];
  final Map<String, Map<String, dynamic>> _usuariosInfo = {};
  bool _isLoading = false;
  bool _hasSearched = false;
  String _selectedCategory = 'Todos';
  String _ordenarPor = 'recientes';

  final List<Map<String, dynamic>> _categories = const [
    {'id': 'Todos', 'name': 'Todos', 'icon': Icons.apps, 'color': Color(0xFFEF233C)},
    {'id': 'Electrónicos', 'name': 'Electrónicos', 'icon': Icons.phone_android, 'color': Color(0xFFEF233C)},
    {'id': 'Comida', 'name': 'Comida', 'icon': Icons.restaurant, 'color': Color(0xFFD90429)},
    {'id': 'Ropa', 'name': 'Ropa', 'icon': Icons.checkroom, 'color': Color(0xFFC1121F)},
    {'id': 'Útiles Escolares', 'name': 'Útiles Escolares', 'icon': Icons.school, 'color': Color(0xFFB91C1C)},
    {'id': 'Deportes', 'name': 'Deportes', 'icon': Icons.sports_soccer, 'color': Color(0xFF991B1B)},
    {'id': 'Hogar', 'name': 'Hogar', 'icon': Icons.home, 'color': Color(0xFF8D0801)},
    {'id': 'Otros', 'name': 'Otros', 'icon': Icons.toys, 'color': Color(0xFFDC2626)},
  ];

  String? _errorMessage;

  // Helper para obtener tonos de color
  Color _getColorShade(Color color, int shade) {
    if (color == Colors.blue) return Colors.blue.shade700;
    if (color == Colors.green) return Colors.green.shade700;
    if (color == Colors.amber) return Colors.amber.shade700;
    if (color == Colors.red) return Colors.red.shade700;
    return color;
  }

  Future<void> _cargarInfoUsuarios(Set<String> usuariosIds) async {
    for (final userId in usuariosIds) {
      if (!_usuariosInfo.containsKey(userId)) {
        try {
          final result = await SupabaseService.getUserById(userId);
          if (result['success']) {
            _usuariosInfo[userId] = result['data'];
          }
        } catch (e) {
          // Si falla, usar datos por defecto
          _usuariosInfo[userId] = {
            'name': 'Usuario desconocido',
            'email': 'N/A',
          };
        }
      }
    }
  }

  Future<void> _buscarProductos() async {
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      // Obtener todos los productos disponibles
      final result = await SupabaseService.getObjetosDisponibles();

      if (result['success']) {
        List<Map<String, dynamic>> productos = List<Map<String, dynamic>>.from(result['data'] ?? []);

        // Filtrar por texto de búsqueda
        final searchText = _searchController.text.trim().toLowerCase();
        if (searchText.isNotEmpty) {
          productos = productos.where((p) {
            final nombre = (p['nombre'] ?? '').toString().toLowerCase();
            final descripcion = (p['descripcion'] ?? '').toString().toLowerCase();
            return nombre.contains(searchText) || descripcion.contains(searchText);
          }).toList();
        }

        // Filtrar por categoría si no es "Todos"
        if (_selectedCategory != 'Todos') {
          productos = productos.where((p) => p['categoria'] == _selectedCategory).toList();
        }

        // Ordenar productos
        _ordenarProductos(productos);

        // Cargar información de usuarios
        final usuariosIds = productos
            .map((p) => p['usuario_id'] as String?)
            .where((id) => id != null)
            .toSet();

        await _cargarInfoUsuarios(usuariosIds.cast<String>());

        setState(() {
          _productos = productos;
          _isLoading = false;
        });
      } else {
        setState(() {
          _productos = [];
          _isLoading = false;
          _errorMessage = result['message'] ?? 'Error al obtener productos';
        });
      }
    } catch (e) {
      setState(() {
        _productos = [];
        _isLoading = false;
        _errorMessage = 'Error de conexión: $e';
      });
    }
  }

  void _ordenarProductos(List<Map<String, dynamic>> productos) {
    switch (_ordenarPor) {
      case 'recientes':
        productos.sort((a, b) => DateTime.parse(b['creado_en']).compareTo(DateTime.parse(a['creado_en'])));
        break;
      case 'puntos_asc':
        productos.sort((a, b) => (a['puntos_necesarios'] ?? 0).compareTo(b['puntos_necesarios'] ?? 0));
        break;
      case 'puntos_desc':
        productos.sort((a, b) => (b['puntos_necesarios'] ?? 0).compareTo(a['puntos_necesarios'] ?? 0));
        break;
      case 'nombre':
        productos.sort((a, b) => (a['nombre'] ?? '').compareTo(b['nombre'] ?? ''));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedCategory == 'Todos' ? 'Buscar Productos' : _selectedCategory,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFFEF233C),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort, color: Colors.white),
            onSelected: (value) {
              setState(() => _ordenarPor = value);
              if (_hasSearched) _buscarProductos();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'recientes', child: Text('Más recientes')),
              const PopupMenuItem(value: 'puntos_asc', child: Text('Menos puntos')),
              const PopupMenuItem(value: 'puntos_desc', child: Text('Más puntos')),
              const PopupMenuItem(value: 'nombre', child: Text('Por nombre')),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEF233C),
              Color(0xCCEF233C),
              Colors.white
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con buscador
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Qué estás buscando?',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Encuentra el producto perfecto para ti',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Barra de búsqueda
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.poppins(),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre...',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFEF233C)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _productos = [];
                                _hasSearched = false;
                              });
                            },
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        onSubmitted: (_) => _buscarProductos(),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Botón de búsqueda
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _buscarProductos,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFFEF233C),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'Buscar',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Contenido
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filtro por categoría
                        Text(
                          'Filtrar por categoría',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFEF233C),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final category = _categories[index];
                              final isSelected = _selectedCategory == category['id'];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 100),
                                    child: Text(
                                      category['name'] as String,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: isSelected ? Colors.white : Colors.grey[700],
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  avatar: isSelected ? null : Icon(
                                    category['icon'] as IconData,
                                    size: 16,
                                    color: category['color'] as Color,
                                  ),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedCategory = category['id'] as String;
                                    });
                                    // Siempre buscar cuando se selecciona una categoría
                                    _buscarProductos();
                                  },
                                  selectedColor: const Color(0xFFEF233C),
                                  backgroundColor: Colors.grey[100],
                                  checkmarkColor: Colors.white,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Resultados
                        Expanded(
                          child: _buildResultados(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultados() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFEF233C),
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Busca productos por nombre',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'o filtra por categoría',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Error en la búsqueda',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.red[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.red[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _buscarProductos,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF233C),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Reintentar',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
      );
    }

    if (_productos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No se encontraron productos',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con otra búsqueda',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_productos.length} producto${_productos.length != 1 ? 's' : ''} encontrado${_productos.length != 1 ? 's' : ''}',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75, // Ajuste para mejorar la proporción
            ),
            itemCount: _productos.length,
            itemBuilder: (context, index) {
              final producto = _productos[index];
              return _buildProductoCard(producto);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductoCard(Map<String, dynamic> producto) {
    final imageUrls = producto['image_urls'] as List?;
    final imageUrl = (imageUrls != null && imageUrls.isNotEmpty) ? imageUrls[0] : null;
    final usuarioInfo = _usuariosInfo[producto['usuario_id']];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _mostrarDetalleProducto(producto, usuarioInfo),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Container(
                  color: Colors.grey[200],
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.image_not_supported, color: Colors.grey);
                          },
                        )
                      : const Icon(Icons.image, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto['nombre'] ?? 'Sin nombre',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (usuarioInfo != null)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: const Color(0xFFEF233C),
                          child: Text(
                            (usuarioInfo['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            usuarioInfo['name'] ?? 'Usuario desconocido',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _buildTag(
                        '${producto['puntos_necesarios'] ?? 0} pts',
                        Colors.amber,
                      ),
                       _buildTag(
                        producto['categoria'] ?? 'Sin categoría',
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _comprarProducto(producto, usuarioInfo),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF233C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text('Intercambiar', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: _getColorShade(color, 700),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getEstadoFisicoLabel(String? estadoFisico) {
    switch (estadoFisico) {
      case 'nuevo':
        return 'Nuevo';
      case 'como_nuevo':
        return 'Como nuevo';
      case 'buen_estado':
        return 'Buen estado';
      case 'usado':
        return 'Usado';
      case 'para_reparar':
        return 'Para reparar';
      default:
        return estadoFisico ?? 'Sin estado';
    }
  }

  void _mostrarDetalleProducto(Map<String, dynamic> producto, Map<String, dynamic>? usuarioInfo) {
    // Implementación simplificada del modal de detalle
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(producto['nombre'] ?? 'Producto'),
        content: Text(producto['descripcion'] ?? 'Sin descripción'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _comprarProducto(producto, usuarioInfo);
            },
            child: const Text('Intercambiar'),
          ),
        ],
      ),
    );
  }

  void _comprarProducto(Map<String, dynamic> producto, Map<String, dynamic>? usuarioInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 50,
                height: 50,
                color: Colors.grey[200],
                child: (producto['image_urls'] as List?)?.isNotEmpty == true
                    ? Image.network(
                  producto['image_urls'][0],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image_not_supported, color: Colors.grey);
                  },
                )
                    : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto['nombre'] ?? 'Sin nombre',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (producto['puntos_necesarios'] != null)
                    Row(
                      children: [
                        const Icon(Icons.stars, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          '${producto['puntos_necesarios']} puntos',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.amber[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿Confirmas el intercambio?',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Se descontarán ${producto['puntos_necesarios'] ?? 0} puntos de tu cuenta',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => _confirmarCompraProducto(producto),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF233C),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Confirmar Intercambio',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarCompraProducto(Map<String, dynamic> producto) async {
    Navigator.pop(context);

    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFEF233C),
        ),
      ),
    );

    try {
      // Obtener ID del usuario actual desde Supabase
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      // Verificar puntos del usuario actual
      final puntosResult = await SupabaseService.getUserById(currentUser.id);

      if (mounted) {
        Navigator.pop(context); // Cerrar loading

        if (puntosResult['success']) {
          final puntosActuales = puntosResult['data']['puntos'] ?? 0;
          final puntosNecesarios = producto['puntos_necesarios'] ?? 0;

          if (puntosActuales >= puntosNecesarios) {
            // Tiene suficientes puntos, proceder con el intercambio
            _procesarIntercambioProducto(producto, puntosActuales, puntosNecesarios);
          } else {
            // No tiene suficientes puntos
            _mostrarErrorPuntos(puntosActuales, puntosNecesarios);
          }
        } else {
          _mostrarErrorGeneral('Error al verificar tus puntos');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        _mostrarErrorGeneral('Error de conexión: $e');
      }
    }
  }

  void _procesarIntercambioProducto(Map<String, dynamic> producto, int puntosActuales, int puntosNecesarios) async {
    // Mostrar loading para obtener información del usuario
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFEF233C),
        ),
      ),
    );

    try {
      // Obtener información del usuario dueño del producto
      final userResult = await SupabaseService.getUserById(producto['usuario_id']);

      if (mounted) {
        Navigator.pop(context); // Cerrar loading

        if (userResult['success']) {
          final userData = userResult['data'];
          final userName = userData['name'] ?? 'Usuario';

          // Mostrar diálogo de confirmación antes de ir al chat
          _mostrarConfirmacionIntercambioProducto(
            producto: producto,
            userName: userName,
            puntosNecesarios: puntosNecesarios,
          );
        } else {
          _mostrarErrorGeneral('Error al obtener información del usuario');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        _mostrarErrorGeneral('Error de conexión: $e');
      }
    }
  }

  void _mostrarConfirmacionIntercambioProducto({
    required Map<String, dynamic> producto,
    required String userName,
    required int puntosNecesarios,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0x1AEF233C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chat,
                color: Color(0xFFEF233C),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Confirmar Intercambio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tienes suficientes puntos para intercambiar por "${producto['nombre']}".',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFFEF233C), size: 20),
                      const SizedBox(width: 8),
                      Text('Propietario: $userName'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag, color: Color(0xFFEF233C), size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Producto: ${producto['nombre']}')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.stars, color: Color(0xFFEF233C), size: 20),
                      const SizedBox(width: 8),
                      Text('Costo: $puntosNecesarios puntos'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Se abrirá un chat con $userName para coordinar los detalles del intercambio.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navegarAlChatProducto(producto['usuario_id'], userName, producto);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF233C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Iniciar Chat'),
          ),
        ],
      ),
    );
  }

  void _navegarAlChatProducto(String otherUserId, String otherUserName, Map<String, dynamic> producto) async {
    // Navegar al chat
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          otherUserId: otherUserId,
          otherUserName: otherUserName,
        ),
      ),
    );

    // Pequeño delay para asegurar que el chat se abra
    await Future.delayed(const Duration(milliseconds: 500));

    // Enviar mensaje automático de intercambio propuesto
    await _enviarMensajeIntercambioPropuestoProducto(otherUserId, producto);

    if (!mounted) return;
    // Mostrar mensaje informativo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.chat, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Intercambio propuesto a $otherUserName',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFEF233C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _enviarMensajeIntercambioPropuestoProducto(String otherUserId, Map<String, dynamic> producto) async {
    try {
      final currentUserId = SupabaseService.getCurrentAuthUser()?.id;
      if (currentUserId == null) return;

      final currentUserData = await SupabaseService.getUserById(currentUserId);
      final currentUserName = currentUserData['success']
          ? (currentUserData['data']['name'] ?? 'Usuario')
          : 'Usuario';

      // Obtener estado físico legible
      String estadoFisico = 'Buen estado';
      if (producto['estado_fisico'] != null) {
        switch (producto['estado_fisico']) {
          case 'nuevo':
            estadoFisico = 'Nuevo';
            break;
          case 'como_nuevo':
            estadoFisico = 'Como nuevo';
            break;
          case 'buen_estado':
            estadoFisico = 'Buen estado';
            break;
          case 'usado':
            estadoFisico = 'Usado';
            break;
          case 'para_reparar':
            estadoFisico = 'Para reparar';
            break;
        }
      }

      // Crear mensaje de intercambio propuesto
      final mensaje = '''🔄 INTERCAMBIO PROPUESTO

📦 Producto: ${producto['nombre'] ?? 'Sin nombre'}
⭐ Puntos: ${producto['puntos_necesarios'] ?? 0} pts
📍 Estado: $estadoFisico
📂 Categoría: ${producto['categoria'] ?? 'Sin categoría'}

¡Hola! Me interesa tu producto "${producto['nombre'] ?? 'este producto'}". Tengo los puntos necesarios y me gustaría coordinar el intercambio contigo. ¿Cuándo podríamos encontrarnos?''';

      // Enviar mensaje usando ChatService
      final chatService = ChatService();
      await chatService.sendMessage(
        senderId: currentUserId,
        receiverId: otherUserId,
        text: mensaje,
      );

      // Enviar notificación al destinatario
      await NotificacionesService.notificarNuevoMensaje(
        destinatarioId: otherUserId,
        remitenteId: currentUserId,
        remitenteNombre: currentUserName,
        mensaje: '🔄 Intercambio propuesto para "${producto['nombre'] ?? 'este producto'}"',
      );
    } catch (e) {
      // Consider logging this error to a service instead of printing
    }
  }

  void _mostrarErrorPuntos(int puntosActuales, int puntosNecesarios) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[600]),
            const SizedBox(width: 12),
            const Text('Puntos Insuficientes'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No tienes suficientes puntos para este intercambio.',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tus puntos actuales:'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$puntosActuales pts',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Puntos necesarios:'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x1AEF233C),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$puntosNecesarios pts',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF233C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Te faltan:'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${puntosNecesarios - puntosActuales} pts',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _mostrarErrorGeneral(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
