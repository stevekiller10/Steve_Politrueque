import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../modelo/user.model.dart';

class UserRoleService {
  static Timer? _roleCheckTimer;
  static String? _currentUserId;
  static String? _currentRole;
  static Function(UserModel)? _onRoleChanged;

  /// Iniciar monitoreo automático de cambios de rol
  static void startRoleMonitoring({
    required String userId,
    required String currentRole,
    required Function(UserModel) onRoleChanged,
  }) {
    _currentUserId = userId;
    _currentRole = currentRole;
    _onRoleChanged = onRoleChanged;

    // Cancelar timer anterior si existe
    _roleCheckTimer?.cancel();

    if (kDebugMode) {
      print('🔄 Iniciando monitoreo de rol para usuario: $userId');
    }

    // Verificar cambios cada 15 segundos
    _roleCheckTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _checkRoleChange();
    });
  }

  /// Detener monitoreo
  static void stopRoleMonitoring() {
    _roleCheckTimer?.cancel();
    _roleCheckTimer = null;
    _currentUserId = null;
    _currentRole = null;
    _onRoleChanged = null;

    if (kDebugMode) {
      print('⏹️ Monitoreo de rol detenido');
    }
  }

  /// Verificar si el rol ha cambiado
  static Future<void> _checkRoleChange() async {
    if (_currentUserId == null || _currentRole == null || _onRoleChanged == null) {
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('usuarios')
          .select('id, name, email, role, created_at')
          .eq('id', _currentUserId!)
          .maybeSingle();

      if (response != null) {
        final newRole = response['role'] as String;
        
        if (kDebugMode) {
          print('🔍 Verificando rol - Actual: $_currentRole, DB: $newRole');
        }
        
        // Si el rol cambió
        if (newRole != _currentRole) {
          if (kDebugMode) {
            print('🔄 ¡ROL CAMBIADO DETECTADO! $_currentRole → $newRole');
            print('📋 Datos del usuario: ${response.toString()}');
          }

          _currentRole = newRole;
          final updatedUser = UserModel.fromJson(response);
          
          if (kDebugMode) {
            print('👤 Usuario actualizado creado: ${updatedUser.nombreCompleto} - Rol: ${updatedUser.rol}');
            print('🔄 Llamando callback _onRoleChanged...');
          }
          
          _onRoleChanged!(updatedUser);
          
          if (kDebugMode) {
            print('✅ Callback _onRoleChanged ejecutado');
          }
        } else {
          if (kDebugMode) {
            print('⏸️ Sin cambios de rol detectados');
          }
        }
      } else {
        if (kDebugMode) {
          print('❌ No se encontró usuario en la base de datos');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al verificar cambio de rol: $e');
      }
    }
  }

  /// Verificar rol manualmente (para botón de actualizar)
  static Future<UserModel?> checkRoleNow(String userId) async {
    try {
      if (kDebugMode) {
        print('🔍 Verificación manual de rol para usuario: $userId');
      }
      
      final response = await Supabase.instance.client
          .from('usuarios')
          .select('id, name, email, role, created_at')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        if (kDebugMode) {
          print('📋 Datos obtenidos: ${response.toString()}');
        }
        
        final user = UserModel.fromJson(response);
        
        if (kDebugMode) {
          print('👤 Usuario creado: ${user.nombreCompleto} - Rol: ${user.rol}');
        }
        
        return user;
      } else {
        if (kDebugMode) {
          print('❌ No se encontraron datos para el usuario');
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al verificar rol manualmente: $e');
      }
      return null;
    }
  }
}