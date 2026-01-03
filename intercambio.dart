import 'package:trueque/modelo/producto_unificado_model.dart';
import 'package:trueque/modelo/user.model.dart';

enum EstadoIntercambio {
  pendiente,
  aceptado,
  rechazado,
  completado,
  cancelado,
}

extension EstadoIntercambioExtension on EstadoIntercambio {
  String get value {
    switch (this) {
      case EstadoIntercambio.pendiente: return 'pendiente';
      case EstadoIntercambio.aceptado: return 'aceptado';
      case EstadoIntercambio.rechazado: return 'rechazado';
      case EstadoIntercambio.completado: return 'completado';
      case EstadoIntercambio.cancelado: return 'cancelado';
    }
  }

  static EstadoIntercambio fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pendiente': return EstadoIntercambio.pendiente;
      case 'aceptado': return EstadoIntercambio.aceptado;
      case 'rechazado': return EstadoIntercambio.rechazado;
      case 'completado': return EstadoIntercambio.completado;
      case 'cancelado': return EstadoIntercambio.cancelado;
      default: return EstadoIntercambio.pendiente;
    }
  }
}

class Intercambio {
  final int idIntercambio;
  final String idUsuarioOfrece;
  final String idUsuarioRecibido;
  final EstadoIntercambio estado;
  final DateTime fechaIntercambio;
  final int idArticuloOld;
  
  final String? codigoVerificacion;
  final bool confirmadoPorOfertante;
  final bool confirmadoPorReceptor;
  final String? idProductoOfertado;
  final String? idProductoSolicitado;
  final int puntosProductoOfertado;
  final int puntosProductoSolicitado;

  final UserModel? usuarioOfertante;
  final UserModel? usuarioReceptor;
  final ProductoUnificado? productoSolicitado;
  final ProductoUnificado? productoOfrecido;

  // Getters de conveniencia para la UI
  bool get estaAceptado => estado == EstadoIntercambio.aceptado;
  bool get estaPendiente => estado == EstadoIntercambio.pendiente;

  Intercambio({
    required this.idIntercambio,
    required this.idUsuarioOfrece,
    required this.idUsuarioRecibido,
    required this.estado,
    required this.fechaIntercambio,
    this.idArticuloOld = 0,
    this.codigoVerificacion,
    this.confirmadoPorOfertante = false,
    this.confirmadoPorReceptor = false,
    this.idProductoOfertado,
    this.idProductoSolicitado,
    this.puntosProductoOfertado = 0,
    this.puntosProductoSolicitado = 0,
    this.usuarioOfertante,
    this.usuarioReceptor,
    this.productoSolicitado,
    this.productoOfrecido,
  });

  factory Intercambio.fromJson(Map<String, dynamic> json) {
    return Intercambio(
      idIntercambio: json['id_intercambio'] as int,
      idUsuarioOfrece: json['id_usuario_ofrece'] as String,
      idUsuarioRecibido: json['id_usuario_recibido'] as String,
      estado: EstadoIntercambioExtension.fromString(json['estado'] as String),
      fechaIntercambio: DateTime.parse(json['fecha_intercambio'] as String),
      idArticuloOld: json['id_articulo_old'] as int? ?? 0,
      
      codigoVerificacion: json['codigo_verificacion'] as String?,
      confirmadoPorOfertante: json['confirmado_por_ofertante'] as bool? ?? false,
      confirmadoPorReceptor: json['confirmado_por_receptor'] as bool? ?? false,
      idProductoOfertado: json['id_producto_ofertado']?.toString(),
      idProductoSolicitado: json['id_producto_solicitado']?.toString(),
      puntosProductoOfertado: json['puntos_producto_ofertado'] as int? ?? 0,
      puntosProductoSolicitado: json['puntos_producto_solicitado'] as int? ?? 0,

      usuarioOfertante: json['usuario_ofertante'] != null ? UserModel.fromJson(json['usuario_ofertante']) : null,
      usuarioReceptor: json['usuario_receptor'] != null ? UserModel.fromJson(json['usuario_receptor']) : null,
      productoSolicitado: json['producto_solicitado'] != null ? ProductoUnificado.fromJson(json['producto_solicitado']) : null,
      productoOfrecido: json['producto_ofertado'] != null ? ProductoUnificado.fromJson(json['producto_ofertado']) : null,
    );
  }
}
