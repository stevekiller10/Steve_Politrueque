import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'notificaciones_service.dart';

class PuntosService {
  static SupabaseClient get _client => SupabaseService.client;

  // ==================== GESTIÓN DE PUNTOS ====================

  static Future<Map<String, dynamic>> getPuntosUsuario(String userId) async {
    try {
      final response = await _client.from('usuarios').select('puntos').eq('id', userId).single();
      return {'success': true, 'puntos': response['puntos'] ?? 0};
    } catch (e) {
      return {'success': false, 'message': 'Error al obtener puntos: $e', 'puntos': 0};
    }
  }

  static Future<Map<String, dynamic>> getHistorialPuntos(String userId) async {
    try {
      final response = await _client.rpc('get_historial_puntos_usuario', params: {'p_usuario_id': userId});
      return {'success': true, 'data': response};
    } catch (e) {
      return {'success': false, 'message': 'Error al obtener historial: $e', 'data': []};
    }
  }

  // ==================== GESTIÓN DE INTERCAMBIOS ====================

  static Future<Map<String, dynamic>> proponerIntercambio({
    required String usuarioReceptorId,
    required String productoSolicitadoId,
    String? productoOfertadoId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return {'success': false, 'message': 'Usuario no autenticado'};

      final productoSolicitado = await _client.from('productos_unificados').select('puntos_necesarios, nombre').eq('id', productoSolicitadoId).single();
      int puntosProductoOfertado = 0;

      if (productoOfertadoId != null) {
        final validacion = await validarIntercambio(usuarioOfertanteId: userId, usuarioReceptorId: usuarioReceptorId, productoOfertadoId: productoOfertadoId, productoSolicitadoId: productoSolicitadoId);
        if (!validacion['success']) return validacion;
        final productoOfertado = await _client.from('productos_unificados').select('puntos_necesarios').eq('id', productoOfertadoId).single();
        puntosProductoOfertado = productoOfertado['puntos_necesarios'];
      } else {
        final puntosUsuario = await getPuntosUsuario(userId);
        if ((puntosUsuario['puntos'] ?? 0) < productoSolicitado['puntos_necesarios']) {
          return {'success': false, 'message': 'No tienes suficientes puntos para este intercambio'};
        }
      }

      final response = await _client.from('intercambio').insert({
        'id_usuario_ofrece': userId,
        'id_usuario_recibido': usuarioReceptorId,
        'id_producto_ofertado': productoOfertadoId,
        'id_producto_solicitado': productoSolicitadoId,
        'puntos_producto_ofertado': puntosProductoOfertado,
        'puntos_producto_solicitado': productoSolicitado['puntos_necesarios'],
        'estado': 'pendiente',
        'id_articulo_old': 0,
      }).select().single();

      // Notificar al receptor
      final currentUser = await SupabaseService.getUserById(userId);
      print('🔔 NOTIFICACIÓN: Enviando propuesta a receptor ID: $usuarioReceptorId');
      
      await NotificacionesService.notificarPropuestaIntercambio(
        destinatarioId: usuarioReceptorId,
        remitenteNombre: currentUser['data']['name'] ?? 'Un usuario',
        productoNombre: productoSolicitado['nombre'],
      );

      return {'success': true, 'message': 'Intercambio propuesto exitosamente', 'data': response};
    } catch (e) {
      return {'success': false, 'message': 'Error al proponer intercambio: $e'};
    }
  }

  static Future<Map<String, dynamic>> aceptarIntercambio(String intercambioId) async {
    try {
      final intercambio = await _client.from('intercambio')
          .select('id_usuario_ofrece, producto_solicitado:id_producto_solicitado(nombre)')
          .eq('id', intercambioId).single();

      await _client.from('intercambio').update({'estado': 'aceptado'}).eq('id', intercambioId);

      print('🔔 NOTIFICACIÓN: Aceptación enviada a ID: ${intercambio['id_usuario_ofrece']}');

      await NotificacionesService.notificarAccionIntercambio(
        destinatarioId: intercambio['id_usuario_ofrece'],
        titulo: '¡Intercambio Aceptado!',
        mensaje: 'Tu propuesta por ${intercambio['producto_solicitado']['nombre']} ha sido aceptada.',
        intercambioId: intercambioId,
      );

      return {'success': true, 'message': 'Intercambio aceptado'};
    } catch (e) {
      return {'success': false, 'message': 'Error al aceptar intercambio: $e'};
    }
  }

  static Future<Map<String, dynamic>> rechazarIntercambio(String intercambioId) async {
    try {
      final intercambio = await _client.from('intercambio')
          .select('id_usuario_ofrece, producto_solicitado:id_producto_solicitado(nombre)')
          .eq('id', intercambioId).single();

      await _client.from('intercambio').update({'estado': 'rechazado'}).eq('id', intercambioId);

      print('🔔 NOTIFICACIÓN: Rechazo enviado a ID: ${intercambio['id_usuario_ofrece']}');

      await NotificacionesService.notificarAccionIntercambio(
        destinatarioId: intercambio['id_usuario_ofrece'],
        titulo: 'Intercambio Rechazado',
        mensaje: 'Tu propuesta por ${intercambio['producto_solicitado']['nombre']} fue rechazada.',
        intercambioId: intercambioId,
      );

      return {'success': true, 'message': 'Intercambio rechazado'};
    } catch (e) {
      return {'success': false, 'message': 'Error al rechazar intercambio: $e'};
    }
  }

  static Future<Map<String, dynamic>> confirmarIntercambio({
    required String intercambioId,
    required bool esOfertante,
  }) async {
    try {
      final field = esOfertante ? 'confirmado_por_ofertante' : 'confirmado_por_receptor';
      await _client.from('intercambio').update({field: true}).eq('id', intercambioId);
      
      return {'success': true, 'message': 'Confirmación enviada correctamente'};
    } catch (e) {
      return {'success': false, 'message': 'Error al confirmar: $e'};
    }
  }

  static Future<Map<String, dynamic>> validarIntercambio({
    required String usuarioOfertanteId,
    required String usuarioReceptorId,
    required String productoOfertadoId,
    required String productoSolicitadoId,
  }) async {
    try {
      final response = await _client.rpc('validar_puntos_intercambio', params: {
        'p_usuario_ofertante_id': usuarioOfertanteId,
        'p_usuario_receptor_id': usuarioReceptorId,
        'p_producto_ofertado_id': productoOfertadoId,
        'p_producto_solicitado_id': productoSolicitadoId,
      });
      return {'success': response['valido'] ?? false, 'message': response['mensaje'] ?? '', 'data': response};
    } catch (e) {
      return {'success': false, 'message': 'Error al validar intercambio: $e'};
    }
  }

  static Future<Map<String, dynamic>> getMisIntercambios() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return {'success': false, 'message': 'Usuario no autenticado', 'data': []};

      final response = await _client.from('intercambio').select('*, producto_ofertado:id_producto_ofertado(id, nombre, image_urls, puntos_necesarios), producto_solicitado:id_producto_solicitado(id, nombre, image_urls, puntos_necesarios), usuario_ofertante:id_usuario_ofrece(id, name, email), usuario_receptor:id_usuario_recibido(id, name, email)').or('id_usuario_ofrece.eq.$userId,id_usuario_recibido.eq.$userId').order('fecha_intercambio', ascending: false);
      return {'success': true, 'data': response};
    } catch (e) {
      return {'success': false, 'message': 'Error al obtener intercambios: $e', 'data': []};
    }
  }

  static Future<Map<String, dynamic>> getIntercambiosPendientes() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return {'success': false, 'message': 'Usuario no autenticado', 'data': []};

      final response = await _client.from('intercambio')
          .select('*, producto_ofertado:id_producto_ofertado(id, nombre, image_urls, puntos_necesarios), producto_solicitado:id_producto_solicitado(id, nombre, image_urls, puntos_necesarios), usuario_ofertante:id_usuario_ofrece(id, name, email)')
          .eq('id_usuario_recibido', userId)
          .eq('estado', 'pendiente');
      
      return {'success': true, 'data': response};
    } catch (e) {
      return {'success': false, 'message': 'Error al obtener pendientes: $e', 'data': []};
    }
  }
}
