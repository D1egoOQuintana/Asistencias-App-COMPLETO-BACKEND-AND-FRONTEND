import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/classroom_service.dart';
import '../../services/admin_service.dart';
import '../../theme/app_design_system.dart';
import '../../models/classroom_model.dart';
import '../../models/user_model.dart';
import '../teacher/classrooms/teacher_classrooms_screen.dart';
import '../teacher/qr_attendance_realtime.dart';

/// Pantalla de inicio mejorada con diseño profesional y responsivo
class ImprovedHomeScreen extends StatefulWidget {
  const ImprovedHomeScreen({super.key});

  @override
  State<ImprovedHomeScreen> createState() => _ImprovedHomeScreenState();
}

class _ImprovedHomeScreenState extends State<ImprovedHomeScreen>
    with AutomaticKeepAliveClientMixin {
  static const Color _celeste = Color(0xFF1976D2);
  static const Color _celesteDark = Color(0xFF1976D2);
  Timer? _clockTimer;
  DateTime _liveNow = DateTime.now();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _recentAttendanceStream;
  Stream<QuerySnapshot>? _teacherClassroomsStream;
  String? _teacherStreamUid;

  void _refreshClockIfNeeded() {
    final now = DateTime.now();
    final changedMinute = now.minute != _liveNow.minute;
    final changedHour = now.hour != _liveNow.hour;
    final changedDay =
        now.day != _liveNow.day ||
        now.month != _liveNow.month ||
        now.year != _liveNow.year;

    if (!mounted || (!changedMinute && !changedHour && !changedDay)) return;
    setState(() {
      _liveNow = now;
    });
  }

  @override
  void initState() {
    super.initState();
    _recentAttendanceStream = FirebaseFirestore.instance
        .collection('attendance')
        .orderBy('timestamp', descending: true)
        .limit(120)
        .snapshots();

    _clockTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshClockIfNeeded();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Stream<QuerySnapshot> _getTeacherClassroomsStream(String teacherUid) {
    if (_teacherClassroomsStream == null || _teacherStreamUid != teacherUid) {
      _teacherStreamUid = teacherUid;
      _teacherClassroomsStream = ClassroomService.getClassroomsByTeacherSimple(
        teacherUid,
      );
    }
    return _teacherClassroomsStream!;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user!;
    final baseTheme = Theme.of(context);
    final manropeTheme = baseTheme.textTheme.apply(
      fontFamily: GoogleFonts.manrope().fontFamily,
    );

    return Theme(
      data: baseTheme.copyWith(textTheme: manropeTheme),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (user.role == UserRole.admin) ...[
                  _buildModernWelcomeHeader(
                    context,
                    user,
                    currentTime: _liveNow,
                  ),
                  const SizedBox(height: 32),
                  _buildAdminDashboard(context),
                ] else
                  _buildTeacherDashboard(context, user.uid),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Header moderno de bienvenida
  Widget _buildModernWelcomeHeader(
    BuildContext context,
    UserModel user, {
    required DateTime currentTime,
  }) {
    final now = currentTime;
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
      stream: _getTeacherClassroomsStream(teacherUid),
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

        final user = Provider.of<AuthProvider>(context, listen: false).user!;
        final firstName = user.fullName.trim().isEmpty
            ? 'Docente'
            : user.fullName.trim().split(' ').first;
        final now = _liveNow;
        final weekdayKey = _getWeekdayKey(now.weekday);

        final todaysScheduled = classrooms
            .where(
              (classroom) =>
                  classroom.schedule != null &&
                  classroom.schedule!.containsKey(weekdayKey),
            )
            .toList();

        final ongoingClassrooms =
            todaysScheduled.where((classroom) {
              final schedule = classroom.schedule![weekdayKey]!;
              return _isNowInsideClassroomSchedule(now, schedule);
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

        final hasActiveClass = ongoingClassrooms.isNotEmpty;
        final targetClassroom = hasActiveClass
          ? ongoingClassrooms.first
          : (upcomingClassrooms.isNotEmpty ? upcomingClassrooms.first : null);

        final targetSchedule = targetClassroom?.schedule?[weekdayKey];
        final nextTime = targetSchedule == null
          ? '--:--'
          : hasActiveClass
          ? '${targetSchedule.startTime} - ${targetSchedule.endTime}'
          : targetSchedule.startTime;

        final hour = now.hour.toString().padLeft(2, '0');
        final minute = now.minute.toString().padLeft(2, '0');

        final greeting = now.hour < 12
            ? 'Buenos días'
            : now.hour < 18
            ? 'Buenas tardes'
            : 'Buenas noches';

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 760;
            final metricWidth = isMobile
                ? (constraints.maxWidth - 12) / 2
                : (constraints.maxWidth - 36) / 4;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFCFE3FF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1976D2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, titleConstraints) {
                            return SizedBox(
                              width: titleConstraints.maxWidth,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: const Text(
                                  'Asistencias',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0D47A1),
                                    letterSpacing: -0.4,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8E8FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          firstName.isEmpty ? 'D' : firstName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF1976D2),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _showLogoutDialog(context),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFDC2626),
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Salir',
                                style: TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '$greeting, $firstName!',
                  style: TextStyle(
                    fontSize: isMobile ? 34 : 44,
                    height: 1.05,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF000D33),
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tienes ${todaysScheduled.length} clases programadas para hoy.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: metricWidth,
                      child: _buildTeacherBentoMetric(
                        title: 'Aulas Totales',
                        value: '${classrooms.length}',
                        icon: Icons.hub,
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _buildTeacherBentoMetric(
                        title: 'Activas Hoy',
                        value: todaysScheduled.length.toString().padLeft(
                          2,
                          '0',
                        ),
                        icon: Icons.calendar_today,
                        iconContainerColor: const Color(0xFFD8E8FF),
                        iconColor: const Color(0xFF0D47A1),
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _buildTeacherBentoMetric(
                        title: 'Hora Actual',
                        value: '$hour:$minute',
                        icon: Icons.schedule,
                      ),
                    ),
                    SizedBox(
                      width: metricWidth,
                      child: _buildTeacherNextClassMetric(
                        title: hasActiveClass ? 'CLASE ACTIVA' : 'PRÓXIMA CLASE',
                        className: targetClassroom?.name ?? 'Sin clase',
                        classTime: nextTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _buildTeacherCentralQrAction(context),
                const SizedBox(height: 24),
                _buildTeacherRecentScans(classrooms: classrooms),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTeacherBentoMetric({
    required String title,
    required String value,
    required IconData icon,
    Color iconContainerColor = const Color(0xFFF1F5FF),
    Color iconColor = const Color(0xFF1976D2),
  }) {
    return Container(
      height: 156,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000D33).withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
              color: Color(0xFF64748B),
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 32,
                      color: Color(0xFF000D33),
                      height: 1,
                    ),
                  ),
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconContainerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, color: iconColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherNextClassMetric({
    required String title,
    required String className,
    required String classTime,
  }) {
    return Container(
      height: 156,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_celeste, _celesteDark],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Text(
            className,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            classTime,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherCentralQrAction(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              Get.to(
                () => const QRAttendanceRealtimeScreen(),
                transition: Transition.fadeIn,
                duration: const Duration(milliseconds: 170),
              );
            },
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_celeste, _celesteDark],
                ),
                border: Border.all(color: Colors.white, width: 8),
                boxShadow: [
                  BoxShadow(
                    color: _celesteDark.withValues(alpha: 0.28),
                    blurRadius: 48,
                    offset: const Offset(0, 22),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 82),
                  SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'ESCANEAR CÓDIGO QR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(
            width: 340,
            child: Text(
              'Coloca el código QR del estudiante dentro del visor para registrar asistencia automática.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherRecentScans({required List<ClassroomModel> classrooms}) {
    final classroomById = <String, ClassroomModel>{
      for (final classroom in classrooms)
        if (classroom.id != null) classroom.id!: classroom,
    };
    final classroomIds = classroomById.keys.toSet();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                'Recientes',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF000D33),
                  fontSize: 20,
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
                  'Ver Todo',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _recentAttendanceStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                );
              }

              final docs = snapshot.data?.docs ?? const [];
              final now = _liveNow;
              final filtered = docs
                  .where((doc) {
                  final classroomIdFromPath =
                    (doc.data()['classroomId'] ?? '').toString();
                    if (!classroomIds.contains(classroomIdFromPath)) return false;

                    final data = doc.data();
                  final ts = data['timestamp'];
                    DateTime? scanTime;
                    if (ts is Timestamp) {
                      scanTime = ts.toDate();
                    } else if (ts is DateTime) {
                      scanTime = ts;
                    }

                    if (scanTime == null) return false;
                    return scanTime.year == now.year &&
                        scanTime.month == now.month &&
                        scanTime.day == now.day;
                  })
                  .take(3)
                  .toList();

              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'Sin registros recientes por ahora.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              return Column(
                children: filtered.map((doc) {
                  final data = doc.data();
                  final studentName = (data['studentName'] ?? 'Estudiante')
                      .toString();
                  final classroomId = (data['classroomId'] ?? '').toString();
                  final classroom = classroomById[classroomId];
                  final timeLabel = _formatRecentTimestamp(data['timestamp']);
                  final isExit = data['exitAt'] != null;
                  final statusLabel = isExit ? 'Salida' : 'Entrada';

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF1976D2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                studentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${classroom?.name ?? 'Sin aula'} • ${classroom?.section ?? '-'}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Hora: $timeLabel',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isExit
                                ? const Color(0xFFFFF3D6)
                                : const Color(0xFFD8E8FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusLabel.toUpperCase(),
                            style: TextStyle(
                              color: isExit
                                  ? const Color(0xFF8A4B00)
                                  : const Color(0xFF0D47A1),
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatRecentTimestamp(dynamic rawTimestamp) {
    DateTime? dateTime;

    if (rawTimestamp is Timestamp) {
      dateTime = rawTimestamp.toDate();
    } else if (rawTimestamp is DateTime) {
      dateTime = rawTimestamp;
    }

    if (dateTime == null) return '--:--:--';

    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  // ignore: unused_element
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

  // ignore: unused_element
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
                                Get.to(
                                  () => const QRAttendanceRealtimeScreen(),
                                  transition: Transition.fadeIn,
                                  duration: const Duration(milliseconds: 170),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _celesteDark,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Tomar Asistencia',
                                style: TextStyle(fontWeight: FontWeight.w500),
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

  // ignore: unused_element
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

  // ignore: unused_element
  Widget _buildCenteredQrActionButton(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Get.to(
                () => const QRAttendanceRealtimeScreen(),
                transition: Transition.fadeIn,
                duration: const Duration(milliseconds: 170),
              );
            },
            icon: const Icon(Icons.qr_code_scanner, size: 24),
            label: const Text(
              'Escanear QR',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _celesteDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              elevation: 8,
              shadowColor: _celesteDark.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
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

  // ignore: unused_element
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
                        style: TextStyle(fontWeight: FontWeight.w500),
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
                        style: TextStyle(fontWeight: FontWeight.w500),
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
