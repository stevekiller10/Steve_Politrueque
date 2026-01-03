import 'package:supabase_flutter/supabase_flutter.dart';

class NotificacionesService {
  static final _supabase = Supabase.instance.client;

  /// Crear una nueva notificación genérica en la base de datos.
  /// Esto disparará el webhook en Supabase que llega a Make.com
  static Future<void> crearNotificacion({
    required String userId,
    required String type,
    required String title,
    String? body,
    String? relatedId,
  }) async {
    try {
      await _supabase.from('notificaciones').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body ?? '',
        'related_id': relatedId,
        'is_read': false,
        'is_hidden': false,
      });
      print('✅ Notificación creada en DB para: $userId');
    } catch (e) {
      print('❌ Error al crear notificación: $e');
    }
  }

  /// Notificar un nuevo mensaje de chat
  static Future<void> notificarNuevoMensaje({
    required String destinatarioId,
    required String remitenteId,
    required String remitenteNombre,
    required String mensaje,
  }) async {
    await crearNotificacion(
      userId: destinatarioId,
      type: 'mensaje',
      title: 'Nuevo mensaje de $remitenteNombre',
      body: mensaje.length > 50 ? '${mensaje.substring(0, 47)}...' : mensaje,
      relatedId: remitenteId,
    );
  }

  /// Notificar propuesta de intercambio
  static Future<void> notificarPropuestaIntercambio({
    required String destinatarioId,
    required String remitenteNombre,
    required String productoNombre,
  }) async {
    await crearNotificacion(
      userId: destinatarioId,
      type: 'intercambio',
      title: 'Propuesta de Intercambio',
      body: '$remitenteNombre quiere intercambiar tu producto: $productoNombre',
    );
  }

  /// Notificar acción de intercambio (Aceptado/Rechazado)
  static Future<void> notificarAccionIntercambio({
    required String destinatarioId,
    required String titulo,
    required String mensaje,
    required String intercambioId,
  }) async {
    await crearNotificacion(
      userId: destinatarioId,
      type: 'intercambio',
      title: titulo,
      body: mensaje,
      relatedId: intercambioId,
    );
  }

  /// Contar notificaciones no leídas
  static Stream<int> contarNoLeidasStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(0);

    return _supabase
        .from('notificaciones')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
          return data.where((n) => n['is_read'] == false && n['is_hidden'] == false).length;
        });
  }

  /// Marcar como leída
  static Future<void> marcarComoLeida(int id) async {
    await _supabase.from('notificaciones').update({'is_read': true}).eq('id', id);
  }

  /// Marcar como NO leída
  static Future<void> marcarComoNoLeida(int id) async {
    await _supabase.from('notificaciones').update({'is_read': false}).eq('id', id);
  }

  /// Marcar todas como leídas
  static Future<bool> marcarTodasComoLeidas() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _supabase
          .from('notificaciones')
          .update({'is_read': true})
          .eq('user_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Eliminar una notificación (la ocultamos)
  static Future<bool> eliminarNotificacion(int id) async {
    try {
      await _supabase.from('notificaciones').update({'is_hidden': true}).eq('id', id);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Eliminar todas las notificaciones del usuario (las ocultamos)
  static Future<bool> eliminarTodas() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      await _supabase
          .from('notificaciones')
          .update({'is_hidden': true})
          .eq('user_id', userId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// STREAM DE NOTIFICACIONES
  static Stream<List<Map<String, dynamic>>> streamNotificaciones() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('notificaciones')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((data) {
          final list = data.where((item) => item['is_hidden'] == false).toList();
          list.sort((a, b) => b['created_at'].compareTo(a['created_at']));
          return list;
        });
  }
}
