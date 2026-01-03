import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trueque/screens/login_screen.dart';
import 'package:trueque/screens/home_screen.dart';
import 'package:trueque/modelo/user.model.dart';
import 'package:trueque/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Esperar un momento para mostrar el splash
      await Future.delayed(const Duration(seconds: 2));

      // Verificar si hay una sesión activa
      final session = supabase.auth.currentSession;
      final user = supabase.auth.currentUser;

      if (session != null && user != null && user.emailConfirmedAt != null) {
        // Usuario está logueado y verificado
        await _navigateToHome(user.id);
      } else {
        // No hay sesión activa, ir al login
        _navigateToLogin();
      }
    } catch (e) {
      // En caso de error, ir al login
      print('Error verificando autenticación: $e');
      _navigateToLogin();
    }
  }

  Future<void> _navigateToHome(String userId) async {
    try {
      // Obtener datos completos del usuario desde la base de datos
      final userData = await supabase
          .from('usuarios')
          .select()
          .eq('id', userId)
          .single();

      final currentUser = UserModel.fromJson(userData);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => HomeScreen(user: currentUser),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('Error obteniendo datos del usuario: $e');
      // Si hay error obteniendo datos, cerrar sesión y ir al login
      await supabase.auth.signOut();
      _navigateToLogin();
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
            
            const SizedBox(height: 30),
            
            // Título
            const Text(
              'POLI-TRUEQUE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            
            const SizedBox(height: 10),
            
            // Subtítulo
            Text(
              'Intercambia con tu comunidad',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
                fontWeight: FontWeight.w300,
              ),
            ),
            
            const SizedBox(height: 50),
            
            // Indicador de carga
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            
            const SizedBox(height: 20),
            
            // Texto de carga
            Text(
              'Verificando sesión...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}