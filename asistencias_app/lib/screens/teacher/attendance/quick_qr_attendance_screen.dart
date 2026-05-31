import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../models/classroom_model.dart';
import '../../../services/teacher_service.dart';
import '../../../theme/app_design_system.dart';

/// Pantalla de asistencia rápida por QR desde navegación
/// Permite seleccionar aula, validar horarios y escanear QR
class QuickQRAttendanceScreen extends StatefulWidget {
  const QuickQRAttendanceScreen({super.key});

  @override
  State<QuickQRAttendanceScreen> createState() =>
      _QuickQRAttendanceScreenState();
}

class _QuickQRAttendanceScreenState extends State<QuickQRAttendanceScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  ClassroomModel? _selectedClassroom;
  List<ClassroomModel> _classrooms = [];
  bool _isLoadingClassrooms = true;
  bool _isScanning = false;
  bool _isShowingResult = false;
  String? _sessionId;
  bool _attendanceActive = false;

  late MobileScannerController _scannerController;
  DateTime? _lastScanAt;
  String? _lastScanRaw;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _loadClassrooms();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  /// Cargar aulas del docente
  Future<void> _loadClassrooms() async {
    if (_currentUser == null) return;

    setState(() => _isLoadingClassrooms = true);

    try {
      final snapshot = await TeacherService.getClassroomsByTeacher(
        _currentUser.uid,
      ).first;

      final classrooms = snapshot.docs
          .map((doc) => ClassroomModel.fromFirestore(doc))
          .where((c) => c.isActive)
          .toList();

      if (mounted) {
        setState(() {
          _classrooms = classrooms;
          _isLoadingClassrooms = false;

          // Si solo hay un aula, seleccionarla automáticamente
          if (classrooms.length == 1) {
            _selectedClassroom = classrooms.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClassrooms = false);
        _showSnackBar('Error al cargar aulas: $e', isError: true);
      }
    }
  }

  /// Helpers de horario
  ClassSchedule? _getScheduleFor(DateTime date, ClassroomModel classroom) {
    if (!classroom.hasSchedule) return null;
    final weekday = date.weekday;
    final key = {
      1: 'monday',
      2: 'tuesday',
      3: 'wednesday',
      4: 'thursday',
      5: 'friday',
      6: 'saturday',
      7: 'sunday',
    }[weekday];
    if (key == null) return null;
    return classroom.schedule?[key];
  }

  DateTime _combine(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return DateTime(day.year, day.month, day.day, h, m);
  }

  bool _isWithinClassTime(DateTime now, ClassSchedule s) {
    final start = _combine(now, s.startTime);
    final end = _combine(now, s.endTime);
    return (now.isAtSameMomentAs(start) || now.isAfter(start)) &&
        now.isBefore(end);
  }

  bool _isAfterEndTime(DateTime now, ClassSchedule s) {
    final end = _combine(now, s.endTime);
    return now.isAfter(end);
  }

  /// Iniciar sesión de asistencia
  Future<void> _startAttendanceSession() async {
    if (_selectedClassroom == null) return;

    try {
      final now = DateTime.now();
      final dateKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final sessionDoc = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .add({
            'classroomId': _selectedClassroom!.id,
            'teacherUid': _currentUser!.uid,
            'startTime': FieldValue.serverTimestamp(),
            'endTime': null,
            'isActive': true,
            'attendanceCount': 0,
            'date': dateKey,
          });

      if (mounted) {
        setState(() {
          _sessionId = sessionDoc.id;
          _attendanceActive = true;
        });
        _showSnackBar('Sesión de asistencia iniciada', isError: false);
      }
    } catch (e) {
      _showSnackBar('Error al iniciar sesión: $e', isError: true);
    }
  }

  /// Detener sesión de asistencia
  Future<void> _stopAttendanceSession() async {
    if (_sessionId == null) return;

    try {
      // Contar asistencias de la sesión
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('classrooms')
          .doc(_selectedClassroom!.id)
          .collection('attendance')
          .where('sessionId', isEqualTo: _sessionId)
          .get();

      await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .doc(_sessionId)
          .update({
            'endTime': FieldValue.serverTimestamp(),
            'isActive': false,
            'attendanceCount': attendanceSnapshot.docs.length,
          });

      if (mounted) {
        setState(() {
          _attendanceActive = false;
          _sessionId = null;
        });
        _showSnackBar('Sesión finalizada correctamente', isError: false);
      }
    } catch (e) {
      _showSnackBar('Error al finalizar sesión: $e', isError: true);
    }
  }

  /// Procesar código QR escaneado
  Future<void> _processQRCode(String qrData) async {
    if (!_attendanceActive || _isScanning || _selectedClassroom == null) return;

    setState(() => _isScanning = true);

    dynamic data;
    String studentName = 'Estudiante';

    try {
      // Validar y decodificar QR
      if (qrData.isEmpty) {
        _showResultModal(
          title: 'QR Inválido',
          message: 'El código QR está vacío',
          color: Colors.red,
          icon: Icons.error,
        );
        return;
      }

      try {
        data = jsonDecode(qrData);
      } catch (e) {
        _showResultModal(
          title: 'QR Inválido',
          message: 'No es un código QR válido',
          color: Colors.red,
          icon: Icons.error,
        );
        return;
      }

      if (data is! Map<String, dynamic>) {
        _showResultModal(
          title: 'QR Inválido',
          message: 'Formato de QR incorrecto',
          color: Colors.red,
          icon: Icons.error,
        );
        return;
      }

      if (!data.containsKey('type') || data['type'] != 'student') {
        _showResultModal(
          title: 'QR Inválido',
          message: 'No es un código de estudiante',
          color: Colors.red,
          icon: Icons.error,
        );
        return;
      }

      if (!data.containsKey('id') || !data.containsKey('name')) {
        _showResultModal(
          title: 'QR Inválido',
          message: 'Datos incompletos en el QR',
          color: Colors.red,
          icon: Icons.error,
        );
        return;
      }

      final studentId = data['id'].toString();
      studentName = data['name'].toString();

      // Validaciones de horario
      final now = DateTime.now();
      final schedule = _getScheduleFor(now, _selectedClassroom!);

      if (schedule == null) {
        _showResultModal(
          title: 'Sin Horario',
          message:
              'Hoy no hay clase programada para ${_selectedClassroom!.name}',
          color: Colors.orange,
          icon: Icons.schedule_outlined,
        );
        return;
      }

      if (!_isWithinClassTime(now, schedule)) {
        final ended = _isAfterEndTime(now, schedule);
        _showResultModal(
          title: ended ? 'Clase Finalizada' : 'Fuera de Horario',
          message: ended
              ? 'La clase ya terminó (${schedule.startTime} - ${schedule.endTime})'
              : 'La clase es de ${schedule.startTime} a ${schedule.endTime}',
          color: ended ? Colors.red : Colors.orange,
          icon: ended ? Icons.stop_circle : Icons.schedule,
        );
        return;
      }

      // Verificar duplicados
      final dateKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final attendanceId = '${studentId}_$dateKey';

      // Pre-chequeo de duplicados
        final existing = await FirebaseFirestore.instance
          .collection('classrooms')
          .doc(_selectedClassroom!.id)
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: dateKey)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception('YA_REGISTRADO');
      }

      // Determinar estado (presente o tarde)
      final maxLate = _combine(now, schedule.maxLateTime);
      final status = (now.isBefore(maxLate) || now.isAtSameMomentAs(maxLate))
          ? 'present'
          : 'late';

      // Registrar asistencia de forma atómica
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final ref = FirebaseFirestore.instance
          .collection('classrooms')
          .doc(_selectedClassroom!.id)
          .collection('attendance')
          .doc(attendanceId);

        final snap = await tx.get(ref);
        if (snap.exists) {
          throw Exception('YA_REGISTRADO');
        }

        tx.set(ref, {
          'studentId': studentId,
          'studentName': studentName,
          'classroomId': _selectedClassroom!.id,
          'sessionId': _sessionId,
          'date': dateKey,
          'status': status,
          'timestamp': FieldValue.serverTimestamp(),
          'entryAt': FieldValue.serverTimestamp(),
        });
      });

      _showResultModal(
        title: '✅ Registrado',
        message: '$studentName\n${status == 'present' ? 'Presente' : 'Tarde'}',
        color: Colors.green,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (e.toString().contains('YA_REGISTRADO')) {
        _showResultModal(
          title: 'Ya Registrado',
          message: '$studentName ya registró asistencia hoy',
          color: Colors.orange,
          icon: Icons.info,
        );
      } else {
        _showResultModal(
          title: 'Error',
          message: 'Error al procesar: ${e.toString()}',
          color: Colors.red,
          icon: Icons.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  /// Mostrar modal de resultado
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
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 48),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
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

  /// Mostrar SnackBar
  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Navegar a configuración de horarios
  void _navigateToScheduleConfig() {
    if (_selectedClassroom == null) return;

    // Navegar al detalle del aula donde puede configurar horarios
    Navigator.pushNamed(
      context,
      '/classroom-detail',
      arguments: _selectedClassroom,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundLight,
      appBar: AppBar(
        title: const Text('Tomar Asistencia'),
        backgroundColor: AppDesignSystem.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingClassrooms
          ? const Center(child: CircularProgressIndicator())
          : _classrooms.isEmpty
          ? _buildEmptyState()
          : SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_classrooms.length > 1) ...[
                      _buildClassroomSelector(isSmallScreen),
                      SizedBox(height: isSmallScreen ? 20 : 24),
                    ],
                    if (_selectedClassroom != null) ...[
                      _buildClassroomInfo(isSmallScreen),
                      SizedBox(height: isSmallScreen ? 20 : 24),
                      _buildScheduleStatus(isSmallScreen),
                      SizedBox(height: isSmallScreen ? 20 : 24),
                      _buildAttendanceSection(isSmallScreen),
                    ] else ...[
                      _buildSelectClassroomPrompt(isSmallScreen),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  /// Estado vacío (sin aulas)
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No tienes aulas asignadas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contacta al administrador para que te asigne aulas',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Selector de aula
  Widget _buildClassroomSelector(bool isSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.school,
                  color: AppDesignSystem.primaryColor,
                  size: isSmall ? 20 : 24,
                ),
                SizedBox(width: isSmall ? 8 : 12),
                Expanded(
                  child: Text(
                    'Selecciona el Aula',
                    style: TextStyle(
                      fontSize: isSmall ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: AppDesignSystem.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmall ? 12 : 16),
            DropdownButtonFormField<ClassroomModel>(
              value: _selectedClassroom,
              decoration: InputDecoration(
                hintText: 'Selecciona un aula',
                prefixIcon: const Icon(Icons.class_),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppDesignSystem.backgroundLight,
              ),
              items: _classrooms.map((classroom) {
                return DropdownMenuItem(
                  value: classroom,
                  child: Text(
                    classroom.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              }).toList(),
              onChanged: (classroom) {
                setState(() {
                  _selectedClassroom = classroom;
                  _attendanceActive = false;
                  _sessionId = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Información del aula seleccionada
  Widget _buildClassroomInfo(bool isSmall) {
    final classroom = _selectedClassroom!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 16 : 20),
        child: Row(
          children: [
            Container(
              width: isSmall ? 50 : 60,
              height: isSmall ? 50 : 60,
              decoration: BoxDecoration(
                color: AppDesignSystem.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  classroom.section.toUpperCase(),
                  style: TextStyle(
                    color: AppDesignSystem.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isSmall ? 18 : 24,
                  ),
                ),
              ),
            ),
            SizedBox(width: isSmall ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classroom.name,
                    style: TextStyle(
                      fontSize: isSmall ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${classroom.grade} - Sección ${classroom.section}',
                    style: TextStyle(
                      fontSize: isSmall ? 14 : 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.groups,
                        size: isSmall ? 14 : 16,
                        color: AppDesignSystem.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Capacidad: ${classroom.capacity}',
                        style: TextStyle(
                          fontSize: isSmall ? 12 : 14,
                          color: Colors.grey[600],
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
    );
  }

  /// Estado del horario
  Widget _buildScheduleStatus(bool isSmall) {
    final classroom = _selectedClassroom!;
    final now = DateTime.now();
    final schedule = _getScheduleFor(now, classroom);
    final hasSchedule = schedule != null;
    final isWithinTime = hasSchedule && _isWithinClassTime(now, schedule);
    final isAfterEnd = hasSchedule && _isAfterEndTime(now, schedule);

    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusMessage;

    if (!hasSchedule) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber;
      statusTitle = 'Sin Horario Configurado';
      statusMessage =
          'Configura un horario para este día antes de tomar asistencia';
    } else if (isAfterEnd) {
      statusColor = Colors.red;
      statusIcon = Icons.stop_circle;
      statusTitle = 'Clase Finalizada';
      statusMessage = 'La clase terminó a las ${schedule.endTime}';
    } else if (!isWithinTime) {
      statusColor = Colors.blue;
      statusIcon = Icons.schedule;
      statusTitle = 'Fuera de Horario';
      statusMessage =
          'La clase es de ${schedule.startTime} a ${schedule.endTime}';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusTitle = 'En Horario de Clase';
      statusMessage = 'Clase activa hasta las ${schedule.endTime}';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 16 : 20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: isSmall ? 32 : 40),
                SizedBox(width: isSmall ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: isSmall ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusMessage,
                        style: TextStyle(
                          fontSize: isSmall ? 14 : 16,
                          color: statusColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!hasSchedule) ...[
              SizedBox(height: isSmall ? 12 : 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _navigateToScheduleConfig,
                  icon: const Icon(Icons.settings),
                  label: const Text('Configurar Horarios'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: isSmall ? 12 : 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Sección de asistencia (escáner QR)
  Widget _buildAttendanceSection(bool isSmall) {
    final classroom = _selectedClassroom!;
    final now = DateTime.now();
    final schedule = _getScheduleFor(now, classroom);
    final canScan = schedule != null && _isWithinClassTime(now, schedule);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  color: AppDesignSystem.primaryColor,
                  size: isSmall ? 20 : 24,
                ),
                SizedBox(width: isSmall ? 8 : 12),
                Expanded(
                  child: Text(
                    'Escáner de Asistencia',
                    style: TextStyle(
                      fontSize: isSmall ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmall ? 16 : 20),
            if (!_attendanceActive) ...[
              ElevatedButton.icon(
                onPressed: canScan ? _startAttendanceSession : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Iniciar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isSmall ? 14 : 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
              if (!canScan) ...[
                SizedBox(height: isSmall ? 8 : 12),
                Text(
                  'Solo puedes tomar asistencia durante el horario de clase',
                  style: TextStyle(
                    fontSize: isSmall ? 12 : 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ] else ...[
              Container(
                height: MediaQuery.of(context).size.height * 0.35,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppDesignSystem.primaryColor,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: (capture) {
                          final List<Barcode> barcodes = capture.barcodes;
                          for (final barcode in barcodes) {
                            if (barcode.rawValue != null) {
                              final raw = barcode.rawValue!;
                              final now = DateTime.now();

                              // Evitar escaneos duplicados en menos de 1.5s
                              if (_lastScanAt != null && _lastScanRaw == raw) {
                                final diff = now
                                    .difference(_lastScanAt!)
                                    .inMilliseconds;
                                if (diff < 1500) {
                                  break;
                                }
                              }

                              _lastScanAt = now;
                              _lastScanRaw = raw;
                              _processQRCode(raw);
                              break;
                            }
                          }
                        },
                      ),
                      if (_isScanning)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      // Overlay con instrucciones
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Text(
                            'Apunta al código QR del estudiante',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isSmall ? 16 : 20),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('classrooms')
                    .doc(_selectedClassroom!.id)
                    .collection('attendance')
                    .where('sessionId', isEqualTo: _sessionId)
                    .orderBy('timestamp', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.hasData
                      ? snapshot.data!.docs.length
                      : 0;

                  return Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmall ? 12 : 16),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: AppDesignSystem.successColor,
                              size: isSmall ? 20 : 24,
                            ),
                            SizedBox(width: isSmall ? 8 : 12),
                            Text(
                              '$count ${count == 1 ? 'estudiante' : 'estudiantes'} registrados',
                              style: TextStyle(
                                fontSize: isSmall ? 14 : 16,
                                fontWeight: FontWeight.bold,
                                color: AppDesignSystem.successColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmall ? 12 : 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _stopAttendanceSession,
                          icon: const Icon(Icons.stop),
                          label: const Text('Finalizar Sesión'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmall ? 14 : 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Mensaje para seleccionar aula
  Widget _buildSelectClassroomPrompt(bool isSmall) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 24 : 32),
        child: Column(
          children: [
            Icon(
              Icons.arrow_upward,
              size: isSmall ? 48 : 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: isSmall ? 12 : 16),
            Text(
              'Selecciona un aula arriba',
              style: TextStyle(
                fontSize: isSmall ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: isSmall ? 8 : 12),
            Text(
              'Elige el aula para comenzar a tomar asistencia',
              style: TextStyle(
                fontSize: isSmall ? 14 : 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
