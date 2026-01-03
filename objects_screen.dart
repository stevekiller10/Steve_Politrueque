import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:trueque/modelo/user.model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/productos_unificados_service.dart';
import '../modelo/producto_unificado_model.dart';

class ObjectsScreen extends StatefulWidget {
  final UserModel currentUser;
  const ObjectsScreen({super.key, required this.currentUser});

  @override
  State<ObjectsScreen> createState() => _ObjectsScreenState();
}

class _ObjectsScreenState extends State<ObjectsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<Map<String, dynamic>> _objetosDisponibles = [];
  List<Map<String, dynamic>> _misAprobados = [];
  List<Map<String, dynamic>> _misPendientes = [];
  List<Map<String, dynamic>> _misRechazados = [];
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final disponiblesRes = await ProductosUnificadosService.getProductosDisponibles();
      final misProductosRes = await ProductosUnificadosService.getMisProductos();
      
      if (mounted) {
        setState(() {
          if (disponiblesRes['success']) {
            _objetosDisponibles = List<Map<String, dynamic>>.from(
              (disponiblesRes['data'] as List).map((p) => (p as ProductoUnificado).toJson())
            );
          }

          if (misProductosRes['success']) {
            final allMyItems = List<Map<String, dynamic>>.from(
              (misProductosRes['data'] as List).map((p) => (p as ProductoUnificado).toJson())
            );
            
            _misAprobados = allMyItems.where((item) => item['estado_aprobacion'] == 'aprobado').toList();
            _misPendientes = allMyItems.where((item) => item['estado_aprobacion'] == 'pendiente' || item['estado_aprobacion'] == 'borrador').toList();
            _misRechazados = allMyItems.where((item) => item['estado_aprobacion'] == 'rechazado').toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Objetos de Intercambio', 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFFEF233C),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 10),
          tabs: [
            const Tab(text: 'Disponibles'),
            Tab(text: 'Aprobados\n(${_misAprobados.length})'),
            Tab(text: 'Pendientes\n(${_misPendientes.length})'),
            Tab(text: 'Rechazados\n(${_misRechazados.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFEF233C)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_objetosDisponibles, "No hay productos disponibles", false),
                _buildList(_misAprobados, "No tienes productos aprobados", true),
                _buildList(_misPendientes, "No tienes productos en revisión", true),
                _buildList(_misRechazados, "No tienes productos rechazados", true),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddObjectDialog(),
        backgroundColor: const Color(0xFFEF233C),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Agregar Objeto', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, String emptyMsg, bool isMine) {
    if (items.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text(emptyMsg, style: GoogleFonts.poppins(color: Colors.grey[600])),
      ]));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildObjetoCard(items[index], isMine),
      ),
    );
  }

  Widget _buildObjetoCard(Map<String, dynamic> objeto, bool esPropio) {
    final status = objeto['estado_aprobacion'] ?? 'pendiente';
    final imageUrls = objeto['image_urls'];
    final primeraImagen = (imageUrls != null && imageUrls is List && imageUrls.isNotEmpty) ? imageUrls.first : null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60, height: 60, color: Colors.grey[100],
                child: primeraImagen != null ? Image.network(primeraImagen, fit: BoxFit.cover) : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
            title: Text(objeto['nombre'] ?? 'Sin nombre', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            subtitle: Text(objeto['categoria'] ?? 'Otros', style: GoogleFonts.poppins(fontSize: 12)),
            trailing: _buildBadge(status),
          ),
          if (status == 'rechazado' && objeto['motivo_rechazo'] != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red[100]!)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text("Motivo: ${objeto['motivo_rechazo']}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.red[900]))),
              ]),
            ),
          if (esPropio && status != 'pendiente')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status != 'aprobado')
                    TextButton.icon(
                      onPressed: () => _showEditDialog(objeto), 
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.indigo), 
                      label: const Text('Editar', style: TextStyle(color: Colors.indigo))
                    ),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(objeto), 
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), 
                    label: const Text('Eliminar', style: TextStyle(color: Colors.red))
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String status) {
    Color color = status == 'aprobado' ? Colors.green : (status == 'pendiente' ? Colors.blue : Colors.red);
    if (status == 'borrador') color = Colors.orange;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }

  void _showAddObjectDialog() {
    _showFormDialog();
  }

  void _showEditDialog(Map<String, dynamic> objeto) {
    _showFormDialog(objeto: objeto);
  }

  void _showFormDialog({Map<String, dynamic>? objeto}) {
    final isEditing = objeto != null;
    final nombreController = TextEditingController(text: objeto?['nombre'] ?? '');
    final descController = TextEditingController(text: objeto?['descripcion'] ?? '');
    String categoria = objeto?['categoria'] ?? 'Electrónicos';
    String estadoFisico = objeto?['estado_fisico'] ?? 'buen_estado';
    XFile? selectedImage;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? 'Editar Objeto' : 'Nuevo Objeto', 
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
                    if (img != null) setDialogState(() => selectedImage = img);
                  },
                  child: Container(
                    height: 150, width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                    child: selectedImage != null 
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12), 
                          child: kIsWeb 
                            ? Image.network(selectedImage!.path, fit: BoxFit.cover) 
                            : Image.network(selectedImage!.path, fit: BoxFit.cover) // Usamos network para previsualizar paths locales en web
                        )
                      : (isEditing && objeto['image_urls'] != null && (objeto['image_urls'] as List).isNotEmpty)
                        ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(objeto['image_urls'][0], fit: BoxFit.cover))
                        : const Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: categoria,
                  items: ['Electrónicos', 'Comida', 'Ropa', 'Útiles Escolares', 'Deportes', 'Hogar', 'Otros']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => categoria = val!,
                  decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setDialogState(() => isSaving = true);
                try {
                  String? url;
                  if (selectedImage != null) {
                    final res = await SupabaseService.uploadImagenObjeto(selectedImage!.path);
                    if (res['success']) url = res['imageUrl'];
                  }

                  if (isEditing) {
                    await SupabaseService.updateObjeto(
                      objetoId: objeto['id'].toString(),
                      nombre: nombreController.text,
                      descripcion: descController.text,
                      categoria: categoria,
                      estado: estadoFisico,
                      imagenUrl: url,
                    );
                    if (objeto['estado_aprobacion'] == 'rechazado') {
                      await SupabaseService.enviarARevision(objeto['id'].toString());
                    }
                  } else {
                    await SupabaseService.createObjeto(
                      nombre: nombreController.text,
                      descripcion: descController.text,
                      categoria: categoria,
                      estado: estadoFisico,
                      imagenUrl: url,
                    );
                  }
                  Navigator.pop(context);
                  _loadData();
                } catch (e) {
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text("Error: $e")));
                } finally {
                  setDialogState(() => isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF233C), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> objeto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar objeto?'),
        content: Text('Esta acción borrará "${objeto['nombre']}" permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await SupabaseService.deleteObjeto(objeto['id'].toString());
              Navigator.pop(context);
              _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
