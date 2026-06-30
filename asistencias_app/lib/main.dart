import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/scheduler.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'services/attendance_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/web_role_blocked_screen.dart';
import 'screens/auth/mobile_role_blocked_screen.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/admin/classrooms/admin_classroom_detail_screen.dart';
import 'screens/dashboard/modern_dashboard_screen.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError capturado: ${details.exceptionAsString()}');
        if (details.stack != null) {
          debugPrint(details.stack.toString());
        }
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Error no manejado (PlatformDispatcher): $error');
        debugPrint(stack.toString());
        return true;
      };

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await initializeDateFormatting('es', null);

      // Warm-up global para reducir jank inicial en primeras animaciones.
      SchedulerBinding.instance.scheduleWarmUpFrame();

      // Cache de imágenes más amplia para evitar stutter por recarga temprana.
      PaintingBinding.instance.imageCache.maximumSizeBytes = 150 << 20;

      runApp(const MyApp());
    },
    (error, stack) {
      debugPrint('Error no manejado (Zone): $error');
      debugPrint(stack.toString());
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(
          create: (_) => AttendanceProvider(AttendanceRepository()),
        ),
      ],
      child: GetMaterialApp(
        title: 'Asistencias Escolares',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
          textTheme: GoogleFonts.manropeTextTheme(ThemeData.light().textTheme),
        ),
        // Transición entre secciones: fade sobrio y rápido (evita el slide
        // pesado por defecto de GetX al cambiar de ruta).
        defaultTransition: Transition.fadeIn,
        transitionDuration: const Duration(milliseconds: 150),
        // Routing web real: `/` (login/guards) + rutas por sección admin.
        // La URL refleja la sección, el refresh la conserva y back/forward
        // del navegador funcionan. Sin paquetes nuevos (GetX ya está).
        initialRoute: '/',
        getPages: [
          GetPage(name: '/', page: () => const AuthWrapper()),
          GetPage(
              name: AdminRoutes.dashboard,
              page: () => const AdminRouteScreen(0)),
          GetPage(
              name: AdminRoutes.docentes,
              page: () => const AdminRouteScreen(1)),
          GetPage(
              name: AdminRoutes.estudiantes,
              page: () => const AdminRouteScreen(2)),
          GetPage(
              name: AdminRoutes.aulas, page: () => const AdminRouteScreen(3)),
          GetPage(
              name: AdminRoutes.sesiones,
              page: () => const AdminRouteScreen(4)),
          GetPage(
              name: AdminRoutes.reportes,
              page: () => const AdminRouteScreen(5)),
          GetPage(
              name: AdminRoutes.incidencias,
              page: () => const AdminRouteScreen(6)),
          GetPage(
              name: AdminRoutes.configuracion,
              page: () => const AdminRouteScreen(7)),
          // Detalle de aula. Ej.: /admin/aulas/Q39spttI7nNWJQHcYFHJ
          GetPage(
            name: '/admin/aulas/:classroomId',
            page: () => AdminClassroomDetailScreen(
              classroomId: Get.parameters['classroomId'] ?? '',
            ),
          ),
        ],
        unknownRoute:
            GetPage(name: '/notfound', page: () => const _RouteNotFound()),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Loader minimal usado durante redirecciones de ruta.
class _RouteLoader extends StatelessWidget {
  const _RouteLoader();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Programa una redirección de ruta segura (sin loops) tras el frame actual.
void _redirectTo(String route) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (Get.currentRoute != route) Get.offAllNamed(route);
  });
}

/// Pantalla-guard de cada ruta `/admin/<sección>`: valida sesión + plataforma
/// y muestra el [AdminShell] de esa sección, o redirige/bloquea.
class AdminRouteScreen extends StatelessWidget {
  final int sectionIndex;
  const AdminRouteScreen(this.sectionIndex, {super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        if (user == null) {
          if (authProvider.isLoading) return const _RouteLoader();
          _redirectTo('/'); // no autenticado → home/login
          return const _RouteLoader();
        }
        // El panel admin es solo web.
        if (!kIsWeb) {
          _redirectTo('/');
          return const _RouteLoader();
        }
        if (user.role == UserRole.admin) {
          return AdminShell(sectionIndex: sectionIndex);
        }
        // Web + rol no-admin → bloqueo (no redirige, mensaje claro).
        return const WebRoleBlockedScreen();
      },
    );
  }
}

/// 404 profesional para rutas inexistentes.
class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FD),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off_rounded,
                size: 56, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            const Text(
              'Página no encontrada',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0B1F3B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'La ruta solicitada no existe en el panel.',
              style: TextStyle(fontSize: 13, color: Color(0xFF5F6470)),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Get.offAllNamed('/'),
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('Ir al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget que maneja la navegación inicial según el estado de autenticación
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _forceShowLogin = false;

  @override
  void initState() {
    super.initState();
    // Timeout de seguridad reducido: si después de 5 segundos sigue cargando, mostrar login
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _forceShowLogin = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 1) Sesión activa → routing por plataforma + rol REAL (Firestore).
        //    El rol proviene de users/{uid}.role vía AuthService/AuthProvider,
        //    no del formulario: la seguridad no depende de la UI.
        final user = authProvider.user;
        if (user != null) {
          if (kIsWeb) {
            // Web = solo Administrador.
            // - admin → redirige a la ruta del dashboard (URL real)
            // - otro  → bloqueo (usar la app móvil)
            if (user.role == UserRole.admin) {
              _redirectTo(AdminRoutes.dashboard);
              return const _RouteLoader();
            }
            return const WebRoleBlockedScreen();
          }
          // Móvil = solo Docente.
          // - docente → flujo docente actual
          // - otro    → bloqueo (usar el panel web)
          if (user.role == UserRole.docente) {
            return const ModernDashboardScreen();
          }
          return const MobileRoleBlockedScreen();
        }

        // 2) Mostrar loading mientras se inicializa (máximo 5 segundos)
        if (authProvider.isLoading && !_forceShowLogin) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando...'),
                ],
              ),
            ),
          );
        }

        // 3) Sin usuario → login, sin selector de portal en ninguna plataforma.
        //    Web   → acceso administrador forzado.
        //    Móvil → acceso docente forzado.
        return kIsWeb
            ? const LoginScreen(forcedRole: UserRole.admin)
            : const LoginScreen(forcedRole: UserRole.docente);
      },
    );
  }
}
