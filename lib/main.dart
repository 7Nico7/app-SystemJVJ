import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:systemjvj/maintenance/data/signatureDatabaseHelper.dart';
import 'package:systemjvj/maintenance/data/signature_sync_service.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';
import 'package:systemjvj/schedule/services/syncService.dart';
import 'package:workmanager/workmanager.dart';
import 'package:systemjvj/features/auth/controller/login_controller.dart';
import 'package:systemjvj/features/auth/domain/login_use_case.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/features/auth/presentation/auth_wrapper.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'syncTask') {
      final sharedPreferences = await SharedPreferences.getInstance();
      final dbHelper = DatabaseHelper.instance;
      final authService = AuthService();
      final connectivity = Connectivity();

      // Creamos OfflineService y SyncService sin ciclo
      final offlineService = OfflineService(dbHelper, null, connectivity);
      final syncService = SyncService(
          offlineService: offlineService,
          dbHelper: dbHelper,
          authService: authService);
      offlineService.syncService = syncService;

      await syncService.syncData();

      try {
        final signatureSyncService = SignatureSyncService();
        await signatureSyncService.syncPendingSignatures();
      } catch (e) {
        print('Error en sincronización de firmas: $e');
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() async {
    final sharedPreferences = await SharedPreferences.getInstance();

    Workmanager().initialize(callbackDispatcher);
    Workmanager().registerPeriodicTask(
      'syncTask',
      'syncTask',
      frequency: const Duration(minutes: 15),
    );

    runApp(
      MultiProvider(
        providers: [
          Provider<SharedPreferences>(create: (_) => sharedPreferences),
          Provider<Connectivity>(create: (_) => Connectivity()),
          StreamProvider<List<ConnectivityResult>>(
            create: (context) => Connectivity().onConnectivityChanged,
            initialData: [ConnectivityResult.none],
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
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('❌ Error en main: $error');
    debugPrint('Stack: $stack');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initMainSyncListener();
    _initSignatureSyncListener();
  }

  void _initMainSyncListener() {
    final connectivity = Provider.of<Connectivity>(context, listen: false);
    final syncService = Provider.of<SyncService>(context, listen: false);

    connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncData();
      }
    });

    connectivity.checkConnectivity().then((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncData();
      }
    });
  }

  void _initSignatureSyncListener() {
    // Lógica de sincronización de firmas
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








/* import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:systemjvj/maintenance/data/signatureDatabaseHelper.dart';
import 'package:systemjvj/maintenance/data/signature_sync_service.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';
import 'package:systemjvj/schedule/services/syncService.dart';
import 'package:workmanager/workmanager.dart';
import 'package:systemjvj/features/auth/controller/login_controller.dart';
import 'package:systemjvj/features/auth/domain/login_use_case.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/features/auth/presentation/auth_wrapper.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'syncTask') {
      final sharedPreferences = await SharedPreferences.getInstance();
      final dbHelper = DatabaseHelper.instance;
      final authService = AuthService();
      final connectivity = Connectivity();

// Paso 1: crear una variable nullable
      SyncService? tempSyncService;

// Paso 2: crear el OfflineService con esa variable (usando `!` más adelante)
      final offlineService = OfflineService(
        dbHelper,
        // se asignará después, pero la pasamos como null temporalmente
        tempSyncService!, // <- por ahora dará error, así que lo haremos después
        connectivity,
      );

// Paso 3: crear el SyncService real
      final syncService = SyncService(
        offlineService: offlineService,
        dbHelper: dbHelper,
        authService: authService,
      );

// Paso 4: ahora asignamos la variable temporal
      tempSyncService = syncService;

      await syncService.syncData();

      try {
        final signatureSyncService = SignatureSyncService();
        await signatureSyncService.syncPendingSignatures();
      } catch (e) {
        print('Error en sincronización de firmas: $e');
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() async {
    final sharedPreferences = await SharedPreferences.getInstance();

    Workmanager().initialize(callbackDispatcher);
    Workmanager().registerPeriodicTask(
      'syncTask',
      'syncTask',
      frequency: const Duration(minutes: 15),
    );

    runApp(
      MultiProvider(
        providers: [
          Provider<SharedPreferences>(create: (_) => sharedPreferences),
          Provider<Connectivity>(create: (_) => Connectivity()),
          StreamProvider<List<ConnectivityResult>>(
            create: (context) => Connectivity().onConnectivityChanged,
            initialData: [ConnectivityResult.none],
          ),
          Provider<DatabaseHelper>(create: (_) => DatabaseHelper.instance),
          ChangeNotifierProvider<OfflineService>(
            create: (context) => OfflineService(
              context.read<DatabaseHelper>(),
              context.read<SyncService>(),
              context.read<Connectivity>(),
            ),
          ),
          Provider<AuthService>(create: (_) => AuthService()),
          ChangeNotifierProvider<SyncService>(
            create: (context) => SyncService(
              offlineService: context.read<OfflineService>(),
              dbHelper: context.read<DatabaseHelper>(),
              authService: context.read<AuthService>(),
            ),
          ),
          ProxyProvider<AuthService, LoginUseCase>(
            update: (_, authService, __) => LoginUseCase(authService),
          ),
          ChangeNotifierProxyProvider2<AuthService, LoginUseCase,
              LoginController>(
            create: (_) => LoginController(
              LoginUseCase(AuthService()),
              AuthService(),
            ),
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
          Provider<SignatureSyncService>(
            create: (context) => SignatureSyncService(),
          ),
        ],
        child: const MyApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('❌ Error en main: $error');
    debugPrint('Stack: $stack');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initMainSyncListener();
    _initSignatureSyncListener();
  }

  void _initMainSyncListener() {
    final connectivity = Provider.of<Connectivity>(context, listen: false);
    final syncService = Provider.of<SyncService>(context, listen: false);

    connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncData();
      }
    });

    connectivity.checkConnectivity().then((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncData();
      }
    });
  }

  void _initSignatureSyncListener() {
    // Aquí pones la lógica que antes tenías para firmas si aplica
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
  */
/* 
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:systemjvj/maintenance/data/signatureDatabaseHelper.dart';
import 'package:systemjvj/maintenance/data/signature_sync_service.dart';
import 'package:systemjvj/schedule/repository/databaseHelper.dart';
import 'package:systemjvj/schedule/services/offlineService.dart';
import 'package:systemjvj/schedule/services/syncService.dart';
import 'package:workmanager/workmanager.dart';
import 'package:systemjvj/features/auth/controller/login_controller.dart';
import 'package:systemjvj/features/auth/domain/login_use_case.dart';
import 'package:systemjvj/features/auth/data/auth_service.dart';
import 'package:systemjvj/features/auth/presentation/auth_wrapper.dart';
import 'package:systemjvj/schedule/providers/schedule_provider.dart';
import 'package:systemjvj/schedule/services/api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'syncTask') {
      final sharedPreferences = await SharedPreferences.getInstance();
      final dbHelper = DatabaseHelper.instance;
      final connectivity = Connectivity();
      final authService = AuthService();

      // Crear SyncService primero (offlineService será asignado después)
      final syncService = SyncService(
        offlineService: null,
        dbHelper: dbHelper,
        authService: authService,
      );

      // Crear OfflineService pasando el SyncService correcto
      final offlineService = OfflineService(
        dbHelper,
        syncService,
        connectivity,
      );

      // Enlazar offlineService dentro de syncService
      syncService.offlineService = offlineService;

      await syncService.syncData();

      try {
        final signatureSyncService = SignatureSyncService();
        await signatureSyncService.syncPendingSignatures();
      } catch (e) {
        print('Error en sincronización de firmas: $e');
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runZonedGuarded(() async {
    final sharedPreferences = await SharedPreferences.getInstance();
    final connectivity = Connectivity();

    Workmanager().initialize(callbackDispatcher);
    Workmanager().registerPeriodicTask(
      'syncTask',
      'syncTask',
      frequency: const Duration(minutes: 15),
    );

    runApp(MultiProvider(
      providers: [
        Provider<SharedPreferences>(create: (_) => sharedPreferences),
        Provider<Connectivity>(create: (_) => connectivity),
        StreamProvider<List<ConnectivityResult>>(
          create: (context) => connectivity.onConnectivityChanged,
          initialData: [ConnectivityResult.none],
        ),
        Provider<DatabaseHelper>(create: (_) => DatabaseHelper.instance),
        Provider<AuthService>(create: (_) => AuthService()),

        // Crear primero el SyncService
        ChangeNotifierProvider<SyncService>(
          create: (context) => SyncService(
            offlineService: null,
            dbHelper: context.read<DatabaseHelper>(),
            authService: context.read<AuthService>(),
          ),
        ),

        // Luego el OfflineService usando el SyncService
        ChangeNotifierProvider<OfflineService>(
          create: (context) {
            final offline = OfflineService(
              context.read<DatabaseHelper>(),
              context.read<SyncService>(),
              context.read<Connectivity>(),
            );
            // enlazarlo al SyncService
            context.read<SyncService>().offlineService = offline;
            return offline;
          },
        ),

        ProxyProvider<AuthService, LoginUseCase>(
          update: (_, authService, __) => LoginUseCase(authService),
        ),
        ChangeNotifierProxyProvider2<AuthService, LoginUseCase,
            LoginController>(
          create: (_) => LoginController(
            LoginUseCase(AuthService()),
            AuthService(),
          ),
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
              connectivity: connectivity,
            ),
            connectivity: connectivity,
          ),
          update: (_, apiService, scheduleProvider) {
            scheduleProvider!..updateApiService(apiService);
            return scheduleProvider;
          },
        ),

        Provider<SignatureDatabaseHelper>(
          create: (_) => SignatureDatabaseHelper.instance,
        ),
        Provider<SignatureSyncService>(
          create: (context) => SignatureSyncService(),
        ),
      ],
      child: const MyApp(),
    ));
  }, (error, stack) {
    debugPrint('❌ Error en main: $error');
    debugPrint('Stack: $stack');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _initMainSyncListener();
    _initSignatureSyncListener();
  }

  void _initMainSyncListener() {
    final connectivity = Provider.of<Connectivity>(context, listen: false);
    final syncService = Provider.of<SyncService>(context, listen: false);

    connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncData();
      }
    });

    connectivity.checkConnectivity().then((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncData();
      }
    });
  }

  void _initSignatureSyncListener() {
    // Aquí pones la lógica que antes tenías para firmas si aplica
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', ''), // Español
      ],
      home: const AuthWrapper(),
    );
  }
}
 */