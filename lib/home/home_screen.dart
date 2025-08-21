import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/features/auth/presentation/auth_wrapper.dart';

import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/home/side_menu.dart';
import 'package:systemjvj/schedule/widgets/schedule_screen.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart'; // Importa el ScheduleProvider

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Obtiene el usuario autenticado
    final authService = Provider.of<AuthService>(context);
    final currentUser = authService.currentUser;

    // Obtiene el ScheduleProvider para resetearlo al cerrar sesión
    final scheduleProvider =
        Provider.of<ScheduleProvider>(context, listen: false);

    // Lista de pantallas
    final List<Widget> _screens = [
      ScheduleScreen(),
      const SearchScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [
/*           IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // RESETEA EL PROVIDER ANTES DE CERRAR SESIÓN
              scheduleProvider.reset();
              authService.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
              );
            },
          ) */
        ],
      ),
      drawer: SideMenu(
        // Pasa los datos del usuario autenticado
        userName: currentUser?.username ?? 'Usuario',
        userEmail:
            '', // currentUser?.email ?? 'email@ejemplo.com', // Agrega email en tu User model
        avatarPath: 'assets/avatar.png',
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Calendario',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Factura',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
      backgroundColor: Colors.white,
      selectedItemColor: Colors.blue[800],
      unselectedItemColor: Colors.grey[600],
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8.0,
    );
  }
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Pantalla de Búsqueda', style: TextStyle(fontSize: 24)),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Ejemplo: mostrar datos del usuario en el perfil
    final currentUser = Provider.of<AuthService>(context).currentUser;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Perfil de ${currentUser?.username ?? "Usuario"}',
              style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 20),
          Text('Rol: ${currentUser?.role ?? "Sin rol"}',
              style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
