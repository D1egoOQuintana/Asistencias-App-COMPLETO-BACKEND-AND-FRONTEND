import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_admin_scaffold/admin_scaffold.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_themes.dart';
import '../admin/teachers/teachers_management_screen.dart' as teachers;
import '../teacher/reports/teacher_reports_screen.dart';

/// Dashboard principal con sidebar responsive
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Widget _selectedScreen = const HomeScreen();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Theme(
      data: AppThemes.getThemeForRole(user.role),
      child: AdminScaffold(
        backgroundColor: Colors.grey[50],
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
            // Usuario info simplificado
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  user.email.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        sideBar: SideBar(
          items: _buildSidebarItems(user.role),
          selectedRoute: '/',
          onSelected: (item) {
            setState(() {
              _selectedScreen = _getScreenForRoute(item.route!, user.role);
            });
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
                      color: Colors.white.withValues(alpha: 0.8),
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
          child: _selectedScreen,
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
          title: 'Gestión de Aulas',
          route: '/classrooms',
          icon: Icons.class_,
        ),
        const AdminMenuItem(
          title: 'Reportes',
          route: '/reports',
          icon: Icons.analytics,
        ),
      ]);
    } else {
      baseItems.addAll([
        const AdminMenuItem(
          title: 'Mi Aula',
          route: '/classroom',
          icon: Icons.class_,
        ),
        const AdminMenuItem(
          title: 'Mis Alumnos',
          route: '/students',
          icon: Icons.people,
        ),
        const AdminMenuItem(
          title: 'Tomar Asistencia',
          route: '/attendance',
          icon: Icons.qr_code_scanner,
        ),
        const AdminMenuItem(
          title: 'Reportes Profesionales',
          route: '/professional-reports',
          icon: Icons.assessment,
        ),
      ]);
    }

    return baseItems;
  }

  /// Obtener pantalla según la ruta
  Widget _getScreenForRoute(String route, UserRole role) {
    switch (route) {
      case '/':
        return const HomeScreen();
      case '/teachers':
        return const teachers.TeachersManagementScreen();
      case '/classrooms':
        return const ClassroomsManagementScreen();
      case '/reports':
        return const ReportsScreen();
      case '/classroom':
        return const MyClassroomScreen();
      case '/students':
        return const MyStudentsScreen();
      case '/attendance':
        return const TakeAttendanceScreen();
      case '/professional-reports':
        return const TeacherReportsScreen();
      default:
        return const HomeScreen();
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
                            // TODO: Aquí mostraremos el aula asignada del docente
                            Text(
                              'Cargando información del aula...',
                              style: TextStyle(color: Colors.grey[600]),
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
class TeachersManagementScreen extends StatelessWidget {
  const TeachersManagementScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // Importamos dinámicamente para evitar conflictos
    return FutureBuilder(
      future: _loadTeachersScreen(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data as Widget;
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Future<Widget> _loadTeachersScreen() async {
    // Cargamos la pantalla real de gestión de docentes
    await Future.delayed(const Duration(milliseconds: 100));
    return const Center(child: Text('Gestión de Docentes - Cargando...'));
  }
}

class ClassroomsManagementScreen extends StatelessWidget {
  const ClassroomsManagementScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Gestión de Aulas - Próximamente'));
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Reportes - Próximamente'));
}

class MyClassroomScreen extends StatelessWidget {
  const MyClassroomScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Mi Aula - Próximamente'));
}

class MyStudentsScreen extends StatelessWidget {
  const MyStudentsScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Mis Alumnos - Próximamente'));
}

class TakeAttendanceScreen extends StatelessWidget {
  const TakeAttendanceScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Tomar Asistencia - Próximamente'));
}
