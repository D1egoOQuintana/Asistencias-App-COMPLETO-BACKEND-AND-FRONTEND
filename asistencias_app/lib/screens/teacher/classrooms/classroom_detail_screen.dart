import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/classroom_model.dart';
import '../../../models/student_model.dart';
import '../../../services/student_service.dart';
// import 'attendance_session_screen.dart';

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
  List<StudentModel> _students = [];
  Map<String, dynamic> _attendanceData = {};
  ClassroomModel? _classroomOverride;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadAttendanceForDay(_selectedDay);
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
          actions: [
            IconButton(
              tooltip: 'Configurar horarios',
              icon: const Icon(Icons.schedule),
              onPressed: _showScheduleSettings,
            ),
          ],
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 260,
                    child: MobileScanner(
                      onDetect: (capture) {
                        final barcode = capture.barcodes.firstOrNull;
                        final raw = barcode?.rawValue;
                        if (raw != null && raw.isNotEmpty) {
                          _processQRCode(raw);
                        }
                      },
                    ),
                  ),
                ),
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

  void _showScheduleSettings() {
    showDialog(
      context: context,
      builder: (context) => _ScheduleSettingsDialog(
        classroom: widget.classroom,
        onSaved: () {
          setState(() {
            // Refrescar día/horario actual para habilitar QR inmediatamente
            _selectedDay = DateTime.now();
            _focusedDay = DateTime.now();
          });
        },
      ),
    );
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
    // Declarar variables en scope amplio para usarlas en catch
    String studentName = 'Estudiante';
    try {
      if (qrData.isEmpty) return;
      dynamic data;
      try {
        data = jsonDecode(qrData);
      } catch (_) {
        // No es JSON; ignorar
        return;
      }
      if (data is! Map<String, dynamic>) return;
      if (data['type'] != 'student') return;
      if (!data.containsKey('id') || !data.containsKey('name')) return;

      final studentId = data['id'].toString();
      studentName = data['name'].toString();

      // Validaciones de horario y sesión
      final now = DateTime.now();
      final schedule = _getScheduleFor(now, widget.classroom);
      if (schedule == null) {
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

      // Pre-chequeo: si ya existe un doc (legado) con ID aleatorio para hoy, evitar duplicar
      final existing = await FirebaseFirestore.instance
          .collection('attendance')
          .where('classroomId', isEqualTo: widget.classroom.id)
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: dateKey)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        throw Exception('YA_REGISTRADO');
      }

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final ref = FirebaseFirestore.instance
            .collection('attendance')
            .doc(attendanceId);
        final snap = await tx.get(ref);
        if (snap.exists) {
          // Ya registrado hoy: no crear nuevo documento
          throw Exception('YA_REGISTRADO');
        }
        tx.set(ref, {
          'studentId': studentId,
          'studentName': studentName,
          'classroomId': widget.classroom.id,
          'sessionId': _sessionId,
          'date': dateKey,
          'status': status,
          'timestamp': FieldValue.serverTimestamp(),
          'entryAt': FieldValue.serverTimestamp(),
        });
      });

      _showResultModal(
        title: 'Asistencia registrada',
        message: '$studentName • ${status == 'present' ? 'Presente' : 'Tarde'}',
        color: Colors.green,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (e.toString().contains('YA_REGISTRADO')) {
        _showResultModal(
          title: 'Ya registrado',
          message: '$studentName ya tiene asistencia registrada hoy',
          color: Colors.orange,
          icon: Icons.info,
        );
      } else {
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

class _ScheduleSettingsDialog extends StatefulWidget {
  final ClassroomModel classroom;
  final VoidCallback onSaved;

  const _ScheduleSettingsDialog({
    required this.classroom,
    required this.onSaved,
  });

  @override
  State<_ScheduleSettingsDialog> createState() =>
      _ScheduleSettingsDialogState();
}

class _ScheduleSettingsDialogState extends State<_ScheduleSettingsDialog> {
  final Map<String, Map<String, String>> _schedules = {};
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  bool _isLoading = false;

  final Map<String, String> _weekDays = {
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

        // Inicializar controladores para este día
        _controllers[entry.key] = {
          'startTime': TextEditingController(text: entry.value.startTime),
          'endTime': TextEditingController(text: entry.value.endTime),
          'maxLateTime': TextEditingController(text: entry.value.maxLateTime),
        };
      }
    }
  }

  @override
  void dispose() {
    // Limpiar controladores
    for (final dayControllers in _controllers.values) {
      for (final controller in dayControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600 || screenSize.height < 700;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(1.0), // Fuerza tamaño fijo de texto
      ),
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isSmallScreen ? screenSize.width * 0.95 : 600,
            maxHeight: isSmallScreen ? screenSize.height * 0.9 : 700,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header - Responsivo
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.blue.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Colors.blue.shade700,
                      size: isSmallScreen ? 24 : 28,
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Expanded(
                      child: Text(
                        'Configurar Horarios',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 18 : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, size: isSmallScreen ? 20 : 24),
                      padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                    ),
                  ],
                ),
              ),

              // Lista de días - Scrolleable
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                  child: ListView(
                    children: _weekDays.entries.map((dayEntry) {
                      final dayKey = dayEntry.key;
                      final dayName = dayEntry.value;

                      return _buildDayScheduleCard(
                        dayKey,
                        dayName,
                        isSmallScreen,
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Botones - Responsivo
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size(0, isSmallScreen ? 44 : 48),
                        ),
                        child: Text(
                          'Cancelar',
                          style: TextStyle(fontSize: isSmallScreen ? 14 : null),
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveSchedules,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          minimumSize: Size(0, isSmallScreen ? 44 : 48),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: isSmallScreen ? 16 : 20,
                                height: isSmallScreen ? 16 : 20,
                                child: const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Guardar',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : null,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayScheduleCard(
    String dayKey,
    String dayName,
    bool isSmallScreen,
  ) {
    final schedule = _schedules[dayKey];
    final hasSchedule = schedule != null;

    return Card(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Transform.scale(
                  scale: isSmallScreen ? 0.9 : 1.0,
                  child: Switch(
                    value: hasSchedule,
                    onChanged: (value) {
                      setState(() {
                        if (value) {
                          _schedules[dayKey] = {
                            'startTime': '08:00',
                            'endTime': '17:00',
                            'maxLateTime': '08:15',
                          };

                          // Crear controladores para este día
                          _controllers[dayKey] = {
                            'startTime': TextEditingController(text: '08:00'),
                            'endTime': TextEditingController(text: '17:00'),
                            'maxLateTime': TextEditingController(text: '08:15'),
                          };
                        } else {
                          _schedules.remove(dayKey);

                          // Limpiar controladores
                          if (_controllers.containsKey(dayKey)) {
                            for (final controller
                                in _controllers[dayKey]!.values) {
                              controller.dispose();
                            }
                            _controllers.remove(dayKey);
                          }
                        }
                      });
                    },
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Expanded(
                  child: Text(
                    dayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isSmallScreen ? 14 : 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (hasSchedule) ...[
              SizedBox(height: isSmallScreen ? 12 : 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isVerySmall = constraints.maxWidth < 300;

                  return isVerySmall
                      ? Column(
                          children: [
                            _buildTimeField(
                              'Hora de entrada',
                              dayKey,
                              'startTime',
                              (value) =>
                                  _schedules[dayKey]!['startTime'] = value,
                              isSmallScreen,
                            ),
                            SizedBox(height: isSmallScreen ? 8 : 12),
                            _buildTimeField(
                              'Hora de salida',
                              dayKey,
                              'endTime',
                              (value) => _schedules[dayKey]!['endTime'] = value,
                              isSmallScreen,
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: _buildTimeField(
                                'Hora de entrada',
                                dayKey,
                                'startTime',
                                (value) =>
                                    _schedules[dayKey]!['startTime'] = value,
                                isSmallScreen,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 12),
                            Expanded(
                              child: _buildTimeField(
                                'Hora de salida',
                                dayKey,
                                'endTime',
                                (value) =>
                                    _schedules[dayKey]!['endTime'] = value,
                                isSmallScreen,
                              ),
                            ),
                          ],
                        );
                },
              ),
              SizedBox(height: isSmallScreen ? 8 : 12),
              _buildTimeField(
                'Máximo para tardanza',
                dayKey,
                'maxLateTime',
                (value) => _schedules[dayKey]!['maxLateTime'] = value,
                isSmallScreen,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(
    String label,
    String dayKey,
    String timeKey,
    Function(String) onChanged,
    bool isSmallScreen,
  ) {
    // Asegurar que existe el controlador
    if (!_controllers.containsKey(dayKey)) {
      _controllers[dayKey] = {};
    }

    if (!_controllers[dayKey]!.containsKey(timeKey)) {
      _controllers[dayKey]![timeKey] = TextEditingController(
        text: _schedules[dayKey]?[timeKey] ?? '08:00',
      );
    }

    final controller = _controllers[dayKey]![timeKey]!;

    return TextFormField(
      controller: controller,
      style: TextStyle(fontSize: isSmallScreen ? 14 : null),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: isSmallScreen ? 12 : null),
        border: const OutlineInputBorder(),
        suffixIcon: Icon(Icons.access_time, size: isSmallScreen ? 20 : 24),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 12 : 16,
        ),
      ),
      onChanged: onChanged,
      keyboardType: TextInputType.text,
      onTap: () async {
        final currentValue = controller.text;
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(
            hour: int.parse(currentValue.split(':')[0]),
            minute: int.parse(currentValue.split(':')[1]),
          ),
        );

        if (time != null) {
          final formattedTime =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

          // Actualizar el controlador inmediatamente
          controller.text = formattedTime;

          // Actualizar el mapa de horarios
          onChanged(formattedTime);
        }
      },
      readOnly: true,
    );
  }

  Future<void> _saveSchedules() async {
    setState(() => _isLoading = true);

    try {
      // Convertir a formato requerido
      final Map<String, ClassSchedule> scheduleMap = {};

      for (final entry in _schedules.entries) {
        scheduleMap[entry.key] = ClassSchedule(
          dayOfWeek: entry.key,
          startTime: entry.value['startTime']!,
          endTime: entry.value['endTime']!,
          maxLateTime: entry.value['maxLateTime']!,
        );
      }

      // Actualizar en Firestore
      await FirebaseFirestore.instance
          .collection('classrooms')
          .doc(widget.classroom.id)
          .update({
            'schedule': scheduleMap.map(
              (key, value) => MapEntry(key, value.toMap()),
            ),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Horarios guardados exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
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
      setState(() => _isLoading = false);
    }
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
