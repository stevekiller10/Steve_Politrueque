import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trueque/screens/password_screen.dart';
import 'package:trueque/screens/register_screen.dart';
import 'package:trueque/theme/app_theme.dart';
import 'package:trueque/widgets/circle_background.dart';
import 'package:trueque/screens/home_screen.dart';
import 'package:trueque/modelo/user.model.dart';
import 'package:trueque/services/push_notifications_service.dart'; // Importante: Importar el servicio

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final supabase = Supabase.instance.client;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginEmail() async {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim();

      if (!email.endsWith('@espoch.edu.ec')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, use un correo institucional (@espoch.edu.ec)'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        EasyLoading.show(status: 'Iniciando sesión...');

        final response = await supabase.auth.signInWithPassword(
          email: email,
          password: _passwordController.text,
        );

        if (response.user != null && response.user!.emailConfirmedAt != null) {
          final userDataResponse = await supabase
              .from('usuarios')
              .select()
              .eq('id', response.user!.id)
              .maybeSingle();

          UserModel currentUser;
          
          if (userDataResponse != null) {
            currentUser = UserModel.fromJson(userDataResponse);
          } else {
            final newUserData = {
              'id': response.user!.id,
              'name': response.user!.userMetadata?['name'] ?? 'Usuario',
              'email': response.user!.email!,
              'role': 'usuario',
            };
            await supabase.from('usuarios').insert(newUserData);
            currentUser = UserModel.fromJson(newUserData);
          }

          // === INICIALIZACIÓN DE NOTIFICACIONES PUSH ===
          // Esto captura el token de Firebase y lo guarda en Supabase
          try {
            await PushNotificationsService.initialize();
          } catch (e) {
            print('Error al inicializar notificaciones push: $e');
          }

          EasyLoading.dismiss();
          EasyLoading.showSuccess('¡Bienvenido!');

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => HomeScreen(user: currentUser),
            ),
            (Route<dynamic> route) => false,
          );

        } else if (response.user != null && response.user!.emailConfirmedAt == null) {
          EasyLoading.dismiss();
          _mostrarError('Su correo electrónico no ha sido confirmado.');
        } else {
          EasyLoading.dismiss();
          _mostrarError('No se pudo iniciar sesión.');
        }
      } on AuthException catch (e) {
        EasyLoading.dismiss();
        _mostrarError(e.message);
      } catch (e) {
        EasyLoading.dismiss();
        _mostrarError('Ocurrió un error inesperado');
      }
    }
  }

  void _mostrarError(String mensaje) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CircleBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 100, height: 100,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.25),
                                        blurRadius: 20, spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                                ),
                                const SizedBox(height: 20),
                                const Text('POLI-TRUEQUE', style: TextStyle(color: AppTheme.primaryDarkColor, fontSize: 30, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 10),
                                Text('Iniciar Sesión', style: TextStyle(color: AppTheme.primaryColor, fontSize: 20, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      labelText: 'Correo electrónico',
                                      prefixIcon: const Icon(Icons.email, color: AppTheme.primaryColor),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: (value) => value == null || value.isEmpty ? 'Por favor ingrese su correo' : null,
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_isPasswordVisible,
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon: const Icon(Icons.lock, color: AppTheme.primaryColor),
                                      suffixIcon: IconButton(
                                        icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: AppTheme.primaryColor),
                                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: (value) => value == null || value.isEmpty ? 'Por favor ingrese su contraseña' : null,
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PasswordScreen())),
                                      child: const Text('¿Olvidó su contraseña?', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w500)),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  SizedBox(
                                    width: double.infinity, height: 55,
                                    child: ElevatedButton(
                                      onPressed: _loginEmail,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('¿No tiene una cuenta? ', style: TextStyle(color: Colors.grey[600])),
                                      GestureDetector(
                                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                                        child: const Text('Registrarse', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
