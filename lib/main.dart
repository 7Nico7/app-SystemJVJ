import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:systemjvj/maintenance/data/inspection_sync_global.dart';
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
import 'package:workmanager/workmanager.dart';
import 'package:systemjvj/schedule/appTheme.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("🔧 Ejecutando tarea en segundo plano: $task");

    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    final hasConnection = results.any((r) => r != ConnectivityResult.none);

    if (!hasConnection) {
      print('📵 No hay conexión, posponiendo tarea $task');
      return Future.value(false);
    }

    try {
      final sharedPreferences = await SharedPreferences.getInstance();
      final authService = AuthService();

      switch (task) {
        case 'syncTask':
          // Sincronizar datos principales
          final dbHelper = DatabaseHelper.instance;
          final offlineService = OfflineService(
            dbHelper: dbHelper,
            connectivity: connectivity,
          );

          final syncService = SyncService(
            offlineService: offlineService,
            dbHelper: dbHelper,
            authService: authService,
          );

          offlineService.syncService = syncService;
          await syncService.syncData();

          // Sincronizar firmas e inspecciones en paralelo
          await Future.wait([
            SignatureSyncService(authService: authService)
                .syncPendingSignatures(),
            MaintenanceSyncService.syncPendingInspectionsBackground(),
          ]);
          break;

        case "syncInspectionsTask":
          await MaintenanceSyncService.syncPendingInspectionsBackground();
          break;

        case "syncSignaturesTask":
          final signatureSyncService =
              SignatureSyncService(authService: authService);
          await signatureSyncService.syncPendingSignatures();
          break;

        case "immediateSync":
          // Tarea única para sincronización inmediata
          final dbHelper = DatabaseHelper.instance;
          final offlineService = OfflineService(
            dbHelper: dbHelper,
            connectivity: connectivity,
          );

          final syncService = SyncService(
            offlineService: offlineService,
            dbHelper: dbHelper,
            authService: authService,
          );

          offlineService.syncService = syncService;

          // Sincronizar todo
          await Future.wait([
            syncService.syncData(),
            SignatureSyncService(authService: authService)
                .syncPendingSignatures(),
            MaintenanceSyncService.syncPendingInspectionsBackground(),
          ]);
          break;

        default:
          print('⚠️ Tarea desconocida: $task');
      }
    } catch (e) {
      print("Error en la tarea $task: $e");
      return Future.value(false);
    }

    return Future.value(true);
  });
}

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    final sharedPreferences = await SharedPreferences.getInstance();
    final connectivity = Connectivity();
    final dbHelper = DatabaseHelper.instance;
    final authService = AuthService();

    try {
      await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
      await _registerPeriodicTasks();
    } catch (e) {
      debugPrint('Error inicializando WorkManager: $e');
    }

    runApp(
      MultiProvider(
        providers: [
          // Providers básicos
          Provider<SharedPreferences>.value(value: sharedPreferences),
          Provider<Connectivity>.value(value: connectivity),
          Provider<DatabaseHelper>.value(value: dbHelper),
          Provider<AuthService>.value(value: authService),

          StreamProvider<List<ConnectivityResult>>(
            create: (_) => connectivity.onConnectivityChanged,
            initialData: const [ConnectivityResult.none],
          ),

          // OfflineService debe crearse primero
          ChangeNotifierProvider<OfflineService>(
            create: (context) {
              final dbHelper = context.read<DatabaseHelper>();
              final connectivity = context.read<Connectivity>();
              return OfflineService(
                dbHelper: dbHelper,
                connectivity: connectivity,
              );
            },
          ),

          // Luego SyncService
          ChangeNotifierProvider<SyncService>(
            create: (context) {
              final offlineService = context.read<OfflineService>();
              final authService = context.read<AuthService>();
              final dbHelper = context.read<DatabaseHelper>();

              final syncService = SyncService(
                offlineService: offlineService,
                dbHelper: dbHelper,
                authService: authService,
              );

              // Asignar syncService a offlineService después de crearlo
              offlineService.syncService = syncService;
              return syncService;
            },
          ),

          // Los demás providers
          ProxyProvider<AuthService, LoginUseCase>(
            update: (_, authService, __) => LoginUseCase(authService),
          ),

          ChangeNotifierProxyProvider2<AuthService, LoginUseCase,
              LoginController>(
            create: (_) =>
                LoginController(LoginUseCase(authService), authService),
            update: (_, authService, loginUseCase, controller) =>
                controller!..updateDependencies(loginUseCase, authService),
          ),

          ProxyProvider3<AuthService, SharedPreferences, Connectivity,
              ApiService>(
            update: (_, authService, prefs, connectivity, __) => ApiService(
                authService: authService,
                prefs: prefs,
                connectivity: connectivity),
          ),

          ChangeNotifierProxyProvider3<AuthService, SharedPreferences,
              Connectivity, ScheduleProvider>(
            create: (context) {
              final authService =
                  Provider.of<AuthService>(context, listen: false);
              final prefs =
                  Provider.of<SharedPreferences>(context, listen: false);
              final connectivity =
                  Provider.of<Connectivity>(context, listen: false);
              final syncService =
                  Provider.of<SyncService>(context, listen: false);

              return ScheduleProvider(
                apiService: ApiService(
                  authService: authService,
                  prefs: prefs,
                  connectivity: connectivity,
                ),
                syncService: syncService,
                connectivity: connectivity,
              );
            },
            update:
                (context, authService, prefs, connectivity, scheduleProvider) {
              final apiService = ApiService(
                authService: authService,
                prefs: prefs,
                connectivity: connectivity,
              );
              final syncService =
                  Provider.of<SyncService>(context, listen: false);

              // Verificación segura para evitar el operador !
              if (scheduleProvider != null) {
                scheduleProvider
                  ..updateApiService(apiService)
                  ..updateSyncService(syncService);
              }

              return scheduleProvider ??
                  ScheduleProvider(
                    apiService: apiService,
                    syncService: syncService,
                    connectivity: connectivity,
                  );
            },
          ),

          Provider<SignatureDatabaseHelper>(
            create: (_) => SignatureDatabaseHelper.instance,
          ),

          Provider<SignatureSyncService>(
            create: (_) => SignatureSyncService(authService: authService),
          ),

          Provider<MaintenanceSyncService>(
            create: (_) => MaintenanceSyncService(authService: authService),
          ),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Error no capturado en main: $error');
    debugPrint('Stack trace: $stack');
  });
}

Future<void> _registerPeriodicTasks() async {
  try {
    await Workmanager().cancelAll();
    await Future.delayed(const Duration(milliseconds: 500));

    await Workmanager().registerPeriodicTask(
      'syncTask',
      'syncTask',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      initialDelay: const Duration(seconds: 30),
    );

    await Workmanager().registerPeriodicTask(
      'syncInspectionsTask',
      'syncInspectionsTask',
      frequency: const Duration(minutes: 10),
      constraints: Constraints(networkType: NetworkType.connected),
      initialDelay: const Duration(minutes: 2),
    );

    await Workmanager().registerPeriodicTask(
      'syncSignaturesTask',
      'syncSignaturesTask',
      frequency: const Duration(minutes: 5),
      constraints: Constraints(networkType: NetworkType.connected),
      initialDelay: const Duration(minutes: 1),
    );

    debugPrint('Tareas periódicas registradas correctamente');
  } catch (e) {
    debugPrint('Error registrando tareas periódicas: $e');
  }
}

// Nuevo método para registrar una tarea única al cerrar la app
/* Future<void> _registerOneTimeSyncTask() async {
  try {
    await Workmanager().registerOneOffTask(
      'immediateSync',
      'immediateSync',
      constraints: Constraints(networkType: NetworkType.connected),
      initialDelay: Duration.zero,
    );
    debugPrint(' Tarea única registrada para sincronización inmediata');
  } catch (e) {
    debugPrint(' Error registrando tarea única: $e');
  }
}
 */

// Nuevo método para registrar una tarea única al cerrar la app
Future<void> _registerOneTimeSyncTask() async {
  try {
    // Verificar si hay datos pendientes antes de registrar la tarea
    final dbHelper = DatabaseHelper.instance;
    final signatureDbHelper = SignatureDatabaseHelper.instance;

    final pendingOperations = await dbHelper.getPendingOperations();
    final pendingSignatures = await signatureDbHelper.getPendingSignatures();

    if (pendingOperations.isNotEmpty || pendingSignatures.isNotEmpty) {
      await Workmanager().registerOneOffTask(
        'immediateSync',
        'immediateSync',
        constraints: Constraints(networkType: NetworkType.connected),
        initialDelay: Duration.zero,
      );
      debugPrint('Tarea única registrada para sincronización inmediata');
    } else {
      debugPrint('No hay datos pendientes, no se registra tarea única');
    }
  } catch (e) {
    debugPrint('Error registrando tarea única: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSyncListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Registrar tarea única al cerrar la app o pasar a segundo plano
      _registerOneTimeSyncTask();
    }
  }

  void _initSyncListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectivity = Provider.of<Connectivity>(context, listen: false);
      final syncService = Provider.of<SyncService>(context, listen: false);
      final signatureSyncService =
          Provider.of<SignatureSyncService>(context, listen: false);
      final maintenanceSyncService =
          Provider.of<MaintenanceSyncService>(context, listen: false);

      _connectivitySubscription =
          connectivity.onConnectivityChanged.listen((results) {
        final hasConnection = results.any((r) => r != ConnectivityResult.none);
        if (hasConnection) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(seconds: 5), () async {
            try {
              await syncService.syncData();
              await signatureSyncService.syncPendingSignatures();
              await maintenanceSyncService.syncPendingInspections();
            } catch (e) {
              debugPrint('Error sincronizando en background: $e');
            }
          });
        }
      });

      connectivity.checkConnectivity().then((results) async {
        final hasConnection = results.any((r) => r != ConnectivityResult.none);
        if (hasConnection) {
          try {
            await syncService.syncData();
            await signatureSyncService.syncPendingSignatures();
            await maintenanceSyncService.syncPendingInspections();
          } catch (e) {
            debugPrint('Error sincronizando inicialmente: $e');
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.customTheme,
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
