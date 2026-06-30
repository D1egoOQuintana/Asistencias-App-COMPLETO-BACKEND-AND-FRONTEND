import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../admin/admin_shell.dart';
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
  final RxInt _currentIndex = 0.obs;
  late final PageController _pageController;
  bool _isTabAnimating = false;
  bool _didPrecacheAssets = false;

  // Cache de widgets para evitar reconstrucciones
  final Map<int, Widget> _screenCache = {};

  static const Duration _tabTransitionDuration = Duration(milliseconds: 240);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex.value);

    // Precalentar pantallas en background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheScreens();
      _warmUpAnimations();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheAssets) return;
    _didPrecacheAssets = true;

    // Precarga mínima de assets críticos para evitar stutter inicial.
    precacheImage(const AssetImage('assets/icon.png'), context);
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

  void _warmUpAnimations() {
    final warmUpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );

    warmUpController
        .forward()
        .then((_) {
          if (mounted) {
            warmUpController.reverse();
          }
        })
        .whenComplete(warmUpController.dispose);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onTabTap(int index) async {
    if (!mounted) return;
    if (_currentIndex.value == index || _isTabAnimating) return;

    _isTabAnimating = true;
    _currentIndex.value = index;

    try {
      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          index,
          duration: _tabTransitionDuration,
          curve: Curves.easeOutCubic,
        );
      }
    } catch (_) {
      // Fallback defensivo para evitar crasheos si la animación se interrumpe.
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    } finally {
      _isTabAnimating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Admin uses its own dedicated shell — no docente code is touched below.
    if (user.role == UserRole.admin) {
      return const AdminShell();
    }

    final isTeacher = user.role == UserRole.docente;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final List<NavigationDestination> destinations = isTeacher
        ? const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded, size: 24),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.class_rounded, size: 24),
              label: 'Mis Aulas',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_rounded, size: 24),
              label: 'Alumnos',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded, size: 24),
              label: 'Reportes',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded, size: 24),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_rounded, size: 24),
              label: 'Docentes',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_rounded, size: 24),
              label: 'Estudiantes',
            ),
            NavigationDestination(
              icon: Icon(Icons.class_rounded, size: 24),
              label: 'Aulas',
            ),
          ];

    final screens = _getScreensForRole(user.role);
    final maxIndex = screens.length - 1;
    if (_currentIndex.value > maxIndex) {
      _currentIndex.value = maxIndex;
    }

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
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => _currentIndex.value = index,
        children: screens
            .map((screen) => RepaintBoundary(child: screen))
            .toList(growable: false),
      ),
      bottomNavigationBar: isMobile
          ? Obx(
              () => NavigationBar(
                selectedIndex: _currentIndex.value.clamp(
                  0,
                  destinations.length - 1,
                ),
                onDestinationSelected: _onTabTap,
                destinations: destinations,
              ),
            )
          : null,
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
