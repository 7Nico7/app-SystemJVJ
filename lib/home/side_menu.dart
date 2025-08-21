import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/features/auth/presentation/auth_wrapper.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';

class SideMenu extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? avatarPath;

  const SideMenu({
    super.key,
    required this.userName,
    required this.userEmail,
    this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
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
                  : const AssetImage('assets/avatar.png'),
            ),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(252, 175, 38, 1.0),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_repair_service),
            title: const Text('Servicios'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_outlined),
            title: const Text('Factura'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Calendario'),
            onTap: () {
              Navigator.pop(context);
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
