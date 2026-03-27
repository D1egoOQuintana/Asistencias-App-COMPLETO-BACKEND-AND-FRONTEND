import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../models/attendance_models.dart';
import '../../models/classroom_model.dart';
import '../../models/student_model.dart';
import '../../providers/attendance_provider.dart';
import '../../services/attendance_repository.dart';

/// Pantalla de registro por QR en tiempo real
/// Integra con AttendanceProvider para actualizar la lista inmediatamente
class QRAttendanceRealtimeScreen extends StatelessWidget {
  final String? classroomId;

  const QRAttendanceRealtimeScreen({super.key, this.classroomId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AttendanceProvider(AttendanceRepository()),
      child: _QRAttendanceRealtimeView(initialClassroomId: classroomId),
    );
  }
}

class _QRAttendanceRealtimeView extends StatefulWidget {
  final String? initialClassroomId;

  const _QRAttendanceRealtimeView({required this.initialClassroomId});

  @override
  State<_QRAttendanceRealtimeView> createState() =>
      _QRAttendanceRealtimeViewState();
}

class _QRAttendanceRealtimeViewState extends State<_QRAttendanceRealtimeView>
    with SingleTickerProviderStateMixin {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  late final MobileScannerController _scannerController;
  late final AnimationController _scanLineController;

  List<ClassroomModel> _classrooms = [];
  String? _selectedClassroomId;
  bool _isLoadingClassrooms = true;
  bool _isProcessingScan = false;
  bool _isTorchEnabled = false;
  String _lastScanMessage = 'Listo para escanear';
  Color _lastScanColor = const Color(0xFF4FC3F7);
  DateTime? _lastScanAt;
  String? _lastScanRaw;
  _ScannedStudentCardData? _lastScannedStudent;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
    );
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _loadClassrooms();
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _loadClassrooms() async {
    if (_currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingClassrooms = false;
        _lastScanMessage = 'No hay sesión activa.';
        _lastScanColor = Colors.red;
      });
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classrooms')
          .where('teacherUid', isEqualTo: _currentUser.uid)
          .where('isActive', isEqualTo: true)
          .get();

      final classrooms = snapshot.docs
          .map((doc) => ClassroomModel.fromFirestore(doc))
          .toList();

      String? selected;
      if (widget.initialClassroomId != null &&
          classrooms.any((c) => c.id == widget.initialClassroomId)) {
        selected = widget.initialClassroomId;
      } else if (classrooms.isNotEmpty) {
        selected = classrooms.first.id;
      }

      if (!mounted) return;
      setState(() {
        _classrooms = classrooms;
        _selectedClassroomId = selected;
        _isLoadingClassrooms = false;
        _lastScannedStudent = null;
        if (classrooms.isEmpty) {
          _lastScanMessage = 'No tienes aulas activas para escanear.';
          _lastScanColor = Colors.orange;
        }
      });

      if (selected != null) {
        context.read<AttendanceProvider>().configure(
          classroomId: selected,
          day: DateTime.now(),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingClassrooms = false;
        _lastScanMessage = 'Error al cargar aulas: $e';
        _lastScanColor = Colors.red;
      });
    }
  }

  String _classroomLabelById(String? classroomId) {
    if (classroomId == null) return 'Sin aula';
    ClassroomModel? classroom;
    for (final room in _classrooms) {
      if (room.id == classroomId) {
        classroom = room;
        break;
      }
    }
    if (classroom == null) return 'Aula no encontrada';
    return '${classroom.grade} ${classroom.section} - ${classroom.name}';
  }

  Future<StudentModel?> _findStudentProfile({
    String? studentId,
    String? dni,
  }) async {
    StudentModel? student;

    if (studentId != null && studentId.trim().isNotEmpty) {
      final byId = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId.trim())
          .get();
      if (byId.exists) {
        student = StudentModel.fromFirestore(byId);
      }
    }

    if (student == null && dni != null && dni.trim().isNotEmpty) {
      final byDni = await FirebaseFirestore.instance
          .collection('students')
          .where('dni', isEqualTo: dni.trim())
          .limit(1)
          .get();
      if (byDni.docs.isNotEmpty) {
        student = StudentModel.fromFirestore(byDni.docs.first);
      }
    }

    return student;
  }

  String _statusText(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.presente:
        return 'PRESENTE';
      case AttendanceStatus.tarde:
        return 'TARDE';
      case AttendanceStatus.ausente:
        return 'AUSENTE';
    }
  }

  String _timeLabel(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    final s = date.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  _ParsedScanData _extractScanData(String raw) {
    String? studentId;
    String? studentName;
    String? dni;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        if (decoded['type'] != null && decoded['type'] != 'student') {
          throw Exception('QR no corresponde a estudiante');
        }
        studentId =
            (decoded['id'] ?? decoded['studentId'] ?? '').toString().trim();
        studentName =
            (decoded['name'] ?? decoded['studentName'] ?? '').toString().trim();
        dni = (decoded['dni'] ?? '').toString().trim();
      }
    } catch (_) {
      studentId = raw.trim();
    }

    studentId = studentId?.trim();
    studentName = studentName?.trim();
    dni = dni?.trim();

    if (studentId == null || studentId.isEmpty) {
      throw Exception('Código QR inválido');
    }

    return _ParsedScanData(
      studentId: studentId,
      studentName: studentName,
      dni: dni,
    );
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    if (!mounted) return;
    setState(() => _isTorchEnabled = !_isTorchEnabled);
  }

  Future<void> _processScan(String raw) async {
    if (_selectedClassroomId == null || _isProcessingScan) return;

    final now = DateTime.now();
    if (_lastScanAt != null && _lastScanRaw == raw) {
      final diff = now.difference(_lastScanAt!).inMilliseconds;
      if (diff < 1200) return;
    }

    _lastScanAt = now;
    _lastScanRaw = raw;

    setState(() {
      _isProcessingScan = true;
      _lastScanMessage = 'Procesando QR...';
      _lastScanColor = const Color(0xFF4FC3F7);
    });

    try {
      final parsed = _extractScanData(raw);
      final student = await _findStudentProfile(
        studentId: parsed.studentId,
        dni: parsed.dni,
      );
      final studentId = student?.id ?? parsed.studentId;
      final studentName =
          (parsed.studentName?.isNotEmpty ?? false)
          ? parsed.studentName!
          : (student?.fullName.isNotEmpty ?? false)
          ? student!.fullName
          : 'Estudiante';

      final status = AttendanceStatus.presente;

      if (!mounted) return;

      await context.read<AttendanceProvider>().markAttendance(
        studentId: studentId.trim(),
        status: status,
        studentName: studentName,
      );

      if (!mounted) return;
      setState(() {
        _lastScanMessage = 'Registrado: $studentName';
        _lastScanColor = const Color(0xFF35D38A);
        _lastScannedStudent = _ScannedStudentCardData(
          fullName: studentName,
          studentId: studentId,
          dni: student?.dni ?? parsed.dni ?? 'No disponible',
          parentEmail: student?.parentEmail ?? 'No registrado',
          parentPhone: student?.parentPhone ?? 'No registrado',
          classroomLabel: _classroomLabelById(_selectedClassroomId),
          scannedAt: now,
          statusLabel: _statusText(status),
          success: true,
          message: 'Asistencia registrada correctamente',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastScanMessage = 'Error: $e';
        _lastScanColor = Colors.red;
        _lastScannedStudent = _ScannedStudentCardData(
          fullName: 'Estudiante no identificado',
          studentId: '-',
          dni: '-',
          parentEmail: '-',
          parentPhone: '-',
          classroomLabel: _classroomLabelById(_selectedClassroomId),
          scannedAt: now,
          statusLabel: 'ERROR',
          success: false,
          message: e.toString(),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingScan = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final lastStudent = _lastScannedStudent;
    final selectedClassroomLabel = _classroomLabelById(_selectedClassroomId);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw == null || raw.isEmpty) continue;
                  _processScan(raw);
                  return;
                }
              },
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF030915).withValues(alpha: 0.45),
                    const Color(0xFF030915).withValues(alpha: 0.2),
                    const Color(0xFF030915).withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                              ),
                            ),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Escáner QR',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Cámara activa en tiempo real',
                                    style: TextStyle(
                                      color: Color(0xFFD6E7FF),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_isLoadingClassrooms)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            else
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  onPressed: _toggleTorch,
                                  icon: Icon(
                                    _isTorchEnabled
                                        ? Icons.flash_on_rounded
                                        : Icons.flash_off_rounded,
                                    color: _isTorchEnabled
                                        ? const Color(0xFFFFD447)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_classrooms.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedClassroomId,
                              isExpanded: true,
                              iconEnabledColor: Colors.white,
                              dropdownColor: const Color(0xFF102038),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                              hint: const Text(
                                'Selecciona un aula',
                                style: TextStyle(color: Colors.white70),
                              ),
                              items: _classrooms
                                  .where((c) => c.id != null)
                                  .map(
                                    (c) => DropdownMenuItem<String>(
                                      value: c.id,
                                      child: Text(
                                        '${c.grade} ${c.section} - ${c.name}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedClassroomId = value;
                                  _lastScannedStudent = null;
                                  _lastScanMessage =
                                      'Aula cambiada. Listo para escanear';
                                  _lastScanColor = const Color(0xFF4FC3F7);
                                });
                                context.read<AttendanceProvider>().configure(
                                  classroomId: value,
                                  day: DateTime.now(),
                                );
                              },
                            ),
                          ),
                        ),
                      const Spacer(),
                      IgnorePointer(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final lineTravel = constraints.maxHeight - 24;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(22),
                                      color: Colors.white.withValues(alpha: 0.04),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                  _buildCorner(
                                    alignment: Alignment.topLeft,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                    ),
                                  ),
                                  _buildCorner(
                                    alignment: Alignment.topRight,
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(20),
                                    ),
                                    mirrorX: true,
                                  ),
                                  _buildCorner(
                                    alignment: Alignment.bottomLeft,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(20),
                                    ),
                                    mirrorY: true,
                                  ),
                                  _buildCorner(
                                    alignment: Alignment.bottomRight,
                                    borderRadius: const BorderRadius.only(
                                      bottomRight: Radius.circular(20),
                                    ),
                                    mirrorX: true,
                                    mirrorY: true,
                                  ),
                                  AnimatedBuilder(
                                    animation: _scanLineController,
                                    builder: (context, child) {
                                      return Positioned(
                                        top: 12 +
                                            (lineTravel * _scanLineController.value),
                                        left: 20,
                                        right: 20,
                                        child: Container(
                                          height: 2,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            gradient: const LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                Color(0xFF4FC3F7),
                                                Color(0xFF67FFC4),
                                                Colors.transparent,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFF67FFC4,
                                                ).withValues(alpha: 0.5),
                                                blurRadius: 12,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 200),
                    ],
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF09162B).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _lastScanColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _lastScanColor.withValues(alpha: 0.6),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _lastScanMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Registros: ${provider.entries.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (lastStudent != null)
                          _buildStudentCard(lastStudent)
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                            child: const Text(
                              'Escanea un código QR para mostrar la tarjeta del estudiante en tiempo real.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          'Aula actual: $selectedClassroomLabel',
                          style: const TextStyle(
                            color: Color(0xFFD6E7FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (provider.isCheckingDuplicate)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (provider.hasDuplicate)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Ya existen registros hoy para este aula.',
                              style: TextStyle(
                                color: Color(0xFFFFCE6B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessingScan)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.22),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCorner({
    required Alignment alignment,
    required BorderRadius borderRadius,
    bool mirrorX = false,
    bool mirrorY = false,
  }) {
    return Align(
      alignment: alignment,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          mirrorX ? -1.0 : 1.0,
          mirrorY ? -1.0 : 1.0,
          1.0,
        ),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: const Border(
              top: BorderSide(color: Color(0xFF4FC3F7), width: 4),
              left: BorderSide(color: Color(0xFF4FC3F7), width: 4),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x884FC3F7),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(_ScannedStudentCardData data) {
    final statusBg = data.success
        ? const Color(0xFF35D38A).withValues(alpha: 0.2)
        : const Color(0xFFFF6B6B).withValues(alpha: 0.2);
    final statusTextColor = data.success
        ? const Color(0xFF8FF4BE)
        : const Color(0xFFFFB1B1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF1D2E4A),
                child: Text(
                  data.fullName.isNotEmpty ? data.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${data.studentId}  •  DNI: ${data.dni}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFD6E7FF),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  data.statusLabel,
                  style: TextStyle(
                    color: statusTextColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoPill(Icons.meeting_room_outlined, data.classroomLabel),
              _buildInfoPill(Icons.schedule, _timeLabel(data.scannedAt)),
              _buildInfoPill(Icons.email_outlined, data.parentEmail),
              _buildInfoPill(Icons.call_outlined, data.parentPhone),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(IconData icon, String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 290),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFB9D8FF), size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFFE8F4FF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedScanData {
  final String studentId;
  final String? studentName;
  final String? dni;

  const _ParsedScanData({
    required this.studentId,
    this.studentName,
    this.dni,
  });
}

class _ScannedStudentCardData {
  final String fullName;
  final String studentId;
  final String dni;
  final String parentEmail;
  final String parentPhone;
  final String classroomLabel;
  final DateTime scannedAt;
  final String statusLabel;
  final bool success;
  final String message;

  const _ScannedStudentCardData({
    required this.fullName,
    required this.studentId,
    required this.dni,
    required this.parentEmail,
    required this.parentPhone,
    required this.classroomLabel,
    required this.scannedAt,
    required this.statusLabel,
    required this.success,
    required this.message,
  });
}
