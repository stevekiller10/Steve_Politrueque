import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trueque/theme/app_theme.dart';
import 'package:trueque/widgets/circle_background.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores para los campos de texto
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Estados para la visibilidad de las contraseñas
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    // Limpiar los controladores cuando el widget se destruye
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }



  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();

    try {
      if (kDebugMode) {
        print('Intentando registrar: $email');
      }

      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _passwordController.text,
        data: {'name': _nameController.text.trim()},
        emailRedirectTo: kIsWeb
            ? 'http://localhost:8080/auth/callback'
            : 'io.supabase.poli-trueque://login-callback/',
      );

      if (response.user != null) {
        if (kDebugMode) {
          print('✅ Registro exitoso - Email de confirmación enviado');
        }
        _mostrarExito();
      } else {
        _mostrarError(
          'No se pudo completar el registro. Por favor intente nuevamente.',
        );
      }

    } on AuthException catch (e) {
      if (kDebugMode) {
        print('❌ AuthException: ${e.message} (Status: ${e.statusCode})');
      }

      String errorMessage;
      if (e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('user already registered') ||
          e.message.toLowerCase().contains('duplicate') ||
          e.message.toLowerCase().contains('unique constraint')) {
        errorMessage = 'Este correo ya está registrado.';
      } else if (e.message.toLowerCase().contains('email not confirmed')) {
        errorMessage = 
            'Este correo ya está registrado pero no confirmado. '
            'Por favor revise su bandeja de entrada y spam para '
            'encontrar el correo de confirmación.';
      } else if (e.message.toLowerCase().contains('invalid email')) {
        errorMessage = 'El formato del correo no es válido.';
      } else if (e.statusCode == '429') {
        errorMessage = 'Demasiados intentos. Por favor espere un momento.';
      } else {
        errorMessage = 'Error de autenticación: ${e.message}';
      }

      _mostrarError(errorMessage);

    } on Exception catch (e) {
      if (kDebugMode) {
        print('❌ Error inesperado en _register: $e');
      }
      
      _mostrarError(
        'Ocurrió un error inesperado.\n'
        'Verifique su conexión a internet e intente nuevamente.',
      );
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 28),
            const SizedBox(width: 10),
            const Text('Error'),
          ],
        ),
        content: Text(mensaje, style: const TextStyle(fontSize: 15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Entendido',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarExito() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Text(
              '¡Revise su correo!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Hemos enviado un correo de confirmación a:\n${_emailController.text}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 14),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: const Text(
                'Iniciar Sesión',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Validador para el campo de contraseña
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su contraseña';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'Debe contener al menos una letra';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Debe contener al menos un número';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Debe contener al menos un carácter especial (!@#%...)';
    }
    return null;
  }

  /// Validador para el campo de correo
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su correo';
    }
    
    final emailRegex = RegExp(r'^[\w\.-]+@espoch\.edu\.ec$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Solo se permiten correos institucionales\n(@espoch.edu.ec)';
    }
    
    return null;
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
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 20),
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.2),
                                        blurRadius: 15,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  '¡Únase a Poli-Trueque!',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Complete el formulario con su correo institucional',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Contenedor principal con el formulario
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                               color: Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Campo Nombre Completo
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: _inputDecoration('Nombre completo', 'Ingrese su nombre', Icons.person),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Por favor ingrese su nombre';
                                      }
                                      if (value.trim().length < 3) {
                                        return 'El nombre debe tener al menos 3 caracteres';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // Campo Correo Institucional
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: _inputDecoration('Correo institucional', 'ejemplo@espoch.edu.ec', Icons.email),
                                    validator: _validateEmail,
                                  ),
                                  const SizedBox(height: 20),

                                  // Campo Contraseña
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_isPasswordVisible,
                                    decoration: _inputDecoration('Contraseña', 'Mín. 8 caracteres con letras, números y símbolos', Icons.lock, isPassword: true),
                                    validator: _validatePassword,
                                  ),
                                  const SizedBox(height: 20),

                                  // Campo Confirmar Contraseña
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: !_isConfirmPasswordVisible,
                                    decoration: _inputDecoration('Confirmar Contraseña', 'Repita su contraseña', Icons.lock_outline, isConfirmPassword: true),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Por favor confirme su contraseña';
                                      }
                                      if (value != _passwordController.text) {
                                        return 'Las contraseñas no coinciden';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 30),

                                  // Botón Registrarse
                                  SizedBox(
                                    width: double.infinity,
                                    height: 55,
                                    child: ElevatedButton(
                                      onPressed: _register,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 5,
                                      ),
                                      child: const Text(
                                        'Registrarse',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Enlace para Iniciar Sesión
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '¿Ya tiene una cuenta? ',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.pop(context),
                                        child: Text(
                                          'Iniciar Sesión',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
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

  InputDecoration _inputDecoration(String label, String hint, IconData icon, {bool isPassword = false, bool isConfirmPassword = false}) {
    bool isVisible;
    VoidCallback toggleVisibility;

    if (isConfirmPassword) {
      isVisible = _isConfirmPasswordVisible;
      toggleVisibility = () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
    } else if (isPassword) {
      isVisible = _isPasswordVisible;
      toggleVisibility = () => setState(() => _isPasswordVisible = !_isPasswordVisible);
    } else {
      isVisible = true;
      toggleVisibility = () {};
    }

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.primaryColor),
      suffixIcon: (isPassword || isConfirmPassword)
          ? IconButton(
              icon: Icon(isVisible ? Icons.visibility_off : Icons.visibility, color: AppTheme.primaryColor),
              onPressed: toggleVisibility,
            )
          : null,
      filled: true,
      fillColor: Colors.grey.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}