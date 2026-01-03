
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Modelo simple para las categorías, para manejar ID y nombre.
class _Category {
  final int id;
  final String name;
  _Category(this.id, this.name);
}

// Modelo simple para las opciones de puntos, para manejar etiqueta y valor.
class _PointsOption {
  final String label;
  final int value;
  _PointsOption(this.label, this.value);
}

class AddProductScreen extends StatefulWidget {
  final String? categoriaPreseleccionada;
  
  const AddProductScreen({
    super.key,
    this.categoriaPreseleccionada,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _ubicacionController = TextEditingController();

  // Futuro para cargar las categorías dinámicamente
  late final Future<List<_Category>> _categoriesFuture;

  final List<_PointsOption> _pointsOptions = [
    _PointsOption('1 punto', 1),
    _PointsOption('2 puntos', 2),
    _PointsOption('3 puntos', 3),
    _PointsOption('4 puntos', 4),
    _PointsOption('5 puntos', 5),
    _PointsOption('6 puntos', 6),
    _PointsOption('7 puntos', 7),
    _PointsOption('8 puntos', 8),
    _PointsOption('9 puntos', 9),
    _PointsOption('10 puntos', 10),
  ];

  // Estado del formulario
  int? _selectedCategoryId;
  int? _selectedPointsValue;
  final List<XFile> _selectedImages = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _fetchCategories();
    _preseleccionarCategoria();
  }

  void _preseleccionarCategoria() async {
    if (widget.categoriaPreseleccionada != null) {
      // Esperar a que se carguen las categorías y luego preseleccionar
      final categories = await _categoriesFuture;
      final categoriaEncontrada = categories.firstWhere(
        (cat) => cat.name == widget.categoriaPreseleccionada,
        orElse: () => _Category(0, ''),
      );
      
      if (categoriaEncontrada.id != 0) {
        setState(() {
          _selectedCategoryId = categoriaEncontrada.id;
        });
      }
    }
  }

  Future<List<_Category>> _fetchCategories() async {
    try {
      final response = await Supabase.instance.client.from('categorias').select('id_categoria, nombre_categoria');
      final List<_Category> categories = (response as List).map((item) {
        return _Category(item['id_categoria'], item['nombre_categoria']);
      }).toList();
      return categories;
    } catch (e) {
      _showErrorSnackBar('No se pudieron cargar las categorías: ${e.toString()}');
      return [];
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _ubicacionController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedImages.length >= 3) {
      _showErrorSnackBar('Puedes seleccionar un máximo de 3 imágenes.');
      return;
    }
    try {
      final pickedFile = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1024);
      if (pickedFile != null) {
        setState(() => _selectedImages.add(pickedFile));
      }
    } catch (e) {
      _showErrorSnackBar('Error al seleccionar la imagen: $e');
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galería'), onTap: () => _pickImageWithPop(ImageSource.gallery)),
            ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Cámara'), onTap: () => _pickImageWithPop(ImageSource.camera)),
          ],
        ),
      ),
    );
  }

  void _pickImageWithPop(ImageSource source) {
    Navigator.of(context).pop();
    _pickImage(source);
  }

  Future<void> _submitPublication() async {
    if (!_formKey.currentState!.validate() || _selectedImages.isEmpty) {
      if (_selectedImages.isEmpty) {
        _showErrorSnackBar('Por favor, sube al menos una imagen.');
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Debes iniciar sesión para publicar.');

      final List<String> imageUrls = [];
      for (final image in _selectedImages) {
        final imageBytes = await image.readAsBytes();
        final imageExtension = image.path.split('.').last.toLowerCase();
        final imageFileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${_selectedImages.indexOf(image)}.$imageExtension';

        await Supabase.instance.client.storage.from('productos_unificados').uploadBinary(
              imageFileName,
              imageBytes,
              fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
            );
        imageUrls.add(Supabase.instance.client.storage.from('productos_unificados').getPublicUrl(imageFileName));
      }

      // Obtener nombre de categoría desde el ID
      final categoriaResponse = await Supabase.instance.client
          .from('categorias')
          .select('nombre_categoria')
          .eq('id_categoria', _selectedCategoryId!)
          .single();
      
      final categoriaNombre = categoriaResponse['nombre_categoria'] as String;
      
      // Determinar estado físico según puntos
      String estadoFisico;
      if (_selectedPointsValue! <= 3) {
        estadoFisico = 'para_reparar';
      } else if (_selectedPointsValue! <= 6) {
        estadoFisico = 'usado';
      } else if (_selectedPointsValue! <= 8) {
        estadoFisico = 'buen_estado';
      } else {
        estadoFisico = 'como_nuevo';
      }

      await Supabase.instance.client.from('productos_unificados').insert({
        'nombre': _nombreController.text,
        'descripcion': _descripcionController.text,
        'categoria': categoriaNombre,
        'estado_fisico': estadoFisico,
        'puntos_necesarios': _selectedPointsValue,
        'ubicacion': _ubicacionController.text,
        'image_urls': imageUrls,
        'usuario_id': user.id,
        'disponible': true,
        'estado_aprobacion': 'pendiente',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Artículo publicado con éxito!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      _showErrorSnackBar('Error al publicar el artículo: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Nuevo Producto'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextFormField(_nombreController, 'Título del producto', 'Ej: Calculadora Casio FX-991'),
              const SizedBox(height: 16),
              _buildTextFormField(_descripcionController, 'Descripción detallada', 'Incluye estado, detalles y características.', maxLines: 4),
              const SizedBox(height: 20),
              _buildImagePicker(),
              const SizedBox(height: 20),
              _buildCategoryDropdown(),
              const SizedBox(height: 16),
              _buildPointsDropdown(),
              const SizedBox(height: 16),
              _buildTextFormField(_ubicacionController, 'Ubicación del producto', 'Ej: Riobamba, Cerca de la ESPOCH'),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitPublication,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('Publicar Artículo', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField(TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) => (value == null || value.isEmpty) ? 'Este campo es obligatorio' : null,
    );
  }

  Widget _buildCategoryDropdown() {
    return FutureBuilder<List<_Category>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return DropdownButtonFormField<int>(
            decoration: InputDecoration(
              labelText: 'Categoría',
              errorText: 'No se pudieron cargar',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            hint: const Text('Error'),
            items: const [],
            onChanged: null,
          );
        }

        final categories = snapshot.data!;
        return DropdownButtonFormField<int>(
          value: _selectedCategoryId,
          decoration: InputDecoration(labelText: 'Categoría', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          hint: const Text('Seleccionar categoría'),
          items: categories.map((category) => DropdownMenuItem<int>(value: category.id, child: Text(category.name))).toList(),
          onChanged: (value) => setState(() => _selectedCategoryId = value),
          validator: (value) => value == null ? 'Debes seleccionar una categoría' : null,
        );
      },
    );
  }

  Widget _buildPointsDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<int>(
          value: _selectedPointsValue,
          decoration: InputDecoration(
            labelText: 'Cantidad de puntos (1-10)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            helperText: 'Selecciona del 1 al 10 según el valor del producto',
          ),
          hint: const Text('Seleccionar puntos'),
          items: _pointsOptions.map((option) => DropdownMenuItem<int>(
            value: option.value, 
            child: Row(
              children: [
                Icon(Icons.stars, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Text(option.label),
              ],
            ),
          )).toList(),
          onChanged: (value) => setState(() => _selectedPointsValue = value),
          validator: (value) => value == null ? 'Debes asignar una cantidad de puntos' : null,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Guía de puntos:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '• 1-3 puntos: Para reparar\n• 4-6 puntos: Usado\n• 7-8 puntos: Buen estado\n• 9-10 puntos: Como nuevo',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Imágenes (máx. 3)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ..._selectedImages.asMap().entries.map((entry) {
              int index = entry.key;
              XFile imageFile = entry.value;
              return SizedBox(
                width: 100, height: 100,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: FutureBuilder<Uint8List>(
                        future: imageFile.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Image.memory(snapshot.data!, width: 100, height: 100, fit: BoxFit.cover);
                          }
                          return Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[300],
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: -8, right: -8,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImages.removeAt(index)),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_selectedImages.length < 3)
              GestureDetector(
                onTap: _showImageSourceActionSheet,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade400, width: 1.5)),
                  child: Center(child: Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade600, size: 36)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
