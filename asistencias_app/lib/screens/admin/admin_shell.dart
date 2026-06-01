import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_design_system.dart';
import 'dashboard/admin_dashboard_screen.dart';
import 'teachers/admin_teachers_screen.dart';
// ImprovedStudentScreen se conserva como respaldo legacy en su archivo original.
import 'students/admin_students_screen.dart';
// ImprovedClassroomScreen se conserva como respaldo legacy en su archivo original.
import 'classrooms/admin_classrooms_screen.dart';
import 'sessions/admin_sessions_screen.dart';
import 'reports/admin_reports_screen.dart';
import 'incidents/admin_incidents_screen.dart';
import 'configuration/admin_configuration_screen.dart';
import 'widgets/admin_ui.dart';

/// Paleta del Admin Web Panel (ver ADMIN_DESIGN_GUIDE.md).
const _kCanvas = Color(0xFFF4F6FA);
const _kNavy = Color(0xFF0D1B2A);
const _kNavyText = Color(0xFFB0BEC5);
const _kNavySection = Color(0xFF6B7A8D);
const _kPrimary = Color(0xFF1976D2);
const _kPrimaryLight = Color(0xFF42A5F5);
const _kBorder = Color(0xFFE6EAF0);

/// Rutas web del Admin Panel (el orden coincide con el índice del sidebar).
class AdminRoutes {
  static const dashboard = '/admin/dashboard';
  static const docentes = '/admin/docentes';
  static const estudiantes = '/admin/estudiantes';
  static const aulas = '/admin/aulas';
  static const sesiones = '/admin/sesiones';
  static const reportes = '/admin/reportes';
  static const incidencias = '/admin/incidencias';
  static const configuracion = '/admin/configuracion';

  /// Rutas por índice de sección (mismo orden que los módulos del sidebar).
  static const byIndex = <String>[
    dashboard,
    docentes,
    estudiantes,
    aulas,
    sesiones,
    reportes,
    incidencias,
    configuracion,
  ];

  static int indexOf(String route) {
    final i = byIndex.indexOf(route);
    return i < 0 ? 0 : i;
  }
}

/// Shell responsivo del panel de administración.
/// Desktop (≥1200px): sidebar expandido 240px + topbar 64px.
/// Tablet  (600–1199px): rail compacto navy 72px + topbar 56px.
/// Mobile  (<600px): AppBar navy + BottomNavigationBar.
class AdminShell extends StatefulWidget {
  /// Índice de sección (orden del sidebar / [AdminRoutes.byIndex]). Lo provee
  /// la ruta web actual (p. ej. `/admin/estudiantes` → 2).
  final int sectionIndex;

  const AdminShell({super.key, this.sectionIndex = 0});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Navega por RUTA: la URL refleja la sección y el back/forward del navegador
  /// funciona. (Sin keep-alive: cada sección se construye al entrar.)
  void _select(int i) {
    if (i == widget.sectionIndex) return;
    Get.toNamed(AdminRoutes.byIndex[i]);
  }

  /// Construye SOLO la pantalla de la sección actual (sin IndexedStack):
  /// menor memoria; el estado se reinicia por navegación (trade-off aceptado).
  Widget _screenForIndex(int i) {
    switch (i) {
      case 1:
        return const AdminTeachersScreen();
      case 2:
        return const AdminStudentsScreen();
      case 3:
        return const AdminClassroomsScreen();
      case 4:
        return const AdminSessionsScreen();
      case 5:
        return const AdminReportsScreen();
      case 6:
        return const AdminIncidentsScreen();
      case 7:
        return const AdminConfigurationScreen();
      case 0:
      default:
        return AdminDashboardScreen(onNavigate: _select);
    }
  }

  // ── Módulos (orden = índice de sección / AdminRoutes.byIndex) ──────────────

  static const _modules = <_AdminModule>[
    _AdminModule(
      label: 'Dashboard',
      subtitle: 'Resumen general del sistema',
      icon: Icons.dashboard_outlined,
      iconSelected: Icons.dashboard_rounded,
      section: 'PRINCIPAL',
    ),
    _AdminModule(
      label: 'Docentes',
      subtitle: 'Gestión del personal docente',
      icon: Icons.school_outlined,
      iconSelected: Icons.school_rounded,
      section: 'GESTIÓN',
    ),
    _AdminModule(
      label: 'Estudiantes',
      subtitle: 'Registro y administración de alumnos',
      icon: Icons.people_outline_rounded,
      iconSelected: Icons.people_rounded,
      section: 'GESTIÓN',
    ),
    _AdminModule(
      label: 'Aulas',
      subtitle: 'Aulas, grados y asignación de docentes',
      icon: Icons.class_outlined,
      iconSelected: Icons.class_rounded,
      section: 'GESTIÓN',
    ),
    _AdminModule(
      label: 'Sesiones',
      subtitle: 'Sesiones de asistencia por aula y fecha',
      icon: Icons.event_note_outlined,
      iconSelected: Icons.event_note_rounded,
      section: 'OPERACIÓN',
      hidden: true,
    ),
    _AdminModule(
      label: 'Reportes',
      subtitle: 'Reportes institucionales de asistencia',
      icon: Icons.bar_chart_outlined,
      iconSelected: Icons.bar_chart_rounded,
      section: 'OPERACIÓN',
    ),
    _AdminModule(
      label: 'Incidencias',
      subtitle: 'Alertas y seguimiento de incidencias',
      icon: Icons.warning_amber_outlined,
      iconSelected: Icons.warning_amber_rounded,
      section: 'OPERACIÓN',
    ),
    _AdminModule(
      label: 'Configuración',
      subtitle: 'Parámetros y ajustes del sistema',
      icon: Icons.settings_outlined,
      iconSelected: Icons.settings_rounded,
      section: 'SISTEMA',
    ),
  ];

  // ── Pantallas (IndexedStack preserva estado; ver _buildScreens) ─────────

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;

    if (width >= AppDesignSystem.breakpointDesktop) {
      return _buildWeb(expanded: true);
    }
    if (width >= AppDesignSystem.breakpointMobile) {
      return _buildWeb(expanded: false);
    }
    return _buildMobile();
  }

  // ── Layout web (desktop + tablet comparten estructura) ─────────────────────

  Widget _buildWeb({required bool expanded}) {
    final module = _modules[widget.sectionIndex];
    final user = Provider.of<AuthProvider>(context, listen: false).user;

    return Scaffold(
      backgroundColor: _kCanvas,
      // Inter para TODO el subárbol admin (topbar, sidebar, placeholders y
      // pantallas). No afecta login ni la app docente (otros subárboles).
      body: DefaultTextStyle.merge(
        style: AdminUi.fontBase,
        child: Row(
        children: [
          _AdminSidebar(
            modules: _modules,
            selectedIndex: widget.sectionIndex,
            expanded: expanded,
            userName: user?.fullName ?? 'Administrador',
            userRole: user?.role.displayName ?? 'Administrador',
            initials: _initials(user?.fullName ?? ''),
            onSelect: _select,
            onLogout: () => _confirmLogout(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminTopbar(
                  title: module.label,
                  subtitle: module.subtitle,
                  expanded: expanded,
                ),
                Expanded(
                  child: _screenForIndex(widget.sectionIndex),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  // ── Layout mobile ──────────────────────────────────────────────────────────

  Widget _buildMobile() {
    // Toma los primeros 5 módulos NO ocultos para el bottom nav, preservando su índice
    // global (necesario para routing — _select usa AdminRoutes.byIndex).
    final mobileModules = <({int globalIndex, _AdminModule module})>[];
    for (var i = 0; i < _modules.length && mobileModules.length < 5; i++) {
      if (_modules[i].hidden) continue;
      mobileModules.add((globalIndex: i, module: _modules[i]));
    }

    return Scaffold(
      backgroundColor: _kCanvas,
      appBar: _buildMobileAppBar(),
      body: DefaultTextStyle.merge(
        style: AdminUi.fontBase,
        child: _screenForIndex(widget.sectionIndex),
      ),
      bottomNavigationBar: _buildMobileBottomNav(mobileModules),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final initials = _initials(user?.fullName ?? '');
    final moduleName =
        _modules[widget.sectionIndex.clamp(0, _modules.length - 1)].label;

    return AppBar(
      backgroundColor: _kNavy,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Text(
        moduleName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            color: _kPrimary,
            borderRadius: AppDesignSystem.borderRadiusSM,
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, size: 22),
          tooltip: 'Notificaciones',
          onPressed: () {},
        ),
        if (initials.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: _kPrimary,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, size: 20),
          tooltip: 'Cerrar sesión',
          onPressed: () => _confirmLogout(context),
        ),
      ],
    );
  }

  Widget _buildMobileBottomNav(
      List<({int globalIndex, _AdminModule module})> modules) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: List.generate(modules.length, (i) {
              final m = modules[i].module;
              final globalIndex = modules[i].globalIndex;
              final selected = widget.sectionIndex == globalIndex;
              return Expanded(
                child: InkWell(
                  borderRadius: AppDesignSystem.borderRadiusMD,
                  onTap: () => _select(globalIndex),
                  child: AnimatedContainer(
                    duration: AppDesignSystem.durationFast,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? _kPrimary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: AppDesignSystem.borderRadiusMD,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? m.iconSelected : m.icon,
                          size: 22,
                          color: selected ? _kPrimary : Colors.grey.shade500,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          m.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color:
                                selected ? _kPrimary : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _initials(String fullName) {
    final parts = fullName.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppDesignSystem.borderRadiusLG,
        ),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text('Se cerrará tu sesión en este dispositivo.'),
        actions: [
          AdminButton.ghost(
            label: 'Cancelar',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          AdminButton.danger(
            label: 'Cerrar sesión',
            onPressed: () {
              Navigator.of(ctx).pop();
              Provider.of<AuthProvider>(context, listen: false).signOut();
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOPBAR
// ─────────────────────────────────────────────────────────────────────────────

class _AdminTopbar extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool expanded;

  const _AdminTopbar({
    required this.title,
    required this.subtitle,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: expanded ? 64 : 56,
      padding: EdgeInsets.symmetric(horizontal: expanded ? 24 : 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.textPrimary,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (expanded)
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppDesignSystem.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDEBAR
// ─────────────────────────────────────────────────────────────────────────────

class _AdminSidebar extends StatelessWidget {
  final List<_AdminModule> modules;
  final int selectedIndex;
  final bool expanded;
  final String userName;
  final String userRole;
  final String initials;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const _AdminSidebar({
    required this.modules,
    required this.selectedIndex,
    required this.expanded,
    required this.userName,
    required this.userRole,
    required this.initials,
    required this.onSelect,
    required this.onLogout,
  });

  static const _width = 240.0;
  static const _widthCompact = 72.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDesignSystem.durationNormal,
      curve: AppDesignSystem.curveStandard,
      width: expanded ? _width : _widthCompact,
      decoration: const BoxDecoration(
        color: _kNavy,
        boxShadow: [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLogo(),
          const SizedBox(height: 6),
          Expanded(child: _buildNav()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      height: expanded ? 64 : 56,
      padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 0),
      alignment: expanded ? Alignment.centerLeft : Alignment.center,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF1C2B3A))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: 12),
            const Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Panel Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Sistema de Asistencia',
                    style: TextStyle(color: _kNavyText, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNav() {
    final items = <Widget>[];
    String? lastSection;

    for (var i = 0; i < modules.length; i++) {
      final m = modules[i];
      // Saltar módulos ocultos: se preserva el índice global (i) para que la
      // ruta /admin/<x> siga funcionando si se navega por URL directa.
      if (m.hidden) continue;
      if (m.section != lastSection) {
        items.add(_buildSectionHeader(m.section));
        lastSection = m.section;
      }
      items.add(_buildNavItem(context: items, module: m, index: i));
    }

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 10 : 8,
        vertical: 8,
      ),
      children: items,
    );
  }

  Widget _buildSectionHeader(String section) {
    if (!expanded) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Divider(color: Color(0xFF1C2B3A), height: 1),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Text(
        section,
        style: const TextStyle(
          color: _kNavySection,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required Object context,
    required _AdminModule module,
    required int index,
  }) {
    final isSelected = selectedIndex == index;

    final content = expanded
        ? _expandedItemContent(module, isSelected)
        : _compactItemContent(module, isSelected);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: expanded ? 2 : 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppDesignSystem.borderRadiusMD,
        child: InkWell(
          borderRadius: AppDesignSystem.borderRadiusMD,
          hoverColor: Colors.white.withValues(alpha: 0.06),
          splashColor: Colors.white.withValues(alpha: 0.10),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          onTap: () => onSelect(index),
          child: content,
        ),
      ),
    );
  }

  Widget _expandedItemContent(_AdminModule module, bool isSelected) {
    return Stack(
      children: [
        if (isSelected)
          Positioned(
            left: 0,
            top: 8,
            bottom: 8,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: _kPrimaryLight,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        AnimatedContainer(
          duration: AppDesignSystem.durationFast,
          margin: const EdgeInsets.only(left: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected
                ? _kPrimary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: AppDesignSystem.borderRadiusMD,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? module.iconSelected : module.icon,
                size: 20,
                color: isSelected ? Colors.white : _kNavyText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  module.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : _kNavyText,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (module.isPlaceholder) _buildSoonBadge(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _compactItemContent(_AdminModule module, bool isSelected) {
    return Tooltip(
      message: module.label,
      child: SizedBox(
        height: 46,
        child: Stack(
          children: [
            if (isSelected)
              Positioned(
                left: 0,
                top: 9,
                bottom: 9,
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: _kPrimaryLight,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            Center(
              child: AnimatedContainer(
                duration: AppDesignSystem.durationFast,
                width: 44,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? _kPrimary.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: AppDesignSystem.borderRadiusMD,
                ),
                child: Icon(
                  isSelected ? module.iconSelected : module.icon,
                  size: 22,
                  color: isSelected ? Colors.white : _kNavyText,
                ),
              ),
            ),
            if (module.isPlaceholder)
              Positioned(
                right: 8,
                top: 6,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _kPrimaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kNavy, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Text(
        'Pronto',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.65),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF1C2B3A))),
      ),
      child: expanded ? _expandedFooter() : _compactFooter(),
    );
  }

  Widget _expandedFooter() {
    return Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _kPrimary,
              child: Text(
                initials.isEmpty ? 'A' : initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    userRole,
                    style: const TextStyle(color: _kNavyText, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          borderRadius: AppDesignSystem.borderRadiusMD,
          child: InkWell(
            borderRadius: AppDesignSystem.borderRadiusMD,
            hoverColor: Colors.white.withValues(alpha: 0.05),
            onTap: onLogout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: AppDesignSystem.borderRadiusMD,
                border: Border.all(
                  color: const Color(0xFFEF5350).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF5350)),
                  SizedBox(width: 10),
                  Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: Color(0xFFEF5350),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactFooter() {
    return Column(
      children: [
        Tooltip(
          message: userName,
          child: CircleAvatar(
            radius: 17,
            backgroundColor: _kPrimary,
            child: Text(
              initials.isEmpty ? 'A' : initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF5350)),
          iconSize: 20,
          tooltip: 'Cerrar sesión',
          onPressed: onLogout,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _AdminModule {
  final String label;
  final String subtitle;
  final IconData icon;
  final IconData iconSelected;
  final String section;
  final bool isPlaceholder;
  /// Si `true`, el módulo no aparece en sidebar ni en bottom nav, pero su
  /// ruta sigue disponible por URL directa.
  final bool hidden;

  const _AdminModule({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconSelected,
    required this.section,
    // Conservado por compatibilidad (badge "Pronto"); hoy ningún módulo lo usa.
    // ignore: unused_element_parameter
    this.isPlaceholder = false,
    this.hidden = false,
  });
}
