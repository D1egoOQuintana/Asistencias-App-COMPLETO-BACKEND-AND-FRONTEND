import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/classroom_model.dart';
import '../../../theme/app_design_system.dart';
import '../../../widgets/common/state_widgets.dart';
import '../../../widgets/common/app_glass_top_bar.dart';
import '../qr_attendance_realtime.dart';
import 'classroom_detail_screen.dart';

class TeacherClassroomsScreen extends StatefulWidget {
  final bool showAppBar;

  const TeacherClassroomsScreen({super.key, this.showAppBar = false});

  @override
  State<TeacherClassroomsScreen> createState() =>
      _TeacherClassroomsScreenState();
}

class _TeacherClassroomsScreenState extends State<TeacherClassroomsScreen>
    with AutomaticKeepAliveClientMixin {
  static const Color _brandBlue = Color(0xFF1976D2);
  static const Color _darkPrimary = Color(0xFF1976D2);
  static const Color _surfaceLow = Color(0xFFF2F4F5);
  static const Color _outline = Color(0xFF5F6470);
  static const Color _outlineVariant = Color(0xFFC5C6D2);
  static const Color _secondary = Color(0xFF1976D2);
  static const Color _secondaryFixed = Color(0xFFD8E2FF);
  static const Color _onSecondaryFixedVariant = Color(0xFF1976D2);

  final User? _currentUser = FirebaseAuth.instance.currentUser;
  List<ClassroomModel>? _cachedClassrooms;

  @override
  bool get wantKeepAlive => true;

  void _openClassroomDetail(
    ClassroomModel classroom, {
    bool openScheduleSettings = false,
  }) {
    if (openScheduleSettings) {
      Navigator.of(context).push(
        PageRouteBuilder(
          settings: const RouteSettings(name: 'classroom-schedule-settings'),
          transitionDuration: AppDesignSystem.durationFast,
          reverseTransitionDuration: AppDesignSystem.durationFast,
          pageBuilder: (context, animation, secondaryAnimation) {
            return ScheduleSettingsScreen(classroom: classroom);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: AppDesignSystem.curveSnappy,
            );

            final slideAnimation = Tween<Offset>(
              begin: const Offset(0.15, 0),
              end: Offset.zero,
            ).animate(curvedAnimation);

            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(curvedAnimation);

            return SlideTransition(
              position: slideAnimation,
              child: FadeTransition(opacity: fadeAnimation, child: child),
            );
          },
        ),
      );
      return;
    }

    Navigator.of(context).push(
      PageRouteBuilder(
        settings: const RouteSettings(name: 'classroom-detail'),
        transitionDuration: AppDesignSystem.durationFast,
        reverseTransitionDuration: AppDesignSystem.durationFast,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ClassroomDetailScreen(classroom: classroom);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: AppDesignSystem.curveSnappy,
          );

          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.15, 0),
            end: Offset.zero,
          ).animate(curvedAnimation);

          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(curvedAnimation);

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child),
          );
        },
      ),
    );
  }

  void _openAttendanceForm(ClassroomModel classroom) {
    Navigator.of(context).push(
      PageRouteBuilder(
        settings: const RouteSettings(name: 'qr-attendance-realtime'),
        transitionDuration: AppDesignSystem.durationFast,
        reverseTransitionDuration: AppDesignSystem.durationFast,
        pageBuilder: (context, animation, secondaryAnimation) {
          return QRAttendanceRealtimeScreen(classroomId: classroom.id);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: AppDesignSystem.curveSnappy,
          );

          final slideAnimation = Tween<Offset>(
            begin: const Offset(0.15, 0),
            end: Offset.zero,
          ).animate(curvedAnimation);

          final fadeAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(curvedAnimation);

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child),
          );
        },
      ),
    );
  }

  String _formatClassName(ClassroomModel classroom) {
    final section = classroom.section.trim();
    final grade = classroom.grade.trim();
    if (section.isEmpty) {
      return grade.isNotEmpty ? grade : classroom.name;
    }
    return '$grade $section'.trim();
  }

  int? _toMinutes(String? value) {
    if (value == null || value.isEmpty || !value.contains(':')) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  String _weekdayKey(DateTime date) {
    const keys = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    return keys[date.weekday - 1];
  }

  ClassSchedule? _todaySchedule(ClassroomModel classroom) {
    final schedule = classroom.schedule;
    if (schedule == null || schedule.isEmpty) return null;
    return schedule[_weekdayKey(DateTime.now())] ?? schedule.values.first;
  }

  // ignore: unused_element
  bool _isLiveNow(ClassroomModel classroom) {
    if (!classroom.isActive) return false;
    final schedule = _todaySchedule(classroom);
    if (schedule == null) return false;
    final start = _toMinutes(schedule.startTime);
    final end = _toMinutes(schedule.endTime);
    if (start == null || end == null) return false;
    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    return current >= start && current <= end;
  }

  String _scheduleCaption(ClassroomModel classroom) {
    final schedule = _todaySchedule(classroom);
    if (schedule == null) return 'Horario pendiente';
    if (schedule.startTime.isEmpty && schedule.endTime.isEmpty) {
      return 'Horario pendiente';
    }
    if (schedule.endTime.isEmpty) {
      return 'Programada • ${schedule.startTime}';
    }
    return '${schedule.startTime} - ${schedule.endTime}';
  }

  bool _isClassConfigured(ClassroomModel classroom) {
    return classroom.hasSchedule;
  }

  List<ClassroomModel> _sortedActive(List<ClassroomModel> classrooms) {
    final active = classrooms.where((classroom) => classroom.isActive).toList();
    active.sort((a, b) {
      final sa = _todaySchedule(a);
      final sb = _todaySchedule(b);
      final am = _toMinutes(sa?.startTime) ?? 24 * 60;
      final bm = _toMinutes(sb?.startTime) ?? 24 * 60;
      return am.compareTo(bm);
    });
    return active;
  }

  Widget _buildDashboardHeader(
    BuildContext context, {
    required String title,
  }) {
    return Padding(
      padding: AppDesignSystem.paddingSymmetric(
        context,
        horizontal: AppDesignSystem.spaceMD,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final titleSize = maxWidth < 360
              ? 30.0
              : maxWidth < 420
              ? 34.0
              : 40.0;

          return Text(
            title,
            softWrap: true,
            style: GoogleFonts.manrope(
              color: _brandBlue,
              fontSize: titleSize,
              height: 1.05,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.9,
            ),
          );
        },
      ),
    );
  }

  // ignore: unused_element
  Widget _buildLiveCard(BuildContext context, ClassroomModel classroom) {
    return Container(
      width: double.infinity,
      padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceLG),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF5FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000D33),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _secondaryFixed,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: _secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'En vivo ahora',
                    style: AppDesignSystem.labelMedium(context).copyWith(
                      color: _onSecondaryFixedVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppDesignSystem.getSpaceSM(context)),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              final iconBox = Container(
                width: compact ? 74 : 96,
                height: compact ? 74 : 96,
                decoration: BoxDecoration(
                  color: _surfaceLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: compact ? 36 : 48,
                  color: _darkPrimary,
                ),
              );

              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatClassName(classroom),
                    style: AppDesignSystem.headlineMedium(context).copyWith(
                      color: _darkPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${classroom.name} • ${_scheduleCaption(classroom)}',
                    style: AppDesignSystem.bodyMedium(
                      context,
                    ).copyWith(color: _outline, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isClassConfigured(classroom)
                          ? const Color(0xFFE7F6ED)
                          : const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _isClassConfigured(classroom)
                            ? const Color(0xFFA7D7B8)
                            : const Color(0xFFFFD9A8),
                      ),
                    ),
                    child: Text(
                      _isClassConfigured(classroom)
                          ? 'Aula configurada'
                          : 'Configurar aula',
                      style: AppDesignSystem.bodySmall(context).copyWith(
                        color: _isClassConfigured(classroom)
                            ? const Color(0xFF1E7A3F)
                            : const Color(0xFF9A5A00),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: AppDesignSystem.getSpaceMD(context)),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openAttendanceForm(classroom),
                        icon: const Icon(Icons.how_to_reg_rounded),
                        label: const Text('Asistencia'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openClassroomDetail(
                          classroom,
                          openScheduleSettings: true,
                        ),
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Horario'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _secondary,
                          side: BorderSide(
                            color: _outlineVariant.withValues(alpha: 0.4),
                            width: 1.4,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [iconBox, const SizedBox(height: 16), content],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  iconBox,
                  const SizedBox(width: 18),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildScheduledCard(BuildContext context, ClassroomModel classroom) {
    return Container(
      padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceLG),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFDFE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.32)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000D33),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: _surfaceLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: _darkPrimary,
                  size: 30,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEEEF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Programada • ${_scheduleCaption(classroom)}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppDesignSystem.bodySmall(context).copyWith(
                      color: const Color(0xFF444650),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppDesignSystem.getSpaceMD(context)),
          Text(
            _formatClassName(classroom),
            style: AppDesignSystem.titleLarge(
              context,
            ).copyWith(color: _darkPrimary, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${classroom.name} • Capacidad ${classroom.capacity}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppDesignSystem.bodyMedium(
              context,
            ).copyWith(color: _outline),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isClassConfigured(classroom)
                  ? const Color(0xFFE7F6ED)
                  : const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: _isClassConfigured(classroom)
                    ? const Color(0xFFA7D7B8)
                    : const Color(0xFFFFD9A8),
              ),
            ),
            child: Text(
              _isClassConfigured(classroom)
                  ? 'Aula configurada'
                  : 'Configurar aula',
              style: AppDesignSystem.bodySmall(context).copyWith(
                color: _isClassConfigured(classroom)
                    ? const Color(0xFF1E7A3F)
                    : const Color(0xFF9A5A00),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(height: AppDesignSystem.getSpaceLG(context)),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Text('Asistencia'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _surfaceLow,
                    foregroundColor: _darkPrimary,
                    disabledBackgroundColor: _surfaceLow,
                    disabledForegroundColor: _darkPrimary.withValues(
                      alpha: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openClassroomDetail(
                    classroom,
                    openScheduleSettings: true,
                  ),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('Horario'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _secondary.withValues(alpha: 0.1),
                    foregroundColor: _secondary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFinishedCard(BuildContext context, ClassroomModel classroom) {
    return Container(
      width: double.infinity,
      padding: AppDesignSystem.paddingAll(context, AppDesignSystem.spaceLG),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outlineVariant.withValues(alpha: 0.45)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;

          final left = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1E3E4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  color: _outline,
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatClassName(classroom)} • Finalizada',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesignSystem.titleMedium(context).copyWith(
                        color: _darkPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${classroom.name} • ${_scheduleCaption(classroom)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesignSystem.bodySmall(
                        context,
                      ).copyWith(color: _outline),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openClassroomDetail(classroom),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('Ver lista'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _outline,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: _outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openClassroomDetail(classroom),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Reporte'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _outline,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: _outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [left, const SizedBox(height: 14), actions],
            );
          }

          return Row(
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildClassroomsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('classrooms')
          .where('teacherUid', isEqualTo: _currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedClassrooms == null) {
          return const LoadingStateWidget(message: 'Cargando aulas...');
        }

        if (snapshot.hasError) {
          return ErrorStateWidget(
            message: 'Error al cargar las aulas: ${snapshot.error}',
            onRetry: () => setState(() {
              _cachedClassrooms = null;
            }),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.class_,
            title: 'No tienes aulas asignadas',
            message:
                'Contacta al administrador para que te asigne aulas para este periodo.',
            color: AppDesignSystem.infoColor,
          );
        }

        _cachedClassrooms = snapshot.data!.docs
            .map((doc) => ClassroomModel.fromFirestore(doc))
            .toList();

        final allClassrooms = _cachedClassrooms ?? [];
        final gridClassrooms = _sortedActive(allClassrooms);

        return Column(
          children: [
            if (!widget.showAppBar)
              const AppGlassTopBar(subtitle: 'Gestión de aulas'),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF2F4F5), Color(0xFFEDEFF2)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    20,
                    24,
                    MediaQuery.of(context).padding.bottom + 80,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDashboardHeader(
                        context,
                        title: 'Gestión de Aulas',
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 760;
                          if (gridClassrooms.isEmpty) {
                            return EmptyStateWidget(
                              icon: Icons.class_,
                              title: 'No hay aulas activas',
                              message:
                                  'No hay aulas activas para mostrar en este momento.',
                              color: AppDesignSystem.infoColor,
                            );
                          }

                          if (isCompact) {
                            return Column(
                              children: [
                                for (final classroom in gridClassrooms)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _buildClassHtmlGridCard(
                                      context,
                                      classroom,
                                    ),
                                  ),
                              ],
                            );
                          }

                          return Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              for (final classroom in gridClassrooms)
                                SizedBox(
                                  width: (constraints.maxWidth - 14) / 2,
                                  child: _buildClassHtmlGridCard(
                                    context,
                                    classroom,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClassHtmlGridCard(
    BuildContext context,
    ClassroomModel classroom,
  ) {
    final daysText = _classDaysLabel(classroom);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000D33),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _cardIconForClass(classroom),
                  color: _darkPrimary,
                  size: 30,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  daysText,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF5F6470),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            _formatClassName(classroom),
            style: const TextStyle(
              color: _darkPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 30,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${classroom.name} • Aula ${classroom.section}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF5F6470),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule, color: _secondary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _scheduleCaption(classroom),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _secondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openAttendanceForm(classroom),
                  icon: const Icon(Icons.how_to_reg, size: 18),
                  label: const Text('Asistencia'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openClassroomDetail(
                    classroom,
                    openScheduleSettings: true,
                  ),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Horario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF2F4F5),
                    foregroundColor: _darkPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _cardIconForClass(ClassroomModel classroom) {
    final name = classroom.name.toLowerCase();
    if (name.contains('mate') || name.contains('calc')) return Icons.functions;
    if (name.contains('bio')) return Icons.biotech;
    if (name.contains('hist')) return Icons.history_edu;
    return Icons.menu_book_rounded;
  }

  String _classDaysLabel(ClassroomModel classroom) {
    final schedule = classroom.schedule;
    if (schedule == null || schedule.isEmpty) return 'Horario pendiente';

    const labels = {
      'monday': 'Lunes',
      'tuesday': 'Martes',
      'wednesday': 'Miércoles',
      'thursday': 'Jueves',
      'friday': 'Viernes',
      'saturday': 'Sábado',
      'sunday': 'Domingo',
    };

    final days = schedule.keys.map((k) => labels[k] ?? k).toList();
    return days.length <= 3 ? days.join(', ') : '${days.first} – ${days.last}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_currentUser == null) {
      return Scaffold(
        body: ErrorStateWidget(
          message:
              'Usuario no autenticado. Por favor inicia sesión nuevamente.',
          icon: Icons.person_off,
          onRetry: () => Navigator.of(context).pushReplacementNamed('/login'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F6),
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Centro de Aulas'),
              backgroundColor: _brandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: SafeArea(child: _buildClassroomsList(context)),
    );
  }
}
