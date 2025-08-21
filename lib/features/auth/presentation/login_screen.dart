/* import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controller/login_controller.dart';
import '../../../home/home_screen.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart'; // Importación añadida

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<LoginController>(context);
    final primaryColor = const Color(0xFFF4C037);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 12,
                  color: Colors.black12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 100,
                  child: Image.asset('assets/images/login_logo.jpg'),
                ),
                const SizedBox(height: 24),
                const Text(
                  '¡Bienvenido!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'tu@email.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: controller.setEmail,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    hintText: '*********',
                  ),
                  obscureText: true,
                  onChanged: controller.setPassword,
                ),
                const SizedBox(height: 12),
                if (controller.error != null)
                  Text(
                    controller.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.isLoading
                        ? null
                        : () async {
                            final success = await controller.login();
                            if (success) {
                              // ACTUALIZAR ROL DEL USUARIO EN EL PROVIDER
                              final scheduleProvider =
                                  Provider.of<ScheduleProvider>(
                                context,
                                listen: false,
                              );
                              scheduleProvider.refreshUserRole();

                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const HomeScreen(),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: controller.isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Ingresar',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
 */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/features/auth/presentation/splashAnimationScreen.dart';
import '../controller/login_controller.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<LoginController>(context);
    final primaryColor = const Color(0xFFF4C037);

    return Scaffold(
      body: Stack(
        children: [
          // Fondo con animación sutil de maquinaria
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey[100]!,
                  Colors.grey[300]!,
                ],
              ),
            ),
          ),

          // Patrón de engranajes de fondo (sutil)
          Positioned(
            right: -50,
            top: -50,
            child: Opacity(
              opacity: 0.1,
              child: Icon(
                Icons.settings,
                size: 200,
                color: Colors.grey[700],
              ),
            ),
          ),

          Positioned(
            left: -30,
            bottom: 100,
            child: Opacity(
              opacity: 0.1,
              child: Icon(
                Icons.settings,
                size: 150,
                color: Colors.grey[700],
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 12,
                      color: Colors.black26,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo con animación de latido
                    PulseAnimation(
                      child: SizedBox(
                        height: 100,
                        child: Image.asset('assets/images/login_logo.jpg'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '¡Bienvenido!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'SystemJVJ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'tu@email.com',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: controller.setEmail,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        hintText: '*********',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      obscureText: true,
                      onChanged: controller.setPassword,
                    ),
                    const SizedBox(height: 12),
                    if (controller.error != null)
                      FadeAnimation(
                        delay: 0.5,
                        child: Text(
                          controller.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: controller.isLoading
                            ? null
                            : () async {
                                final success = await controller.login();
                                if (success) {
                                  final scheduleProvider =
                                      Provider.of<ScheduleProvider>(
                                    context,
                                    listen: false,
                                  );
                                  scheduleProvider.refreshUserRole();

                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SplashAnimationScreen(),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 4,
                        ),
                        child: controller.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black),
                                ),
                              )
                            : const Text(
                                'Ingresar',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    /*     
                    TextButton(
                      onPressed: () {
                        // Acción para recuperar contraseña
                      },
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ), */
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Animación de pulso para el logo
class PulseAnimation extends StatefulWidget {
  final Widget child;

  const PulseAnimation({super.key, required this.child});

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

// Animación de fade in para elementos
class FadeAnimation extends StatefulWidget {
  final Widget child;
  final double delay;

  const FadeAnimation({super.key, required this.child, required this.delay});

  @override
  State<FadeAnimation> createState() => _FadeAnimationState();
}

class _FadeAnimationState extends State<FadeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).round()), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}
