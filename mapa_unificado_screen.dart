import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trueque/modelo/user.model.dart';
import 'package:trueque/screens/chat_screen.dart';
import 'package:trueque/services/supabase_service.dart';

class MapaUnificadoScreen extends StatefulWidget {
  final UserModel? currentUser;
  
  const MapaUnificadoScreen({super.key, this.currentUser});

  @override
  State<MapaUnificadoScreen> createState() => _MapaUnificadoScreenState();
}

class _MapaUnificadoScreenState extends State<MapaUnificadoScreen> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final _supabase = Supabase.instance.client;
  final LatLng _espochCenter = LatLng(-1.6540, -78.6789);

  // Subscriptions
  StreamSubscription<List<Map<String, dynamic>>>? _locationsSubscription;
  Timer? _userLocationTimer;

  // State
  Position? _currentUserPosition;
  List<Map<String, dynamic>> _allUserLocations = [];
  List<Map<String, dynamic>> _puntosIntercambio = [];
  Map<String, String> _userNames = {};
  bool _hasCenteredMap = false;
  bool _isCreatingPoint = false;
  bool _showUsers = true;
  bool _showPoints = true;

  // NUEVA VARIABLE PARA PRIVACIDAD (PARA NO BORRAR NADA)
  List<String> _partnerIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeMapAsync();
    _refreshPartnerList(); // Iniciar filtro de partners
  }
  
  void _initializeMapAsync() {
    _loadPuntosIntercambio();
    _initializeLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _startLocationUpdates();
      _refreshPartnerList();
    } else if (state == AppLifecycleState.paused) {
      _stopLocationUpdates();
    }
  }

  /// LÓGICA DE PRIVACIDAD: Obtener socios de intercambio aceptado
  Future<void> _refreshPartnerList() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final exchanges = await _supabase
          .from('intercambio')
          .select('id_usuario_ofrece, id_usuario_recibido')
          .eq('estado', 'aceptado')
          .or('id_usuario_ofrece.eq.$myId,id_usuario_recibido.eq.$myId');

      final List<String> ids = [];
      for (var ex in exchanges) {
        if (ex['id_usuario_ofrece'] != myId) ids.add(ex['id_usuario_ofrece']);
        if (ex['id_usuario_recibido'] != myId) ids.add(ex['id_usuario_recibido']);
      }

      if (mounted) {
        setState(() {
          _partnerIds = ids;
        });
      }
    } catch (e) {
      debugPrint('Error partners: $e');
    }
  }

  Future<void> _initializeLocation() async {
    await _getInitialLocation();
    _setupUserLocationsStream();
    _requestLocationPermission();
  }
  
  Future<void> _requestLocationPermission() async {
    try {
      var status = await Permission.location.request();
      if (status.isGranted) {
        _startLocationUpdates();
      }
    } catch (e) {
      debugPrint('⚠️ Error permisos: $e');
    }
  }

  Future<void> _loadPuntosIntercambio() async {
    try {
      final result = await SupabaseService.getPuntosIntercambio();
      if (result['success'] && mounted) {
        setState(() {
          _puntosIntercambio = List<Map<String, dynamic>>.from(result['data']);
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error puntos: $e');
    }
  }

  Future<void> _getInitialLocation() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('localizacion')
          .select('lat, lon')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['lat'] != null && response['lon'] != null && mounted) {
        setState(() {
          _currentUserPosition = Position(
            latitude: (response['lat'] as num).toDouble(),
            longitude: (response['lon'] as num).toDouble(),
            timestamp: DateTime.now(),
            accuracy: 0, altitude: 0, altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0,
          );
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error inicial: $e');
    }
  }

  void _setupUserLocationsStream() {
    _locationsSubscription = _supabase
        .from('localizacion')
        .stream(primaryKey: ['user_id']).listen((locations) {
      if (!mounted) return;

      final userIds = locations
          .map((loc) => loc['user_id'] as String?)
          .where((id) => id != null)
          .toSet();
      
      _fetchUserNames(userIds);

      if (mounted) {
        setState(() {
          _allUserLocations = locations;
        });
      }
    }, onError: (error) {
      debugPrint('❌ Error stream: $error');
    });
  }

  Future<void> _fetchUserNames(Set<String?> userIds) async {
    final idsToFetch = userIds
        .where((id) => id != null && !_userNames.containsKey(id))
        .cast<String>()
        .toList();

    if (idsToFetch.isEmpty) return;

    try {
      final response = await _supabase
          .from('usuarios')
          .select('id, name')
          .inFilter('id', idsToFetch);

      if (mounted) {
        final Map<String, String> newNames = {
          for (var user in response)
            user['id'] as String: user['name'] as String
        };
        setState(() {
          _userNames.addAll(newNames);
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error nombres: $e');
    }
  }

  void _startLocationUpdates() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || (_userLocationTimer?.isActive ?? false)) return;

    Future<void> updateUserPosition() async {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) return;

        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 3),
        );
        
        if (mounted) {
          setState(() => _currentUserPosition = position);
          _updateUserLocationInSupabase(position, currentUserId);
          _refreshPartnerList(); // Actualizar privacidad periódicamente
        }
      } catch (e) {
        debugPrint('⚠️ GPS error');
      }
    }

    updateUserPosition();
    _userLocationTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      await updateUserPosition();
    });
  }

  Future<void> _updateUserLocationInSupabase(Position position, String userId) async {
    try {
      await _supabase.from('localizacion').upsert({
        'user_id': userId,
        'lat': position.latitude,
        'lon': position.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('Error update loc: $e');
    }
  }

  void _stopLocationUpdates() {
    _userLocationTimer?.cancel();
  }

  bool _canManagePoints() {
    if (widget.currentUser == null) return false;
    final role = widget.currentUser!.rol.toLowerCase();
    return role == 'admin' || role == 'administrador' || role == 'moderador';
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];
    final currentUserId = _supabase.auth.currentUser?.id;

    // Marcador de la ESPOCH
    markers.add(
      Marker(
        point: _espochCenter,
        width: 60, height: 60,
        child: GestureDetector(
          onTap: () => _showInfoDialog('ESPOCH', 'Politécnica de Chimborazo', Icons.school, const Color(0xFFEF233C)),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFEF233C), shape: BoxShape.circle),
            child: const Icon(Icons.school, color: Colors.white, size: 24),
          ),
        ),
      ),
    );

    // Marcadores de usuarios (FILTRO DE PRIVACIDAD INTEGRADO)
    if (_showUsers) {
      for (var location in _allUserLocations) {
        final userId = location['user_id'];
        
        // SOLO MOSTRAR SI ES MI PARTNER DE INTERCAMBIO ACEPTADO
        if (userId == currentUserId || !_partnerIds.contains(userId)) continue;

        final lat = location['lat'];
        final lon = location['lon'];
        if (lat == null || lon == null) continue;

        final userName = _userNames[userId] ?? 'Usuario';

        markers.add(
          Marker(
            width: 50, height: 50,
            point: LatLng((lat as num).toDouble(), (lon as num).toDouble()),
            child: GestureDetector(
              onTap: () => _showUserDialog(userId, userName),
              child: const Icon(Icons.location_on, color: Colors.green, size: 40),
            ),
          ),
        );
      }
    }

    // Marcador de ubicación actual
    if (_currentUserPosition != null) {
      markers.add(
        Marker(
          width: 50, height: 50,
          point: LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude),
          child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
        ),
      );
    }

    // Marcadores de puntos de intercambio
    if (_showPoints) {
      for (var punto in _puntosIntercambio) {
        markers.add(
          Marker(
            point: LatLng(punto['latitud'], punto['longitud']),
            width: 50, height: 50,
            child: GestureDetector(
              onTap: () => _showPuntoDialog(punto),
              child: const Icon(Icons.place, color: Color(0xFFEF233C), size: 40),
            ),
          ),
        );
      }
    }

    return markers;
  }

  void _showInfoDialog(String title, String description, IconData icon, Color color) {
    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Row(children: [Icon(icon, color: color), const SizedBox(width: 12), Expanded(child: Text(title))]), content: Text(description), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]));
  }

  void _showUserDialog(String userId, String userName) {
    showDialog(context: context, builder: (context) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Color(0xFFEF233C), borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))), child: Row(children: [CircleAvatar(backgroundColor: Colors.white, radius: 30, child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFEF233C)))), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(userName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 4), Row(children: const [Icon(Icons.circle, color: Colors.greenAccent, size: 12), SizedBox(width: 6), Text('En línea', style: TextStyle(fontSize: 14, color: Colors.white70))])]))])), Padding(padding: const EdgeInsets.all(20), child: Column(children: [const Text('¿Deseas iniciar una conversación?', style: TextStyle(fontSize: 16), textAlign: TextAlign.center), const SizedBox(height: 24), Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFEF233C)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Cancelar', style: TextStyle(color: Color(0xFFEF233C)))), ElevatedButton.icon(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: userId, otherUserName: userName))); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF233C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.chat_bubble, color: Colors.white), label: const Text('Chatear', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))])]))])));
  }

  void _showCreatePointDialog(LatLng point) {
    final nombreController = TextEditingController();
    final descripcionController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(context: context, builder: (dialogContext) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFEF233C).withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_location_alt, color: Color(0xFFEF233C))), const SizedBox(width: 12), const Text('Nuevo Punto')]), content: Form(key: formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text('Ubicación: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 12))), const SizedBox(height: 16), TextFormField(controller: nombreController, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()), validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa un nombre' : null), const SizedBox(height: 16), TextFormField(controller: descripcionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()), validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa una descripción' : null)])), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')), ElevatedButton(onPressed: () async { if (formKey.currentState!.validate()) { Navigator.pop(dialogContext); final result = await SupabaseService.createPuntoIntercambio(nombre: nombreController.text.trim(), descripcion: descripcionController.text.trim(), latitud: point.latitude, longitud: point.longitude); if (result['success']) { await _loadPuntosIntercambio(); setState(() => _isCreatingPoint = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Punto creado'))); } } }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF233C)), child: const Text('Guardar', style: TextStyle(color: Colors.white)))]));
  }

  void _showPuntoDialog(Map<String, dynamic> punto) {
    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Row(children: [const Icon(Icons.place, color: Color(0xFFEF233C)), const SizedBox(width: 12), Expanded(child: Text(punto['nombre']))]), content: Text(punto['descripcion'] ?? 'Sin descripción'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')), if (_canManagePoints()) ElevatedButton.icon(onPressed: () async { Navigator.pop(context); final result = await SupabaseService.deletePuntoIntercambio(punto['id']); if (result['success']) { await _loadPuntosIntercambio(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Punto eliminado'))); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), icon: const Icon(Icons.delete, color: Colors.white), label: const Text('Eliminar', style: TextStyle(color: Colors.white)))]));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopLocationUpdates();
    _locationsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LatLng? userLatLng;
    if (_currentUserPosition != null) {
      userLatLng = LatLng(_currentUserPosition!.latitude, _currentUserPosition!.longitude);
    }

    if (!_hasCenteredMap && userLatLng != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasCenteredMap) {
          _mapController.move(userLatLng!, 16.0);
          _hasCenteredMap = true;
        }
      });
    }

    final currentUserId = _supabase.auth.currentUser?.id;
    // LISTA INFERIOR FILTRADA POR PRIVACIDAD
    final otherUsers = _allUserLocations
        .where((loc) => loc['user_id'] != currentUserId && _partnerIds.contains(loc['user_id']))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa Interactivo'),
        backgroundColor: const Color(0xFFEF233C),
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) { setState(() { if (value == 'users') _showUsers = !_showUsers; if (value == 'points') _showPoints = !_showPoints; }); },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(value: 'users', checked: _showUsers, child: const Text('Mostrar usuarios')),
              CheckedPopupMenuItem(value: 'points', checked: _showPoints, child: const Text('Mostrar puntos')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: userLatLng ?? _espochCenter,
                    initialZoom: 16.0,
                    onTap: (_, point) { if (_isCreatingPoint) _showCreatePointDialog(point); },
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                    MarkerLayer(markers: _buildMarkers()),
                  ],
                ),
                Positioned(
                  right: 16, bottom: 16,
                  child: Column(
                    children: [
                      _buildControlButton(Icons.add, () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1); }),
                      const SizedBox(height: 8),
                      _buildControlButton(Icons.remove, () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1); }),
                      const SizedBox(height: 8),
                      _buildControlButton(Icons.my_location, () async {
                        if (userLatLng != null) {
                          _mapController.move(userLatLng, 16.0);
                        } else {
                          try {
                            final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 5));
                            setState(() => _currentUserPosition = position);
                            _mapController.move(LatLng(position.latitude, position.longitude), 16.0);
                          } catch (e) {
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Activa el GPS.'), backgroundColor: Colors.orange));
                          }
                        }
                      }),
                    ],
                  ),
                ),
                Positioned(
                  left: 16, bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Leyenda', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildLegendItem(Icons.school, 'ESPOCH', const Color(0xFFEF233C)),
                        if (_showUsers) _buildLegendItem(Icons.location_on, 'Intercambio activo', Colors.green),
                        if (_showPoints) _buildLegendItem(Icons.place, 'Puntos', const Color(0xFFEF233C)),
                        _buildLegendItem(Icons.my_location, 'Mi ubicación', Colors.blue),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showUsers && otherUsers.isNotEmpty)
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.grey[100],
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: otherUsers.length,
                  itemBuilder: (context, index) {
                    final userLocation = otherUsers[index];
                    final userId = userLocation['user_id'];
                    final userName = _userNames[userId] ?? 'Cargando...';
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.person, color: Colors.white)),
                        title: Text(userName),
                        subtitle: const Text('Partner de intercambio'),
                        trailing: IconButton(icon: const Icon(Icons.chat, color: Color(0xFFEF233C)), onPressed: () { if (userName != 'Cargando...') Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(otherUserId: userId, otherUserName: userName))); }),
                        onTap: () {
                          final lat = userLocation['lat'];
                          final lon = userLocation['lon'];
                          if (lat != null && lon != null) _mapController.move(LatLng((lat as num).toDouble(), (lon as num).toDouble()), 16.0);
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _canManagePoints()
          ? FloatingActionButton(
              onPressed: () { setState(() => _isCreatingPoint = !_isCreatingPoint); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isCreatingPoint ? '📍 Toca el mapa para crear un punto' : 'Modo creación desactivado'))); },
              backgroundColor: _isCreatingPoint ? Colors.blue : const Color(0xFFEF233C),
              child: Icon(_isCreatingPoint ? Icons.close : Icons.add_location_alt),
            )
          : null,
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed) {
    return Material(color: Colors.white, borderRadius: BorderRadius.circular(12), elevation: 4, child: InkWell(onTap: onPressed, borderRadius: BorderRadius.circular(12), child: Container(padding: const EdgeInsets.all(12), child: Icon(icon, color: const Color(0xFFEF233C)))));
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 16), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 11))]));
  }
}
