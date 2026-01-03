class PuntosIntercambio {
  final String id;
  final String nombre;
  final String? descripcion;
  final double latitud;
  final double longitud;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PuntosIntercambio({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.latitud,
    required this.longitud,
    this.createdAt,
    this.updatedAt,
  });

  factory PuntosIntercambio.fromJson(Map<String, dynamic> json) {
    return PuntosIntercambio(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'latitud': latitud,
      'longitud': longitud,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'latitud': latitud,
      'longitud': longitud,
    };
  }

  PuntosIntercambio copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    double? latitud,
    double? longitud,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PuntosIntercambio(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'PuntosIntercambio(id: $id, nombre: $nombre, latitud: $latitud, longitud: $longitud)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PuntosIntercambio && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}