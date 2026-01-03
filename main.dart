import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:trueque/modelo/intercambio.dart';
import 'package:trueque/modelo/user.model.dart';
import 'package:trueque/screens/profile_screen.dart';
import 'package:trueque/screens/register_screen.dart';
import 'package:trueque/theme/app_theme.dart';
import 'package:trueque/screens/login_screen.dart';
import 'package:trueque/screens/splash_screen.dart';
import 'package:trueque/screens/new_password_screen.dart'; 
import 'package:trueque/screens/home_screen.dart';
import 'package:trueque/screens/chat_screen.dart';
import 'package:trueque/screens/intercambio/mis_intercambios_screen.dart';
import 'package:trueque/screens/intercambio/detalle_intercambio_screen.dart';
import 'package:trueque/screens/intercambio/propose_exchange_screen.dart';
import 'package:trueque/services/push_notifications_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. INICIALIZAR FIREBASE (Requerido para generar el token que va a Supabase)
  try {
    await Firebase.initializeApp();
    print('✅ Motor de notificaciones activado');
  } catch (e) {
    print('❌ Firebase no configurado: El token no se generará hasta que agregues google-services.json');
  }

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_KEY']!,
  );

  // 2. ESCUCHADOR DE SESIÓN
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;

    if (session != null && (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession)) {
      PushNotificationsService.initialize();
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, 
      debugShowCheckedModeBanner: false,
      title: 'Trueque',
      theme: AppTheme.getTheme(),
      initialRoute: '/',
      builder: EasyLoading.init(), // CORRECCIÓN: Inicializar EasyLoading aquí
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/registro': (context) => const RegisterScreen(),
        '/home': (context) {
          final arguments = ModalRoute.of(context)?.settings.arguments;
          if (arguments is UserModel) return HomeScreen(user: arguments);
          return const LoginScreen();
        },
        '/profile': (context) => const ProfileScreen(),
        '/intercambios': (context) => const MisIntercambiosScreen(),
        '/detalle-intercambio': (context) {
          final intercambio = ModalRoute.of(context)!.settings.arguments as Intercambio;
          return DetalleIntercambioScreen(intercambio: intercambio);
        },
        '/propose-exchange': (context) => const ProposeExchangeScreen(),
      }
    );
  }
}
