import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../models/attendance_models.dart';
import 'absentees_notifier_sheet.dart';

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

class _AttendanceCorrectionsScreenState
    extends State<AttendanceCorrectionsScreen> {
  // Paleta alineada al resto de la app (students/reports).
  static const Color _brandBlue = Color(0xFF1976D2);
  static const Color _ink = Color(0xFF000D33);
  static const Color _muted = Color(0xFF556474);
  static const Color _border = Color(0xFFE1E3E4);

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
      .collection('classrooms')
      .doc(widget.classroomId)
      .collection('attendance');
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _matchesSelectedDay(Map<String, dynamic> data) {
    final selected = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );

    final dateField = data['date'];
    if (dateField is String && dateField == _dateKey(selected)) {
      return true;
    }
    if (dateField is Timestamp && _isSameDay(dateField.toDate().toLocal(), selected)) {
      return true;
    }
    if (dateField is DateTime && _isSameDay(dateField.toLocal(), selected)) {
      return true;
    }

    final entryAt = data['entryAt'];
    if (entryAt is Timestamp && _isSameDay(entryAt.toDate().toLocal(), selected)) {
      return true;
    }

    final timestamp = data['timestamp'];
    if (timestamp is Timestamp && _isSameDay(timestamp.toDate().toLocal(), selected)) {
      return true;
    }

    return false;
  }

  void _openAbsenteesNotifier() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AbsenteesNotifierSheet(
        classroomId: widget.classroomId,
        classroomLabel: widget.classroomLabel,
        day: _selectedDay,
      ),
    );
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
            hasExit
                ? 'Salida removida para corrección.'
                : 'Salida registrada manualmente.',
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

  Widget _statusChip({
    required String label,
    required AttendanceStatus target,
    required AttendanceStatus current,
    required DocumentReference<Map<String, dynamic>> ref,
    required String docId,
    required bool isBusy,
  }) {
    final selected = current == target;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: _brandBlue,
      backgroundColor: const Color(0xFFF0F4FF),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _ink,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: selected ? _brandBlue : _border),
      onSelected: isBusy
          ? null
          : (_) => _updateStatus(ref: ref, docId: docId, status: target),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _brandBlue,
        title: const Text(
          'Corrección de asistencias',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Notificar ausentes',
            color: _brandBlue,
            onPressed: _openAbsenteesNotifier,
            icon: const Icon(Icons.notifications_active_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000D33),
                  blurRadius: 12,
                  offset: Offset(0, 4),
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
                    color: _brandBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Fecha: ${_formatShortDate(_selectedDay)}',
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickDate,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: _brandBlue,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
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
                    child: Text('No se pudo cargar la asistencia del día.'),
                  );
                }

                final docs = (snapshot.data?.docs ?? [])
                  .where((doc) => _matchesSelectedDay(doc.data()))
                  .toList();

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
                        'No hay registros para esta fecha.\nEscanea QR primero y luego corrige aquí si hace falta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
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
                        border: Border.all(color: _border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F000D33),
                            blurRadius: 10,
                            offset: Offset(0, 3),
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
                                backgroundColor: const Color(0xFFD4E4F6),
                                child: Text(
                                  (studentName.isNotEmpty
                                          ? studentName
                                          : studentId)[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF2C4383),
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
                                        fontWeight: FontWeight.w800,
                                        color: _ink,
                                      ),
                                    ),
                                    Text(
                                      'ID: $studentId',
                                      style: const TextStyle(
                                        color: _muted,
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
                                  color: const Color(0xFFE0E7FF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Entrada ${_formatTime(data['entryAt'] as Timestamp?)}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _brandBlue,
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
                              _statusChip(
                                label: 'Presente',
                                target: AttendanceStatus.presente,
                                current: status,
                                ref: doc.reference,
                                docId: doc.id,
                                isBusy: isBusy,
                              ),
                              _statusChip(
                                label: 'Tarde',
                                target: AttendanceStatus.tarde,
                                current: status,
                                ref: doc.reference,
                                docId: doc.id,
                                isBusy: isBusy,
                              ),
                              _statusChip(
                                label: 'Ausente',
                                target: AttendanceStatus.ausente,
                                current: status,
                                ref: doc.reference,
                                docId: doc.id,
                                isBusy: isBusy,
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
                                    fontWeight: FontWeight.w700,
                                    color: hasExit
                                        ? const Color(0xFF1DA056)
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
                                style: TextButton.styleFrom(
                                  foregroundColor: _brandBlue,
                                ),
                                icon: Icon(
                                  hasExit
                                      ? Icons.remove_circle_outline_rounded
                                      : Icons.logout_rounded,
                                ),
                                label: Text(
                                  hasExit
                                      ? 'Quitar salida'
                                      : 'Registrar salida',
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
