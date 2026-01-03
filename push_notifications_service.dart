import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class PushNotificationsService {
  static final _supabase = Supabase.instance.client;

  /// Método principal que DEBE ejecutarse al iniciar sesión
  static Future<void> initialize() async {
    if (kIsWeb) {
      print('🌐 Notificaciones Push no soportadas en Web en esta versión.');
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) {
      print('⚠️ Error: No hay usuario para registrar el token.');
      return;
    }

    try {
      print('🚀 Iniciando registro de token para: ${user.email}');

      // 1. Asegurar que Firebase esté listo
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final messaging = FirebaseMessaging.instance;

      // 2. Pedir permisos de forma directa
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized || 
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        print('🔔 Permisos concedidos. Capturando token...');

        // 3. Obtener el token (Usamos el método más directo)
        String? token = await messaging.getToken();
        
        if (token != null) {
          print('🎫 TOKEN GENERADO: $token');
          // 4. GUARDAR EN SUPABASE SIN IMPORTAR SI YA EXISTÍA
          await _saveTokenToSupabase(token, user.id);
        } else {
          print('❌ Error: El celular no generó un token.');
        }
      } else {
        print('🚫 El usuario rechazó los permisos de notificación.');
      }
    } catch (e) {
      print('💥 ERROR CRÍTICO EN PUSH SERVICE: $e');
    }
  }

  static Future<void> _saveTokenToSupabase(String token, String userId) async {
    try {
      await _supabase
          .from('usuarios')
          .update({'fcm_token': token})
          .eq('id', userId);
      
      print('✅ ÉXITO: El token de este celular ya está en Supabase.');
    } catch (e) {
      print('❌ Error al escribir en la tabla usuarios de Supabase: $e');
    }
  }

  static Future<void> clearToken() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('usuarios').update({'fcm_token': null}).eq('id', user.id);
        print('🗑️ Token eliminado de Supabase.');
      } catch (e) {}
    }
  }
}
