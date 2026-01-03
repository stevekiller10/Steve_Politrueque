class UserModel {
  final String id;
  final String nombreCompleto;
  final String correoElectronico;
  final String rol;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.nombreCompleto,
    required this.correoElectronico,
    required this.rol,
    this.createdAt,
    this.updatedAt,
  });

  // Create UserModel from JSON - CORREGIDO para coincidir con Supabase
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      nombreCompleto: json['name'] as String? ?? '', // CAMBIADO: 'name' en vez de 'nombre_completo'
      correoElectronico: json['email'] as String? ?? '', // CAMBIADO: 'email' en vez de 'correo_electronico'
      rol: json['role'] as String? ?? 'usuario', // CAMBIADO: 'role' en vez de 'rol'
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // Convert UserModel to JSON - CORREGIDO para Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': nombreCompleto, // CAMBIADO
      'email': correoElectronico, // CAMBIADO
      'role': rol, // CAMBIADO
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  // Get user initials for avatar
  String getInitials() {
    if (nombreCompleto.trim().isEmpty) {
      return 'U';
    }
    
    final names = nombreCompleto.trim().split(' ').where((name) => name.isNotEmpty).toList();
    
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty && names[0].isNotEmpty) {
      return names[0][0].toUpperCase();
    }
    return 'U';
  }

  // Check if user is admin
  bool isAdmin() {
    return rol.toLowerCase() == 'admin' || rol.toLowerCase() == 'administrador';
  }

  // Check if user is moderator
  bool isModerador() {
    return rol.toLowerCase() == 'moderador';
  }

  // Check if user is regular user
  bool isUsuario() {
    return rol.toLowerCase() == 'usuario';
  }

  // Get role display name
  String getRoleDisplayName() {
    switch (rol.toLowerCase()) {
      case 'admin':
      case 'administrador':
        return 'Administrador';
      case 'moderador':
        return 'Moderador';
      case 'usuario':
        return 'Usuario';
      default:
        return 'Usuario';
    }
  }

  // Copy with method (útil para actualizaciones)
  UserModel copyWith({
    String? id,
    String? nombreCompleto,
    String? correoElectronico,
    String? rol,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      correoElectronico: correoElectronico ?? this.correoElectronico,
      rol: rol ?? this.rol,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}