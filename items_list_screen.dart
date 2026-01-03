// ARCHIVO CORREGIDO Y VERIFICADO
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trueque/widgets/proponer_intercambio_dialog.dart';
import 'package:trueque/modelo/user.model.dart'; 
import 'package:trueque/modelo/producto_unificado_model.dart';
import 'package:trueque/screens/home_screen.dart';

class ItemsListScreen extends StatelessWidget {
  final Category category;
  final UserModel currentUser;

  const ItemsListScreen({
    super.key,
    required this.category,
    required this.currentUser,
  });

  Future<List<ProductoUnificado>> _fetchItems(BuildContext context) async {
    try {
      final response = await Supabase.instance.client
          .from('productos_unificados')
          .select('*, usuario:usuario_id(*)')
          .eq('categoria', category.id)
          .eq('disponible', true)
          .neq('usuario_id', currentUser.id)
          .order('creado_en', ascending: false);

      final List<ProductoUnificado> items = (response as List)
          .map((data) => ProductoUnificado.fromJson(data))
          .toList();
      return items;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar productos: $e')),
        );
      }
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: category.color,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              category.color,
              category.color.withAlpha(204), // 0.8 opacity
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: FutureBuilder<List<ProductoUnificado>>(
                  future: _fetchItems(context),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: category.color));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No hay productos',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No hay productos disponibles en esta categoría.',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.6,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _ItemCard(
                          item: item,
                          currentUser: currentUser,
                          categoryColor: category.color,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final ProductoUnificado item;
  final UserModel currentUser;
  final Color categoryColor;

  const _ItemCard({
    required this.item,
    required this.currentUser,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = (item.imageUrls != null && item.imageUrls!.isNotEmpty) ? item.imageUrls![0] : null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _mostrarDetalleProducto(context, item),
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
                    item.nombre,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (item.usuario != null)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: categoryColor,
                          child: Text(
                            item.usuario!.getInitials(),
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
                            item.usuario!.nombreCompleto,
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
                        '${item.puntosNecesarios} pts',
                        Colors.amber,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (item.usuario == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: El propietario de este producto no está disponible.')),
                      );
                      return;
                    }
                    showDialog(
                      context: context,
                      builder: (context) => ProponerIntercambioDialog(
                        productoSolicitado: item,
                        usuarioActual: currentUser,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: categoryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Intercambiar', style: GoogleFonts.poppins(fontSize: 12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

void _mostrarDetalleProducto(BuildContext context, ProductoUnificado producto) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(producto.nombre, style: GoogleFonts.poppins()),
      content: Text(producto.descripcion, style: GoogleFonts.poppins()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cerrar', style: GoogleFonts.poppins()),
        ),
      ],
    ),
  );
}

Widget _buildTag(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(25), // 0.1 opacity
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withAlpha(76)), // 0.3 opacity
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

Color _getColorShade(Color color, int shade) {
  if (color == Colors.blue) return Colors.blue.shade700;
  if (color == Colors.green) return Colors.green.shade700;
  if (color == Colors.amber) return Colors.amber.shade700;
  if (color == Colors.red) return Colors.red.shade700;
  return color;
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
