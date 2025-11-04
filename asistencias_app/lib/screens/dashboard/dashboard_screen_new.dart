import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_admin_scaffold/admin_scaffold.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_themes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/classroom_service.dart';
import '../../models/classroom_model.dart';
import '../teacher/attendance/take_attendance_screen.dart';
import '../admin/teachers/teachers_management_screen.dart';
import '../admin/database/database_setup_screen.dart';
import '../admin/students/improved_student_screen.dart';
import '../admin/classrooms/improved_classroom_screen.dart';
import '../teacher/classrooms/teacher_classrooms_screen.dart';
import '../teacher/students/teacher_students_screen.dart';
import 'improved_home_screen.dart';

/// Dashboard principal con sidebar responsive
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Widget _selectedScreen = const ImprovedHomeScreen();
  String _selectedRoute = '/';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _closeDrawerAfterSelection(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scaffoldState = _scaffoldKey.currentState;
      scaffoldState?.closeDrawer();
    });

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isTeacher = user.role == UserRole.docente;

    return Theme(
      data: AppThemes.getThemeForRole(user.role),
      child: AdminScaffold(
        key: _scaffoldKey,
        backgroundColor: isTeacher ? Colors.white : Colors.grey[50],
        appBar: AppBar(
          title: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = MediaQuery.of(context).size.width < 400;
              return Text(
                'Panel de ${user.role.displayName}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isSmallScreen ? 16 : 20,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          backgroundColor: AppThemes.getThemeForRole(user.role).primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            // Usuario info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      user.email.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.email.split('@')[0],
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        user.role.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        sideBar: SideBar(
          items: _buildSidebarItems(user.role),
          selectedRoute: _selectedRoute,
          onSelected: (item) {
            final route = item.route ?? '/';
            final shouldUpdate = route != _selectedRoute;

            if (shouldUpdate) {
              setState(() {
                _selectedRoute = route;
                _selectedScreen = _getScreenForRoute(route, user.role);
              });
            }

            _closeDrawerAfterSelection(context);
          },
          header: Container(
            height: 120,
            width: double.infinity,
            color: AppThemes.getThemeForRole(user.role).primaryColor,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    user.role == UserRole.admin
                        ? Icons.admin_panel_settings
                        : Icons.school,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Asistencias',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user.role.displayName,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          footer: Container(
            height: 80,
            width: double.infinity,
            color: Colors.grey[100],
            child: Center(
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Cerrar Sesión',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => _showLogoutDialog(context),
              ),
            ),
          ),
        ),
        body: Container(
          padding: const EdgeInsets.all(24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(_selectedRoute),
              child: _selectedScreen,
            ),
          ),
        ),
      ),
    );
  }

  /// Construir items del sidebar según el rol
  List<AdminMenuItem> _buildSidebarItems(UserRole role) {
    final baseItems = [
      const AdminMenuItem(title: 'Inicio', route: '/', icon: Icons.dashboard),
    ];

    if (role == UserRole.admin) {
      baseItems.addAll([
        const AdminMenuItem(
          title: 'Gestión de Docentes',
          route: '/teachers',
          icon: Icons.people,
        ),
        const AdminMenuItem(
          title: 'Gestión de Estudiantes',
          route: '/students-admin',
          icon: Icons.school,
        ),
        const AdminMenuItem(
          title: 'Gestión de Aulas',
          route: '/classrooms',
          icon: Icons.class_,
        ),
        const AdminMenuItem(
          title: 'Reportes',
          route: '/reports',
          icon: Icons.analytics,
        ),
        const AdminMenuItem(
          title: 'Configurar BD',
          route: '/database-setup',
          icon: Icons.settings,
        ),
      ]);
    } else {
      baseItems.addAll([
        const AdminMenuItem(
          title: 'Mis Aulas',
          route: '/classroom',
          icon: Icons.class_,
        ),
        const AdminMenuItem(
          title: 'Mis Alumnos',
          route: '/students',
          icon: Icons.people,
        ),
        const AdminMenuItem(
          title: 'Historial',
          route: '/history',
          icon: Icons.history,
        ),
      ]);
    }

    return baseItems;
  }

  /// Obtener pantalla según la ruta
  Widget _getScreenForRoute(String route, UserRole role) {
    switch (route) {
      case '/':
        return const ImprovedHomeScreen();
      case '/teachers':
        return const TeachersManagementScreen();
      case '/students-admin':
        return const ImprovedStudentScreen();
      case '/classrooms':
        return const ImprovedClassroomScreen();
      case '/reports':
        return const ReportsScreen();
      case '/database-setup':
        return const DatabaseSetupScreen();
      case '/classroom':
        return const TeacherClassroomsScreen();
      case '/students':
        return const TeacherStudentsScreen();
      case '/attendance':
        return const TakeAttendanceScreen();
      case '/history':
        return const TakeAttendanceScreen();
      default:
        return const ImprovedHomeScreen();
    }
  }

  /// Mostrar diálogo de confirmación para cerrar sesión
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pantalla de inicio/bienvenida
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¡Bienvenido, ${user.email.split('@')[0]}!',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (user.role == UserRole.docente) ...[
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.class_,
                        color: AppThemes.getThemeForRole(
                          user.role,
                        ).primaryColor,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tu Aula Asignada',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            // Aula asignada del docente (primera)
                            StreamBuilder<QuerySnapshot>(
                              stream: ClassroomService.getClassroomsByTeacher(
                                user.uid,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Text(
                                    'Cargando información del aula...',
                                    style: TextStyle(color: Colors.grey[600]),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Text(
                                    'Error al cargar aula',
                                    style: TextStyle(color: Colors.red[600]),
                                  );
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return Text(
                                    'No tienes aulas asignadas',
                                    style: TextStyle(color: Colors.grey[600]),
                                  );
                                }
                                final classroom = ClassroomModel.fromFirestore(
                                  snapshot.data!.docs.first,
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      classroom.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${classroom.grade} - Sección ${classroom.section}',
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildAdminCard(
                  context,
                  'Docentes',
                  Icons.people,
                  '0', // TODO: Obtener de Firebase
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAdminCard(
                  context,
                  'Aulas',
                  Icons.class_,
                  '0', // TODO: Obtener de Firebase
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAdminCard(
                  context,
                  'Alumnos',
                  Icons.school,
                  '0', // TODO: Obtener de Firebase
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAdminCard(
    BuildContext context,
    String title,
    IconData icon,
    String count,
    Color color,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 16),
            Text(
              count,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

// Pantallas placeholder - las implementaremos paso a paso
// IMPORTANTE: Usar nombres distintos para no colisionar con pantallas reales
class TeachersManagementPlaceholder extends StatelessWidget {
  const TeachersManagementPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Gestión de Docentes - Próximamente'));
}

// La implementación real está en ../admin/classrooms/classroom_management_screen.dart
// class ClassroomsManagementScreen extends StatelessWidget {
//   const ClassroomsManagementScreen({super.key});
//   @override
//   Widget build(BuildContext context) =>
//       const Center(child: Text('Gestión de Aulas - Próximamente'));
// }

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Reportes - Próximamente'));
}

class MyClassroomPlaceholder extends StatelessWidget {
  const MyClassroomPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Mi Aula - Próximamente'));
}

class MyStudentsPlaceholder extends StatelessWidget {
  const MyStudentsPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Mis Alumnos - Próximamente'));
}

// La implementación real está en ../teacher/attendance/take_attendance_screen.dart
// class TakeAttendanceScreen extends StatelessWidget {
//   const TakeAttendanceScreen({super.key});
//   @override
//   Widget build(BuildContext context) =>
//       const Center(child: Text('Tomar Asistencia - Próximamente'));
// }

class AttendanceHistoryPlaceholder extends StatelessWidget {
  const AttendanceHistoryPlaceholder({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Historial - Próximamente'));
}
