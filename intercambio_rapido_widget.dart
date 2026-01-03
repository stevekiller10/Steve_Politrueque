import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/intercambio/crear_intercambio_simple_screen.dart';
import '../screens/chat_screen.dart';
import '../services/supabase_service.dart';

class IntercambioRapidoWidget extends StatelessWidget {
  final Map<String, dynamic> producto;
  final VoidCallback? onIntercambioCreado;

  const IntercambioRapidoWidget({
    super.key,
    required this.producto,
    this.onIntercambioCreado,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFB71C1C).withOpacity(0.1),
            const Color(0xFFB71C1C).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB71C1C).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.swap_horiz,
                color: const Color(0xFFB71C1C),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '¿Te interesa este producto?',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB71C1C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Text(
            'Puedes intercambiarlo de forma rápida y segura',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              // Botón de Chat
              Expanded(
                child: _buildBotonAccion(
                  context,
                  icon: Icons.chat_bubble_outline,
                  label: 'Preguntar',
                  color: Colors.blue,
                  onTap: () => _abrirChat(context),
                ),
              ),
              const SizedBox(width: 12),
              
              // Botón de Intercambio
              Expanded(
                flex: 2,
                child: _buildBotonAccion(
                  context,
                  icon: Icons.swap_horiz,
                  label: 'Proponer Intercambio',
                  color: const Color(0xFFB71C1C),
                  isPrimary: true,
                  onTap: () => _abrirIntercambio(context),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Información adicional
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Intercambio seguro con código de verificación',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonAccion(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? color : Colors.white,
        foregroundColor: isPrimary ? Colors.white : color,
        side: isPrimary ? null : BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: isPrimary ? 2 : 0,
      ),
    );
  }

  Future<void> _abrirChat(BuildContext context) async {
    try {
      final result = await SupabaseService.getUserById(producto['user_id']);
      
      if (result['success'] && context.mounted) {
        final propietario = result['data'];
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              otherUserId: producto['user_id'],
              otherUserName: propietario['name'] ?? 'Usuario',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _abrirIntercambio(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearIntercambioSimpleScreen(
          idUsuarioReceptor: producto['user_id'],
          idProductoSolicitado: producto['id'],
          productoSolicitado: producto,
        ),
      ),
    ).then((resultado) {
      if (resultado == true) {
        onIntercambioCreado?.call();
      }
    });
  }
}

// Widget para mostrar intercambios sugeridos
class IntercambiosSugeridosWidget extends StatefulWidget {
  const IntercambiosSugeridosWidget({super.key});

  @override
  State<IntercambiosSugeridosWidget> createState() => _IntercambiosSugeridosWidgetState();
}

class _IntercambiosSugeridosWidgetState extends State<IntercambiosSugeridosWidget> {
  List<Map<String, dynamic>> _productosSugeridos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarProductosSugeridos();
  }

  Future<void> _cargarProductosSugeridos() async {
    try {
      final result = await SupabaseService.getObjetosDisponibles();
      final usuarioActual = SupabaseService.client.auth.currentUser;
      
      if (usuarioActual != null && result['success']) {
        final productos = result['data'] as List<dynamic>;
        // Filtrar productos de otros usuarios y tomar los más recientes
        final productosFiltrados = productos
            .cast<Map<String, dynamic>>()
            .where((p) => 
                p['user_id'] != usuarioActual.id && 
                p['estado_aprobacion'] == 'aprobado')
            .take(3)
            .toList();
        
        setState(() {
          _productosSugeridos = productosFiltrados;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_productosSugeridos.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '🔥 Intercambios Sugeridos',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFB71C1C),
            ),
          ),
        ),
        
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _productosSugeridos.length,
            itemBuilder: (context, index) {
              final producto = _productosSugeridos[index];
              return _buildProductoSugerido(producto);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductoSugerido(Map<String, dynamic> producto) {
    final imageUrls = producto['image_urls'] as List?;
    final imageUrl = (imageUrls != null && imageUrls.isNotEmpty) ? imageUrls[0] : null;

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 120,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported, color: Colors.grey);
                      },
                    )
                  : const Icon(Icons.image, color: Colors.grey, size: 40),
            ),
          ),
          
          // Información
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto['nombre'] ?? 'Sin nombre',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                
                if (producto['categoria'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      producto['categoria'],
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                // Botón de intercambio
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _abrirIntercambio(producto),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB71C1C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Intercambiar',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _abrirIntercambio(Map<String, dynamic> producto) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CrearIntercambioSimpleScreen(
          idUsuarioReceptor: producto['user_id'],
          idProductoSolicitado: producto['id'],
          productoSolicitado: producto,
        ),
      ),
    );
  }
}