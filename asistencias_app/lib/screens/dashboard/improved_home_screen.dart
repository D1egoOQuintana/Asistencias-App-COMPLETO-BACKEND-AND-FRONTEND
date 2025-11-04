import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/classroom_service.dart';
import '../../services/admin_service.dart';
import '../../theme/app_design_system.dart';
import '../../widgets/common/state_widgets.dart';
import '../../models/classroom_model.dart';
import '../../models/user_model.dart';

/// Pantalla de inicio mejorada con diseño profesional y responsivo
class ImprovedHomeScreen extends StatefulWidget {
  const ImprovedHomeScreen({super.key});

  @override
  State<ImprovedHomeScreen> createState() => _ImprovedHomeScreenState();
}

class _ImprovedHomeScreenState extends State<ImprovedHomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de bienvenida
            _buildModernWelcomeHeader(context, user),
            const SizedBox(height: 32),

            // Contenido específico según el rol
            if (user.role == UserRole.admin)
              _buildAdminDashboard(context)
            else
              _buildTeacherDashboard(context, user.uid),
          ],
        ),
      ),
    );
  }

  /// Header moderno de bienvenida
  Widget _buildModernWelcomeHeader(BuildContext context, UserModel user) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    IconData greetingIcon;

    if (hour < 12) {
      greeting = 'Buenos días';
      greetingIcon = Icons.wb_sunny_outlined;
    } else if (hour < 18) {
      greeting = 'Buenas tardes';
      greetingIcon = Icons.wb_twilight_outlined;
    } else {
      greeting = 'Buenas noches';
      greetingIcon = Icons.nightlight_outlined;
    }

    final isTeacher = user.role == UserRole.docente;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
          decoration: BoxDecoration(
            color: isTeacher ? Colors.white : Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(24),
            border: isTeacher
                ? Border.all(color: Colors.grey[200]!, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: isTeacher
                    ? Colors.grey.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar con gradiente
              Container(
                width: isSmallScreen ? 56 : 64,
                height: isSmallScreen ? 56 : 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isTeacher
                        ? [const Color(0xFF2196F3), const Color(0xFF1976D2)]
                        : [
                            Colors.white.withValues(alpha: 0.3),
                            Colors.white.withValues(alpha: 0.2),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isTeacher ? const Color(0xFF2196F3) : Colors.white)
                              .withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName.substring(0, 1).toUpperCase()
                        : user.email.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 24 : 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              SizedBox(width: isSmallScreen ? 16 : 20),

              // Información del usuario
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          greetingIcon,
                          size: isSmallScreen ? 16 : 18,
                          color: isTeacher
                              ? Colors.grey[600]
                              : Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            greeting,
                            style: TextStyle(
                              color: isTeacher
                                  ? Colors.grey[600]
                                  : Colors.white.withValues(alpha: 0.9),
                              fontSize: isSmallScreen ? 14 : 15,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    Text(
                      user.fullName.isNotEmpty
                          ? user.fullName
                          : user.email.split('@')[0],
                      style: TextStyle(
                        color: isTeacher ? Colors.grey[900] : Colors.white,
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12,
                        vertical: isSmallScreen ? 4 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: isTeacher
                            ? const Color(0xFF2196F3).withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: isTeacher
                            ? Border.all(
                                color: const Color(
                                  0xFF2196F3,
                                ).withValues(alpha: 0.3),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            user.role == UserRole.admin
                                ? Icons.admin_panel_settings
                                : Icons.school,
                            size: isSmallScreen ? 14 : 16,
                            color: isTeacher
                                ? const Color(0xFF2196F3)
                                : Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user.role.displayName,
                            style: TextStyle(
                              color: isTeacher
                                  ? const Color(0xFF2196F3)
                                  : Colors.white,
                              fontSize: isSmallScreen ? 12 : 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Dashboard para administradores
  Widget _buildAdminDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen del Sistema',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Cards de estadísticas
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
            // Ajustar aspect ratio según el número de columnas
            final aspectRatio = crossAxisCount == 2 ? 1.2 : 1.5;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossAxisCount,
              childAspectRatio: aspectRatio,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildStatCard(
                  context: context,
                  title: 'Total Docentes',
                  icon: Icons.people,
                  color: Colors.blue,
                  stream: AdminService.getActiveTeachers(),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Total Aulas',
                  icon: Icons.class_,
                  color: Colors.green,
                  stream: ClassroomService.getAllClassrooms(),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Total Estudiantes',
                  icon: Icons.school,
                  color: Colors.orange,
                  stream: FirebaseFirestore.instance
                      .collection('students')
                      .where('isActive', isEqualTo: true)
                      .snapshots(),
                ),
                _buildStatCard(
                  context: context,
                  title: 'Asistencias Hoy',
                  icon: Icons.check_circle,
                  color: Colors.purple,
                  stream: FirebaseFirestore.instance
                      .collection('attendances')
                      .where('date', isEqualTo: _getTodayString())
                      .snapshots(),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 32),

        // Lista de aulas recientes
        Text(
          'Aulas Registradas',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildRecentClassrooms(),
      ],
    );
  }

  /// Dashboard para docentes
  Widget _buildTeacherDashboard(BuildContext context, String teacherUid) {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Métricas de hoy
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 600;
            return Text(
              'Resumen de Hoy',
              style: TextStyle(
                fontSize: isSmallScreen ? 22 : 26,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
                letterSpacing: -0.5,
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        _buildTodayMetrics(context, teacherUid, todayKey),

        const SizedBox(height: 32),

        // Accesos rápidos
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 600;
            return Text(
              'Accesos Rápidos',
              style: TextStyle(
                fontSize: isSmallScreen ? 22 : 26,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
                letterSpacing: -0.5,
              ),
            );
          },
        ),
        const SizedBox(height: 20),

        _buildQuickActions(context),
      ],
    );
  }

  /// Métricas del día actual
  Widget _buildTodayMetrics(
    BuildContext context,
    String teacherUid,
    String todayKey,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: ClassroomService.getClassroomsByTeacherSimple(teacherUid),
      builder: (context, classroomSnapshot) {
        if (classroomSnapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(strokeWidth: 3),
                const SizedBox(height: 16),
                Text(
                  'Cargando métricas...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          );
        }

        if (classroomSnapshot.hasError) {
          return const ErrorStateWidget(
            message: 'Error al cargar métricas. Intenta nuevamente.',
            icon: Icons.analytics_outlined,
          );
        }

        final classrooms =
            classroomSnapshot.data?.docs
                .map((doc) => ClassroomModel.fromFirestore(doc))
                .toList() ??
            [];

        final totalClassrooms = classrooms.length;
        final activeClassrooms = classrooms.where((c) => c.isActive).length;

        return LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
            final spacing = 16.0;
            final availableWidth = constraints.maxWidth;
            final itemWidth = crossAxisCount > 1
                ? (availableWidth - spacing * (crossAxisCount - 1)) /
                      crossAxisCount
                : availableWidth;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: crossAxisCount > 1 ? itemWidth : availableWidth,
                  child: _buildMetricCard(
                    context,
                    icon: Icons.class_,
                    title: 'Aulas Totales',
                    value: '$totalClassrooms',
                    subtitle: '$activeClassrooms activas',
                    color: AppDesignSystem.primaryColor,
                    gradient: LinearGradient(
                      colors: [
                        AppDesignSystem.primaryColor,
                        AppDesignSystem.primaryLight,
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: crossAxisCount > 1 ? itemWidth : availableWidth,
                  child: _buildMetricCard(
                    context,
                    icon: Icons.today,
                    title: 'Fecha de Hoy',
                    value: '${DateTime.now().day}',
                    subtitle:
                        _getMonthName(DateTime.now().month) +
                        ' ${DateTime.now().year}',
                    color: AppDesignSystem.successColor,
                    gradient: LinearGradient(
                      colors: [
                        AppDesignSystem.successColor,
                        AppDesignSystem.successLight,
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: crossAxisCount > 1 ? itemWidth : availableWidth,
                  child: _buildMetricCard(
                    context,
                    icon: Icons.access_time,
                    title: 'Hora Actual',
                    value:
                        '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    subtitle: 'Actualizado',
                    color: AppDesignSystem.infoColor,
                    gradient: LinearGradient(
                      colors: [
                        AppDesignSystem.infoColor,
                        AppDesignSystem.infoLight,
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: crossAxisCount > 1 ? itemWidth : availableWidth,
                  child: _buildMetricCard(
                    context,
                    icon: Icons.event_available,
                    title: 'Con Horarios',
                    value: '${classrooms.where((c) => c.hasSchedule).length}',
                    subtitle: 'aulas configuradas',
                    color: AppDesignSystem.secondaryColor,
                    gradient: LinearGradient(
                      colors: [
                        AppDesignSystem.secondaryColor,
                        AppDesignSystem.secondaryLight,
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Card de métrica moderna
  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required Gradient gradient,
  }) {
    return Card(
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: AppDesignSystem.borderRadiusMD,
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.05), Colors.white],
          ),
          borderRadius: AppDesignSystem.borderRadiusMD,
        ),
        padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: AppDesignSystem.paddingAll(
                    context,
                    AppDesignSystem.spaceSM,
                  ),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: AppDesignSystem.borderRadiusSM,
                    boxShadow: [AppDesignSystem.getShadowSM(color: color)],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: AppDesignSystem.spacing(context, 24),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppDesignSystem.getSpaceMD(context)),
            Text(
              title,
              style: AppDesignSystem.labelMedium(
                context,
              ).copyWith(color: AppDesignSystem.textSecondary),
            ),
            SizedBox(height: AppDesignSystem.getSpaceXS(context)),
            Text(
              value,
              style: AppDesignSystem.displayMedium(
                context,
              ).copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppDesignSystem.getSpaceXS(context)),
            Text(subtitle, style: AppDesignSystem.bodySmall(context)),
          ],
        ),
      ),
    );
  }

  /// Accesos rápidos
  Widget _buildQuickActions(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
        final spacing = 16.0;
        final availableWidth = constraints.maxWidth;
        final itemWidth = crossAxisCount > 1
            ? (availableWidth - spacing * (crossAxisCount - 1)) / crossAxisCount
            : availableWidth;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: crossAxisCount > 1 ? itemWidth : availableWidth,
              child: _buildQuickActionCard(
                context,
                icon: Icons.qr_code_scanner,
                title: 'Tomar Asistencia',
                subtitle: 'Escanear código QR',
                color: AppDesignSystem.primaryColor,
                onTap: () {
                  // Navegar a tomar asistencia
                },
              ),
            ),
            SizedBox(
              width: crossAxisCount > 1 ? itemWidth : availableWidth,
              child: _buildQuickActionCard(
                context,
                icon: Icons.calendar_today,
                title: 'Ver Calendario',
                subtitle: 'Horarios y eventos',
                color: AppDesignSystem.secondaryColor,
                onTap: () {
                  // Navegar a calendario
                },
              ),
            ),
            SizedBox(
              width: crossAxisCount > 1 ? itemWidth : availableWidth,
              child: _buildQuickActionCard(
                context,
                icon: Icons.analytics,
                title: 'Estadísticas',
                subtitle: 'Reportes y análisis',
                color: AppDesignSystem.infoColor,
                onTap: () {
                  // Navegar a estadísticas
                },
              ),
            ),
            SizedBox(
              width: crossAxisCount > 1 ? itemWidth : availableWidth,
              child: _buildQuickActionCard(
                context,
                icon: Icons.settings,
                title: 'Configuración',
                subtitle: 'Ajustes de perfil',
                color: AppDesignSystem.textSecondary,
                onTap: () {
                  // Navegar a configuración
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Card de acción rápida
  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shadowColor: color.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: AppDesignSystem.borderRadiusMD,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDesignSystem.borderRadiusMD,
        child: Padding(
          padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceMD),
          child: Row(
            children: [
              Container(
                padding: AppDesignSystem.paddingAll(
                  context,
                  AppDesignSystem.spaceSM,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppDesignSystem.borderRadiusSM,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: AppDesignSystem.spacing(context, 28),
                ),
              ),
              SizedBox(width: AppDesignSystem.getSpaceMD(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppDesignSystem.titleMedium(context)),
                    SizedBox(height: AppDesignSystem.getSpaceXS(context)),
                    Text(subtitle, style: AppDesignSystem.bodySmall(context)),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppDesignSystem.textDisabled,
                size: AppDesignSystem.spacing(context, 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card de estado vacío
  /// Card de estadística
  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required Stream<QuerySnapshot> stream,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Card(
          elevation: 4,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(height: 12),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Lista de aulas recientes para admin
  Widget _buildRecentClassrooms() {
    return StreamBuilder<QuerySnapshot>(
      stream: ClassroomService.getAllClassrooms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text('Error al cargar aulas: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.class_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No hay aulas registradas',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final classrooms = snapshot.data!.docs
            .map((doc) => ClassroomModel.fromFirestore(doc))
            .take(5) // Mostrar solo las primeras 5
            .toList();

        return Card(
          child: Column(
            children: [
              ...classrooms.map(
                (classroom) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    child: Text(
                      '${classroom.grade}${classroom.section}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(classroom.name),
                  subtitle: Text('${classroom.grade}° ${classroom.section}'),
                  trailing: classroom.teacherName != null
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Chip(
                            label: Text(
                              classroom.teacherName!,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.green.withOpacity(0.1),
                          ),
                        )
                      : const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Chip(
                            label: Text(
                              'Sin docente',
                              style: TextStyle(fontSize: 12),
                            ),
                            backgroundColor: Colors.grey,
                          ),
                        ),
                ),
              ),
              if (snapshot.data!.docs.length > 5)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Y ${snapshot.data!.docs.length - 5} aulas más...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Eliminado: navegación temporal mediante SnackBar; ahora navegamos directamente

  /// Obtener número de columnas según el ancho
  int _getCrossAxisCount(double width) {
    if (width > 1200) return 4;
    if (width > 800) return 3;
    // Cambio: Siempre mostrar 2 columnas en móviles (antes era 1)
    return 2;
  }

  /// Obtener fecha de hoy como string
  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Obtener nombre del mes en español
  String _getMonthName(int month) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return months[month - 1];
  }
}
