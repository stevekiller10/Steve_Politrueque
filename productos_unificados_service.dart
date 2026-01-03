import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../modelo/producto_unificado_model.dart';

/// Servicio unificado para gestión de productos
/// Combina lo mejor de ambos sistemas anteriores
class ProductosUnificadosService {
  static SupabaseClient get client => Supabase.instance.client;

  // ==================== OBTENER PRODUCTOS ====================

  /// Obtiene todos los productos aprobados y disponibles
  static Future<Map<String, dynamic>> getProductosDisponibles() async {
    try {
      final response = await client
          .from('productos_unificados')
          .select()
          .eq('disponible', true)
          .eq('estado_aprobacion', 'aprobado')
          .order('creado_en', ascending: false);

      final List<ProductoUnificado> productos = (response as List)
          .map((json) => ProductoUnificado.fromJson(json))
          .toList();

      return {
        'success': true,
        'data': productos,
      };
    } catch (e) {
      print('Error al obtener productos: $e');
      return {
        'success': false,
        'message': 'Error al cargar productos: $e',
        'data': [],
      };
    }
  }

  /// Obtiene productos filtrados por categoría
  static Future<Map<String, dynamic>> getProductosPorCategoria(
      String categoria) async {
    try {
      final response = await client
          .from('productos_unificados')
          .select()
          .eq('categoria', categoria)
          .eq('disponible', true)
          .eq('estado_aprobacion', 'aprobado')
          .order('creado_en', ascending: false);

      final List<ProductoUnificado> productos = (response as List)
          .map((json) => ProductoUnificado.fromJson(json))
          .toList();

      return {
        'success': true,
        'data': productos,
      };
    } catch (e) {
      print('Error al obtener productos por categoría: $e');
      return {
        'success': false,
        'message': 'Error al cargar productos: $e',
        'data': [],
      };
    }
  }

  /// Obtiene productos filtrados por puntos
  static Future<Map<String, dynamic>> getProductosPorPuntos(int puntos) async {
    try {
      final response = await client
          .from('productos_unificados')
          .select()
          .eq('puntos_necesarios', puntos)
          .eq('disponible', true)
          .eq('estado_aprobacion', 'aprobado')
          .order('creado_en', ascending: false);

      final List<ProductoUnificado> productos = (response as List)
          .map((json) => ProductoUnificado.fromJson(json))
          .toList();

      return {
        'success': true,
        'data': productos,
      };
    } catch (e) {
      print('Error al obtener productos por puntos: $e');
      return {
        'success': false,
        'message': 'Error al cargar productos: $e',
        'data': [],
      };
    }
  }

  /// Obtiene los productos del usuario actual
  static Future<Map<String, dynamic>> getMisProductos() async {
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

      final List<ProductoUnificado> productos = (response as List)
          .map((json) => ProductoUnificado.fromJson(json))
          .toList();

      return {
        'success': true,
        'data': productos,
      };
    } catch (e) {
      print('Error al obtener mis productos: $e');
      return {
        'success': false,
        'message': 'Error al cargar tus productos: $e',
        'data': [],
      };
    }
  }

  /// Obtiene un producto por ID
  static Future<Map<String, dynamic>> getProductoPorId(String productoId) async {
    try {
      final response = await client
          .from('productos_unificados')
          .select()
          .eq('id', productoId)
          .single();

      final producto = ProductoUnificado.fromJson(response);

      return {
        'success': true,
        'data': producto,
      };
    } catch (e) {
      print('Error al obtener producto: $e');
      return {
        'success': false,
        'message': 'Error al cargar producto: $e',
      };
    }
  }

  // ==================== CREAR Y ACTUALIZAR ====================

  /// Crea un nuevo producto
  static Future<Map<String, dynamic>> createProducto({
    required String nombre,
    required String descripcion,
    required String categoria,
    required String estadoFisico,
    required int puntosNecesarios,
    String? ubicacion,
    List<String>? imageUrls,
  }) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      final response = await client.from('productos_unificados').insert({
        'usuario_id': userId,
        'nombre': nombre,
        'descripcion': descripcion,
        'categoria': categoria,
        'estado_fisico': estadoFisico,
        'puntos_necesarios': puntosNecesarios,
        'ubicacion': ubicacion,
        'image_urls': imageUrls ?? [],
        'disponible': true,
        'estado_aprobacion': 'pendiente',
      }).select().single();

      final producto = ProductoUnificado.fromJson(response);

      return {
        'success': true,
        'data': producto,
        'message': 'Producto creado exitosamente',
      };
    } catch (e) {
      print('Error al crear producto: $e');
      return {
        'success': false,
        'message': 'Error al crear producto: $e',
      };
    }
  }

  /// Actualiza un producto existente
  static Future<Map<String, dynamic>> updateProducto({
    required String productoId,
    required String nombre,
    required String descripcion,
    required String categoria,
    required String estadoFisico,
    required int puntosNecesarios,
    String? ubicacion,
    List<String>? imageUrls,
  }) async {
    try {
      final data = <String, dynamic>{
        'nombre': nombre,
        'descripcion': descripcion,
        'categoria': categoria,
        'estado_fisico': estadoFisico,
        'puntos_necesarios': puntosNecesarios,
        'ubicacion': ubicacion,
      };

      if (imageUrls != null) {
        data['image_urls'] = imageUrls;
      }

      await client
          .from('productos_unificados')
          .update(data)
          .eq('id', productoId);

      return {
        'success': true,
        'message': 'Producto actualizado exitosamente',
      };
    } catch (e) {
      print('Error al actualizar producto: $e');
      return {
        'success': false,
        'message': 'Error al actualizar producto: $e',
      };
    }
  }

  /// Elimina un producto
  static Future<Map<String, dynamic>> deleteProducto(String productoId) async {
    try {
      // Obtener URLs de imágenes para eliminarlas del storage
      final producto = await client
          .from('productos_unificados')
          .select('image_urls')
          .eq('id', productoId)
          .single();

      // Eliminar producto de la BD
      await client.from('productos_unificados').delete().eq('id', productoId);

      // Intentar eliminar imágenes del storage
      if (producto['image_urls'] != null) {
        final List<String> imageUrls =
            List<String>.from(producto['image_urls']);
        for (final imageUrl in imageUrls) {
          try {
            final filePath = imageUrl.split('/productos_unificados/').last;
            await client.storage.from('productos_unificados').remove([filePath]);
          } catch (e) {
            print('Error al eliminar imagen del Storage: $e');
          }
        }
      }

      return {
        'success': true,
        'message': 'Producto eliminado exitosamente',
      };
    } catch (e) {
      print('Error al eliminar producto: $e');
      return {
        'success': false,
        'message': 'Error al eliminar producto: $e',
      };
    }
  }

  // ==================== GESTIÓN DE IMÁGENES ====================

  /// Sube una imagen al Storage de Supabase
  static Future<Map<String, dynamic>> uploadImagen(String filePath) async {
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
      final storagePath = '$userId/$fileName';

      await client.storage.from('productos_unificados').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$fileExt',
              upsert: false,
            ),
          );

      final imageUrl =
          client.storage.from('productos_unificados').getPublicUrl(storagePath);

      return {
        'success': true,
        'imageUrl': imageUrl,
        'filePath': storagePath,
      };
    } catch (e) {
      print('Error al subir imagen: $e');
      return {
        'success': false,
        'message': 'Error al subir imagen: $e',
      };
    }
  }

  /// Sube múltiples imágenes
  static Future<Map<String, dynamic>> uploadMultiplesImagenes(
      List<String> filePaths) async {
    try {
      final List<String> imageUrls = [];

      for (final filePath in filePaths) {
        final result = await uploadImagen(filePath);
        if (result['success']) {
          imageUrls.add(result['imageUrl']);
        } else {
          return {
            'success': false,
            'message': 'Error al subir una de las imágenes',
          };
        }
      }

      return {
        'success': true,
        'imageUrls': imageUrls,
      };
    } catch (e) {
      print('Error al subir múltiples imágenes: $e');
      return {
        'success': false,
        'message': 'Error al subir imágenes: $e',
      };
    }
  }

  // ==================== FLUJO DE APROBACIÓN ====================

  /// Envía un producto para revisión
  static Future<Map<String, dynamic>> enviarARevision(String productoId) async {
    try {
      await client.from('productos_unificados').update({
        'estado_aprobacion': 'pendiente',
      }).eq('id', productoId);

      return {
        'success': true,
        'message': 'Producto enviado a revisión',
      };
    } catch (e) {
      print('Error al enviar a revisión: $e');
      return {
        'success': false,
        'message': 'Error al enviar a revisión: $e',
      };
    }
  }

  /// Obtiene productos pendientes de aprobación (admin/moderador)
  static Future<Map<String, dynamic>> getProductosPendientes() async {
    try {
      final response = await client
          .from('productos_unificados')
          .select()
          .eq('estado_aprobacion', 'pendiente')
          .order('creado_en', ascending: false);

      return {
        'success': true,
        'data': response,
      };
    } catch (e) {
      print('Error al obtener productos pendientes: $e');
      return {
        'success': false,
        'message': 'Error al cargar productos pendientes: $e',
        'data': [],
      };
    }
  }

  /// Aprueba un producto (admin/moderador)
  /// Permite ajustar los puntos y categoría si no están acordes al producto
  static Future<Map<String, dynamic>> aprobarProducto(
    String productoId, {
    int? puntosAjustados,
    String? categoriaAjustada,
  }) async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return {
          'success': false,
          'message': 'Usuario no autenticado',
        };
      }

      final updateData = {
        'estado_aprobacion': 'aprobado',
        'aprobado_por': userId,
        'fecha_aprobacion': DateTime.now().toIso8601String(),
        'disponible': true,
      };

      // Si el moderador/administrador ajusta los puntos, actualizarlos
      if (puntosAjustados != null) {
        updateData['puntos_necesarios'] = puntosAjustados;
        print('🔍 SERVICE: Ajustando puntos a $puntosAjustados');
      } else {
        print('🔍 SERVICE: No se ajustan puntos (null)');
      }

      // Si el moderador/administrador ajusta la categoría, actualizarla
      if (categoriaAjustada != null) {
        updateData['categoria'] = categoriaAjustada;
        print('🔍 SERVICE: Ajustando categoría a $categoriaAjustada');
      } else {
        print('🔍 SERVICE: No se ajusta categoría (null)');
      }

      print('🔍 SERVICE: updateData = $updateData');
      
      await client.from('productos_unificados').update(updateData).eq('id', productoId);
      
      print('🔍 SERVICE: Update ejecutado exitosamente');

      return {
        'success': true,
        'message': 'Producto aprobado exitosamente',
      };
    } catch (e) {
      print('Error al aprobar producto: $e');
      return {
        'success': false,
        'message': 'Error al aprobar producto: $e',
      };
    }
  }

  /// Rechaza un producto (admin/moderador)
  static Future<Map<String, dynamic>> rechazarProducto(
      String productoId, String motivo) async {
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
      }).eq('id', productoId);

      return {
        'success': true,
        'message': 'Producto rechazado',
      };
    } catch (e) {
      print('Error al rechazar producto: $e');
      return {
        'success': false,
        'message': 'Error al rechazar producto: $e',
      };
    }
  }

  // ==================== DISPONIBILIDAD ====================

  /// Marca un producto como no disponible (intercambiado)
  static Future<Map<String, dynamic>> marcarComoIntercambiado(
      String productoId) async {
    try {
      await client
          .from('productos_unificados')
          .update({'disponible': false})
          .eq('id', productoId);

      return {
        'success': true,
        'message': 'Producto marcado como intercambiado',
      };
    } catch (e) {
      print('Error al actualizar disponibilidad: $e');
      return {
        'success': false,
        'message': 'Error al actualizar disponibilidad: $e',
      };
    }
  }

  /// Marca un producto como disponible nuevamente
  static Future<Map<String, dynamic>> marcarComoDisponible(
      String productoId) async {
    try {
      await client
          .from('productos_unificados')
          .update({'disponible': true})
          .eq('id', productoId);

      return {
        'success': true,
        'message': 'Producto marcado como disponible',
      };
    } catch (e) {
      print('Error al actualizar disponibilidad: $e');
      return {
        'success': false,
        'message': 'Error al actualizar disponibilidad: $e',
      };
    }
  }

  // ==================== BÚSQUEDA Y FILTROS ====================

  /// Busca productos por texto
  static Future<Map<String, dynamic>> buscarProductos(String query) async {
    try {
      final response = await client
          .from('productos_unificados')
          .select()
          .or('nombre.ilike.%$query%,descripcion.ilike.%$query%')
          .eq('disponible', true)
          .eq('estado_aprobacion', 'aprobado')
          .order('creado_en', ascending: false);

      final List<ProductoUnificado> productos = (response as List)
          .map((json) => ProductoUnificado.fromJson(json))
          .toList();

      return {
        'success': true,
        'data': productos,
      };
    } catch (e) {
      print('Error al buscar productos: $e');
      return {
        'success': false,
        'message': 'Error en la búsqueda: $e',
        'data': [],
      };
    }
  }

  // ==================== ESTADÍSTICAS ====================

  /// Obtiene estadísticas de productos
  static Future<Map<String, dynamic>> getEstadisticas() async {
    try {
      final total = await client
          .from('productos_unificados')
          .select('id')
          .count(CountOption.exact);

      final aprobados = await client
          .from('productos_unificados')
          .select('id')
          .eq('estado_aprobacion', 'aprobado')
          .count(CountOption.exact);

      final pendientes = await client
          .from('productos_unificados')
          .select('id')
          .eq('estado_aprobacion', 'pendiente')
          .count(CountOption.exact);

      final disponibles = await client
          .from('productos_unificados')
          .select('id')
          .eq('disponible', true)
          .eq('estado_aprobacion', 'aprobado')
          .count(CountOption.exact);

      return {
        'success': true,
        'data': {
          'total': total.count ?? 0,
          'aprobados': aprobados.count ?? 0,
          'pendientes': pendientes.count ?? 0,
          'disponibles': disponibles.count ?? 0,
        },
      };
    } catch (e) {
      print('Error al obtener estadísticas: $e');
      return {
        'success': false,
        'message': 'Error al obtener estadísticas: $e',
      };
    }
  }
}
