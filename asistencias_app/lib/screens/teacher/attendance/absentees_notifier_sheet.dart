import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../models/student_model.dart';
import '../../../services/attendance_repository.dart';

/// Hoja para notificar a apoderados de estudiantes AUSENTES (no escanearon QR)
/// en un aula y fecha dados.
///
/// Muestra un preview de los ausentes (cruce local de estudiantes activos vs
/// asistencia del día) y dispara la notificación REAL por el bot de Telegram
/// mediante la Cloud Function `notifyClassroomAbsences`. El bot envía solo a
/// los apoderados ya vinculados (`parentTelegramChatId`).
class AbsenteesNotifierSheet extends StatefulWidget {
  final String classroomId;
  final String classroomLabel;
  final DateTime day;

  const AbsenteesNotifierSheet({
    super.key,
    required this.classroomId,
    required this.classroomLabel,
    required this.day,
  });

  @override
  State<AbsenteesNotifierSheet> createState() =>
      _AbsenteesNotifierSheetState();
}

class _AbsenteesNotifierSheetState extends State<AbsenteesNotifierSheet> {
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<StudentModel> _absentees = const [];
  int _totalStudents = 0;
  int _persistedAbsent = 0;
  _SendResult? _result;

  static const _navy = Color(0xFF0F2747);
  static const _blue = Color(0xFF1F4E84);
  static const _telegram = Color(0xFF229ED9);

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatShortDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Estudiantes activos del aula.
      final studentsSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('classroomId', isEqualTo: widget.classroomId)
          .where('isActive', isEqualTo: true)
          .get();

      final students = studentsSnap.docs
          .map((d) => StudentModel.fromFirestore(d))
          .toList();

      // 2) Asistencia del día → set de studentId presentes.
      final attendanceSnap = await FirebaseFirestore.instance
          .collection('classrooms')
          .doc(widget.classroomId)
          .collection('attendance')
          .where('date', isEqualTo: _dateKey(widget.day))
          .get();

      final presentIds = <String>{};
      for (final doc in attendanceSnap.docs) {
        final sid = (doc.data()['studentId'] ?? '').toString().trim();
        if (sid.isNotEmpty) presentIds.add(sid);
      }

      // 3) Ausentes = activos sin registro de asistencia hoy.
      final absentees = students
          .where((s) => s.id != null && !presentIds.contains(s.id))
          .toList()
        ..sort((a, b) => a.fullName
            .toLowerCase()
            .compareTo(b.fullName.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _absentees = absentees;
        _totalStudents = students.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo calcular la lista de ausentes.\n$e';
        _loading = false;
      });
    }
  }

  Future<void> _notifyByTelegram() async {
    setState(() {
      _sending = true;
      _result = null;
    });

    // 1) Persistir los ausentes en la ruta real ANTES de notificar.
    //    markAbsentStudentsForDay es idempotente y NO sobrescribe registros
    //    existentes de presente/tarde/ausente (filtra por documentos del día).
    int createdAbsent = 0;
    try {
      final repo = AttendanceRepository();
      final absentIds =
          _absentees.where((s) => s.id != null).map((s) => s.id!).toList();
      final names = {
        for (final s in _absentees)
          if (s.id != null) s.id!: s.fullName,
      };
      createdAbsent = await repo.markAbsentStudentsForDay(
        classroomId: widget.classroomId,
        activeStudentIds: absentIds,
        studentNames: names,
        day: widget.day,
      );
    } catch (e) {
      // No bloquear la notificación si falla la persistencia; avisar y seguir.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No se pudieron registrar los ausentes: $e'),
          backgroundColor: Colors.orange,
        ));
      }
    }

    // 2) Notificar por Telegram.
    try {
      final callable = FirebaseFunctions.instance
          .httpsCallable('notifyClassroomAbsences');
      final resp = await callable.call(<String, dynamic>{
        'classroomId': widget.classroomId,
        'date': _dateKey(widget.day),
      });

      final data = Map<String, dynamic>.from(resp.data as Map);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _persistedAbsent = createdAbsent;
        _result = _SendResult(
          notified: (data['notified'] ?? 0) as int,
          skippedNoChat: (data['skippedNoChat'] ?? 0) as int,
          alreadyNotified: (data['alreadyNotified'] ?? 0) as int,
          absent: (data['absent'] ?? 0) as int,
        );
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo notificar: ${e.message ?? e.code}'),
        backgroundColor: Colors.red,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al notificar: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
      decoration: const BoxDecoration(
        color: Color(0xFFF4F8FF),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _grabber(),
          _header(),
          Flexible(child: _body()),
          if (!_loading && _error == null && _absentees.isNotEmpty)
            _footer(),
        ],
      ),
    );
  }

  Widget _grabber() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFB8C6DE),
          borderRadius: BorderRadius.circular(99),
        ),
      );

  Widget _header() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, _blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Notificar inasistencia',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Manrope',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.classroomLabel} · ${_formatShortDate(widget.day)}',
            style: const TextStyle(
              color: Color(0xFFD9E9FF),
              fontFamily: 'WorkSans',
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF8A2C2C),
              fontFamily: 'WorkSans',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (_absentees.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.verified_rounded,
                size: 44, color: Color(0xFF1E6E50)),
            const SizedBox(height: 12),
            Text(
              _totalStudents == 0
                  ? 'Este aula no tiene estudiantes activos registrados.'
                  : 'Todos los estudiantes registraron asistencia.\n¡No hay ausentes!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF10233E),
                fontFamily: 'WorkSans',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_absentees.length} ausente${_absentees.length != 1 ? 's' : ''} de $_totalStudents estudiante${_totalStudents != 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Color(0xFF10233E),
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_result != null) _resultBanner(_result!),
        Flexible(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            shrinkWrap: true,
            itemCount: _absentees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _absenteeRow(_absentees[i]),
          ),
        ),
      ],
    );
  }

  Widget _resultBanner(_SendResult r) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F6EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E6E50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF1E6E50), size: 18),
              const SizedBox(width: 8),
              Text(
                '${r.notified} notificación${r.notified != 1 ? 'es' : ''} enviada${r.notified != 1 ? 's' : ''} por Telegram',
                style: const TextStyle(
                  color: Color(0xFF1E6E50),
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (_persistedAbsent > 0) ...[
            const SizedBox(height: 4),
            Text(
              '$_persistedAbsent ausente${_persistedAbsent != 1 ? 's' : ''} registrado${_persistedAbsent != 1 ? 's' : ''} en el sistema',
              style: const TextStyle(
                color: Color(0xFF3B5B49),
                fontFamily: 'WorkSans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (r.skippedNoChat > 0 || r.alreadyNotified > 0) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (r.skippedNoChat > 0)
                  '${r.skippedNoChat} sin Telegram vinculado',
                if (r.alreadyNotified > 0)
                  '${r.alreadyNotified} ya avisados hoy',
              ].join(' · '),
              style: const TextStyle(
                color: Color(0xFF3B5B49),
                fontFamily: 'WorkSans',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _absenteeRow(StudentModel s) {
    final linked = s.parentTelegramChatId != null &&
        s.parentTelegramChatId.toString().trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE7F7)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFFFE7E0),
            child: Text(
              s.fullName.isNotEmpty
                  ? s.fullName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Color(0xFFB5462A),
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
                  s.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10233E),
                  ),
                ),
                Text(
                  linked
                      ? 'Telegram vinculado'
                      : 'Sin Telegram vinculado',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'WorkSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: linked
                        ? const Color(0xFF1E6E50)
                        : const Color(0xFF8A5C22),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            linked
                ? Icons.send_rounded
                : Icons.link_off_rounded,
            size: 18,
            color: linked
                ? _telegram
                : const Color(0xFFB8842E),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    final linkedCount = _absentees
        .where((s) =>
            s.parentTelegramChatId != null &&
            s.parentTelegramChatId.toString().trim().isNotEmpty)
        .length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _sending ? null : _notifyByTelegram,
            style: FilledButton.styleFrom(
              backgroundColor: _telegram,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _sending
                  ? 'Enviando…'
                  : linkedCount > 0
                      ? 'Notificar por Telegram ($linkedCount)'
                      : 'Notificar por Telegram',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendResult {
  final int notified;
  final int skippedNoChat;
  final int alreadyNotified;
  final int absent;

  const _SendResult({
    required this.notified,
    required this.skippedNoChat,
    required this.alreadyNotified,
    required this.absent,
  });
}
