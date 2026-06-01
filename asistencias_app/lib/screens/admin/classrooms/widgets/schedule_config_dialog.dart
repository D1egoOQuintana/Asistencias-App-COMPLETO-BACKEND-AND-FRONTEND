import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../models/classroom_model.dart';
import '../../../../theme/app_design_system.dart';
import '../../widgets/admin_ui.dart';

const _kBorder = Color(0xFFE6EAF0);
const _kCanvas = Color(0xFFF4F6FA);

const _kDays = [
  ('monday', 'Lunes'),
  ('tuesday', 'Martes'),
  ('wednesday', 'Miércoles'),
  ('thursday', 'Jueves'),
  ('friday', 'Viernes'),
];

/// Diálogo para configurar el horario semanal del aula.
/// Respeta la estructura `Map<dayOfWeek, {startTime, maxLateTime, endTime}>` en Firestore.
class ScheduleConfigDialog extends StatefulWidget {
  final ClassroomModel classroom;

  const ScheduleConfigDialog({super.key, required this.classroom});

  @override
  State<ScheduleConfigDialog> createState() => _ScheduleConfigDialogState();
}

class _ScheduleConfigDialogState extends State<ScheduleConfigDialog> {
  final Map<String, bool> _enabled = {};
  final Map<String, TimeOfDay> _start = {};
  final Map<String, TimeOfDay> _maxLate = {};
  final Map<String, TimeOfDay> _end = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final (key, _) in _kDays) {
      final schedule = widget.classroom.schedule;
      if (schedule != null && schedule.containsKey(key)) {
        final s = schedule[key]!;
        _enabled[key] = true;
        _start[key] = _parse(s.startTime) ?? const TimeOfDay(hour: 8, minute: 0);
        _maxLate[key] = _parse(s.maxLateTime) ?? const TimeOfDay(hour: 8, minute: 15);
        _end[key] = _parse(s.endTime) ?? const TimeOfDay(hour: 13, minute: 0);
      } else {
        _enabled[key] = false;
        _start[key] = const TimeOfDay(hour: 8, minute: 0);
        _maxLate[key] = const TimeOfDay(hour: 8, minute: 15);
        _end[key] = const TimeOfDay(hour: 13, minute: 0);
      }
    }
  }

  TimeOfDay? _parse(String? t) {
    if (t == null || t.isEmpty) return null;
    final parts = t.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool _isBefore(TimeOfDay a, TimeOfDay b) {
    final aMin = a.hour * 60 + a.minute;
    final bMin = b.hour * 60 + b.minute;
    return aMin < bMin;
  }

  String? _validate() {
    for (final (key, label) in _kDays) {
      if (!(_enabled[key] ?? false)) continue;
      final s = _start[key]!;
      final ml = _maxLate[key]!;
      final e = _end[key]!;
      if (!_isBefore(s, ml)) {
        return '$label: la hora de inicio debe ser menor que la hora límite tardanza';
      }
      if (!_isBefore(ml, e)) {
        return '$label: la hora límite tardanza debe ser menor que la hora de fin';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AdminFeedback.snack(AdminFeedbackType.warning, error),
      );
      return;
    }

    // Capture refs before the async gap to avoid using BuildContext across awaits.
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      final scheduleMap = <String, dynamic>{};
      for (final (key, _) in _kDays) {
        if (_enabled[key] == true) {
          scheduleMap[key] = {
            'dayOfWeek': key,
            'startTime': _fmt(_start[key]!),
            'maxLateTime': _fmt(_maxLate[key]!),
            'endTime': _fmt(_end[key]!),
          };
        }
      }
      await FirebaseFirestore.instance
          .collection('classrooms')
          .doc(widget.classroom.id)
          .update({
        'schedule': scheduleMap,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        AdminFeedback.snack(
          AdminFeedbackType.success,
          'Horario guardado correctamente',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        AdminFeedback.snack(AdminFeedbackType.error, 'Error: $e'),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickTime(
    BuildContext ctx,
    String day,
    Map<String, TimeOfDay> map,
  ) async {
    final picked = await showTimePicker(
      context: ctx,
      initialTime: map[day] ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => map[day] = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabledDays = _kDays.where((d) => _enabled[d.$1] == true).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppDesignSystem.borderRadiusLG),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppDesignSystem.successColor.withValues(alpha: 0.1),
                      borderRadius: AppDesignSystem.borderRadiusMD,
                    ),
                    child: const Icon(Icons.schedule_rounded,
                        size: 20, color: AppDesignSystem.successColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Configurar horario',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppDesignSystem.textPrimary,
                          ),
                        ),
                        Text(
                          widget.classroom.name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppDesignSystem.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    color: AppDesignSystem.textSecondary,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$enabledDays ${enabledDays == 1 ? 'día configurado' : 'días configurados'}',
                    style: const TextStyle(
                        fontSize: 12, color: AppDesignSystem.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: _kBorder, height: 1),
                ],
              ),
            ),

            // Day rows
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  children: _kDays.map((dayTuple) {
                    final key = dayTuple.$1;
                    final label = dayTuple.$2;
                    return _DayRow(
                      dayKey: key,
                      dayLabel: label,
                      enabled: _enabled[key] ?? false,
                      startTime: _start[key]!,
                      maxLateTime: _maxLate[key]!,
                      endTime: _end[key]!,
                      onToggle: (v) => setState(() => _enabled[key] = v),
                      onPickStart: (ctx) => _pickTime(ctx, key, _start),
                      onPickMaxLate: (ctx) => _pickTime(ctx, key, _maxLate),
                      onPickEnd: (ctx) => _pickTime(ctx, key, _end),
                      formatTime: _fmt,
                    );
                  }).toList(),
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                children: [
                  Divider(color: _kBorder, height: 1),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AdminButton.ghost(
                        label: 'Cancelar',
                        onPressed:
                            _isSaving ? null : () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      AdminButton.primary(
                        label: 'Guardar horario',
                        icon: Icons.save_rounded,
                        loading: _isSaving,
                        onPressed: _isSaving ? null : _save,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// DAY ROW
// ─────────────────────────────────────────────────────────────────────────────

class _DayRow extends StatelessWidget {
  final String dayKey;
  final String dayLabel;
  final bool enabled;
  final TimeOfDay startTime;
  final TimeOfDay maxLateTime;
  final TimeOfDay endTime;
  final ValueChanged<bool> onToggle;
  final void Function(BuildContext) onPickStart;
  final void Function(BuildContext) onPickMaxLate;
  final void Function(BuildContext) onPickEnd;
  final String Function(TimeOfDay) formatTime;

  const _DayRow({
    required this.dayKey,
    required this.dayLabel,
    required this.enabled,
    required this.startTime,
    required this.maxLateTime,
    required this.endTime,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickMaxLate,
    required this.onPickEnd,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? Colors.white : _kCanvas,
          borderRadius: AppDesignSystem.borderRadiusMD,
          border: Border.all(
            color: enabled
                ? AppDesignSystem.successColor.withValues(alpha: 0.3)
                : _kBorder,
          ),
        ),
        child: Column(
          children: [
            // Toggle row
            InkWell(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDesignSystem.radiusMD)),
              onTap: () => onToggle(!enabled),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Switch(
                      value: enabled,
                      onChanged: onToggle,
                      activeThumbColor: AppDesignSystem.successColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            enabled ? FontWeight.w700 : FontWeight.w500,
                        color: enabled
                            ? AppDesignSystem.textPrimary
                            : AppDesignSystem.textSecondary,
                      ),
                    ),
                    if (enabled) ...[
                      const Spacer(),
                      _timeSummaryChip(context),
                    ],
                  ],
                ),
              ),
            ),
            // Time pickers (visible when enabled)
            if (enabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _TimePicker(
                        label: 'Inicio',
                        time: startTime,
                        color: AppDesignSystem.primaryColor,
                        onTap: () => onPickStart(context),
                        formatTime: formatTime,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TimePicker(
                        label: 'Límite tardanza',
                        time: maxLateTime,
                        color: AppDesignSystem.warningColor,
                        onTap: () => onPickMaxLate(context),
                        formatTime: formatTime,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _TimePicker(
                        label: 'Fin',
                        time: endTime,
                        color: AppDesignSystem.textSecondary,
                        onTap: () => onPickEnd(context),
                        formatTime: formatTime,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _timeSummaryChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesignSystem.successColor.withValues(alpha: 0.08),
        borderRadius: AppDesignSystem.borderRadiusFull,
      ),
      child: Text(
        '${formatTime(startTime)} – ${formatTime(endTime)}',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppDesignSystem.successColor,
        ),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final Color color;
  final VoidCallback onTap;
  final String Function(TimeOfDay) formatTime;

  const _TimePicker({
    required this.label,
    required this.time,
    required this.color,
    required this.onTap,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppDesignSystem.borderRadiusSM,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _kCanvas,
          borderRadius: AppDesignSystem.borderRadiusSM,
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppDesignSystem.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              formatTime(time),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 1),
            Icon(Icons.edit_rounded, size: 10, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
