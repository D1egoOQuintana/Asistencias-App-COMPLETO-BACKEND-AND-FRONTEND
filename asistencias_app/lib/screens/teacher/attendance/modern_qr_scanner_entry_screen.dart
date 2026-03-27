import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../models/classroom_model.dart';
import '../../../services/teacher_service.dart';
import '../classrooms/teacher_classrooms_screen.dart';
import '../qr_attendance_realtime.dart';

/// Entrada rápida al scanner QR moderno.
/// Selecciona automáticamente el aula más relevante y abre el scanner directo.
class ModernQrScannerEntryScreen extends StatefulWidget {
  const ModernQrScannerEntryScreen({super.key});

  @override
  State<ModernQrScannerEntryScreen> createState() =>
      _ModernQrScannerEntryScreenState();
}

class _ModernQrScannerEntryScreenState
    extends State<ModernQrScannerEntryScreen> {
  bool _isLoading = true;
  bool _hasClassrooms = true;
  String? _error;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _openModernScanner();
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

  DateTime _parseTimeOnDate(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  bool _isLiveNow(ClassroomModel classroom, DateTime now) {
    final schedule = classroom.schedule;
    if (schedule == null || schedule.isEmpty) return false;

    final today = schedule[_weekdayKey(now)];
    if (today == null) return false;

    final start = _parseTimeOnDate(now, today.startTime);
    final end = _parseTimeOnDate(now, today.endTime);

    return (now.isAtSameMomentAs(start) || now.isAfter(start)) &&
        now.isBefore(end);
  }

  ClassroomModel _pickBestClassroom(List<ClassroomModel> classrooms) {
    final now = DateTime.now();
    final active = classrooms.where((c) => c.isActive).toList();
    final source = active.isNotEmpty ? active : classrooms;

    for (final classroom in source) {
      if (_isLiveNow(classroom, now)) return classroom;
    }

    final weekday = _weekdayKey(now);
    final upcoming = source.where((classroom) {
      final schedule = classroom.schedule?[weekday];
      if (schedule == null) return false;
      return _parseTimeOnDate(now, schedule.startTime).isAfter(now);
    }).toList();

    if (upcoming.isNotEmpty) {
      upcoming.sort((a, b) {
        final aTime = _parseTimeOnDate(now, a.schedule![weekday]!.startTime);
        final bTime = _parseTimeOnDate(now, b.schedule![weekday]!.startTime);
        return aTime.compareTo(bTime);
      });
      return upcoming.first;
    }

    source.sort((a, b) {
      final aKey = '${a.grade}-${a.section}-${a.name}'.toLowerCase();
      final bKey = '${b.grade}-${b.section}-${b.name}'.toLowerCase();
      return aKey.compareTo(bKey);
    });
    return source.first;
  }

  Future<void> _openModernScanner() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No hay sesión activa.';
      });
      return;
    }

    try {
      final snapshot = await TeacherService.getClassroomsByTeacher(
        user.uid,
      ).first;
      final classrooms = snapshot.docs
          .map((doc) => ClassroomModel.fromFirestore(doc))
          .toList();

      if (!mounted) return;

      if (classrooms.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasClassrooms = false;
        });
        return;
      }

      if (_navigated) return;
      _navigated = true;

      final selected = _pickBestClassroom(classrooms);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QRAttendanceRealtimeScreen(classroomId: selected.id!),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No se pudo abrir el scanner: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner QR')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isLoading
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text('Abriendo scanner moderno...'),
                  ],
                )
              : _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 44,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center),
                  ],
                )
              : !_hasClassrooms
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.class_outlined,
                      size: 44,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No tienes aulas asignadas para escanear.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) =>
                                const TeacherClassroomsScreen(showAppBar: true),
                          ),
                        );
                      },
                      icon: const Icon(Icons.class_rounded),
                      label: const Text('Ir a Mis Aulas'),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
