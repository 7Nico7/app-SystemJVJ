import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:systemjvj/maintenance/data/maintenanceSyncService.dart';
import 'package:systemjvj/maintenance/data/signatureDatabaseHelper.dart';
import 'package:systemjvj/maintenance/data/signature_sync_service.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';
import 'package:systemjvj/schedule/services/syncService.dart';
import 'package:systemjvj/features/auth/controller/login_controller.dart';
import 'package:systemjvj/features/auth/domain/login_use_case.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/features/auth/presentation/auth_wrapper.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:systemjvj/maintenance/data/inspection_sync_global.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("🔧 Ejecutando tarea en segundo plano: $task");

    try {
      if (task == 'syncTask') {
        final sharedPreferences = await SharedPreferences.getInstance();
        final dbHelper = DatabaseHelper.instance;
        final authService = AuthService();
        final connectivity = Connectivity();

        // Sincronización de datos principales
        final offlineService = OfflineService(dbHelper, null, connectivity);
        final syncService = SyncService(
          offlineService: offlineService,
          dbHelper: dbHelper,
          authService: authService,
        );
        offlineService.syncService = syncService;
        await syncService.syncData();

        // Sincronización de firmas (mejorada)
        try {
          final signatureSyncService = SignatureSyncService();
          final success = await signatureSyncService.syncPendingSignatures();
          print('✅ Sincronización de firmas completada: $success');
        } catch (e) {
          print('❌ Error en sincronización de firmas: $e');
        }
        // Sincronización de inspecciones
        try {
          await syncInspectionsGlobal();
        } catch (e) {
          print('Error en sincronización de inspecciones: $e');
        }
      } else if (task == "syncInspectionsTask") {
        // Esta tarea es específica para inspecciones, llamamos directamente al método
        print('BACKGROUND: Sincronizando inspecciones...');
        final syncService = MaintenanceSyncService();
        await syncService.syncPendingInspections();
        print('BACKGROUND: Sincronización de inspecciones completada');
      } else if (task == "syncSignaturesTask") {
        print('🔄 Sincronizando firmas...');
        final signatureSyncService = SignatureSyncService();
        final success = await signatureSyncService.syncPendingSignatures();
        print('✅ Sincronización de firmas completada: $success');
      }
    } catch (e) {
      print("❌ Error en la tarea $task: $e");
      return Future.error(e);
    }

    return Future.value(true);
  });
}

void main() async {
  // SOLUCIÓN 1: Mover runZonedGuarded para envolver todo
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Todas las operaciones asíncronas dentro de la zona
    final sharedPreferences = await SharedPreferences.getInstance();

    // Inicialización del WorkManager
    try {
      Workmanager().initialize(callbackDispatcher);

      // Registrar tareas periódicas
      await _registerPeriodicTasks();

      // Inicializar el callback dispatcher para inspecciones
      MaintenanceSyncService.callbackDispatcher();
    } catch (e) {
      debugPrint(
          '################!!!!!!!!!!!!! Error inicializando WorkManager: $e');
    }

    // Ejecutar la app dentro de la misma zona
    runApp(
      MultiProvider(
        providers: [
          Provider<SharedPreferences>(create: (_) => sharedPreferences),
          Provider<Connectivity>(create: (_) => Connectivity()),
          StreamProvider<List<ConnectivityResult>>(
            create: (context) => Connectivity().onConnectivityChanged,
            initialData: const [ConnectivityResult.none],
          ),
          Provider<DatabaseHelper>(create: (_) => DatabaseHelper.instance),
          Provider<AuthService>(create: (_) => AuthService()),
          // OfflineService sin leer SyncService aún
          ChangeNotifierProvider<OfflineService>(
            create: (context) => OfflineService(
              context.read<DatabaseHelper>(),
              null, // se asignará después
              context.read<Connectivity>(),
            ),
          ),
          // SyncService con OfflineService ya disponible
          ChangeNotifierProvider<SyncService>(
            create: (context) {
              final offlineService = context.read<OfflineService>();
              final syncService = SyncService(
                offlineService: offlineService,
                dbHelper: context.read<DatabaseHelper>(),
                authService: context.read<AuthService>(),
              );
              offlineService.syncService = syncService; // asignación después
              return syncService;
            },
          ),
          ProxyProvider<AuthService, LoginUseCase>(
            update: (_, authService, __) => LoginUseCase(authService),
          ),
          ChangeNotifierProxyProvider2<AuthService, LoginUseCase,
              LoginController>(
            create: (_) =>
                LoginController(LoginUseCase(AuthService()), AuthService()),
            update: (_, authService, loginUseCase, controller) =>
                controller!..updateDependencies(loginUseCase, authService),
          ),
          ProxyProvider3<AuthService, SharedPreferences, Connectivity,
              ApiService>(
            update: (_, authService, prefs, connectivity, __) => ApiService(
              authService: authService,
              prefs: prefs,
              connectivity: connectivity,
            ),
          ),
          ChangeNotifierProxyProvider<ApiService, ScheduleProvider>(
            create: (_) => ScheduleProvider(
              apiService: ApiService(
                authService: AuthService(),
                prefs: sharedPreferences,
                connectivity: Connectivity(),
              ),
              connectivity: Connectivity(),
            ),
            update: (_, apiService, scheduleProvider) {
              scheduleProvider!..updateApiService(apiService);
              return scheduleProvider;
            },
          ),
          Provider<SignatureDatabaseHelper>(
            create: (_) => SignatureDatabaseHelper.instance,
          ),
          Provider<SignatureSyncService>(create: (_) => SignatureSyncService()),
          Provider<MaintenanceSyncService>(
            create: (_) => MaintenanceSyncService(),
          ),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint(
        '################!!!!!!!!!!!!! Error no capturado en main: $error');
    debugPrint('################!!!!!!!!!!!!! Stack trace: $stack');
  });
}

Future<void> _registerPeriodicTasks() async {
  try {
    // Cancelar tareas existentes para evitar duplicados
    await Workmanager().cancelAll();

    // Esperar un breve momento antes de registrar nuevas tareas
    await Future.delayed(const Duration(milliseconds: 500));

    // Registrar tarea principal de sincronización
    await Workmanager().registerPeriodicTask(
      'syncTask',
      'syncTask',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
        //    batteryNotLow: true, // Solo ejecutar si la batería no está baja
      ),
      initialDelay: const Duration(seconds: 30),
    );

    // Registrar tarea específica para inspecciones
    await Workmanager().registerPeriodicTask(
      'syncInspectionsTask',
      'syncInspectionsTask',
      frequency: const Duration(minutes: 10),
      constraints: Constraints(
        networkType: NetworkType.connected,
        //     batteryNotLow: true,
      ),
      initialDelay: const Duration(minutes: 2),
    );

    // Registrar tarea específica para firmas
    await Workmanager().registerPeriodicTask(
      'syncSignaturesTask',
      'syncSignaturesTask',
      frequency: const Duration(minutes: 5), // Reducido a 10 minutos
      constraints: Constraints(
        networkType: NetworkType.connected,
        //    batteryNotLow: true,
      ),
      initialDelay: const Duration(minutes: 1),
    );

    debugPrint(
        '################### Tareas periódicas registradas correctamente');
  } catch (e) {
    debugPrint('################### Error registrando tareas periódicas: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initSyncListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

/*   void _initSyncListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectivity = Provider.of<Connectivity>(context, listen: false);
      final syncService = Provider.of<SyncService>(context, listen: false);
      final signatureSyncService =
          Provider.of<SignatureSyncService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final maintenanceSyncService =
          Provider.of<MaintenanceSyncService>(context, listen: false);
      // Escuchar cambios de conectividad
      _connectivitySubscription =
          connectivity.onConnectivityChanged.listen((results) async {
        // Verificar si hay alguna conexión activa
        final hasConnection =
            results.any((result) => result != ConnectivityResult.none);

        if (hasConnection) {
          debugPrint(' Conexión detectada, iniciando sincronización...');

          // Verificar si el token es válido antes de sincronizar
          /*        final isValidToken = await authService.isValidToken();
          if (isValidToken) { */
          // Sincronizar datos principales

          await maintenanceSyncService.syncPendingInspections();

          await syncService.syncData();

          // Sincronizar firmas pendientes
          await signatureSyncService.syncPendingSignatures();

          /*     } else {
            debugPrint(' Token inválido, no se puede sincronizar');
          } */
        }
      });

      // Verificar conectividad inicial
      connectivity.checkConnectivity().then((results) async {
        final hasConnection =
            results.any((result) => result != ConnectivityResult.none);

        if (hasConnection) {
          debugPrint(
              ' Conexión inicial detectada, iniciando sincronización...');

          /*        final isValidToken = await authService.isValidToken();
        if (isValidToken) { */
          await syncService.syncData();
          await signatureSyncService.syncPendingSignatures();
          /*      } */
        }
      }).catchError((error) {
        debugPrint(' Error verificando conectividad inicial: $error');
      });
    });
  } */

  void _initSyncListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectivity = Provider.of<Connectivity>(context, listen: false);
      final syncService = Provider.of<SyncService>(context, listen: false);
      final signatureSyncService =
          Provider.of<SignatureSyncService>(context, listen: false);
      final maintenanceSyncService =
          Provider.of<MaintenanceSyncService>(context, listen: false); // Nuevo
      final authService = Provider.of<AuthService>(context, listen: false);

      // Escuchar cambios de conectividad
      _connectivitySubscription =
          connectivity.onConnectivityChanged.listen((results) async {
        // Verificar si hay alguna conexión activa
        final hasConnection =
            results.any((result) => result != ConnectivityResult.none);

        if (hasConnection) {
          debugPrint(
              '################### Conexión detectada, iniciando sincronización...');

          try {
            //Registro de horas y firma de tecnico
            await syncService.syncData();
          } catch (e) {
            debugPrint(
                '❌ Error en sincronización de datos Horas y firma de tecnico: $e');
          }

          try {
            // Registro de firma de cliente y calificación
            await signatureSyncService.syncPendingSignatures();
          } catch (e) {
            debugPrint('❌ Error en sincronización de firmas de cliente: $e');
          }

          try {
            // Registro de inspecciones de formulario de inspección
            await maintenanceSyncService.syncPendingInspections();
          } catch (e) {
            debugPrint(
                '❌ Error en sincronización de inspecciones formulario: $e');
          }
        }
      });

      // Verificar conectividad inicial
      connectivity.checkConnectivity().then((results) async {
        final hasConnection =
            results.any((result) => result != ConnectivityResult.none);

        if (hasConnection) {
          debugPrint(
              '################### Conexión inicial detectada, iniciando sincronización...');

          await syncService.syncData();
          await signatureSyncService.syncPendingSignatures();
          await maintenanceSyncService.syncPendingInspections();
        }
      }).catchError((error) {
        debugPrint(
            '################### Error verificando conectividad inicial: $error');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color.fromRGBO(252, 175, 38, 1.0),
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        appBarTheme: const AppBarTheme(
          color: Color.fromRGBO(252, 175, 38, 1.0),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('es', ''),
        Locale('es', 'ES'),
        Locale('es', 'MX'),
      ],
      home: const AuthWrapper(),
    );
  }
}
