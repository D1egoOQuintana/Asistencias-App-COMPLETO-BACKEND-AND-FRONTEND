import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/classroom_service.dart';
import '../../services/admin_service.dart';
import '../../theme/app_design_system.dart';
import '../../models/classroom_model.dart';
import '../../models/user_model.dart';
import '../teacher/classrooms/teacher_classrooms_screen.dart';
import '../teacher/attendance/quick_qr_attendance_screen.dart';

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

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user.role == UserRole.admin) ...[
                _buildModernWelcomeHeader(context, user),
                const SizedBox(height: 32),
                _buildAdminDashboard(context),
              ] else
                _buildTeacherDashboard(context, user.uid),
            ],
          ),
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
    return StreamBuilder<QuerySnapshot>(
      stream: ClassroomService.getClassroomsByTeacherSimple(teacherUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final classrooms =
            snapshot.data?.docs
                .map((doc) => ClassroomModel.fromFirestore(doc))
                .where((classroom) => classroom.isActive)
                .toList() ??
            [];

        final now = DateTime.now();
        final weekdayKey = _getWeekdayKey(now.weekday);

        final activeClassroom = classrooms.cast<ClassroomModel?>().firstWhere(
          (classroom) =>
              classroom != null &&
              classroom.schedule != null &&
              classroom.schedule!.containsKey(weekdayKey) &&
              _isNowInsideClassroomSchedule(
                now,
                classroom.schedule![weekdayKey]!,
              ),
          orElse: () => null,
        );

        final todaysScheduled = classrooms
            .where(
              (classroom) =>
                  classroom.schedule != null &&
                  classroom.schedule!.containsKey(weekdayKey),
            )
            .toList();

        final upcomingClassrooms =
            todaysScheduled.where((classroom) {
              final schedule = classroom.schedule![weekdayKey]!;
              return _parseTimeOnDate(now, schedule.startTime).isAfter(now);
            }).toList()..sort((a, b) {
              final aTime = _parseTimeOnDate(
                now,
                a.schedule![weekdayKey]!.startTime,
              );
              final bTime = _parseTimeOnDate(
                now,
                b.schedule![weekdayKey]!.startTime,
              );
              return aTime.compareTo(bTime);
            });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTeacherTopIntroCard(context),
            const SizedBox(height: 24),
            _buildTeacherActiveSessionCard(
              context,
              activeClassroom: activeClassroom,
              totalStudents: classrooms.fold<int>(
                0,
                (total, classroom) => total + classroom.capacity,
              ),
            ),
            const SizedBox(height: 24),
            _buildTeacherPerformanceSection(
              context,
              totalScheduledToday: todaysScheduled.length,
              totalClassrooms: classrooms.length,
              upcomingCount: upcomingClassrooms.length,
            ),
            const SizedBox(height: 24),
            _buildCenteredQrActionButton(context),
            const SizedBox(height: 24),
            _buildTeacherNextSessionsSection(
              context,
              upcomingClassrooms: upcomingClassrooms,
              weekdayKey: weekdayKey,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTeacherTopIntroCard(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user!;
    final firstName = user.fullName.split(' ').first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppDesignSystem.primaryColor, width: 2),
              color: const Color(0xFFE2E8F0),
            ),
            child: Center(
              child: Text(
                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'P',
                style: const TextStyle(
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido de nuevo,',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prof. $firstName',
                  style: const TextStyle(
                    color: AppDesignSystem.primaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showLogoutDialog(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFF1F2),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Icon(
                Icons.logout,
                color: Color(0xFFDC2626),
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherActiveSessionCard(
    BuildContext context, {
    required ClassroomModel? activeClassroom,
    required int totalStudents,
  }) {
    final now = DateTime.now();
    final weekdayKey = _getWeekdayKey(now.weekday);

    final schedule =
        activeClassroom?.schedule != null &&
            activeClassroom!.schedule!.containsKey(weekdayKey)
        ? activeClassroom.schedule![weekdayKey]!
        : null;

    final classTitle = activeClassroom?.name ?? 'Sin sesión activa';
    final classSubtitle = activeClassroom != null
        ? '${activeClassroom.grade}° ${activeClassroom.section}'
        : 'No hay clase en curso en este momento';
    final classTime = schedule != null
        ? '${schedule.startTime} - ${schedule.endTime}'
        : '--:-- - --:--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'SESIÓN ACTIVA',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppDesignSystem.primaryColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppDesignSystem.primaryColor.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuDLm2Mgj6-rEyTTQ4baxgg9eiyDa8w6IGcPotcEAC9b75pgJCkvdX0ZwlTdARdQRHSRBPz27w7stIeRC_0HVAHfikr347o5PjWsxnue3nrNUjJb0UuKOkiDtZGB72_FlrhvVchXjFuD2qH1iAH6oWnF74s5SyFl6WRoYsBGYN1EMlJ8EcdD4FtTF_20aKALL5I5fFu7TTcgTpqWbq8eJ7FkQtNz8etaDtzQMD4W-PnGA64oCfAelS_nqo7u9uiWdzn0nkgf2BQ80t0',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(color: const Color(0xFF1E40AF));
                          },
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.25),
                                Colors.black.withValues(alpha: 0.45),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        top: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'EN VIVO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        classTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _buildTeacherSessionInfo(
                            icon: Icons.schedule,
                            text: classTime,
                          ),
                          _buildTeacherSessionInfo(
                            icon: Icons.group,
                            text: '$totalStudents estudiantes',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const QuickQRAttendanceScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppDesignSystem.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Tomar Asistencia',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.more_horiz,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherSessionInfo({
    required IconData icon,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherPerformanceSection(
    BuildContext context, {
    required int totalScheduledToday,
    required int totalClassrooms,
    required int upcomingCount,
  }) {
    final attendanceRate = totalClassrooms > 0
        ? ((totalScheduledToday / totalClassrooms) * 100).clamp(0, 100)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'RENDIMIENTO DE HOY',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.35,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildTeacherMetricCard(
              icon: Icons.check_circle_outline,
              iconBg: const Color(0xFFE0E7FF),
              iconColor: AppDesignSystem.primaryColor,
              trendText: '+4%',
              trendColor: Colors.green,
              mainValue: '${attendanceRate.toStringAsFixed(1)}%',
              label: 'Cobertura de Horarios',
            ),
            _buildTeacherMetricCard(
              icon: Icons.calendar_today,
              iconBg: const Color(0xFFE0E7FF),
              iconColor: AppDesignSystem.primaryColor,
              trendText: '',
              trendColor: Colors.transparent,
              mainValue: '$upcomingCount / $totalScheduledToday',
              label: 'Sesiones Restantes',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeacherMetricCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String trendText,
    required Color trendColor,
    required String mainValue,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
              if (trendText.isNotEmpty)
                Text(
                  trendText,
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            mainValue,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredQrActionButton(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const QuickQRAttendanceScreen(),
                ),
              );
            },
            icon: const Icon(Icons.qr_code_scanner, size: 24),
            label: const Text(
              'Escanear QR',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesignSystem.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              elevation: 8,
              shadowColor: AppDesignSystem.primaryColor.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherNextSessionsSection(
    BuildContext context, {
    required List<ClassroomModel> upcomingClassrooms,
    required String weekdayKey,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'PRÓXIMAS SESIONES',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const TeacherClassroomsScreen(showAppBar: true),
                  ),
                );
              },
              child: const Text(
                'Ver horario',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (upcomingClassrooms.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'No tienes sesiones pendientes para hoy.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Column(
            children: upcomingClassrooms.take(2).map((classroom) {
              final schedule = classroom.schedule![weekdayKey]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text(
                              schedule.startTime,
                              style: const TextStyle(
                                color: AppDesignSystem.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'HORA',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              classroom.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${classroom.grade}° ${classroom.section} • ${classroom.capacity} estudiantes',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  String _getWeekdayKey(int weekday) {
    const map = {
      1: 'monday',
      2: 'tuesday',
      3: 'wednesday',
      4: 'thursday',
      5: 'friday',
      6: 'saturday',
      7: 'sunday',
    };
    return map[weekday] ?? 'monday';
  }

  bool _isNowInsideClassroomSchedule(DateTime now, ClassSchedule schedule) {
    final start = _parseTimeOnDate(now, schedule.startTime);
    final end = _parseTimeOnDate(now, schedule.endTime);
    return (now.isAfter(start) || now.isAtSameMomentAs(start)) &&
        now.isBefore(end);
  }

  DateTime _parseTimeOnDate(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFF1F2),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFDC2626),
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Cerrar sesión',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Se cerrará tu sesión actual en este dispositivo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sí, salir',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
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
                colors: [
                  color.withValues(alpha: 0.1),
                  color.withValues(alpha: 0.05),
                ],
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
                    ).primaryColor.withValues(alpha: 0.1),
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
                            backgroundColor: Colors.green.withValues(
                              alpha: 0.1,
                            ),
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

  /// Obtener número de columnas según el ancho (ya no se usa, mantener para compatibilidad)
  int _getCrossAxisCount(double width) {
    if (width > 1200) return 4;
    if (width > 800) return 3;
    return 1;
  }

  /// Obtener fecha de hoy como string
  String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
