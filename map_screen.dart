import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:trueque/modelo/user.model.dart';
import 'package:trueque/services/supabase_service.dart';


class MapScreen extends StatefulWidget {
  final UserModel? currentUser;
  const MapScreen({super.key, this.currentUser});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  // Centro aproximado de la ESPOCH
  final LatLng _espochCenter = LatLng(-1.6540, -78.6789);

  List<Marker> _markers = [];
  List<Map<String, dynamic>> _puntosIntercambio = [];
  bool _isCreatingPoint = false;
  bool _isLoading = true;
  LatLng? _currentLocation;
  bool _isTrackingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadPuntos();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isTrackingLocation = true;
      });

      // Centrar el mapa en la ubicación actual si está dentro del área
      if (_currentLocation != null) {
        _mapController.move(_currentLocation!, 16.0);
      }

      // Actualizar ubicación en tiempo real
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      });
    } catch (e) {
      print('Error obteniendo ubicación: $e');
    }
  }

  Future<void> _loadPuntos() async {
    setState(() => _isLoading = true);
    
    final result = await SupabaseService.getPuntosIntercambio();
    
    if (result['success']) {
      _puntosIntercambio = List<Map<String, dynamic>>.from(result['data']);
    }
    
    _initializeMarkers();
    setState(() => _isLoading = false);
  }

  void _initializeMarkers() {
    _markers.clear();
    
    // Marcador principal de la ESPOCH
    _markers.add(
      Marker(
        point: _espochCenter,
        width: 60,
        height: 60,
        child: GestureDetector(
          onTap: () => _showMarkerInfo('ESPOCH', 'Escuela Superior Politécnica de Chimborazo'),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFEF233C),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 24),
          ),
        ),
      ),
    );

    // Marcador de ubicación actual del usuario
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          point: _currentLocation!,
          width: 50,
          height: 50,
          child: const Icon(
            Icons.location_on,
            color: Colors.blue,
            size: 40,
          ),
        ),
      );
    }

    // Cargar puntos de intercambio desde la base de datos
    for (var punto in _puntosIntercambio) {
      _markers.add(
        Marker(
          point: LatLng(punto['latitud'], punto['longitud']),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _showPuntoInfo(punto),
            child: const Icon(
              Icons.location_on,
              color: Color(0xFFEF233C),
              size: 40,
            ),
          ),
        ),
      );
    }
  }

  void _showMarkerInfo(String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.school, color: Color(0xFFEF233C)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFFEF233C))),
          ),
        ],
      ),
    );
  }

  void _showPuntoInfo(Map<String, dynamic> punto) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFFEF233C)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                punto['nombre'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(punto['descripcion'] ?? 'Sin descripción'),
            const SizedBox(height: 12),
            Text(
              'Coordenadas: ${punto['latitud'].toStringAsFixed(4)}, ${punto['longitud'].toStringAsFixed(4)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
          ),
          if (_canManagePoints())
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _confirmDeletePunto(punto);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF233C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.delete, color: Colors.white, size: 18),
              label: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDeletePunto(Map<String, dynamic> punto) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¿Eliminar punto?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${punto['nombre']}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              // Mostrar indicador de carga
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const CircularProgressIndicator(color: Color(0xFFEF233C)),
                  ),
                ),
              );

              final result = await SupabaseService.deletePuntoIntercambio(punto['id']);
              
              if (mounted) Navigator.pop(context); // Cerrar indicador
              
              if (result['success']) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Punto eliminado'),
                    backgroundColor: Colors.green,
                  ),
                );
                await _loadPuntos(); // Recargar puntos
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ ${result['message']}'),
                    backgroundColor: const Color(0xFFEF233C),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF233C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  bool _canManagePoints() {
    if (widget.currentUser == null) return false;
    final role = widget.currentUser!.rol.toLowerCase();
    return role == 'admin' || role == 'administrador' || role == 'moderador';
  }

  bool _isPointInsideESPOCH(LatLng point) {
    // Para esta versión, cualquier punto es válido
    // Ya no validamos el polígono porque fue eliminado
    return true;
  }

  void _showCreatePointDialog(LatLng point) {
    final nombreController = TextEditingController();
    final descripcionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF233C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_location_alt, color: Color(0xFFEF233C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nuevo Punto',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ubicación: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Nombre', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nombreController,
                    decoration: InputDecoration(
                      hintText: 'Ej: Edificio Central',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa un nombre' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Descripción', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: descripcionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Describe el punto...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa una descripción' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (formKey.currentState!.validate()) {
                  setDialogState(() => isSaving = true);
                  
                  final result = await SupabaseService.createPuntoIntercambio(
                    nombre: nombreController.text.trim(),
                    descripcion: descripcionController.text.trim(),
                    latitud: point.latitude,
                    longitud: point.longitude,
                  );
                  
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  
                  if (result['success']) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Punto creado'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _loadPuntos();
                  } else {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('❌ ${result['message']}'),
                        backgroundColor: const Color(0xFFEF233C),
                      ),
                    );
                  }
                  
                  setState(() => _isCreatingPoint = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF233C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('lib/assets/fondo.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3)),
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Capa del Mapa
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _espochCenter,
                      initialZoom: 16.0,
                      onTap: (t, p) {
                        if (_isCreatingPoint) {
                          _showCreatePointDialog(p);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      ),
                      MarkerLayer(markers: _markers),
                    ],
                  ),
                ),
                
                // Barra superior personalizada (Botón atrás + Título)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
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
                                    const Icon(Icons.map, color: Color(0xFFEF233C), size: 20),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Mapa de Intercambios',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFFEF233C),
                                      ),
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
                ),

                // Controles de zoom
                Positioned(
                  right: 16,
                  bottom: 120,
                  child: Column(
                    children: [
                      _buildControlButton(Icons.add, () {
                        _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        );
                      }),
                      const SizedBox(height: 8),
                      _buildControlButton(Icons.remove, () {
                        _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        );
                      }),
                      const SizedBox(height: 8),
                      _buildControlButton(Icons.my_location, () async {
                        if (_currentLocation != null) {
                          _mapController.move(_currentLocation!, 18.0);
                        } else {
                          // Verificar si el GPS está activado
                          bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                          if (!serviceEnabled) {
                            // Mostrar diálogo para activar GPS
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Row(
                                  children: [
                                    const Icon(Icons.location_off, color: Colors.orange),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'GPS Desactivado',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                content: const Text(
                                  'Para ver tu ubicación en el mapa, activa el GPS de tu dispositivo.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await Geolocator.openLocationSettings();
                                      // Intentar obtener ubicación después de que el usuario regrese
                                      Future.delayed(const Duration(seconds: 2), () {
                                        _getCurrentLocation();
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF233C),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text(
                                      'Activar GPS',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // GPS activado pero no hay ubicación aún
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Esperando ubicación GPS...',
                                ),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      }),
                    ],
                  ),
                ),

                // Leyenda
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 4,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Leyenda',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildLegendItem(Icons.school, 'Campus ESPOCH', const Color(0xFFEF233C)),
                          _buildLegendItem(Icons.location_on, 'Punto de Intercambio', const Color(0xFFEF233C)),
                          if (_isTrackingLocation)
                            _buildLegendItem(Icons.my_location, 'Mi Ubicación', Colors.blue),
                        ],
                      ),
                    ),
                  ),
                ),

                // Indicador de carga
                if (_isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: Color(0xFFEF233C)),
                            const SizedBox(height: 16),
                            const Text(
                              'Cargando mapa...',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Botón flotante para crear puntos (solo admin/moderador)
                if (_canManagePoints())
                  Positioned(
                    top: 100,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: () {
                        setState(() {
                          _isCreatingPoint = !_isCreatingPoint;
                        });
                        
                        // Centrar automáticamente en ESPOCH
                        _mapController.move(_espochCenter, 17.0);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isCreatingPoint
                                  ? '📍 Toca el mapa para crear un punto'
                                  : 'Modo creación desactivado',
                            ),
                            backgroundColor: _isCreatingPoint
                                ? const Color(0xFF2563EB)
                                : Colors.grey,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      backgroundColor: _isCreatingPoint
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFEF233C),
                      child: Icon(
                        _isCreatingPoint ? Icons.close : Icons.add_location_alt,
                        color: Colors.white,
                        size: 28,
                      ),
                      elevation: 6,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: const Color(0xFFEF233C), size: 22),
        ),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}