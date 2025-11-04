import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendance_models.dart';
import '../providers/attendance_provider.dart';

/// Widget simple para mostrar un "calendario" de un día con totales y lista
/// Se actualiza en tiempo real al compartir el mismo AttendanceProvider
class AttendanceCalendarDay extends StatelessWidget {
  const AttendanceCalendarDay({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final entries = provider.entries;

    int count(AttendanceStatus s) => entries.where((e) => e.status == s).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _chip(
              context,
              'Presentes',
              count(AttendanceStatus.presente),
              Colors.green.shade600,
            ),
            _chip(
              context,
              'Tarde',
              count(AttendanceStatus.tarde),
              Colors.orange.shade700,
            ),
            _chip(
              context,
              'Faltó',
              count(AttendanceStatus.ausente),
              Colors.red.shade600,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...entries.map(
          (e) => ListTile(
            dense: true,
            leading: Icon(
              e.status == AttendanceStatus.presente
                  ? Icons.check_circle
                  : e.status == AttendanceStatus.tarde
                  ? Icons.schedule
                  : Icons.cancel,
              color: e.status == AttendanceStatus.presente
                  ? Colors.green
                  : e.status == AttendanceStatus.tarde
                  ? Colors.orange
                  : Colors.red,
            ),
            title: Text(e.studentName ?? e.studentId),
            subtitle: Text(
              'Hora: ${TimeOfDay.fromDateTime(e.timestamp).format(context)}',
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, int value, Color color) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 8),
      label: Text('$label: $value'),
      shape: StadiumBorder(side: BorderSide(color: color.withOpacity(0.2))),
    );
  }
}
