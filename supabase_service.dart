import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // ==================== INICIALIZACIÓN ====================
  
  /// Inicialización básica (llamar en main.dart)
  static Future<void> initialize() async {
    await Supabase.initialize(
     url: 'SUPABASE_URL',
      anonKey:'SUPABASE_KEY'
      
    );
  }

  // ==================== AUTENTICACIÓN ====================

  /// Registro de usuario
  static Future<Map<String, dynamic>> registerUser({
    required String name, 
    required String email, 
    required String contrasena,
  }) async {
    try {
      // 1. Crear usuario en autenticación
      final AuthResponse res = await client.auth.signUp(
        email: email,
        password: contrasena,
        data: {
          'name': name, 
        },
      );

      if (res.user != null) {
        // 2. Insertar en la tabla usuarios con el rol por defecto
       return {
          'success': true,
          'message': 'Registro exitoso. Por favor revisa tu correo para confirmar.'
        };
      } else {
        return {'success': false, 'message': 'No se pudo crear el usuario.'};
      }
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Error inesperado: $e'};
    }
  }

  /// Iniciar Sesión
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return {'success': true, 'message': 'Bienvenido'};
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión'};
    }
  }

  /// Iniciar Sesión con datos de usuario (usado por login_screen.dart)
  static Future<Map<String, dynamic>> loginUser({
    required String email, 
    required String contrasena,
  }) async {
    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: contrasena,
      );

      if (response.user != null) {
       
        final userData = await client
            .from('usuarios')
            .select('id, name, email, role, puntos, created_at, updated_at') 
            .eq('id', response.user!.id)
            .single();

        // Debug: Imprimir el rol recibido
        print('🔍 DEBUG: Usuario cargado - ID: ${userData['id']}, Rol: ${userData['role']}');

        return {
          'success': true,
          'message': '¡Bienvenido!',
          'data': userData,
        };
      } else {
        return {'success': false, 'message': 'Error al iniciar sesión'};
      }
    } on AuthException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión: $e'};
    }
  }

  /// Obtener datos actualizados del usuario (para refrescar el rol)
  static Future<Map<String, dynamic>> getCurrentUser(String userId) async {
    try {
      final userData = await client
          .from('usuarios')
          .select('id, name, email, role, puntos, created_at, updated_at') // AGREGADO: puntos
          .eq('id', userId)
          .single();

      return {
        'success': true,
        'data': userData,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al obtener datos del usuario: $e',
      };
    }
  }

  /// Obtener el usuario actual autenticado
  static User? getCurrentAuthUser() {
    return client.auth.currentUser;
  }

  static bool isLoggedIn() {
    return client.auth.currentUser != null;
  }

  /// Cerrar sesión
  static Future<Map<String, dynamic>> signOut() async {
    try {
      await client.auth.signOut();
      return {
        'success': true,
        'message': 'Sesión cerrada correctamente',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al cerrar sesión: $e',
      };
    }
  }

  /// Verificar si el email existe (para recuperación de contraseña)
  static Future<Map<String, dynamic>> checkEmailExists(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email);
      return {'success': true, 'message': 'Si el correo existe, se ha enviado un enlace.'};
    } catch (e) {
      return {'success': false, 'message': 'Error al procesar solicitud'};
    }
  }

  // ==================== GESTIÓN DE USUARIOS ====================

  /// Obtiene todos los usuarios del sistema con sus roles
  static Future<Map<String, dynamic>> getAllUsers() async {
    try {
      print('📋 Obteniendo todos los usuarios...');
      
      // CORRECCIÓN: Obtener usuarios y el rol directamente de la tabla 'usuarios'
      final usersData = await client.rpc('get_all_users');
        print('Usuarios obtenidos de Supabase: ${usersData.length}');
      
   
      //  FIN DEL BLOQUE 

    final List<Map<String, dynamic>> processedUsers = List<Map<String, dynamic>>.from(usersData).map((userData) {
        final role = userData['role'] ?? 'usuario';
        print(' Usuario: ${userData['name']} - Rol en BD: $role');
        return {
          'id': userData['id'],
          'name': userData['name'],
          'email': userData['email'],
          'role': role, 
          'created_at': userData['created_at'],
          'updated_at': userData['updated_at'],
        };
      }).toList();

      //  FIN DEL BLOQUE 

      print('✅ Total procesados: ${processedUsers.length}');

      return {
        'success': true,
        'data': processedUsers,
      };
    } catch (e) {
      print('❌ Error al obtener usuarios: $e');
      return {
        'success': false,
        'message': 'Error al obtener usuarios: $e',
        'data': [],
      };
    }
  }

  /// Obtener un usuario por ID
  static Future<Map<String, dynamic>> getUserById(String userId) async {
    try {
      final response = await client
          .from('usuarios')
          .select('id, name, email, role, puntos, created_at, updated_at') // AGREGADO: puntos
          .eq('id', userId)
          .single();

      return {
        'success': true,
        'data': response,
        'message': 'Usuario encontrado',
      };
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'message': 'Error al obtener usuario: $e',
      };
    }
  }

  /// Actualiza los datos de un usuario incluyendo su rol
  static Future<Map<String, dynamic>> updateUser({
    required String userId,
    required String name, 
    required String email, 
    required String rol,
  }) async {
    try {
      print('🔄 Actualizando usuario $userId');
      print('   Nombre: $name');
      print('   Email: $email');
      print('   Rol: $rol');
      
      await client
          .from('usuarios')
          .update({
            'name': name, 
            'email': email, 
            'role': rol,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      print('✅ Usuario actualizado exitosamente en BD');

      return {
        'success': true,
        'message': 'Usuario actualizado exitosamente',
      };
    } on PostgrestException catch (e) {
      print('❌ Error PostgrestException: ${e.message}');
      return {
        'success': false,
        'message': 'Error de base de datos: ${e.message}',
      };
    } catch (e) {
      print('❌ Error general: $e');
      return {
        'success': false,
        'message': 'Error al actualizar usuario: $e',
      };
    }
  }

  /// Elimina un usuario completamente (autenticación y base de datos)
  static Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      print('🗑️ Intentando eliminar usuario: $userId');
      
      // Primero verificar que el usuario existe
      final userCheck = await client
          .from('usuarios')
          .select('id, name, email')
          .eq('id', userId)
          .maybeSingle();
      
      if (userCheck == null) {
        print(' Usuario no encontrado en la base de datos');
        return {
          'success': false,
          'message': 'Usuario no encontrado',
        };
      }
      
      print(' Usuario encontrado: ${userCheck['name']}');
      print('🔄 Eliminando de la tabla usuarios...');
      
      final deleteResponse = await client
          .from('usuarios')
          .delete()
          .eq('id', userId)
          .select();
      
      print('📊 Respuesta de eliminación: $deleteResponse');

      // Intentar eliminar del auth (esto puede fallar si no hay permisos de admin)
      try {
        print('🔄 Intentando eliminar del auth...');
        await client.auth.admin.deleteUser(userId);
        print('✅ Usuario eliminado del auth');
      } catch (e) {
        print('⚠️ No se pudo eliminar del auth (puede requerir permisos): $e');
      }

      print('✅ Usuario eliminado exitosamente de la BD');
      return {
        'success': true,
        'message': 'Usuario eliminado exitosamente',
      };
    } on PostgrestException catch (e) {
      print('❌ Error PostgrestException: ${e.message}');
      print('   Código: ${e.code}');
      print('   Detalles: ${e.details}');
      return {
        'success': false,
        'message': 'Error de base de datos: ${e.message}',
      };
    } catch (e) {
      print('💥 Error general al eliminar usuario: $e');
      return {
        'success': false,
        'message': 'Error al eliminar usuario: $e',
      };
    }
  }

  // ==================== ROLES ====================

  /// Obtiene los roles disponibles para cambiar, basado en el rol ORIGINAL del usuario.
  static List<String> getAvailableRoles(String originalRole) {
    final rol = originalRole.toLowerCase();
    
    if (rol == 'admin' || rol == 'administrador') {
      return ['admin', 'moderador', 'usuario'];
    } else if (rol == 'moderador') {
      return ['moderador', 'usuario'];
    }
    
    return [];
  }

    // ==================== GESTIÓN DE PUNTOS ====================

  /// Actualizar puntos del usuario
  static Future<Map<String, dynamic>> updateUserPoints({
    required String userId,
    required int points,
  }) async {
    try {
      await client.from('usuarios').update({
        'points': points,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      return {
        'success': true,
        'message': 'Puntos actualizados correctamente',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al actualizar puntos: $e',
      };
    }
  }

  /// Incrementar puntos del usuario
  static Future<Map<String, dynamic>> incrementUserPoints({
    required String userId,
    required int pointsToAdd,
  }) async {
    try {
      final currentUser = await getUserById(userId);
      if (!currentUser['success']) {
        return {
          'success': false,
          'message': 'Usuario no encontrado',
        };
      }

      final currentPoints = currentUser['data']['points'] ?? 0;
      final newPoints = currentPoints + pointsToAdd;

      return await updateUserPoints(userId: userId, points: newPoints);
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al incrementar puntos: $e',
      };
    }
  }

  // ==================== GESTIÓN DE PUNTOS DE INTERCAMBIO ====================
  // (Estos métodos no necesitan cambios ya que no usan las tablas de usuarios)

  /// Obtiene todos los puntos de intercambio
  static Future<Map<String, dynamic>> getPuntosIntercambio() async {
    try {
      final puntos = await client
          .from('puntos_intercambio')
          .select('*')
          .order('created_at', ascending: false);

      return {
        'success': true,
        'data': puntos,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al obtener puntos: $e',
        'data': [],
      };
    }
  }

  /// Crea un nuevo punto de intercambio
  static Future<Map<String, dynamic>> createPuntoIntercambio({
    required String nombre,
    required String descripcion,
    required double latitud,
    required double longitud,
  }) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      await client.from('puntos_intercambio').insert({
        'nombre': nombre,
        'descripcion': descripcion,
        'latitud': latitud,
        'longitud': longitud,
        'creado_por': userId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return {
        'success': true,
        'message': 'Punto creado exitosamente',
      };
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'message': 'Error de base de datos: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al crear punto: $e',
      };
    }
  }

  /// Elimina un punto de intercambio
  static Future<Map<String, dynamic>> deletePuntoIntercambio(String puntoId) async {
    try {
      await client
          .from('puntos_intercambio')
          .delete()
          .eq('id', puntoId);

      return {
        'success': true,
        'message': 'Punto eliminado exitosamente',
      };
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'message': 'Error de base de datos: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error al eliminar punto: $e',
      };
    }
  }

  // ==================== MÉTODOS PARA OBJETOS ====================
  // (Estos métodos no necesitan cambios ya que no usan las tablas de usuarios)

  /// Obtiene todos los objetos disponibles para intercambio (solo aprobados)
  static Future<Map<String, dynamic>> getObjetosDisponibles() async {
    try {
      final response = await client
          .from('productos_unificados')
          .select()
          .eq('disponible', true)
          .eq('estado_aprobacion', 'aprobado')
          .order('creado_en', ascending: false);

      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      print('Error al obtener objetos: $e');
      return {
        'success': false,
        'message': 'Error al cargar objetos: $e',
        'data': [],
      };
    }
  }

  /// Obtiene los objetos del usuario actual
  static Future<Map<String, dynamic>> getMisObjetos() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
          'data': [],
        };
      }

      final response = await client
          .from('productos_unificados')
          .select()
          .eq('usuario_id', userId)
          .order('creado_en', ascending: false);

      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      print('Error al obtener mis objetos: $e');
      return {
        'success': false,
        'message': 'Error al cargar tus objetos: $e',
        'data': [],
      };
    }
  }

  /// Sube una imagen al Storage de Supabase
  static Future<Map<String, dynamic>> uploadImagenObjeto(String filePath) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      final bytes = await File(filePath).readAsBytes();
      final fileExt = filePath.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath2 = '$userId/$fileName';

      await client.storage.from('productos').uploadBinary(
            filePath2,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: false,
            ),
          );

      final imageUrl = client.storage.from('productos').getPublicUrl(filePath2);

      return {
        'success': true,
        'imageUrl': imageUrl,
        'filePath': filePath2,
      };
    } catch (e) {
      print('Error al subir imagen: $e');
      return {
        'success': false,
        'message': 'Error al subir imagen: $e',
      };
    }
  }

  /// Crea un nuevo objeto para intercambio
  static Future<Map<String, dynamic>> createObjeto({
    required String nombre,
    required String descripcion,
    required String categoria,
    required String estado,
    String? imagenUrl,
    int? puntosNecesarios,
  }) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      final data = {
        'usuario_id': userId,
        'nombre': nombre,
        'descripcion': descripcion,
        'categoria': categoria,
        'estado_fisico': estado,
        'disponible': true,
        'estado_aprobacion': 'borrador',
        'puntos_necesarios': puntosNecesarios ?? 6,
      };

      if (imagenUrl != null) {
        data['image_urls'] = [imagenUrl];
      }

      final response = await client.from('productos_unificados').insert(data).select().single();

      return {
        'success': true,
        'data': response,
        'message': 'Objeto creado exitosamente',
      };
    } catch (e) {
      print('Error al crear objeto: $e');
      return {
        'success': false,
        'message': 'Error al crear objeto: $e',
      };
    }
  }

  /// Actualiza un objeto existente
  static Future<Map<String, dynamic>> updateObjeto({
    required String objetoId,
    required String nombre,
    required String descripcion,
    required String categoria,
    required String estado,
    String? imagenUrl,
    bool? disponible,
  }) async {
    try {
      final data = <String, dynamic>{
        'nombre': nombre,
        'descripcion': descripcion,
        'categoria': categoria,
        'estado_fisico': estado, // Cambio: estado → estado_fisico
      };

      // Cambio: imagen_url → image_urls (array)
      if (imagenUrl != null) {
        data['image_urls'] = [imagenUrl]; // Convertir a array
      }
      if (disponible != null) data['disponible'] = disponible;

      // Cambio: objetos → productos_unificados
      await client.from('productos_unificados').update(data).eq('id', objetoId);

      return {
        'success': true,
        'message': 'Objeto actualizado exitosamente',
      };
    } catch (e) {
      print('Error al actualizar objeto: $e');
      return {
        'success': false,
        'message': 'Error al actualizar objeto: $e',
      };
    }
  }

  /// Elimina un objeto
  static Future<Map<String, dynamic>> deleteObjeto(String objetoId) async {
    try {
      final objeto = await client
          .from('productos_unificados')
          .select('image_urls')
          .eq('id', objetoId)
          .single();

      await client.from('productos_unificados').delete().eq('id', objetoId);

      if (objeto['image_urls'] != null) {
        try {
          final imageUrls = List<String>.from(objeto['image_urls'] as List);
          for (final imageUrl in imageUrls) {
            if (imageUrl.isNotEmpty) {
              final filePath = imageUrl.split('/productos/').last;
              await client.storage.from('productos').remove([filePath]);
            }
          }
        } catch (e) {
          print('Error al eliminar imágenes del Storage: $e');
        }
      }

      return {
        'success': true,
        'message': 'Objeto eliminado exitosamente',
      };
    } catch (e) {
      print('Error al eliminar objeto: $e');
      return {
        'success': false,
        'message': 'Error al eliminar objeto: $e',
      };
    }
  }

  /// Marca un objeto como no disponible
  static Future<Map<String, dynamic>> marcarObjetoNoDisponible(String objetoId) async {
    try {
      await client
          .from('productos_unificados')
          .update({'disponible': false})
          .eq('id', objetoId);

      return {
        'success': true,
        'message': 'Objeto marcado como no disponible',
      };
    } catch (e) {
      print('Error al actualizar disponibilidad: $e');
      return {
        'success': false,
        'message': 'Error al actualizar disponibilidad: $e',
      };
    }
  }

  /// Envía un objeto para revisión de admin/moderador
  static Future<Map<String, dynamic>> enviarARevision(String objetoId) async {
    try {
      await client
          .from('productos_unificados')
          .update({'estado_aprobacion': 'pendiente'})
          .eq('id', objetoId);

      return {
        'success': true,
        'message': 'Objeto enviado a revisión',
      };
    } catch (e) {
      print('Error al enviar a revisión: $e');
      return {
        'success': false,
        'message': 'Error al enviar a revisión: $e',
      };
    }
  }

  /// Obtiene todos los objetos pendientes de aprobación (solo admin/moderador)
  static Future<Map<String, dynamic>> getObjetosPendientes() async {
    try {
      final objetosResponse = await client
          .from('productos_unificados')
          .select()
          .eq('estado_aprobacion', 'pendiente')
          .order('creado_en', ascending: false);

      List<Map<String, dynamic>> objetosConUsuario = [];
      
      for (var objeto in objetosResponse) {
        try {
          // CORRECCIÓN: Obtener nombre de usuario directamente
          final usuarioResponse = await client
              .from('usuarios')
              .select('name, email, puntos') // AGREGADO: puntos
              .eq('id', objeto['usuario_id'])
              .single();
          
          objetosConUsuario.add({
            ...objeto,
            'usuarios': usuarioResponse,
          });
        } catch (e) {
          objetosConUsuario.add({
            ...objeto,
            'usuarios': {
              'name': 'Usuario desconocido', // CAMBIO: Clave corregida
              'email': 'N/A', // CAMBIO: Clave corregida
              'puntos': 0, // AGREGADO: puntos por defecto
            },
          });
        }
      }

      return {
        'success': true,
        'data': objetosConUsuario,
      };
    } catch (e) {
      print('Error al obtener objetos pendientes: $e');
      return {
        'success': false,
        'message': 'Error al cargar objetos pendientes: $e',
        'data': [],
      };
    }
  }

  /// Aprueba un objeto (solo admin/moderador)
  static Future<Map<String, dynamic>> aprobarObjeto(String objetoId) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      await client.from('productos_unificados').update({
        'estado_aprobacion': 'aprobado',
        'aprobado_por': userId,
        'fecha_aprobacion': DateTime.now().toIso8601String(),
        'disponible': true,
      }).eq('id', objetoId);

      return {
        'success': true,
        'message': 'Objeto aprobado exitosamente',
      };
    } catch (e) {
      print('Error al aprobar objeto: $e');
      return {
        'success': false,
        'message': 'Error al aprobar objeto: $e',
      };
    }
  }

  /// Rechaza un objeto (solo admin/moderador)
  static Future<Map<String, dynamic>> rechazarObjeto(String objetoId, String motivo) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      await client.from('productos_unificados').update({
        'estado_aprobacion': 'rechazado',
        'aprobado_por': userId,
        'fecha_aprobacion': DateTime.now().toIso8601String(),
        'motivo_rechazo': motivo,
      }).eq('id', objetoId);

      return {
        'success': true,
        'message': 'Objeto rechazado',
      };
    } catch (e) {
      print('Error al rechazar objeto: $e');
      return {
        'success': false,
        'message': 'Error al rechazar objeto: $e',
      };
    }
  }

  // ==================== BÚSQUEDA Y FILTROS ====================

  /// Buscar usuarios por nombre o email
  static Future<Map<String, dynamic>> searchUsers(String query) async {
    try {
      // CORRECCIÓN: Buscar directamente en la tabla usuarios
      final response = await client
          .from('usuarios')
          .select('id, name, email, role, puntos, created_at, updated_at') // AGREGADO: puntos
          .or('name.ilike.%$query%,email.ilike.%$query%') // CAMBIO: Columnas corregidas
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> processedUsers = response.map((userData) {
        return {
          'id': userData['id'],
          'name': userData['name'],
          'email': userData['email'],
          'role': userData['role'] ?? 'usuario', // CORRECCIÓN: Usar 'role' en lugar de 'rol'
          'puntos': userData['puntos'] ?? 0, // AGREGADO: puntos
          'created_at': userData['created_at'],
          'updated_at': userData['updated_at'],
        };
      }).toList();

      return {
        'success': true,
        'data': processedUsers,
        'message': 'Búsqueda completada',
      };
    } catch (e) {
      return {
        'success': false,
        'data': [],
        'message': 'Error en la búsqueda: $e',
      };
    }
  }

  /// Obtener usuarios por rol
  static Future<Map<String, dynamic>> getUsersByRole(String role) async {
    try {
      final usersData = await client
          .from('usuarios')
          .select('id, name, email, role, puntos, created_at, updated_at') // AGREGADO: puntos
          .eq('role', role)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> processedUsers = usersData.map((userData) {
        return {
          'id': userData['id'],
          'name': userData['name'],
          'email': userData['email'],
          'role': userData['role'], // CORRECCIÓN: Usar 'role' en lugar de 'rol'
          'puntos': userData['puntos'] ?? 0, // AGREGADO: puntos
          'created_at': userData['created_at'],
          'updated_at': userData['updated_at'],
        };
      }).toList();

      return {
        'success': true,
        'data': processedUsers,
        'message': 'Usuarios filtrados correctamente',
      };
    } catch (e) {
      return {
        'success': false,
        'data': [],
        'message': 'Error al filtrar usuarios: $e',
      };
    }
  }

  // ==================== ESTADÍSTICAS ====================

  /// Contar total de usuarios
  static Future<Map<String, dynamic>> getTotalUsers() async {
    try {
      final response = await client
          .from('usuarios')
          .select('id')
          .count(CountOption.exact);

      return {
        'success': true,
        'count': response.count ?? 0,
        'message': 'Total de usuarios obtenido',
      };
    } catch (e) {
      return {
        'success': false,
        'count': 0,
        'message': 'Error al contar usuarios: $e',
      };
    }
  }

  /// Contar usuarios por rol
  static Future<Map<String, dynamic>> countUsersByRole() async {
    try {
      final admins = await client.from('usuarios').select('id').eq('role', 'admin').count(CountOption.exact);
      final moderadores = await client.from('usuarios').select('id').eq('role', 'moderador').count(CountOption.exact);
      final usuarios = await client.from('usuarios').select('id').eq('role', 'usuario').count(CountOption.exact);

      return {
        'success': true,
        'data': {
          'admins': admins.count ?? 0,
          'moderadores': moderadores.count ?? 0,
          'usuarios': usuarios.count ?? 0,
        },
        'message': 'Estadísticas obtenidas',
      };
    } catch (e) {
      return {
        'success': false,
        'data': null,
        'message': 'Error al obtener estadísticas: $e',
      };
    }
  }
}