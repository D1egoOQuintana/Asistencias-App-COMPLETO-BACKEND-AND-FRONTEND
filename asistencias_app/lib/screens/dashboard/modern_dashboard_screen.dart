import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_themes.dart';
import '../teacher/attendance/take_attendance_screen.dart';
import '../admin/teachers/teachers_management_screen.dart';
import '../admin/database/database_setup_screen.dart';
import '../admin/students/improved_student_screen.dart';
import '../admin/classrooms/improved_classroom_screen.dart';
import '../teacher/classrooms/teacher_classrooms_screen.dart';
import '../teacher/students/teacher_students_screen.dart';
import 'improved_home_screen.dart';

/// Dashboard moderno con navegación inferior estilo Instagram
class ModernDashboardScreen extends StatefulWidget {
  const ModernDashboardScreen({super.key});

  @override
  State<ModernDashboardScreen> createState() => _ModernDashboardScreenState();
}

class _ModernDashboardScreenState extends State<ModernDashboardScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  int _currentIndex = 0;
  late AnimationController _fabAnimationController;

  // Controllers para mantener el estado de cada página
  final PageController _pageController = PageController();

  // Cache de widgets para evitar reconstrucciones
  final Map<int, Widget> _screenCache = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimationController.forward();

    // Precalentar pantallas en background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheScreens();
    });
  }

  /// Precarga pantallas para transiciones suaves
  void _precacheScreens() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    final screens = _getScreensForRole(user.role);
    for (int i = 0; i < screens.length; i++) {
      if (!_screenCache.containsKey(i)) {
        _screenCache[i] = screens[i];
      }
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isTeacher = user.role == UserRole.docente;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Definir iconos y pantallas según el rol (outline + filled)
    final List<IconData> iconListOutline = isTeacher
        ? [
            Icons.home_outlined,
            Icons.class_outlined,
            Icons.people_outline,
            Icons.history_outlined,
          ]
        : [
            Icons.home_outlined,
            Icons.people_outline,
            Icons.school_outlined,
            Icons.class_outlined,
          ];

    final List<IconData> iconListFilled = isTeacher
        ? [Icons.home, Icons.class_, Icons.people, Icons.history]
        : [Icons.home, Icons.people, Icons.school, Icons.class_];

    final List<String> labelList = isTeacher
        ? ['Inicio', 'Mis Aulas', 'Alumnos', 'Historial']
        : ['Inicio', 'Docentes', 'Estudiantes', 'Aulas'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          labelList[_currentIndex],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppThemes.getThemeForRole(user.role).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Avatar del usuario
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _showProfileMenu(context),
              child: Hero(
                tag: 'user_avatar',
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF64B5F6), Color(0xFF42A5F5)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user.email.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        physics: const NeverScrollableScrollPhysics(), // Desactivar swipe
        children: _getScreensForRole(user.role),
      ),
      floatingActionButton:
          isMobile && isTeacher && MediaQuery.of(context).viewInsets.bottom == 0
          ? ScaleTransition(
              scale: _fabAnimationController,
              child: FloatingActionButton(
                onPressed: () {
                  // Acción central (ej: escanear QR)
                  _showCenterAction(context);
                },
                backgroundColor: AppThemes.getThemeForRole(
                  user.role,
                ).primaryColor,
                child: const Icon(Icons.qr_code_scanner, color: Colors.white),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: isMobile
          ? _buildModernBottomNavBar(
              iconListOutline: iconListOutline,
              iconListFilled: iconListFilled,
              labelList: labelList,
              isTeacher: isTeacher,
              primaryColor: AppThemes.getThemeForRole(user.role).primaryColor,
            )
          : null,
    );
  }

  /// Barra de navegación inferior personalizada con estilo moderno
  Widget _buildModernBottomNavBar({
    required List<IconData> iconListOutline,
    required List<IconData> iconListFilled,
    required List<String> labelList,
    required bool isTeacher,
    required Color primaryColor,
  }) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.grey.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        child: SizedBox(
          height: 65,
          child: Row(
            children: List.generate(
              iconListOutline.length,
              (index) => Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _currentIndex = index;
                      });
                      _pageController.jumpToPage(index);
                    },
                    splashColor: primaryColor.withValues(alpha: 0.1),
                    highlightColor: primaryColor.withValues(alpha: 0.05),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Ícono
                          Icon(
                            _currentIndex == index
                                ? iconListFilled[index]
                                : iconListOutline[index],
                            size: 26,
                            color: _currentIndex == index
                                ? primaryColor
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(height: 4),
                          // Texto
                          Flexible(
                            child: Text(
                              labelList[index],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _currentIndex == index
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: _currentIndex == index
                                    ? primaryColor
                                    : const Color(0xFF6B7280),
                                height: 1.2,
                                letterSpacing: 0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Obtener las pantallas según el rol del usuario
  List<Widget> _getScreensForRole(UserRole role) {
    if (role == UserRole.admin) {
      return [
        const ImprovedHomeScreen(),
        const TeachersManagementScreen(),
        const ImprovedStudentScreen(),
        const ImprovedClassroomScreen(),
      ];
    } else {
      return [
        const ImprovedHomeScreen(),
        const TeacherClassroomsScreen(),
        const TeacherStudentsScreen(),
        const TakeAttendanceScreen(),
      ];
    }
  }

  /// Mostrar menú de perfil
  void _showProfileMenu(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user!;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de drag
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Avatar y datos del usuario
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF64B5F6), Color(0xFF42A5F5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF42A5F5).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  user.email.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.email.split('@')[0],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppThemes.getThemeForRole(
                  user.role,
                ).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user.role.displayName,
                style: TextStyle(
                  color: AppThemes.getThemeForRole(user.role).primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Opciones
            if (user.role == UserRole.admin) ...[
              _buildMenuOption(
                icon: Icons.analytics,
                label: 'Ver Reportes',
                onTap: () {
                  Navigator.pop(context);
                  // Navegar a reportes
                },
              ),
              const SizedBox(height: 12),
              _buildMenuOption(
                icon: Icons.settings,
                label: 'Configurar BD',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DatabaseSetupScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],

            _buildMenuOption(
              icon: Icons.logout,
              label: 'Cerrar Sesión',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.grey[700], size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: color ?? Colors.grey[900],
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  /// Mostrar acción central (QR scanner para docentes)
  void _showCenterAction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Icon(
              Icons.qr_code_scanner,
              size: 64,
              color: Color(0xFF2196F3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Escanear Código QR',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Escanea el código QR del estudiante para registrar asistencia',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Aquí iría la navegación al scanner QR
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Abrir Escáner',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Mostrar diálogo de confirmación para cerrar sesión
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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
