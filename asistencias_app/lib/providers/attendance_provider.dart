import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/attendance_models.dart';
import '../services/attendance_repository.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceRepository _repo;
  AttendanceProvider(this._repo);

  String? _classroomId;
  DateTime _selectedDay = DateTime.now();
  StreamSubscription<List<AttendanceEntry>>? _sub;

  List<AttendanceEntry> _entries = [];
  bool _isCheckingDuplicate = false;
  bool _hasDuplicate = false; // True si ya existe registro del día
  String? _error;

  List<AttendanceEntry> get entries => _entries;
  bool get isCheckingDuplicate => _isCheckingDuplicate;
  bool get hasDuplicate => _hasDuplicate;
  String? get error => _error;
  DateTime get selectedDay => _selectedDay;
  String? get classroomId => _classroomId;

  void configure({required String classroomId, DateTime? day}) {
    final newDay = day ?? DateTime.now();
    if (_classroomId == classroomId &&
        _selectedDay.year == newDay.year &&
        _selectedDay.month == newDay.month &&
        _selectedDay.day == newDay.day)
      return;

    _classroomId = classroomId;
    _selectedDay = newDay;
    _listen();
    _checkDuplicate();
  }

  void _listen() {
    _sub?.cancel();
    if (_classroomId == null) return;
    _sub = _repo
        .entriesForDayStream(classroomId: _classroomId!, day: _selectedDay)
        .listen(
          (data) {
            _entries = data;
            notifyListeners();
          },
          onError: (e) {
            _error = e.toString();
            notifyListeners();
          },
        );
  }

  Future<void> _checkDuplicate() async {
    if (_classroomId == null) return;
    _isCheckingDuplicate = true;
    _error = null;
    notifyListeners();
    try {
      _hasDuplicate = await _repo.hasSessionForDay(
        classroomId: _classroomId!,
        day: _selectedDay,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isCheckingDuplicate = false;
      notifyListeners();
    }
  }

  Future<void> markAttendance({
    required String studentId,
    required AttendanceStatus status,
    String? studentName,
  }) async {
    if (_classroomId == null) return;
    await _repo.upsertEntryForDay(
      classroomId: _classroomId!,
      studentId: studentId,
      status: status,
      studentName: studentName,
      when: _selectedDay,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
