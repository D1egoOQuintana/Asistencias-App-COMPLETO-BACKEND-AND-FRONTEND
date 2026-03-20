import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_themes.dart';
import '../teacher/attendance/quick_qr_attendance_screen.dart';
import '../admin/teachers/teachers_management_screen.dart';
import '../admin/students/improved_student_screen.dart';
import '../admin/classrooms/improved_classroom_screen.dart';
import '../teacher/classrooms/teacher_classrooms_screen.dart';
import '../teacher/students/teacher_students_screen.dart';
import '../teacher/reports/teacher_reports_screen.dart';
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
            Icons.assessment_outlined,
          ]
        : [
            Icons.home_outlined,
            Icons.people_outline,
            Icons.school_outlined,
            Icons.class_outlined,
          ];

    final List<IconData> iconListFilled = isTeacher
        ? [Icons.home, Icons.class_, Icons.people, Icons.assessment]
        : [Icons.home, Icons.people, Icons.school, Icons.class_];

    final List<String> labelList = isTeacher
        ? ['Inicio', 'Mis Aulas', 'Alumnos', 'Reportes']
        : ['Inicio', 'Docentes', 'Estudiantes', 'Aulas'];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: user.role == UserRole.admin
          ? AppBar(
              title: const Text(
                'Panel Admin',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              actions: [
                IconButton(
                  tooltip: 'Cerrar sesión',
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () => _showLogoutDialog(context),
                ),
              ],
            )
          : null,
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
                  // Navegar directamente al escáner QR
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QuickQRAttendanceScreen(),
                    ),
                  );
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
        const TeacherReportsScreen(),
      ];
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas cerrar sesión ahora?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Provider.of<AuthProvider>(context, listen: false).signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}
