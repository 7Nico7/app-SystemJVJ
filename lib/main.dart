/* import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'syncTask') {
      final sharedPreferences = await SharedPreferences.getInstance();
      final dbHelper = DatabaseHelper.instance;
      final offlineService = OfflineService(dbHelper);
      final authService = AuthService();
      final syncService = SyncService(
        offlineService: offlineService,
        dbHelper: dbHelper,
        authService: authService,
      );

      // Intentar sincronizar
      await syncService.syncData();
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();

  // Inicializar Workmanager
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask(
    'syncTask',
    'syncTask',
    frequency: Duration(minutes: 15),
  );

  runApp(
    MultiProvider(
      providers: [
        // Servicios básicos
        Provider<SharedPreferences>(create: (_) => sharedPreferences),
        Provider<Connectivity>(create: (_) => Connectivity()),

        // Stream de conectividad - SOLUCIÓN ACTUALIZADA
        StreamProvider<List<ConnectivityResult>>(
          create: (context) => Connectivity().onConnectivityChanged,
          initialData: [ConnectivityResult.none],
        ),

        // Database Helper
        Provider<DatabaseHelper>(create: (_) => DatabaseHelper.instance),

        // Offline Service
        ChangeNotifierProvider<OfflineService>(
          create: (context) => OfflineService(context.read<DatabaseHelper>()),
        ),

        // AuthService (gestión de autenticación)
        Provider<AuthService>(create: (_) => AuthService()),

        // Sync Service
        Provider<SyncService>(
          create: (context) => SyncService(
            offlineService: context.read<OfflineService>(),
            dbHelper: context.read<DatabaseHelper>(),
            authService: context.read<AuthService>(),
          ),
        ),

        // Dependencias de autenticación
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

        // Dependencias del calendario
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
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
        Locale('en', ''), // Inglés
        Locale('es', ''), // Español (genérico)
        Locale('es', 'ES'), // Español de España
        Locale('es', 'MX'), // Español de México
      ],
      home: const AuthWrapper(),
    );
  }
}
  */

/* 
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

// Añade estas importaciones

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'syncTask') {
      final sharedPreferences = await SharedPreferences.getInstance();
      final dbHelper = DatabaseHelper.instance;
      final offlineService = OfflineService(dbHelper);
      final authService = AuthService();
      final syncService = SyncService(
        offlineService: offlineService,
        dbHelper: dbHelper,
        authService: authService,
      );

      // 1. Sincronización principal (siempre se ejecuta)
      await syncService.syncData();

      // 2. Sincronización de firmas (solo si está habilitada)
      try {
        final signatureSyncService = SignatureSyncService();
        await signatureSyncService.syncPendingSignatures();
      } catch (e) {
        print('Error en sincronización de firmas: $e');
        // No detiene el flujo, solo registra el error
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();

  // Inicializar Workmanager
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask(
    'syncTask',
    'syncTask',
    frequency: Duration(minutes: 15),
  );

  runApp(
    MultiProvider(
      providers: [
        // Servicios básicos
        Provider<SharedPreferences>(create: (_) => sharedPreferences),
        Provider<Connectivity>(create: (_) => Connectivity()),

        // Stream de conectividad
        StreamProvider<List<ConnectivityResult>>(
          create: (context) => Connectivity().onConnectivityChanged,
          initialData: [ConnectivityResult.none],
        ),

        // Database Helper
        Provider<DatabaseHelper>(create: (_) => DatabaseHelper.instance),

        // Offline Service
        ChangeNotifierProvider<OfflineService>(
          create: (context) => OfflineService(context.read<DatabaseHelper>()),
        ),

        // AuthService (gestión de autenticación)
        Provider<AuthService>(create: (_) => AuthService()),

        // Sync Service
        Provider<SyncService>(
          create: (context) => SyncService(
            offlineService: context.read<OfflineService>(),
            dbHelper: context.read<DatabaseHelper>(),
            authService: context.read<AuthService>(),
          ),
        ),

        // Dependencias de autenticación
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

        // Dependencias del calendario
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

        // --------------------- PROVIDERS PARA FIRMAS ---------------------
        // Database Helper para firmas
        Provider<SignatureDatabaseHelper>(
          create: (_) => SignatureDatabaseHelper.instance,
        ),

        // Servicio de sincronización de firmas
        Provider<SignatureSyncService>(
          create: (context) => SignatureSyncService(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Iniciar listeners de sincronización
    _initMainSyncListener(context);

    // No iniciar el listener de firmas hasta que el backend esté listo
    _initSignatureSyncListener(context);

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
        Locale('en', ''), // Inglés
        Locale('es', ''), // Español (genérico)
        Locale('es', 'ES'), // Español de España
        Locale('es', 'MX'), // Español de México
      ],
      home: const AuthWrapper(),
    );
  }

  void _initMainSyncListener(BuildContext context) {
    final connectivity = Provider.of<Connectivity>(context, listen: false);
    final syncService = Provider.of<SyncService>(context, listen: false);

    connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncData();
      }
    });

    // Sincronizar al iniciar si hay conexión
    connectivity.checkConnectivity().then((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncData();
      }
    });
  }

  // Este método se puede habilitar cuando el backend para firmas esté listo

  void _initSignatureSyncListener(BuildContext context) {
    final connectivity = Provider.of<Connectivity>(context, listen: false);
    final syncService =
        Provider.of<SignatureSyncService>(context, listen: false);

    connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncPendingSignatures();
      }
    });

    connectivity.checkConnectivity().then((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncPendingSignatures();
      }
    });
  }
}
 */

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

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'syncTask') {
      final sharedPreferences = await SharedPreferences.getInstance();
      final dbHelper = DatabaseHelper.instance;
      final offlineService = OfflineService(dbHelper);
      final authService = AuthService();
      final syncService = SyncService(
        offlineService: offlineService,
        dbHelper: dbHelper,
        authService: authService,
      );

      // 1. Sincronización principal (siempre se ejecuta)
      await syncService.syncData();

      // 2. Sincronización de firmas (solo si está habilitada)
      try {
        final signatureSyncService = SignatureSyncService();
        await signatureSyncService.syncPendingSignatures();
      } catch (e) {
        print('Error en sincronización de firmas: $e');
        // No detiene el flujo, solo registra el error
      }
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();

  // Inicializar Workmanager
  Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask(
    'syncTask',
    'syncTask',
    frequency: Duration(minutes: 15),
  );

  runApp(
    MultiProvider(
      providers: [
        // Servicios básicos
        Provider<SharedPreferences>(create: (_) => sharedPreferences),
        Provider<Connectivity>(create: (_) => Connectivity()),

        // Stream de conectividad
        StreamProvider<List<ConnectivityResult>>(
          create: (context) => Connectivity().onConnectivityChanged,
          initialData: [ConnectivityResult.none],
        ),

        // Database Helper
        Provider<DatabaseHelper>(create: (_) => DatabaseHelper.instance),

        // Offline Service
        ChangeNotifierProvider<OfflineService>(
          create: (context) => OfflineService(context.read<DatabaseHelper>()),
        ),

        // AuthService (gestión de autenticación)
        Provider<AuthService>(create: (_) => AuthService()),

        // Sync Service (ahora es ChangeNotifier)
        ChangeNotifierProvider<SyncService>(
          create: (context) => SyncService(
            offlineService: context.read<OfflineService>(),
            dbHelper: context.read<DatabaseHelper>(),
            authService: context.read<AuthService>(),
          ),
        ),

        // Dependencias de autenticación
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

        // Dependencias del calendario
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

        // --------------------- PROVIDERS PARA FIRMAS ---------------------
        // Database Helper para firmas
        Provider<SignatureDatabaseHelper>(
          create: (_) => SignatureDatabaseHelper.instance,
        ),

        // Servicio de sincronización de firmas
        Provider<SignatureSyncService>(
          create: (context) => SignatureSyncService(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Iniciar listeners de sincronización
    _initMainSyncListener(context);

    // No iniciar el listener de firmas hasta que el backend esté listo
    _initSignatureSyncListener(context);

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
        Locale('en', ''), // Inglés
        Locale('es', ''), // Español (genérico)
        Locale('es', 'ES'), // Español de España
        Locale('es', 'MX'), // Español de México
      ],
      home: const AuthWrapper(),
    );
  }

  void _initMainSyncListener(BuildContext context) {
    final connectivity = Provider.of<Connectivity>(context, listen: false);
    final syncService = Provider.of<SyncService>(context, listen: false);

    connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncData();
      }
    });

    // Sincronizar al iniciar si hay conexión
    connectivity.checkConnectivity().then((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncData();
      }
    });
  }

  // Este método se puede habilitar cuando el backend para firmas esté listo
  void _initSignatureSyncListener(BuildContext context) {
    final connectivity = Provider.of<Connectivity>(context, listen: false);
    final syncService =
        Provider.of<SignatureSyncService>(context, listen: false);

    connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncPendingSignatures();
      }
    });

    connectivity.checkConnectivity().then((result) {
      if (result != ConnectivityResult.none) {
        syncService.syncPendingSignatures();
      }
    });
  }
}
