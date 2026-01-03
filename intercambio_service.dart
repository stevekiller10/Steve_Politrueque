import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../modelo/intercambio.dart';
import '../modelo/puntos_intercambio.dart';

class IntercambioService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==================== PUNTOS DE INTERCAMBIO ====================

  Future<List<PuntosIntercambio>> obtenerPuntosIntercambio() async {
    try {
      final response = await _supabase.from('puntos_intercambio').select().order('nombre');
      return (response as List).map((json) => PuntosIntercambio.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error al obtener puntos de intercambio: $e');
    }
  }

  Future<List<PuntosIntercambio>> obtenerPuntosIntercambioCercanos({
    required double latitud,
    required double longitud,
    double radioKm = 10.0,
  }) async {
    try {
      final response = await _supabase.rpc('puntos_intercambio_cercanos', params: {
        'lat_usuario': latitud,
        'lng_usuario': longitud,
        'radio_km': radioKm,
      });
      return (response as List).map((json) => PuntosIntercambio.fromJson(json)).toList();
    } catch (e) {
      final todosPuntos = await obtenerPuntosIntercambio();
      return todosPuntos.where((punto) {
        final distancia = _calcularDistancia(latitud, longitud, punto.latitud, punto.longitud);
        return distancia <= radioKm;
      }).toList();
    }
  }

  Future<PuntosIntercambio> crearPuntoIntercambio(PuntosIntercambio punto) async {
    try {
      final response = await _supabase.from('puntos_intercambio').insert(punto.toInsertJson()).select().single();
      return PuntosIntercambio.fromJson(response);
    } catch (e) {
      throw Exception('Error al crear punto de intercambio: $e');
    }
  }

  // ==================== INTERCAMBIOS ====================

  Future<Intercambio> crearIntercambio({
    required String idUsuarioRecibido,
    String? idProductoOfertado,
    String? idProductoSolicitado,
    Map<String, dynamic>? productoSolicitado,
  }) async {
    try {
      final usuarioActual = _supabase.auth.currentUser;
      if (usuarioActual == null) {
        throw Exception('Usuario no autenticado');
      }
      final response = await _supabase.from('intercambio').insert({
        'id_usuario_ofrece': usuarioActual.id,
        'id_usuario_recibido': idUsuarioRecibido,
        'id_producto_ofertado': idProductoOfertado,
        'id_producto_solicitado': idProductoSolicitado,
        'estado': 'pendiente',
        'fecha_intercambio': DateTime.now().toIso8601String(),
        'id_articulo_old': 0,
      }).select().single();
      return Intercambio.fromJson(response);
    } catch (e) {
      throw Exception('Error al crear intercambio: $e');
    }
  }

  Future<List<Intercambio>> obtenerMisIntercambios() async {
    try {
      final usuarioActual = _supabase.auth.currentUser;
      if (usuarioActual == null) {
        throw Exception('Usuario no autenticado');
      }
      final response = await _supabase
          .from('intercambio')
          .select('*, usuario_ofertante:id_usuario_ofrece(*), usuario_receptor:id_usuario_recibido(*), producto_solicitado:id_producto_solicitado(*), producto_ofertado:id_producto_ofertado(*)')
          .or('id_usuario_ofrece.eq.${usuarioActual.id},id_usuario_recibido.eq.${usuarioActual.id}')
          .order('fecha_intercambio', ascending: false);
      return (response as List).map((json) => Intercambio.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error al obtener intercambios: $e');
    }
  }

  Future<List<Intercambio>> obtenerIntercambiosPendientes() async {
    try {
      final usuarioActual = _supabase.auth.currentUser;
      if (usuarioActual == null) throw Exception('Usuario no autenticado');
      
      final response = await _supabase
          .from('intercambio')
          .select('*, usuario_ofertante:id_usuario_ofrece(*), usuario_receptor:id_usuario_recibido(*), producto_solicitado:id_producto_solicitado(*), producto_ofertado:id_producto_ofertado(*)')
          .eq('id_usuario_recibido', usuarioActual.id)
          .eq('estado', 'pendiente');
          
      return (response as List).map((json) => Intercambio.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Intercambio> aceptarIntercambio(int idIntercambio) async {
    try {
      final response = await _supabase.from('intercambio').update({'estado': EstadoIntercambio.aceptado.value}).eq('id_intercambio', idIntercambio).select().single();
      return Intercambio.fromJson(response);
    } catch (e) {
      throw Exception('Error al aceptar intercambio: $e');
    }
  }

  Future<Intercambio> rechazarIntercambio(int idIntercambio) async {
    try {
      final response = await _supabase.from('intercambio').update({'estado': EstadoIntercambio.rechazado.value}).eq('id_intercambio', idIntercambio).select().single();
      return Intercambio.fromJson(response);
    } catch (e) {
      throw Exception('Error al rechazar intercambio: $e');
    }
  }

  Future<void> calificarIntercambio({
    required int idIntercambio,
    required double calificacion,
    String? comentario,
    bool esOfertante = true,
  }) async {
    try {
      await _supabase.from('calificaciones').insert({
        'id_intercambio': idIntercambio,
        'puntuacion': calificacion,
        'comentario': comentario,
        'fecha': DateTime.now().toIso8601String(),
        'es_ofertante': esOfertante,
      });
    } catch (e) {
      throw Exception('Error al calificar intercambio: $e');
    }
  }

  Future<void> confirmarEntregaOfertante(int idIntercambio) async {
    try {
      await _supabase.from('intercambio').update({'confirmado_por_ofertante': true}).eq('id_intercambio', idIntercambio);
    } catch (e) {
      throw Exception('Error al confirmar entrega: $e');
    }
  }

  Future<void> confirmarRecepcionReceptor(int idIntercambio) async {
    try {
      await _supabase.from('intercambio').update({'confirmado_por_receptor': true}).eq('id_intercambio', idIntercambio);
    } catch (e) {
      throw Exception('Error al confirmar recepción: $e');
    }
  }
  
  double _calcularDistancia(double lat1, double lon1, double lat2, double lon2) {
    const double radioTierra = 6371;
    final double dLat = _gradosARadianes(lat2 - lat1);
    final double dLon = _gradosARadianes(lon2 - lon1);
    final double a = sin(dLat / 2) * sin(dLat / 2) + cos(_gradosARadianes(lat1)) * cos(_gradosARadianes(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radioTierra * c;
  }

  double _gradosARadianes(double grados) {
    return grados * (pi / 180);
  }
}
