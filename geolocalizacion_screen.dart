import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trueque/screens/chat_screen.dart';

class GeolocalizacionScreen extends StatefulWidget {
  const GeolocalizacionScreen({super.key});

  @override
  State<GeolocalizacionScreen> createState() => _GeolocalizacionScreenState();
}

class _GeolocalizacionScreenState extends State<GeolocalizacionScreen> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final _supabase = Supabase.instance.client;

  // Stream subscriptions
  StreamSubscription<List<Map<String, dynamic>>>? _locationsSubscription;

  Timer? _userLocationTimer;
  bool _hasCenteredMap = false;

  // State
  Position? _currentUserPosition;
  List<Map<String, dynamic>> _allLocations = [];
  Map<String, String> _userNames = {}; // Map<userId, userName>

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePermissionsAndStreams();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _startLocationUpdates();
    } else if (state == AppLifecycleState.paused) {
      _stopLocationUpdates();
    }
  }

  void _initializePermissionsAndStreams() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      await _getInitialLocation(); // Carga rápida de la ubicación inicial desde la DB
      _startLocationUpdates(); // Inicia la actualización precisa por GPS
      _setupSupabaseStreams();
    } else {
      debugPrint('Permiso de ubicación denegado.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El permiso de ubicación es necesario para usar el mapa.'),
        ));
      }
    }
  }
  
  // NUEVO: Carga la última ubicación conocida para una vista inicial rápida
  Future<void> _getInitialLocation() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('localizacion')
          .select('lat, lon')
          .eq('user_id', userId)
          .single();

      if (mounted && response['lat'] != null && response['lon'] != null) {
        setState(() {
          _currentUserPosition = Position(
            latitude: (response['lat'] as num).toDouble(),
            longitude: (response['lon'] as num).toDouble(),
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0
          );
        });
      }
    } catch (e) {
      debugPrint('No se encontró ubicación inicial en la DB: $e');
    }
  }

  void _setupSupabaseStreams() {
    _locationsSubscription = _supabase
        .from('localizacion')
        .stream(primaryKey: ['user_id']).listen((locations) {
      if (!mounted) return;

      final userIds = locations
          .map((loc) => loc['user_id'] as String?)
          .where((id) => id != null)
          .toSet();
      
      _fetchUserNames(userIds);

      setState(() {
        _allLocations = locations;
      });
    }, onError: (e) => debugPrint('Error en stream de localizacion: $e'));
  }

  Future<void> _fetchUserNames(Set<String?> userIds) async {
    final idsToFetch = userIds
        .where((id) => id != null && !_userNames.containsKey(id))
        .cast<String>()
        .toList();

    if (idsToFetch.isEmpty) {
      return;
    }

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
      debugPrint('Error fetching user names: $e');
    }
  }

  void _startLocationUpdates() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || (_userLocationTimer?.isActive ?? false)) return;

    Future<void> updateUserPosition() async {
      try {
        final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.best);
        if (mounted) {
          setState(() => _currentUserPosition = position);
          _updateUserLocationInSupabase(position, currentUserId);
        }
      } catch (e) {
        debugPrint('Error al obtener la ubicación: $e');
      }
    }

    await updateUserPosition();

    _userLocationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
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
      debugPrint('Error al actualizar la ubicación en Supabase: $e');
    }
  }

  void _stopLocationUpdates() {
    _userLocationTimer?.cancel();
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
        if (mounted) {
          _mapController.move(userLatLng!, 16.0);
          _hasCenteredMap = true;
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Usuarios'),
        backgroundColor: const Color(0xFFB71C1C),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                _buildMap(userPosition: userLatLng, allLocations: _allLocations),
                Positioned(
                  bottom: 20,
                  right: 15,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'zoom_in',
                        mini: true,
                        onPressed: () {
                          _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                        },
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton(
                        heroTag: 'zoom_out',
                        mini: true,
                        onPressed: () {
                          _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                        },
                        child: const Icon(Icons.remove),
                      ),
                      const SizedBox(height: 20),
                      FloatingActionButton(
                        heroTag: 'center_location',
                        onPressed: () {
                          if (userLatLng != null) {
                            _mapController.move(userLatLng, 16.0);
                          }
                        },
                        child: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: _buildUserList(allLocations: _allLocations),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList({required List<Map<String, dynamic>> allLocations}) {
    final currentUserId = _supabase.auth.currentUser?.id;
    final otherUsers = allLocations.where((loc) => loc['user_id'] != currentUserId).toList();

    if (otherUsers.isEmpty) {
      return const Center(child: Text("No hay otros usuarios activos.", style: TextStyle(color: Colors.grey)));
    }

    return Container(
      color: Colors.grey[100],
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: otherUsers.length,
        itemBuilder: (context, index) {
          final userLocation = otherUsers[index];
          final userId = userLocation['user_id'];
          final userName = _userNames[userId] ?? 'Cargando...';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.withAlpha(51),
                child: const Icon(Icons.person, color: Colors.green),
              ),
              title: Text(userName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Tocar para ver en el mapa'),
              trailing: IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFFB71C1C)),
                tooltip: 'Comunicarse',
                onPressed: () {
                  if (userName != 'Cargando...') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          otherUserId: userId,
                          otherUserName: userName,
                        ),
                      ),
                    );
                  }
                },
              ),
              onTap: () {
                final lat = userLocation['lat'];
                final lon = userLocation['lon'];
                if (lat != null && lon != null) {
                  _mapController.move(
                    LatLng((lat as num).toDouble(), (lon as num).toDouble()),
                    16.0,
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMap({LatLng? userPosition, required List<Map<String, dynamic>> allLocations}) {
    final List<Marker> allMarkers = [];
    final currentUserId = _supabase.auth.currentUser?.id;

    for (var location in allLocations) {
      final userId = location['user_id'];
      if (userId == currentUserId) continue;

      final lat = location['lat'];
      final lon = location['lon'];

      if (lat == null || lon == null) continue;

      final userName = _userNames[userId] ?? 'Usuario';

      allMarkers.add(Marker(
        width: 80.0,
        height: 80.0,
        point: LatLng((lat as num).toDouble(), (lon as num).toDouble()),
        child: Tooltip(
          message: userName,
          child: Icon(Icons.location_on, color: Colors.green.shade700, size: 40.0),
        ),
      ));
    }

    if (userPosition != null) {
      allMarkers.add(Marker(
        width: 80.0,
        height: 80.0,
        point: userPosition,
        child: const Tooltip(
          message: 'Tu ubicación',
          child: Icon(Icons.my_location, color: Colors.blue, size: 40.0),
        ),
      ));
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: userPosition ?? const LatLng(-1.6709, -78.6471), // Default to Ecuador
        initialZoom: 14.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),
        MarkerLayer(markers: allMarkers),
      ],
    );
  }
}
