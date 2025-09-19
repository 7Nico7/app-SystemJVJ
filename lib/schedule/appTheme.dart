import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData customTheme = ThemeData(
    scaffoldBackgroundColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color.fromRGBO(252, 175, 38, 1.0),
      primary: const Color.fromRGBO(252, 175, 38, 1.0),
      onPrimary: Colors.black,
      secondary: const Color.fromRGBO(255, 193, 7, 1.0),
      onSecondary: Colors.black,
      surface: Colors.white,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
    ),
    primaryColor: const Color.fromRGBO(252, 175, 38, 1.0),
    primaryColorDark: const Color.fromRGBO(255, 160, 0, 1.0),
    primaryColorLight: const Color.fromRGBO(255, 206, 102, 1.0),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color.fromRGBO(252, 175, 38, 1.0),
      iconTheme: IconThemeData(
        color:
            Colors.white, // Para íconos principales como el botón de retroceso
      ),
      actionsIconTheme: IconThemeData(
        color: Colors.black, // Para íconos de acción (a la derecha)
      ),
      titleTextStyle: TextStyle(
        color: Colors.black, // Para el título del AppBar
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: Colors.black),
    ),
  );
}
