import 'package:flutter/material.dart';

class AppTheme {
  // Definimos nuestro color rojo principal
  static const Color primaryColor = Color(0xFFB71C1C); // Un rojo vibrante
  static const Color primaryDarkColor = Color(0xFFC62828); // Un rojo más oscuro
  static const Color primaryLightColor = Color(0xFFFFCDD2); // Un rojo muy claro

  // Creamos un MaterialColor a partir de nuestro color primario.
  // Esto nos permite usar diferentes tonalidades (ej: Colors.red.shade300)
  static const MaterialColor primaryMaterialColor = MaterialColor(
    0xFFE53935, // El color base
    <int, Color>{
      50: Color(0xFFFFEBEE),
      100: Color(0xFFFFCDD2),
      200: Color(0xFFEF9A9A),
      300: Color(0xFFE57373),
      400: Color(0xFFEF5350),
      500: Color(0xFFE53935), // Color base
      600: Color(0xFFE53935),
      700: Color(0xFFD32F2F),
      800: Color(0xFFC62828),
      900: Color(0xFFB71C1C),
    },
  );

  // Definimos el tema completo de la aplicación
  static ThemeData getTheme() {
    return ThemeData(
      // Usamos nuestro color primario personalizado
      primarySwatch: primaryMaterialColor,
      primaryColor: primaryColor,
      
      // Configuración del AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      
      // Configuración de los botones elevados
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white, // Color del texto
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        ),
      ),
    );
  }
}