import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/classroom_model.dart';
import '../../../models/student_model.dart';
import '../../../services/student_service.dart';
import '../../../theme/app_design_system.dart';
import '../../../widgets/common/app_feedback_dialog.dart';

enum SortOrder { aToZ, zToA, newest, oldest }

class ClassroomDetailScreen extends StatefulWidget {
  final ClassroomModel classroom;

  const ClassroomDetailScreen({super.key, required this.classroom});

  @override
  State<ClassroomDetailScreen> createState() => _ClassroomDetailScreenState();
}

class _ClassroomDetailScreenState extends State<ClassroomDetailScreen> {
  final Map<String, String> _weekDays = const {
    'monday': 'Lunes',
    'tuesday': 'Martes',
    'wednesday': 'Miércoles',
    'thursday': 'Jueves',
    'friday': 'Viernes',
    'saturday': 'Sábado',
    'sunday': 'Domingo',
  };

  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  String? _sessionId;
  bool _attendanceActive = false;
  bool _isScanning = false;
  bool _isShowingResult = false;
  bool _torchEnabled = false;
  List<StudentModel> _students = [];
  Map<String, dynamic> _attendanceData = {};
  ClassroomModel? _classroomOverride;
  late final MobileScannerController _scannerController;
  DateTime? _lastScanAt;
  String? _lastScanRaw;
  Map<String, String> _lastScannedInfo = const {};
  String _lastScanStatus = 'LISTO';
  Color _lastScanStatusColor = Colors.blue;
  bool _lastScanSuccess = false;
  bool _scanLineForward = true;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _loadStudents();
    _loadAttendanceForDay(_selectedDay);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classroomId = widget.classroom.id;

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.classroom.fullName),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: classroomId == null
              ? null
              : FirebaseFirestore.instance
                    .collection('classrooms')
                    .doc(classroomId)
                    .snapshots(),
          builder: (context, snapshot) {
            final classroom = (snapshot.data != null && snapshot.data!.exists)
                ? ClassroomModel.fromFirestore(snapshot.data!)
                : (_classroomOverride ?? widget.classroom);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildScheduleList(classroom),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _attendanceActive
                                ? _stopAttendanceSession
                                : _startAttendanceSession,
                            icon: Icon(
                              _attendanceActive
                                  ? Icons.stop_circle
                                  : Icons.play_circle,
                            ),
                            label: Text(
                              _attendanceActive
                                  ? 'Finalizar sesión'
                                  : 'Iniciar sesión',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _showEditAttendanceDialog(_selectedDay),
                          icon: const Icon(Icons.edit_calendar),
                          label: const Text('Editar'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TableCalendar(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2100),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(day, _selectedDay),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        _loadAttendanceForDay(selectedDay);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Escáner QR',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildScannerExperience(),
                const SizedBox(height: 12),
                const Text(
                  'Resumen del día',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildDailyAttendanceList(classroom.id),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildScannerExperience() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 520,
        child: Stack(
          children: [
            Positioned.fill(
              child: MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  for (final barcode in capture.barcodes) {
                    final raw = barcode.rawValue;
                    if (raw == null || raw.isEmpty) continue;

                    final now = DateTime.now();
                    if (_lastScanAt != null && _lastScanRaw == raw) {
                      final diff = now.difference(_lastScanAt!).inMilliseconds;
                      if (diff < 1200) {
                        return;
                      }
                    }

                    _lastScanAt = now;
                    _lastScanRaw = raw;
                    _processQRCode(raw);
                    return;
                  }
                },
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.32)),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.25),
                      Colors.transparent,
                      Colors.black.withOpacity(0.25),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                height: 78,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withOpacity(0.18)),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.18),
                      child: const Icon(Icons.school, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Attendance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 286,
                    height: 286,
                    child: Stack(
                      children: [
                        const Positioned(
                          top: 0,
                          left: 0,
                          child: _ScanCorner(top: true, left: true),
                        ),
                        const Positioned(
                          top: 0,
                          right: 0,
                          child: _ScanCorner(top: true, left: false),
                        ),
                        const Positioned(
                          bottom: 0,
                          left: 0,
                          child: _ScanCorner(top: false, left: true),
                        ),
                        const Positioned(
                          bottom: 0,
                          right: 0,
                          child: _ScanCorner(top: false, left: false),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.qr_code_scanner,
                                size: 64,
                                color: Color(0x55FFFFFF),
                              ),
                            ),
                          ),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: _scanLineForward ? -110 : 110,
                            end: _scanLineForward ? 110 : -110,
                          ),
                          duration: const Duration(milliseconds: 2600),
                          onEnd: () {
                            if (!mounted) return;
                            setState(
                              () => _scanLineForward = !_scanLineForward,
                            );
                          },
                          builder: (context, yOffset, child) {
                            return Positioned(
                              left: 0,
                              right: 0,
                              top: 143 + yOffset,
                              child: IgnorePointer(
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        const Color(
                                          0xFF1C6EE8,
                                        ).withOpacity(0.2),
                                        const Color(0xFF1C6EE8),
                                        const Color(
                                          0xFF1C6EE8,
                                        ).withOpacity(0.2),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _isScanning
                        ? 'Procesando QR...'
                        : 'Alinea el código QR dentro del marco',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 100,
              child: _buildLastScannedCard(),
            ),
            Positioned(
              right: 12,
              top: 200,
              child: Column(
                children: [
                  _buildFloatingIconButton(
                    icon: _torchEnabled
                        ? Icons.flashlight_on
                        : Icons.flashlight_off,
                    onTap: () {
                      setState(() => _torchEnabled = !_torchEnabled);
                      _scannerController.toggleTorch();
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildFloatingIconButton(
                    icon: Icons.keyboard_alt_outlined,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Próximamente: ingreso manual de código',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 20,
              child: ElevatedButton.icon(
                onPressed: _attendanceActive
                    ? _stopAttendanceSession
                    : _startAttendanceSession,
                icon: Icon(
                  _attendanceActive ? Icons.stop : Icons.arrow_forward,
                ),
                label: Text(
                  _attendanceActive ? 'Finish Session' : 'Iniciar sesión',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: const Color(0xFF00174B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            if (_isScanning)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withOpacity(0.25),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastScannedCard() {
    if (_lastScannedInfo.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.5)),
        ),
        child: const Text(
          'Escanea un QR para mostrar la información completa del estudiante.',
          style: TextStyle(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      );
    }

    final studentName = _lastScannedInfo['name'] ?? 'Estudiante';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29000D33),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF0059BB).withOpacity(0.12),
            child: const Icon(Icons.person, color: Color(0xFF0059BB), size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF000D33),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _lastScanStatusColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _lastScanStatus,
                        style: TextStyle(
                          color: _lastScanStatusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildInfoLine(
                  'DNI',
                  _lastScannedInfo['dni'] ?? 'No disponible',
                ),
                _buildInfoLine(
                  'Aula',
                  _lastScannedInfo['classroom'] ?? widget.classroom.name,
                ),
                _buildInfoLine(
                  'Correo apoderado',
                  _lastScannedInfo['parentEmail'] ?? 'No registrado',
                ),
                _buildInfoLine(
                  'Teléfono apoderado',
                  _lastScannedInfo['parentPhone'] ?? 'No registrado',
                ),
                _buildInfoLine('Hora', _lastScannedInfo['time'] ?? '--:--'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _lastScanSuccess ? Icons.check_circle : Icons.info,
                      color: _lastScanStatusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _lastScannedInfo['message'] ?? '',
                        style: TextStyle(
                          color: _lastScanStatusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Color(0xFF444650)),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  String _formatClock(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final ampm = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  void _updateLastScannedCard({
    required String studentName,
    required StudentModel? student,
    required String message,
    required String status,
    required Color statusColor,
    required bool success,
  }) {
    if (!mounted) return;

    final now = DateTime.now();
    setState(() {
      _lastScanStatus = status;
      _lastScanStatusColor = statusColor;
      _lastScanSuccess = success;
      _lastScannedInfo = {
        'name': studentName,
        'dni': student?.dni ?? 'No disponible',
        'parentEmail': student?.parentEmail ?? 'No registrado',
        'parentPhone': student?.parentPhone ?? 'No registrado',
        'classroom': widget.classroom.name,
        'time': _formatClock(now),
        'message': message,
      };
    });
  }

  Widget _buildDailyAttendanceList(String? classroomId) {
    if (classroomId == null || classroomId.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('No se pudo cargar el salón.'),
        ),
      );
    }

    final dateKey = _formatDate(_selectedDay);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('classroomId', isEqualTo: classroomId)
          .where('date', isEqualTo: dateKey)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final dayMap = <String, String>{};
        for (final doc in docs) {
          final data = doc.data();
          final sid = (data['studentId'] ?? '').toString();
          final status = (data['status'] ?? 'absent').toString();
          if (sid.isNotEmpty) {
            dayMap[sid] = status;
          }
        }

        final total = _students.length;
        final present = dayMap.values
            .where((v) => v == 'present' || v == 'presente')
            .length;
        final late = dayMap.values
            .where((v) => v == 'late' || v == 'tarde')
            .length;
        final absent = total - present - late;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Presentes',
                        '$present',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Tardanzas',
                        '$late',
                        Icons.access_time,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Faltas',
                        '$absent',
                        Icons.cancel,
                        Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_students.isEmpty)
                  const ListTile(
                    title: Text('No hay estudiantes en este salón.'),
                  )
                else
                  ..._students.map((st) {
                    final sid = st.id ?? '';
                    final status = dayMap[sid] ?? 'absent';
                    final label = status == 'present'
                        ? 'Presente'
                        : status == 'late'
                        ? 'Tarde'
                        : 'Faltó';
                    final color = status == 'present'
                        ? Colors.green
                        : status == 'late'
                        ? Colors.orange
                        : Colors.red;

                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.person, color: color),
                      title: Text('${st.firstName} ${st.lastName}'),
                      trailing: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  ClassSchedule? _getScheduleFor(DateTime now, ClassroomModel classroom) {
    final scheduleMap = classroom.schedule;
    if (scheduleMap == null || scheduleMap.isEmpty) {
      return null;
    }
    final weekdayKey = switch (now.weekday) {
      DateTime.monday => 'monday',
      DateTime.tuesday => 'tuesday',
      DateTime.wednesday => 'wednesday',
      DateTime.thursday => 'thursday',
      DateTime.friday => 'friday',
      DateTime.saturday => 'saturday',
      DateTime.sunday => 'sunday',
      _ => '',
    };
    return scheduleMap[weekdayKey];
  }

  DateTime _combine(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  bool _isWithinClassTime(DateTime now, ClassSchedule schedule) {
    final start = _combine(now, schedule.startTime);
    final end = _combine(now, schedule.endTime);
    return !now.isBefore(start) && !now.isAfter(end);
  }

  bool _isAfterEndTime(DateTime now, ClassSchedule schedule) {
    final end = _combine(now, schedule.endTime);
    return now.isAfter(end);
  }

  Widget _buildScheduleList(ClassroomModel classroom) {
    if (classroom.schedule == null) return Container();

    final schedules = classroom.schedule!;

    return Column(
      children: _weekDays.entries.map((dayEntry) {
        final dayKey = dayEntry.key;
        final dayName = dayEntry.value;
        final schedule = schedules[dayKey];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: schedule != null
                ? Colors.green.shade50
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: schedule != null
                  ? Colors.green.shade200
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  dayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: schedule != null
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: schedule != null
                    ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.green.shade700,
                          ),
                          Text(
                            '${schedule.startTime} - ${schedule.endTime}',
                            style: TextStyle(color: Colors.green.shade700),
                          ),
                          Icon(
                            Icons.schedule,
                            size: 16,
                            color: Colors.orange.shade700,
                          ),
                          Text(
                            'Puntual hasta: ${schedule.maxLateTime}',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        'Sin horario configurado',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Future<void> _showScheduleSettings() async {
    final saved = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        settings: const RouteSettings(name: 'classroom-schedule-settings'),
        transitionDuration: AppDesignSystem.durationFast,
        reverseTransitionDuration: AppDesignSystem.durationFast,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ScheduleSettingsScreen(classroom: widget.classroom);
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

    if (saved == true && mounted) {
      setState(() {
        _selectedDay = DateTime.now();
        _focusedDay = DateTime.now();
      });

      await AppFeedbackDialog.success(
        context,
        title: 'Aula configurada',
        message: 'Los horarios del aula se guardaron correctamente.',
      );
    }
  }

  void _startAttendanceSession() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay usuario autenticado')),
        );
        return;
      }

      final dateKey = DateTime.now().toIso8601String().split('T')[0];
      final sessionDoc = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .add({
            'classroomId': widget.classroom.id,
            'teacherUid': currentUser.uid,
            'startTime': FieldValue.serverTimestamp(),
            'endTime': null,
            'isActive': true,
            'attendanceCount': 0,
            'date': dateKey,
          });

      setState(() {
        _sessionId = sessionDoc.id;
        _attendanceActive = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al iniciar sesión: $e')));
      }
    }
  }

  void _stopAttendanceSession() async {
    try {
      if (_sessionId != null) {
        await FirebaseFirestore.instance
            .collection('attendance_sessions')
            .doc(_sessionId)
            .update({
              'endTime': FieldValue.serverTimestamp(),
              'isActive': false,
            });
      } else {
        // Fallback: marcar cualquier sesión activa de hoy para este salón como finalizada
        final dateKey = DateTime.now().toIso8601String().split('T')[0];
        final q = await FirebaseFirestore.instance
            .collection('attendance_sessions')
            .where('classroomId', isEqualTo: widget.classroom.id)
            .where('date', isEqualTo: dateKey)
            .where('isActive', isEqualTo: true)
            .get();
        for (final doc in q.docs) {
          await doc.reference.update({
            'endTime': FieldValue.serverTimestamp(),
            'isActive': false,
          });
        }
      }

      setState(() {
        _attendanceActive = false;
        _sessionId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión de asistencia finalizada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al finalizar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Procesar QR en sitio y registrar en 'attendance'
  Future<void> _processQRCode(String qrData) async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    String studentName = 'Estudiante';
    StudentModel? scannedStudent;
    try {
      if (qrData.isEmpty) {
        _updateLastScannedCard(
          studentName: studentName,
          student: null,
          message: 'Código vacío',
          status: 'ERROR',
          statusColor: Colors.red,
          success: false,
        );
        return;
      }

      dynamic data;
      try {
        data = jsonDecode(qrData);
      } catch (_) {
        _updateLastScannedCard(
          studentName: studentName,
          student: null,
          message: 'El QR no tiene formato JSON válido',
          status: 'ERROR',
          statusColor: Colors.red,
          success: false,
        );
        return;
      }

      if (data is! Map<String, dynamic>) {
        _updateLastScannedCard(
          studentName: studentName,
          student: null,
          message: 'Formato de datos inválido',
          status: 'ERROR',
          statusColor: Colors.red,
          success: false,
        );
        return;
      }
      if (data['type'] != 'student') {
        _updateLastScannedCard(
          studentName: studentName,
          student: null,
          message: 'El QR no corresponde a un estudiante',
          status: 'ERROR',
          statusColor: Colors.red,
          success: false,
        );
        return;
      }
      if (!data.containsKey('id') || !data.containsKey('name')) {
        _updateLastScannedCard(
          studentName: studentName,
          student: null,
          message: 'Datos de estudiante incompletos en el QR',
          status: 'ERROR',
          statusColor: Colors.red,
          success: false,
        );
        return;
      }

      final studentId = data['id'].toString();
      studentName = data['name'].toString();
      for (final student in _students) {
        if (student.id == studentId) {
          scannedStudent = student;
          break;
        }
      }
      scannedStudent ??= await StudentService.getStudentById(studentId);

      // Validaciones de horario y sesión
      final now = DateTime.now();
      final schedule = _getScheduleFor(now, widget.classroom);
      if (schedule == null) {
        _updateLastScannedCard(
          studentName: studentName,
          student: scannedStudent,
          message: 'No hay clase programada para hoy',
          status: 'SIN HORARIO',
          statusColor: Colors.orange,
          success: false,
        );
        _showResultModal(
          title: 'No programado',
          message: 'Hoy no hay clase programada para este salón',
          color: Colors.orange,
          icon: Icons.info,
        );
        return;
      }

      // Bloquear antes del inicio o después de finalizar
      if (!_isWithinClassTime(now, schedule)) {
        final startMsg = '${schedule.startTime}';
        final endMsg = '${schedule.endTime}';
        final ended = _isAfterEndTime(now, schedule);
        _updateLastScannedCard(
          studentName: studentName,
          student: scannedStudent,
          message: ended
              ? 'Clase finalizada ($startMsg - $endMsg)'
              : 'Fuera de horario ($startMsg - $endMsg)',
          status: ended ? 'CERRADO' : 'HORARIO',
          statusColor: ended ? Colors.red : Colors.orange,
          success: false,
        );
        _showResultModal(
          title: ended ? 'Clase finalizada' : 'Fuera de horario',
          message: ended
              ? 'La clase ya terminó ($startMsg - $endMsg). Usa "Editar" en el calendario.'
              : 'Aún no es hora de clase. Disponible hoy de $startMsg a $endMsg.',
          color: ended ? Colors.red : Colors.orange,
          icon: ended ? Icons.stop_circle : Icons.schedule,
        );
        return;
      }

      if (!_attendanceActive || _sessionId == null) {
        _updateLastScannedCard(
          studentName: studentName,
          student: scannedStudent,
          message: 'Debes iniciar sesión para registrar asistencia',
          status: 'INACTIVO',
          statusColor: Colors.blue,
          success: false,
        );
        _showResultModal(
          title: 'Inicia la sesión',
          message: 'Debes iniciar la sesión de asistencia antes de escanear.',
          color: Colors.blue,
          icon: Icons.play_arrow,
        );
        return;
      }

      // Evitar duplicados por sesión (TEMPORAL: comentado por permisos)
      // if (_sessionId != null) {
      //   final dup = await FirebaseFirestore.instance
      //       .collection('attendance')
      //       .where('sessionId', isEqualTo: _sessionId)
      //       .where('studentId', isEqualTo: studentId)
      //       .limit(1)
      //       .get();
      //   if (dup.docs.isNotEmpty) {
      //     if (mounted) {
      //       ScaffoldMessenger.of(context).showSnackBar(
      //         SnackBar(content: Text('$studentName ya fue registrado')),
      //       );
      //     }
      //     return;
      //   }
      // }

      // Evitar duplicados por día/aula/estudiante (TEMPORAL: comentado por permisos)
      final dateKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      // final existing = await FirebaseFirestore.instance
      //     .collection('attendance')
      //     .where('classroomId', isEqualTo: widget.classroom.id)
      //     .where('studentId', isEqualTo: studentId)
      //     .where('date', isEqualTo: dateKey)
      //     .limit(1)
      //     .get();
      // if (existing.docs.isNotEmpty) {
      //   _showResultModal(
      //     title: 'Ya registrado',
      //     message: '$studentName ya tiene asistencia registrada hoy',
      //     color: Colors.orange,
      //     icon: Icons.info,
      //   );
      //   return;
      // }
      // Determinar estado segun maxLateTime y registrar de forma atómica y sin duplicados (ID determinista)
      final maxLate = _combine(now, schedule.maxLateTime);
      final status = (now.isBefore(maxLate) || now.isAtSameMomentAs(maxLate))
          ? 'present'
          : 'late';

      final attendanceId = '${studentId}_$dateKey';

      final attendanceRef = FirebaseFirestore.instance
          .collection('attendance')
          .doc(attendanceId);
      final entryEventRef = FirebaseFirestore.instance
          .collection('classrooms')
          .doc(widget.classroom.id)
          .collection('attendance_events')
          .doc('${attendanceId}__entry');
      final exitEventRef = FirebaseFirestore.instance
          .collection('classrooms')
          .doc(widget.classroom.id)
          .collection('attendance_events')
          .doc('${attendanceId}__exit');

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final attendanceSnap = await tx.get(attendanceRef);

        if (!attendanceSnap.exists) {
          tx.set(attendanceRef, {
            'studentId': studentId,
            'studentName': studentName,
            'classroomId': widget.classroom.id,
            'sessionId': _sessionId,
            'date': dateKey,
            'status': status,
            'timestamp': FieldValue.serverTimestamp(),
            'entryAt': FieldValue.serverTimestamp(),
            'eventDriven': true,
            'source': 'attendance_event',
          }, SetOptions(merge: true));

          tx.set(entryEventRef, {
            'eventType': 'entry',
            'studentId': studentId,
            'studentName': studentName,
            'classroomId': widget.classroom.id,
            'sessionId': _sessionId,
            'date': dateKey,
            'status': status,
            'eventAt': FieldValue.serverTimestamp(),
            'source': 'qr',
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          return;
        }

        final attendanceData = attendanceSnap.data() ?? {};
        if (attendanceData['exitAt'] != null) {
          throw Exception('YA_SALIDA_REGISTRADA');
        }

        tx.set(attendanceRef, {
          'exitAt': FieldValue.serverTimestamp(),
          'exitSource': 'qr',
          'updatedAt': FieldValue.serverTimestamp(),
          'eventDriven': true,
          'source': 'attendance_event',
        }, SetOptions(merge: true));

        tx.set(exitEventRef, {
          'eventType': 'exit',
          'studentId': studentId,
          'studentName': studentName,
          'classroomId': widget.classroom.id,
          'sessionId': _sessionId,
          'date': dateKey,
          'status': 'exit',
          'eventAt': FieldValue.serverTimestamp(),
          'source': 'qr',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      final updatedDoc = await attendanceRef.get();
      final hasExit = (updatedDoc.data() ?? {})['exitAt'] != null;

      _updateLastScannedCard(
        studentName: studentName,
        student: scannedStudent,
        message: hasExit
            ? 'Salida registrada correctamente'
            : 'Asistencia marcada como ${status == 'present' ? 'Presente' : 'Tarde'}',
        status: 'SUCCESS',
        statusColor: Colors.green,
        success: true,
      );

      _showResultModal(
        title: hasExit ? 'Salida registrada' : 'Asistencia registrada',
        message: hasExit
            ? '$studentName • Salida'
            : '$studentName • ${status == 'present' ? 'Presente' : 'Tarde'}',
        color: Colors.green,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (e.toString().contains('YA_SALIDA_REGISTRADA')) {
        _updateLastScannedCard(
          studentName: studentName,
          student: scannedStudent,
          message: 'Salida ya registrada hoy',
          status: 'DUPLICADO',
          statusColor: Colors.orange,
          success: false,
        );
        _showResultModal(
          title: 'Ya registró salida',
          message: '$studentName ya tiene salida registrada hoy',
          color: Colors.orange,
          icon: Icons.info,
        );
      } else if (e.toString().contains('YA_REGISTRADO')) {
        _updateLastScannedCard(
          studentName: studentName,
          student: scannedStudent,
          message: 'Asistencia ya registrada hoy',
          status: 'DUPLICADO',
          statusColor: Colors.orange,
          success: false,
        );
        _showResultModal(
          title: 'Ya registrado',
          message: '$studentName ya tiene asistencia registrada hoy',
          color: Colors.orange,
          icon: Icons.info,
        );
      } else {
        _updateLastScannedCard(
          studentName: studentName,
          student: scannedStudent,
          message: 'Error al procesar QR',
          status: 'ERROR',
          statusColor: Colors.red,
          success: false,
        );
        _showResultModal(
          title: 'Error',
          message: 'Error al procesar QR: $e',
          color: Colors.red,
          icon: Icons.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _showResultModal({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    if (_isShowingResult) return;
    _isShowingResult = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
          }
        });
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(message, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      _isShowingResult = false;
    });
  }

  // Stream de asistencias del día y salón desde 'attendance'
  // ignore: unused_element
  Stream<QuerySnapshot> _attendanceStreamForDay(
    String classroomId,
    DateTime day,
  ) {
    final dateKey =
        '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return FirebaseFirestore.instance
        .collection('attendance')
        .where('classroomId', isEqualTo: classroomId)
        .where('date', isEqualTo: dateKey)
        .snapshots();
  }

  // Cargar estudiantes del aula
  Future<void> _loadStudents() async {
    if (!mounted) return;

    try {
      final studentsStream = StudentService.getStudentsByClassroom(
        widget.classroom.id ?? '',
      );
      final studentsSnapshot = await studentsStream.first;

      if (!mounted) return;

      final students = studentsSnapshot.docs
          .map((doc) => StudentModel.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _students = students;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar estudiantes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Cargar asistencia para un día específico
  Future<void> _loadAttendanceForDay(DateTime day) async {
    if (!mounted) return;

    final dateKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('attendances')
          .doc('${widget.classroom.id}_$dateKey')
          .get();

      if (!mounted) return;

      if (doc.exists) {
        setState(() {
          _attendanceData = doc.data() ?? {};
        });
      } else {
        setState(() {
          _attendanceData = {};
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _attendanceData = {};
        });
      }
    }
  }

  // Mostrar diálogo para editar asistencia
  void _showEditAttendanceDialog(DateTime day) {
    showDialog(
      context: context,
      builder: (context) => _EditAttendanceDialog(
        classroom: widget.classroom,
        selectedDay: day,
        students: _students,
        attendanceData: _attendanceData,
        onSaved: () {
          _loadAttendanceForDay(day);
        },
      ),
    );
  }

  // Reabrir asistencia del día
  // ignore: unused_element
  void _reopenAttendance(DateTime day) async {
    final dateKey =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

    try {
      // Verificar límite de reaperturas
      final sessionDoc = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .doc('${widget.classroom.id}_$dateKey')
          .get();

      int reopenCount = 0;
      if (sessionDoc.exists) {
        reopenCount = sessionDoc.data()?['reopenCount'] ?? 0;
      }

      if (reopenCount >= 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Has alcanzado el límite de 5 reaperturas para este día',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Confirmar reapertura
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reabrir Asistencia'),
          content: Text(
            '¿Estás seguro de reabrir la asistencia del ${day.day}/${day.month}/${day.year}?\n\nReaperturas usadas: $reopenCount/5',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reabrir'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // Reabrir sesión
        await FirebaseFirestore.instance
            .collection('attendance_sessions')
            .doc('${widget.classroom.id}_$dateKey')
            .set({
              'classroomId': widget.classroom.id,
              'date': dateKey,
              'startTime': FieldValue.serverTimestamp(),
              'isActive': true,
              'reopenCount': reopenCount + 1,
            }, SetOptions(merge: true));

        setState(() {
          _attendanceActive = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Asistencia reabierta correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reabrir asistencia: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Construir lista de estudiantes con asistencias
  // Removed old _buildStudentAttendanceList in favor of real-time provider widget
}

class _ScanCorner extends StatelessWidget {
  final bool top;
  final bool left;

  const _ScanCorner({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFF0059BB);

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: top && left ? const Radius.circular(14) : Radius.zero,
          topRight: top && !left ? const Radius.circular(14) : Radius.zero,
          bottomLeft: !top && left ? const Radius.circular(14) : Radius.zero,
          bottomRight: !top && !left ? const Radius.circular(14) : Radius.zero,
        ),
        border: Border(
          top: top
              ? const BorderSide(color: borderColor, width: 4)
              : BorderSide.none,
          bottom: !top
              ? const BorderSide(color: borderColor, width: 4)
              : BorderSide.none,
          left: left
              ? const BorderSide(color: borderColor, width: 4)
              : BorderSide.none,
          right: !left
              ? const BorderSide(color: borderColor, width: 4)
              : BorderSide.none,
        ),
      ),
    );
  }
}

class ScheduleSettingsScreen extends StatefulWidget {
  final ClassroomModel classroom;

  static const Color brandBlue = Color(0xFF1976D2);
  static const Color surfaceLow = Color(0xFFF2F4F5);
  static const Color surfaceMid = Color(0xFFEDEFF2);
  static const Color outline = Color(0xFF5F6470);
  static const Color outlineVariant = Color(0xFFC5C6D2);
  static const Color secondaryFixed = Color(0xFFD8E2FF);

  const ScheduleSettingsScreen({super.key, required this.classroom});

  @override
  State<ScheduleSettingsScreen> createState() => _ScheduleSettingsScreenState();
}

class _ScheduleSettingsScreenState extends State<ScheduleSettingsScreen> {
  final Map<String, Map<String, String>> _schedules = {};
  bool _isLoading = false;

  final Map<String, String> _weekDays = const {
    'monday': 'Lunes',
    'tuesday': 'Martes',
    'wednesday': 'Miércoles',
    'thursday': 'Jueves',
    'friday': 'Viernes',
    'saturday': 'Sábado',
    'sunday': 'Domingo',
  };

  @override
  void initState() {
    super.initState();
    _loadExistingSchedules();
  }

  void _loadExistingSchedules() {
    if (widget.classroom.schedule != null) {
      for (final entry in widget.classroom.schedule!.entries) {
        _schedules[entry.key] = {
          'startTime': entry.value.startTime,
          'endTime': entry.value.endTime,
          'maxLateTime': entry.value.maxLateTime,
        };
      }
    }
  }

  int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return (hour * 60) + minute;
  }

  String _formatHour(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }

  int _totalConfiguredMinutes() {
    var total = 0;
    for (final schedule in _schedules.values) {
      final start = _toMinutes(schedule['startTime'] ?? '08:00');
      final end = _toMinutes(schedule['endTime'] ?? '17:00');
      if (end > start) total += (end - start);
    }
    return total;
  }

  int _configuredDaysCount() => _schedules.length;

  String _totalHoursLabel() {
    final hours = _totalConfiguredMinutes() / 60;
    final text = hours == hours.roundToDouble()
        ? hours.toInt().toString()
        : hours.toStringAsFixed(1);
    return '$text horas operativas configuradas';
  }

  int _loadPercent() {
    const fullWeekMinutes = 49 * 60;
    final percentage = (_totalConfiguredMinutes() / fullWeekMinutes) * 100;
    return percentage.clamp(0, 100).round();
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return const TimeOfDay(hour: 8, minute: 0);
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _timeLabel(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _editDaySchedule(String dayKey, String dayName) async {
    final existing = _schedules[dayKey];
    var enabled = existing != null;
    var start = _parseTime(existing?['startTime'] ?? '08:00');
    var end = _parseTime(existing?['endTime'] ?? '17:00');
    var maxLate = _parseTime(existing?['maxLateTime'] ?? '08:15');

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ScheduleSettingsScreen.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickTime(
              TimeOfDay current,
              ValueChanged<TimeOfDay> onPicked,
            ) async {
              final picked = await showTimePicker(
                context: context,
                initialTime: current,
              );
              if (picked != null) {
                setSheetState(() => onPicked(picked));
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dayName,
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: ScheduleSettingsScreen.brandBlue,
                            ),
                          ),
                        ),
                        Switch(
                          value: enabled,
                          onChanged: (value) {
                            setSheetState(() => enabled = value);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      enabled
                          ? 'Configura el rango horario y la puntualidad.'
                          : 'Activa para añadir horario a este día.',
                      style: GoogleFonts.manrope(
                        color: ScheduleSettingsScreen.outline,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (enabled) ...[
                      _TimePickerTile(
                        label: 'Hora de entrada',
                        value: _timeLabel(start),
                        icon: Icons.login_rounded,
                        onTap: () =>
                            pickTime(start, (picked) => start = picked),
                      ),
                      const SizedBox(height: 10),
                      _TimePickerTile(
                        label: 'Hora de salida',
                        value: _timeLabel(end),
                        icon: Icons.logout_rounded,
                        onTap: () => pickTime(end, (picked) => end = picked),
                      ),
                      const SizedBox(height: 10),
                      _TimePickerTile(
                        label: 'Puntual hasta',
                        value: _timeLabel(maxLate),
                        icon: Icons.schedule,
                        onTap: () =>
                            pickTime(maxLate, (picked) => maxLate = picked),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ScheduleSettingsScreen.brandBlue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'Aplicar cambios',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (changed != true || !mounted) return;

    setState(() {
      if (enabled) {
        _schedules[dayKey] = {
          'startTime': _timeLabel(start),
          'endTime': _timeLabel(end),
          'maxLateTime': _timeLabel(maxLate),
        };
      } else {
        _schedules.remove(dayKey);
      }
    });
  }

  Future<void> _saveSchedules() async {
    setState(() => _isLoading = true);

    try {
      final Map<String, ClassSchedule> scheduleMap = {};
      for (final entry in _schedules.entries) {
        scheduleMap[entry.key] = ClassSchedule(
          dayOfWeek: entry.key,
          startTime: entry.value['startTime']!,
          endTime: entry.value['endTime']!,
          maxLateTime: entry.value['maxLateTime']!,
        );
      }

      await FirebaseFirestore.instance
          .collection('classrooms')
          .doc(widget.classroom.id)
          .update({
            'schedule': scheduleMap.map(
              (key, value) => MapEntry(key, value.toMap()),
            ),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100
        ? 3
        : width >= 760
        ? 2
        : 1;

    return Scaffold(
      backgroundColor: ScheduleSettingsScreen.surfaceLow,
      appBar: AppBar(
        backgroundColor: ScheduleSettingsScreen.surfaceLow,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: ScheduleSettingsScreen.brandBlue),
        title: Text(
          'Asistencias',
          style: GoogleFonts.manrope(
            color: ScheduleSettingsScreen.brandBlue,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _isLoading ? null : _saveSchedules,
              style: FilledButton.styleFrom(
                backgroundColor: ScheduleSettingsScreen.brandBlue,
                foregroundColor: Colors.white,
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isLoading ? 'Guardando' : 'Guardar'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ScheduleSettingsScreen.surfaceLow,
                ScheduleSettingsScreen.surfaceMid,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Text(
                'Configuración de Horarios',
                style: GoogleFonts.manrope(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: ScheduleSettingsScreen.brandBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Define y gestiona los rangos operativos de la institución para el ciclo lectivo vigente.',
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  color: ScheduleSettingsScreen.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                itemCount: _weekDays.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 182,
                ),
                itemBuilder: (context, index) {
                  final entry = _weekDays.entries.elementAt(index);
                  final schedule = _schedules[entry.key];

                  if (schedule != null) {
                    return _ConfiguredDayCard(
                      dayName: entry.value,
                      startTime: _formatHour(schedule['startTime'] ?? '08:00'),
                      endTime: _formatHour(schedule['endTime'] ?? '17:00'),
                      maxLateTime: _formatHour(
                        schedule['maxLateTime'] ?? '08:15',
                      ),
                      onEdit: () => _editDaySchedule(entry.key, entry.value),
                    );
                  }

                  return _UnconfiguredDayCard(
                    dayName: entry.value,
                    onAdd: () => _editDaySchedule(entry.key, entry.value),
                  );
                },
              ),
              const SizedBox(height: 16),
              _WeeklySummaryCard(
                hoursLabel: _totalHoursLabel(),
                configuredDays: _configuredDaysCount(),
                loadPercent: _loadPercent(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfiguredDayCard extends StatelessWidget {
  final String dayName;
  final String startTime;
  final String endTime;
  final String maxLateTime;
  final VoidCallback onEdit;

  const _ConfiguredDayCard({
    required this.dayName,
    required this.startTime,
    required this.endTime,
    required this.maxLateTime,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: const Border(
              left: BorderSide(
                width: 4,
                color: ScheduleSettingsScreen.brandBlue,
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayName,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ScheduleSettingsScreen.outline,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ScheduleSettingsScreen.secondaryFixed,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Configurado',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: ScheduleSettingsScreen.brandBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit,
                      color: ScheduleSettingsScreen.brandBlue,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '$startTime - $endTime',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ScheduleSettingsScreen.brandBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Puntual hasta: $maxLateTime',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ScheduleSettingsScreen.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnconfiguredDayCard extends StatelessWidget {
  final String dayName;
  final VoidCallback onAdd;

  const _UnconfiguredDayCard({required this.dayName, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ScheduleSettingsScreen.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dayName,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ScheduleSettingsScreen.outline,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sin horario configurado',
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
              color: ScheduleSettingsScreen.outline,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: ScheduleSettingsScreen.brandBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text(
                'Añadir',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  final String hoursLabel;
  final int configuredDays;
  final int loadPercent;

  const _WeeklySummaryCard({
    required this.hoursLabel,
    required this.configuredDays,
    required this.loadPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ScheduleSettingsScreen.brandBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen Semanal',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hoursLabel,
            style: GoogleFonts.manrope(
              color: ScheduleSettingsScreen.secondaryFixed,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(label: 'Días', value: '$configuredDays/7'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryItem(label: 'Carga', value: '$loadPercent%'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.manrope(
              color: ScheduleSettingsScreen.secondaryFixed,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _TimePickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: ScheduleSettingsScreen.brandBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ScheduleSettingsScreen.outline,
                  ),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ScheduleSettingsScreen.brandBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditAttendanceDialog extends StatefulWidget {
  final ClassroomModel classroom;
  final DateTime selectedDay;
  final List<StudentModel> students;
  final Map<String, dynamic> attendanceData;
  final VoidCallback onSaved;

  const _EditAttendanceDialog({
    required this.classroom,
    required this.selectedDay,
    required this.students,
    required this.attendanceData,
    required this.onSaved,
  });

  @override
  State<_EditAttendanceDialog> createState() => _EditAttendanceDialogState();
}

class _EditAttendanceDialogState extends State<_EditAttendanceDialog> {
  Map<String, String> _attendanceStatus = {};
  final Map<String, String> _initialStatus = {};
  bool _isLoading = false;
  bool _isLoadingExisting = true;
  final Map<String, String> _existingDocIds =
      {}; // studentId -> attendance docId

  @override
  void initState() {
    super.initState();
    _loadExistingAttendance();
  }

  Future<void> _loadExistingAttendance() async {
    setState(() => _isLoadingExisting = true);
    try {
      _attendanceStatus.clear();
      _initialStatus.clear();
      _existingDocIds.clear();

      final dateKey =
          '${widget.selectedDay.year.toString().padLeft(4, '0')}'
          '-${widget.selectedDay.month.toString().padLeft(2, '0')}'
          '-${widget.selectedDay.day.toString().padLeft(2, '0')}';

      final snap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('classroomId', isEqualTo: widget.classroom.id)
          .where('date', isEqualTo: dateKey)
          .get();

      final dayMap = <String, String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final sid = (data['studentId'] ?? '').toString();
        final status = (data['status'] ?? 'absent').toString();
        if (sid.isNotEmpty) {
          dayMap[sid] = status;
          _existingDocIds[sid] = d.id;
        }
      }

      for (final student in widget.students) {
        final sid = student.id ?? '';
        if (sid.isEmpty) continue;
        final initial = dayMap[sid] ?? 'absent';
        _attendanceStatus[sid] = initial;
        _initialStatus[sid] = initial;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar asistencias del día: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingExisting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.edit, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Editar Asistencia - ${widget.selectedDay.day}/${widget.selectedDay.month}/${widget.selectedDay.year}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Lista de estudiantes (responsive)
            Expanded(
              child: _isLoadingExisting
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: widget.students.length,
                      itemBuilder: (context, index) {
                        final student = widget.students[index];
                        final currentStatus =
                            _attendanceStatus[student.id ?? ''] ?? 'absent';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar y nombre del estudiante
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    student.firstName[0].toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${student.firstName} ${student.lastName}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'DNI: ${student.dni}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Opciones de estado (Wrap para responsividad)
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _buildStatusButton(
                                            student.id ?? '',
                                            'present',
                                            'Asistió',
                                            Icons.check_circle,
                                            Colors.green,
                                            currentStatus == 'present',
                                          ),
                                          _buildStatusButton(
                                            student.id ?? '',
                                            'late',
                                            'Tardanza',
                                            Icons.access_time,
                                            Colors.orange,
                                            currentStatus == 'late',
                                          ),
                                          _buildStatusButton(
                                            student.id ?? '',
                                            'absent',
                                            'Faltó',
                                            Icons.cancel,
                                            Colors.red,
                                            currentStatus == 'absent',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 24),

            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAttendance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(
    String studentId,
    String status,
    String label,
    IconData icon,
    Color color,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _attendanceStatus[studentId] = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAttendance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('Usuario no autenticado');
      }

      final dateKey =
          '${widget.selectedDay.year.toString().padLeft(4, '0')}'
          '-${widget.selectedDay.month.toString().padLeft(2, '0')}'
          '-${widget.selectedDay.day.toString().padLeft(2, '0')}';

      final batch = FirebaseFirestore.instance.batch();

      for (final entry in _attendanceStatus.entries) {
        final studentId = entry.key;
        final status = entry.value;
        if (studentId.isEmpty) {
          continue;
        }

        final existingId = _existingDocIds[studentId];
        final initialStatus = _initialStatus[studentId];

        if (initialStatus != null && status == initialStatus) {
          continue;
        }

        StudentModel? student;
        for (final s in widget.students) {
          if ((s.id ?? '') == studentId) {
            student = s;
            break;
          }
        }
        if (student == null) {
          continue;
        }

        final deterministicId = '${studentId}_$dateKey';

        if (status == 'absent') {
          // Escribir/actualizar estado 'absent' en lugar de eliminar
          if (existingId != null) {
            final docRef = FirebaseFirestore.instance
                .collection('attendance')
                .doc(existingId);
            batch.update(docRef, {
              'status': 'absent',
              'entryAt': null,
              'editedAt': FieldValue.serverTimestamp(),
              'editedBy': currentUser.uid,
              'source': 'manual_edit_calendar',
            });
          } else {
            final docRef = FirebaseFirestore.instance
                .collection('attendance')
                .doc(deterministicId);
            batch.set(docRef, {
              'studentId': studentId,
              'studentName': '${student.firstName} ${student.lastName}',
              'classroomId': widget.classroom.id,
              'teacherUid': currentUser.uid,
              'timestamp': FieldValue.serverTimestamp(),
              'status': 'absent',
              'date': dateKey,
              'entryAt': null,
              'editedAt': FieldValue.serverTimestamp(),
              'editedBy': currentUser.uid,
              'source': 'manual_edit_calendar',
            }, SetOptions(merge: true));
          }
          continue;
        }

        if (existingId != null) {
          final docRef = FirebaseFirestore.instance
              .collection('attendance')
              .doc(existingId);
          batch.update(docRef, {
            'status': status,
            'editedAt': FieldValue.serverTimestamp(),
            'editedBy': currentUser.uid,
            'source': 'manual_edit_calendar',
          });
        } else {
          final docRef = FirebaseFirestore.instance
              .collection('attendance')
              .doc(deterministicId);
          batch.set(docRef, {
            'studentId': studentId,
            'studentName': '${student.firstName} ${student.lastName}',
            'classroomId': widget.classroom.id,
            'teacherUid': currentUser.uid,
            'timestamp': FieldValue.serverTimestamp(),
            'status': status,
            'date': dateKey,
            'editedAt': FieldValue.serverTimestamp(),
            'editedBy': currentUser.uid,
            'source': 'manual_edit_calendar',
          }, SetOptions(merge: true));
        }
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Asistencia actualizada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar asistencia: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
