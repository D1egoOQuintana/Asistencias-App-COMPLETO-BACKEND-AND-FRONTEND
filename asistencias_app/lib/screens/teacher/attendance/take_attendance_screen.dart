import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/attendance_model.dart';
import '../../../models/student_model.dart';
import '../../../models/classroom_model.dart';
import '../../../services/attendance_service.dart';
import '../../../services/classroom_service.dart';

class TakeAttendanceScreen extends StatefulWidget {
  const TakeAttendanceScreen({super.key});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  String? _selectedClassroomId;
  DateTime _selectedDate = DateTime.now();
  List<StudentModel> _students = [];
  Map<String, AttendanceModel> _todayAttendances = {};
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Si es docente, buscar su salón asignado
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final classroomsQuery = await FirebaseFirestore.instance
            .collection('classrooms')
            .where('teacherUid', isEqualTo: user.uid)
            .where('isActive', isEqualTo: true)
            .get();

        if (classroomsQuery.docs.isNotEmpty) {
          _selectedClassroomId = classroomsQuery.docs.first.id;
          await _loadStudentsAndAttendance();
        }
      } catch (e) {
        if (mounted) {
          print('Error loading initial data: $e');
        }
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadStudentsAndAttendance() async {
    if (_selectedClassroomId == null || !mounted) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Cargar estudiantes del salón
      final studentsQuery = await FirebaseFirestore.instance
          .collection('students')
          .where('classroomId', isEqualTo: _selectedClassroomId)
          .where('isActive', isEqualTo: true)
          .get();

      _students = studentsQuery.docs
          .map((doc) => StudentModel.fromFirestore(doc))
          .toList();

      // Cargar asistencias del día seleccionado
      await _loadTodayAttendances();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error al cargar datos: $e', isError: true);
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadTodayAttendances() async {
    if (_selectedClassroomId == null || !mounted) return;

    try {
      final dayStart = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final dayEnd = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        23,
        59,
        59,
      );

      final attendanceQuery = await FirebaseFirestore.instance
          .collection('attendance')
          .where('classroomId', isEqualTo: _selectedClassroomId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(dayEnd))
          .get();

      _todayAttendances.clear();
      for (final doc in attendanceQuery.docs) {
        final attendance = AttendanceModel.fromFirestore(doc);
        _todayAttendances[attendance.studentId] = attendance;
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        print('Error loading today attendances: $e');
      }
    }
  }

  Future<void> _recordAttendance(
    String studentId,
    AttendanceStatus status,
  ) async {
    try {
      final result = await AttendanceService.recordAttendance(
        studentId: studentId,
        status: status,
        notes: 'Registrado manualmente',
      );

      if (result['success']) {
        final attendance = result['attendance'] as AttendanceModel;
        if (mounted) {
          setState(() {
            _todayAttendances[studentId] = attendance;
          });
          _showSnackBar('Asistencia registrada: ${status.displayName}');
        }
      } else {
        if (mounted) {
          _showSnackBar(result['message'], isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Future<void> _markAllAbsent() async {
    if (_selectedClassroomId == null || !mounted) return;

    final confirm = await _showConfirmDialog(
      'Marcar Ausentes',
      '¿Marcar como ausentes a todos los estudiantes sin registro?',
    );

    if (!confirm || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final result = await AttendanceService.markAbsentStudents(
        classroomId: _selectedClassroomId!,
        date: _selectedDate,
      );

      if (mounted) {
        if (result['success']) {
          _showSnackBar(result['message']);
          await _loadTodayAttendances();
        } else {
          _showSnackBar(result['message'], isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: $e', isError: true);
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Tomar Asistencia'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_students.isNotEmpty)
            IconButton(
              onPressed: _isSaving ? null : _markAllAbsent,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.assignment_late),
              tooltip: 'Marcar ausentes automáticamente',
            ),
        ],
      ),
      body: Column(
        children: [
          // Panel de control superior
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Selector de salón y fecha
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: ClassroomService.getAvailableClassrooms(
                          FirebaseAuth.instance.currentUser?.uid ?? '',
                        ),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }

                          final classrooms = snapshot.data!.docs;
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedClassroomId,
                            decoration: const InputDecoration(
                              labelText: 'Salón',
                              border: OutlineInputBorder(),
                            ),
                            items: classrooms.map((doc) {
                              final classroom = ClassroomModel.fromFirestore(
                                doc,
                              );
                              return DropdownMenuItem(
                                value: doc.id,
                                child: Text(
                                  '${classroom.grade} - ${classroom.section}',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              setState(() => _selectedClassroomId = value);
                              if (value != null) {
                                await _loadStudentsAndAttendance();
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 30),
                            ),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _selectedDate = date);
                            await _loadTodayAttendances();
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Estadísticas rápidas
                if (_students.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildQuickStats(),
                ],
              ],
            ),
          ),

          // Lista de estudiantes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _students.isEmpty
                ? const Center(
                    child: Text('Selecciona un salón para ver los estudiantes'),
                  )
                : _buildStudentsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final presentCount = _todayAttendances.values
        .where((a) => a.status == AttendanceStatus.present)
        .length;
    final absentCount = _todayAttendances.values
        .where((a) => a.status == AttendanceStatus.absent)
        .length;
    final lateCount = _todayAttendances.values
        .where((a) => a.status == AttendanceStatus.late)
        .length;
    final noRecord = _students.length - _todayAttendances.length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total',
            _students.length.toString(),
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Presentes',
            presentCount.toString(),
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard('Ausentes', absentCount.toString(), Colors.red),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Tardanzas',
            lateCount.toString(),
            Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Sin registro',
            noRecord.toString(),
            Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        final attendance = _todayAttendances[student.id];

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Info del estudiante
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      if (attendance != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: _getStatusColor(attendance.status),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              attendance.status.displayName,
                              style: TextStyle(
                                color: _getStatusColor(attendance.status),
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${attendance.recordedAt.hour}:${attendance.recordedAt.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Botones de asistencia
                if (attendance == null) ...[
                  _buildAttendanceButton(
                    Icons.check,
                    Colors.green,
                    'Presente',
                    () => _recordAttendance(
                      student.id!,
                      AttendanceStatus.present,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildAttendanceButton(
                    Icons.schedule,
                    Colors.orange,
                    'Tardanza',
                    () => _recordAttendance(student.id!, AttendanceStatus.late),
                  ),
                  const SizedBox(width: 8),
                  _buildAttendanceButton(
                    Icons.close,
                    Colors.red,
                    'Ausente',
                    () =>
                        _recordAttendance(student.id!, AttendanceStatus.absent),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        attendance.status,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getStatusColor(
                          attendance.status,
                        ).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      'Registrado',
                      style: TextStyle(
                        color: _getStatusColor(attendance.status),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceButton(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return Colors.green;
      case AttendanceStatus.absent:
        return Colors.red;
      case AttendanceStatus.late:
        return Colors.orange;
      case AttendanceStatus.justified:
        return Colors.blue;
    }
  }
}
