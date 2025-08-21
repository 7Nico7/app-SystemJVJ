import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import '../../../home/home_screen.dart';
import '../data/auth_service.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart'; // Importación añadida

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final scheduleProvider =
        Provider.of<ScheduleProvider>(context, listen: false);

    await authService.checkAuthStatus();

    // ACTUALIZAR ROL DESPUÉS DE VERIFICAR AUTENTICACIÓN
    scheduleProvider.refreshUserRole();

    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return authService.currentUser != null
        ? const HomeScreen()
        : const LoginScreen();
  }
}
