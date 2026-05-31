import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import '../../../models/classroom_model.dart';
import '../../../services/firestore_service.dart';

class AttendanceSessionScreen extends StatefulWidget {
  final ClassroomModel classroom;

  const AttendanceSessionScreen({super.key, required this.classroom});

  @override
  State<AttendanceSessionScreen> createState() =>
      _AttendanceSessionScreenState();
}

class _AttendanceSessionScreenState extends State<AttendanceSessionScreen> {
  late MobileScannerController _scannerController;
  bool _isSessionActive = true;
  bool _isScanning = false;
  String? _sessionId;
  List<Map<String, dynamic>> _attendanceList = [];

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _createAttendanceSession();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _createAttendanceSession() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final classroomId = widget.classroom.id;
      if (classroomId == null) {
        print('Error: ID del aula no válido');
        return;
      }

      final sessionDoc = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .add({
            'classroomId': classroomId,
            'teacherUid': currentUser.uid,
            'startTime': FieldValue.serverTimestamp(),
            'endTime': null,
            'isActive': true,
            'attendanceCount': 0,
            'date': DateTime.now().toIso8601String().split('T')[0],
          });

      if (mounted) {
        setState(() {
          _sessionId = sessionDoc.id;
        });
      }

      // Debug info (comentado para producción)
      // print('Session created with ID: $_sessionId');
      _listenToAttendance();
    } catch (e) {
      // print('Error creating session: $e');
    }
  }

  void _listenToAttendance() {
    if (_sessionId == null) {
      // print('Session ID is null, cannot listen to attendance');
      return;
    }

    // print('Starting to listen to attendance for session: $_sessionId');

    FirebaseFirestore.instance
      .collection('classrooms')
      .doc(widget.classroom.id)
      .collection('attendance')
        .where('sessionId', isEqualTo: _sessionId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
          // print('Received ${snapshot.docs.length} attendance records');
          if (mounted) {
            setState(() {
              _attendanceList = snapshot.docs.map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'studentName': data['studentName'] ?? 'Desconocido',
                  'timestamp': data['timestamp'] as Timestamp,
                  'status': data['status'] ?? 'present',
                };
              }).toList();
            });
          }
        });
  }

  Future<void> _processQRCode(String qrData) async {
    if (!_isSessionActive || _isScanning) return;

    if (mounted) {
      setState(() {
        _isScanning = true;
      });
    }

    // Declarar variables en scope más amplio para acceso en catch
    dynamic data;
    String studentName = 'Estudiante';

    try {
      // Validar que qrData no esté vacío
      if (qrData.isEmpty) {
        _showMessage('QR vacío o inválido', isError: true);
        return;
      }

      // Intentar decodificar JSON
      try {
        data = jsonDecode(qrData);
      } catch (e) {
        _showMessage('QR inválido: No es un código JSON válido', isError: true);
        return;
      }

      // Validar que sea un Map
      if (data is! Map<String, dynamic>) {
        _showMessage('QR inválido: Formato incorrecto', isError: true);
        return;
      }

      // Validar que tenga el campo type
      if (!data.containsKey('type') || data['type'] != 'student') {
        _showMessage(
          'QR inválido: No es un código de estudiante',
          isError: true,
        );
        return;
      }

      // Validar campos requeridos
      if (!data.containsKey('id') || !data.containsKey('name')) {
        _showMessage('QR inválido: Datos incompletos', isError: true);
        return;
      }

      final studentId = data['id'].toString();
      studentName = data['name'].toString(); // Asignar a variable de scope amplio

      // Verificar si ya registró asistencia HOY usando FirestoreService
      final classroomId = widget.classroom.id;
      if (classroomId == null) {
        _showMessage('Error: ID del aula no válido', isError: true);
        return;
      }

      final hasAttendanceToday = await FirestoreService.hasAttendanceToday(
        studentId,
        classroomId,
      );

      if (hasAttendanceToday) {
        _showMessage('$studentName ya registró su asistencia hoy', isError: true);
        return;
      }

      // Registrar asistencia con ID determinista para evitar duplicados
    final now = DateTime.now();
    final dayKey =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final attendanceId = '${studentId}_$dayKey';

      // Pre-chequeo: evitar duplicar si ya existe un registro para hoy con ID aleatorio
      final legacyExisting = await FirebaseFirestore.instance
          .collection('classrooms')
          .doc(classroomId)
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: dayKey)
          .limit(1)
          .get();
      if (legacyExisting.docs.isNotEmpty) {
        throw Exception('Ya registrado hoy');
      }

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final attendanceRef = FirebaseFirestore.instance
          .collection('classrooms')
          .doc(classroomId)
          .collection('attendance')
            .doc(attendanceId);

        final existing = await transaction.get(attendanceRef);
        if (existing.exists) {
          throw Exception('Ya registrado hoy');
        }

        transaction.set(attendanceRef, {
          'studentId': studentId,
          'classroomId': classroomId,
          'timestamp': FieldValue.serverTimestamp(),
          'date': dayKey,
          'status': 'present',
          'sessionId': _sessionId,
          'studentName': studentName,
          'entryAt': FieldValue.serverTimestamp(),
        });
      });

      _showMessage('✅ $studentName registrado exitosamente', isError: false);
    } on Exception catch (e) {
      if (e.toString().contains('Ya registrado hoy')) {
        _showMessage('$studentName ya registró asistencia hoy', isError: true);
      } else {
        _showMessage('Error al procesar QR: $e', isError: true);
      }
    } catch (e) {
      _showMessage('Error al procesar QR: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _endSession() async {
    if (_sessionId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .doc(_sessionId)
          .update({
            'endTime': FieldValue.serverTimestamp(),
            'isActive': false,
            'attendanceCount': _attendanceList.length,
          });

      if (mounted) {
        setState(() {
          _isSessionActive = false;
        });
      }

      _showMessage('Sesión de asistencia finalizada', isError: false);

      // Volver a la pantalla anterior después de 2 segundos
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      _showMessage('Error al finalizar sesión: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Asistencia - ${widget.classroom.name}'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_isSessionActive)
            IconButton(
              onPressed: _endSession,
              icon: const Icon(Icons.stop),
              tooltip: 'Finalizar Sesión',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Estado de la sesión
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _isSessionActive
                  ? Colors.green.shade100
                  : Colors.red.shade100,
              child: Row(
                children: [
                  Icon(
                    _isSessionActive
                        ? Icons.radio_button_checked
                        : Icons.stop_circle,
                    color: _isSessionActive
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isSessionActive
                          ? 'Sesión Activa - Escaneando códigos QR'
                          : 'Sesión Finalizada',
                      style: TextStyle(
                        color: _isSessionActive
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _isSessionActive
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_attendanceList.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Contenido principal con scroll
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Escáner QR
                    if (_isSessionActive) ...[
                      Container(
                        height: MediaQuery.of(context).size.height * 0.35,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.shade300,
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
                                  final List<Barcode> barcodes =
                                      capture.barcodes;
                                  for (final barcode in barcodes) {
                                    if (barcode.rawValue != null) {
                                      _processQRCode(barcode.rawValue!);
                                      break;
                                    }
                                  }
                                },
                              ),

                              // Overlay con instrucciones
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.center,
                                    colors: [
                                      Colors.black.withOpacity(0.7),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text(
                                    'Apunta la cámara al código QR del estudiante',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),

                              // Indicador de escaneando
                              if (_isScanning)
                                Container(
                                  color: Colors.black.withOpacity(0.5),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'Procesando QR...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Lista de asistencia
                    Container(
                      height: MediaQuery.of(context).size.height * 0.35,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade700,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Estudiantes Registrados (${_attendanceList.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),

                          Expanded(
                            child: _attendanceList.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.people,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'No hay estudiantes registrados aún',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(8),
                                    itemCount: _attendanceList.length,
                                    itemBuilder: (context, index) {
                                      final attendance = _attendanceList[index];
                                      final timestamp =
                                          attendance['timestamp'] as Timestamp;
                                      final time = timestamp.toDate();

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor:
                                                  Colors.green.shade100,
                                              child: Text(
                                                attendance['studentName'][0]
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                attendance['studentName'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green.shade700,
                                              size: 14,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Botón finalizar sesión
            if (_isSessionActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: _endSession,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Finalizar Sesión'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
