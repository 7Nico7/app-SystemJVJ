import 'package:flutter/material.dart';
import '../../../home/home_screen.dart';

class SplashAnimationScreen extends StatefulWidget {
  const SplashAnimationScreen({super.key});

  @override
  State<SplashAnimationScreen> createState() => _SplashAnimationScreenState();
}

class _SplashAnimationScreenState extends State<SplashAnimationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 50),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.linear),
      ),
    );

    _colorAnimation = ColorTween(
            begin: const Color.fromARGB(13, 99, 99, 99),
            end: const Color.fromRGBO(252, 175, 38, 1.0))
        .animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Esperar a que termine la animación antes de navegar
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    Colors.white,
                    _colorAnimation.value ?? const Color(0xFFF4C037),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Engranaje grande de fondo
                  Transform.rotate(
                    angle: _rotationAnimation.value * 3.14,
                    child: Opacity(
                      opacity: 0.2,
                      child: Icon(
                        Icons.settings,
                        size: 300,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),

                  // Engranaje medio
                  Positioned(
                    top: 100,
                    right: 80,
                    child: Transform.rotate(
                      angle: -_rotationAnimation.value * 3.1416,
                      child: Opacity(
                        opacity: 0.3,
                        child: Icon(
                          Icons.settings,
                          size: 150,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),

                  // Engranaje pequeño
                  Positioned(
                    bottom: 100,
                    left: 80,
                    child: Transform.rotate(
                      angle: _rotationAnimation.value * 3.1416 * 1.5,
                      child: Opacity(
                        opacity: 0.3,
                        child: Icon(
                          Icons.settings,
                          size: 100,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),

                  // Contenido principal
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 15,
                                  color: Colors.black.withOpacity(0.2),
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              height: 120,
                              width: 120,
                              child: Image.asset('assets/images/logo.png'),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Texto con animación
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _controller,
                          curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Bienvenido',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Cargando sistema de registro...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Barra de progreso
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _colorAnimation.value ?? const Color(0xFFF4C037),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
