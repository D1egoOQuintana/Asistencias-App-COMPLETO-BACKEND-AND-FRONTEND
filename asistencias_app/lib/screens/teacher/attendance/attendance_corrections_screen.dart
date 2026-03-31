import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/attendance_models.dart';

class AttendanceCorrectionsScreen extends StatefulWidget {
  final String classroomId;
  final String classroomLabel;

  const AttendanceCorrectionsScreen({
    super.key,
    required this.classroomId,
    required this.classroomLabel,
  });

  @override
  State<AttendanceCorrectionsScreen> createState() =>
      _AttendanceCorrectionsScreenState();
}

class _AttendanceCorrectionsScreenState extends State<AttendanceCorrectionsScreen> {
  final Set<String> _busyIds = <String>{};
  DateTime _selectedDay = DateTime.now();

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatShortDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '--:--';
    final d = ts.toDate();
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Query<Map<String, dynamic>> _queryForSelectedDay() {
    return FirebaseFirestore.instance
      .collection('attendance')
      .where('classroomId', isEqualTo: widget.classroomId)
        .where('date', isEqualTo: _dateKey(_selectedDay));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDay = picked;
    });
  }

  Future<void> _updateStatus({
    required DocumentReference<Map<String, dynamic>> ref,
    required String docId,
    required AttendanceStatus status,
  }) async {
    setState(() => _busyIds.add(docId));
    try {
      await ref.set({
        'status': statusToString(status),
        'updatedAt': FieldValue.serverTimestamp(),
        'editedFrom': 'attendance_corrections_screen',
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado actualizado correctamente.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el estado.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(docId));
      }
    }
  }

  Future<void> _toggleExit({
    required DocumentReference<Map<String, dynamic>> ref,
    required String docId,
    required bool hasExit,
  }) async {
    setState(() => _busyIds.add(docId));
    try {
      if (hasExit) {
        await ref.set({
          'exitAt': FieldValue.delete(),
          'exitSource': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
          'editedFrom': 'attendance_corrections_screen',
        }, SetOptions(merge: true));
      } else {
        await ref.set({
          'exitAt': FieldValue.serverTimestamp(),
          'exitSource': 'manual_correction',
          'timestamp': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'editedFrom': 'attendance_corrections_screen',
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasExit ? 'Salida removida para correccion.' : 'Salida registrada manualmente.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar la salida.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(docId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0E2340),
        title: const Text(
          'Correccion de asistencias',
          style: TextStyle(fontWeight: FontWeight.w800, fontFamily: 'Manrope'),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2747), Color(0xFF1F4E84)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.classroomLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Manrope',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fecha: ${_formatShortDate(_selectedDay)}',
                        style: const TextStyle(
                          color: Color(0xFFD9E9FF),
                          fontFamily: 'WorkSans',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickDate,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded, size: 18),
                      label: const Text('Cambiar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _queryForSelectedDay().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'No se pudo cargar la asistencia del dia.',
                      style: TextStyle(fontFamily: 'WorkSans'),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                docs.sort((a, b) {
                  final ta = (a.data()['timestamp'] as Timestamp?)?.toDate();
                  final tb = (b.data()['timestamp'] as Timestamp?)?.toDate();
                  if (ta == null && tb == null) return 0;
                  if (ta == null) return 1;
                  if (tb == null) return -1;
                  return tb.compareTo(ta);
                });

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No hay registros para esta fecha.\nEscanea QR primero y luego corrige aqui si hace falta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF4E5B73),
                          fontFamily: 'WorkSans',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final studentName = (data['studentName'] ?? '').toString();
                    final studentId = (data['studentId'] ?? doc.id).toString();
                    final status = statusFromString(
                      (data['status'] ?? 'presente').toString(),
                    );
                    final hasExit = data['exitAt'] != null;
                    final isBusy = _busyIds.contains(doc.id);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDCE7F7)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFE8F1FF),
                                child: Text(
                                  (studentName.isNotEmpty ? studentName : studentId)[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF1D4F87),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      studentName.isNotEmpty
                                          ? studentName
                                          : 'Estudiante sin nombre',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Manrope',
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF10233E),
                                      ),
                                    ),
                                    Text(
                                      'ID: $studentId',
                                      style: const TextStyle(
                                        fontFamily: 'WorkSans',
                                        color: Color(0xFF4E5B73),
                                        fontWeight: FontWeight.w600,
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
                                  color: const Color(0xFFF0F6FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Entrada ${_formatTime(data['entryAt'] as Timestamp?)}',
                                  style: const TextStyle(
                                    fontFamily: 'WorkSans',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2B4770),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Text('Presente'),
                                selected: status == AttendanceStatus.presente,
                                onSelected: isBusy
                                    ? null
                                    : (_) => _updateStatus(
                                          ref: doc.reference,
                                          docId: doc.id,
                                          status: AttendanceStatus.presente,
                                        ),
                              ),
                              ChoiceChip(
                                label: const Text('Tarde'),
                                selected: status == AttendanceStatus.tarde,
                                onSelected: isBusy
                                    ? null
                                    : (_) => _updateStatus(
                                          ref: doc.reference,
                                          docId: doc.id,
                                          status: AttendanceStatus.tarde,
                                        ),
                              ),
                              ChoiceChip(
                                label: const Text('Ausente'),
                                selected: status == AttendanceStatus.ausente,
                                onSelected: isBusy
                                    ? null
                                    : (_) => _updateStatus(
                                          ref: doc.reference,
                                          docId: doc.id,
                                          status: AttendanceStatus.ausente,
                                        ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  hasExit
                                      ? 'Salida: ${_formatTime(data['exitAt'] as Timestamp?)}'
                                      : 'Salida pendiente',
                                  style: TextStyle(
                                    fontFamily: 'WorkSans',
                                    fontWeight: FontWeight.w700,
                                    color: hasExit
                                        ? const Color(0xFF1E6E50)
                                        : const Color(0xFF8A5C22),
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: isBusy
                                    ? null
                                    : () => _toggleExit(
                                          ref: doc.reference,
                                          docId: doc.id,
                                          hasExit: hasExit,
                                        ),
                                icon: Icon(
                                  hasExit
                                      ? Icons.remove_circle_outline_rounded
                                      : Icons.logout_rounded,
                                ),
                                label: Text(
                                  hasExit ? 'Quitar salida' : 'Registrar salida',
                                ),
                              ),
                            ],
                          ),
                          if (isBusy)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
