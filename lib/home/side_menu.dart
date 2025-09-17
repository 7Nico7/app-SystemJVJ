/* 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/features/auth/presentation/auth_wrapper.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/widgets/schedule_screen.dart';

class SideMenu extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? avatarPath;
  final Function(int)? onNavigationItemSelected;

  const SideMenu({
    super.key,
    required this.userName,
    required this.userEmail,
    this.avatarPath,
    this.onNavigationItemSelected,
    // this.authService,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(userName),
            accountEmail: Text(userEmail),
            currentAccountPicture: CircleAvatar(
              backgroundImage: avatarPath != null
                  ? AssetImage(avatarPath!)
                  : const AssetImage('assets/avatar.png') as ImageProvider,
            ),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(252, 175, 38, 1.0),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_outlined),
            title: const Text('Servicios'),
            onTap: () {
              Navigator.pop(context);
              if (onNavigationItemSelected != null) {
                onNavigationItemSelected!(2); // Índice para Factura
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_outlined),
            title: const Text('Factura'),
            onTap: () {
              Navigator.pop(context);
              if (onNavigationItemSelected != null) {
                onNavigationItemSelected!(1); // Índice para Factura
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Calendario'),
            onTap: () {
              Navigator.pop(context);
              if (onNavigationItemSelected != null) {
                onNavigationItemSelected!(0); // Índice para Calendario
              } else {
                // Fallback: navegación directa si no hay callback
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (context) => ScheduleScreen(
                            authService: authService,
                          )),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Cerrar sesión'),
            onTap: () {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              final scheduleProvider =
                  Provider.of<ScheduleProvider>(context, listen: false);

              // RESETEAR EL PROVIDER ANTES DE CERRAR SESIÓN
              scheduleProvider.reset();
              authService.logout();

              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
              );
            },
          )
        ],
      ),
    );
  }
}
 */

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/features/auth/presentation/auth_wrapper.dart';
import 'package:systemjvj/features/auth/presentation/change_password_screen.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/widgets/schedule_screen.dart';

class SideMenu extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? avatarPath;
  final Function(int)? onNavigationItemSelected;

  const SideMenu({
    super.key,
    required this.userName,
    required this.userEmail,
    this.avatarPath,
    this.onNavigationItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(userName),
            accountEmail: Text(userEmail),
            currentAccountPicture: CircleAvatar(
              backgroundImage: avatarPath != null
                  ? AssetImage(avatarPath!)
                  : const AssetImage('assets/avatar.png') as ImageProvider,
            ),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(252, 175, 38, 1.0),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inventory_outlined),
            title: const Text('Servicios'),
            onTap: () {
              Navigator.pop(context);
              if (onNavigationItemSelected != null) {
                onNavigationItemSelected!(2);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_outlined),
            title: const Text('Factura'),
            onTap: () {
              Navigator.pop(context);
              if (onNavigationItemSelected != null) {
                onNavigationItemSelected!(1);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Calendario'),
            onTap: () {
              Navigator.pop(context);
              if (onNavigationItemSelected != null) {
                onNavigationItemSelected!(0);
              } else {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) =>
                        ScheduleScreen(authService: authService),
                  ),
                );
              }
            },
          ),
          // Nueva opción para cambiar contraseña
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Cambiar contraseña'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ChangePasswordScreen(authService: authService),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Cerrar sesión'),
            onTap: () {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              final scheduleProvider =
                  Provider.of<ScheduleProvider>(context, listen: false);

              scheduleProvider.reset();
              authService.logout();

              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const AuthWrapper()),
              );
            },
          )
        ],
      ),
    );
  }
}
