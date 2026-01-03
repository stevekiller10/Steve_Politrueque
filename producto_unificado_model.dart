import 'package:trueque/modelo/user.model.dart';

class ProductoUnificado {
  final String id;
  final String usuarioId;
  final String nombre;
  final String descripcion;
  final String categoria;
  final String estadoFisico;
  final int puntosNecesarios;
  final String? ubicacion;
  final List<String> imageUrls;
  final bool disponible;
  final String estadoAprobacion;
  final String? aprobadoPor;
  final DateTime? fechaAprobacion;
  final String? motivoRechazo;
  final DateTime creadoEn;
  final DateTime actualizadoEn;
  final UserModel? usuario;

  ProductoUnificado({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.descripcion,
    required this.categoria,
    required this.estadoFisico,
    required this.puntosNecesarios,
    this.ubicacion,
    required this.imageUrls,
    this.disponible = true,
    this.estadoAprobacion = 'borrador',
    this.aprobadoPor,
    this.fechaAprobacion,
    this.motivoRechazo,
    required this.creadoEn,
    required this.actualizadoEn,
    this.usuario,
  });

  factory ProductoUnificado.fromJson(Map<String, dynamic> json) {
    return ProductoUnificado(
      id: json['id'] ?? '',
      usuarioId: json['usuario_id'] ?? '',
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      categoria: json['categoria'] ?? '',
      estadoFisico: json['estado_fisico'] ?? 'buen_estado',
      puntosNecesarios: json['puntos_necesarios'] ?? 0,
      ubicacion: json['ubicacion'],
      imageUrls: _parseImageUrls(json['image_urls']),
      disponible: json['disponible'] ?? true,
      estadoAprobacion: json['estado_aprobacion'] ?? 'borrador',
      aprobadoPor: json['aprobado_por'],
      fechaAprobacion: json['fecha_aprobacion'] != null ? DateTime.parse(json['fecha_aprobacion']) : null,
      motivoRechazo: json['motivo_rechazo'],
      creadoEn: json['creado_en'] != null ? DateTime.parse(json['creado_en']) : DateTime.now(),
      actualizadoEn: json['actualizado_en'] != null ? DateTime.parse(json['actualizado_en']) : DateTime.now(),
      usuario: json['usuario'] != null ? UserModel.fromJson(json['usuario']) : null,
    );
  }

  static List<String> _parseImageUrls(dynamic imageUrls) {
    if (imageUrls == null) return [];
    if (imageUrls is List) return imageUrls.map((url) => url.toString()).toList();
    if (imageUrls is String) {
      if (imageUrls.startsWith('[')) {
        try {
          final List<dynamic> parsed = imageUrls as List<dynamic>;
          return parsed.map((url) => url.toString()).toList();
        } catch (e) {
          return [imageUrls];
        }
      }
      return [imageUrls];
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria': categoria,
      'estado_fisico': estadoFisico,
      'puntos_necesarios': puntosNecesarios,
      'ubicacion': ubicacion,
      'image_urls': imageUrls,
      'disponible': disponible,
      'estado_aprobacion': estadoAprobacion,
      'aprobado_por': aprobadoPor,
      'fecha_aprobacion': fechaAprobacion?.toIso8601String(),
      'motivo_rechazo': motivoRechazo,
      'creado_en': creadoEn.toIso8601String(),
      'actualizado_en': actualizadoEn.toIso8601String(),
    };
  }

  String getPuntosLabel() {
    if (puntosNecesarios <= 2) return '1-2 puntos';
    if (puntosNecesarios <= 4) return '3-4 puntos';
    if (puntosNecesarios <= 6) return '5-6 puntos';
    if (puntosNecesarios <= 8) return '7-8 puntos';
    return '9-10 puntos';
  }

  String getEstadoFisicoLabel() {
    switch (estadoFisico) {
      case 'nuevo': return 'Nuevo';
      case 'como_nuevo': return 'Como nuevo';
      case 'buen_estado': return 'Buen estado';
      case 'usado': return 'Usado';
      case 'para_reparar': return 'Para reparar';
      default: return estadoFisico;
    }
  }

  String getEstadoAprobacionLabel() {
    switch (estadoAprobacion) {
      case 'borrador': return 'Borrador';
      case 'pendiente': return 'En Revisión';
      case 'aprobado': return 'Aprobado';
      case 'rechazado': return 'Rechazado';
      default: return estadoAprobacion;
    }
  }

  ProductoUnificado copyWith({ String? id, String? usuarioId, String? nombre, String? descripcion, String? categoria, String? estadoFisico, int? puntosNecesarios, String? ubicacion, List<String>? imageUrls, bool? disponible, String? estadoAprobacion, String? aprobadoPor, DateTime? fechaAprobacion, String? motivoRechazo, DateTime? creadoEn, DateTime? actualizadoEn, UserModel? usuario,}) {
    return ProductoUnificado(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      categoria: categoria ?? this.categoria,
      estadoFisico: estadoFisico ?? this.estadoFisico,
      puntosNecesarios: puntosNecesarios ?? this.puntosNecesarios,
      ubicacion: ubicacion ?? this.ubicacion,
      imageUrls: imageUrls ?? this.imageUrls,
      disponible: disponible ?? this.disponible,
      estadoAprobacion: estadoAprobacion ?? this.estadoAprobacion,
      aprobadoPor: aprobadoPor ?? this.aprobadoPor,
      fechaAprobacion: fechaAprobacion ?? this.fechaAprobacion,
      motivoRechazo: motivoRechazo ?? this.motivoRechazo,
      creadoEn: creadoEn ?? this.creadoEn,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
      usuario: usuario ?? this.usuario,
    );
  }
}

// CORRECCIÓN: Se añaden las clases de ayuda que faltaban.
class OpcionesPuntos {
  static const List<Map<String, dynamic>> opciones = [
    {'label': '1-2 puntos (Para reparar)', 'value': 2},
    {'label': '3-4 puntos (Usado)', 'value': 4},
    {'label': '5-6 puntos (Buen estado)', 'value': 6},
    {'label': '7-8 puntos (Como nuevo)', 'value': 8},
    {'label': '9-10 puntos (Nuevo)', 'value': 10},
  ];

  static int getPuntosPorEstado(String estadoFisico) {
    switch (estadoFisico) {
      case 'para_reparar': return 2;
      case 'usado': return 4;
      case 'buen_estado': return 6;
      case 'como_nuevo': return 8;
      case 'nuevo': return 10;
      default: return 6;
    }
  }
}

class EstadosFisicos {
  static const List<Map<String, String>> estados = [
    {'value': 'nuevo', 'label': 'Nuevo'},
    {'value': 'como_nuevo', 'label': 'Como nuevo'},
    {'value': 'buen_estado', 'label': 'Buen estado'},
    {'value': 'usado', 'label': 'Usado'},
    {'value': 'para_reparar', 'label': 'Para reparar'},
  ];
}

class Categorias {
  static const List<String> lista = [
    'Electrónicos',
    'Comida',
    'Ropa',
    'Útiles Escolares',
    'Deportes',
    'Hogar',
    'Otros',
  ];
}
