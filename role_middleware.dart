import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoleMiddleware {
  // Método mejorado que acepta múltiples roles
  static Widget protectedRoute({
    required Widget child,
    required List<String> allowedRoles, // Cambio: ahora es una lista
  }) {
    return FutureBuilder<String?>(
      future: _getUserRole(),
      builder: (context, snapshot) {
        // 1. Mientras carga el rol
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFEF233C),
              ),
            ),
          );
        }

        // 2. Si hay un error (no hay sesión, etc.)
        if (snapshot.hasError || !snapshot.hasData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          });
          return const Scaffold(
            body: Center(
              child: Text('Verificando autenticación...'),
            ),
          );
        }

        final userRole = snapshot.data!;

        // 3. Si el rol del usuario está en la lista de roles permitidos
        if (allowedRoles.contains(userRole)) {
          return child; // Permite el acceso
        }

        // 4. Si el rol no coincide (Acceso Denegado)
        return Scaffold(
          appBar: AppBar(
            title: const Text('Acceso Denegado'),
            backgroundColor: const Color(0xFFEF233C),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Color(0xFFEF233C),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Acceso Denegado',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No tienes permisos para ver esta página.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF233C),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text(
                      'Volver',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Función privada para obtener el rol desde la tabla 'usuarios'
  static Future<String?> _getUserRole() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return null;

    try {
      final response = await supabase
          .from('usuarios')
          .select('role')
          .eq('id', user.id)
          .single();

      return response['role'] as String?;
    } catch (e) {
      print('Error al obtener rol: $e');
      return null;
    }
  }
  
  // Método auxiliar para verificar si el usuario tiene un rol específico
  static Future<bool> hasRole(String role) async {
    final userRole = await _getUserRole();
    return userRole == role;
  }
  
  // Método auxiliar para obtener el rol actual (útil para UI)
  static Future<String?> getCurrentRole() async {
    return await _getUserRole();
  }
}