import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'services/attendance_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/modern_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Precalentar shaders para evitar jank en la primera animación
  await _warmUpShaders();

  runApp(const MyApp());
}

/// Precalienta shaders comunes para evitar lag en primeras animaciones
Future<void> _warmUpShaders() async {
  try {
    final PipelineOwner pipelineOwner = PipelineOwner();
    final RenderView renderView = RenderView(
      configuration: ViewConfiguration.fromView(
        WidgetsBinding.instance.platformDispatcher.views.first,
      ),
      view: WidgetsBinding.instance.platformDispatcher.views.first,
    );
    pipelineOwner.rootNode = renderView;
    renderView.prepareInitialFrame();

    // Simular frame para warm-up
    pipelineOwner.flushLayout();
    pipelineOwner.flushCompositingBits();
    pipelineOwner.flushPaint();
  } catch (e) {
    // Ignorar errores en warm-up (no es crítico)
    debugPrint('Shader warm-up skipped: $e');
  }
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
      child: MaterialApp(
        title: 'Asistencias Escolares',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        ),
        // Bloquear textScaleFactor para mantener UI estable
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.0)),
            child: child!,
          );
        },
        home: const AuthWrapper(),
        debugShowCheckedModeBanner: false,
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
        // 1) Si hay usuario autenticado, ir al dashboard SIEMPRE
        if (authProvider.user != null) {
          return const ModernDashboardScreen();
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

        // 3) Si no hay usuario, mostrar login (aunque haya error o se haya agotado el tiempo)
        return const LoginScreen();
      },
    );
  }
}
