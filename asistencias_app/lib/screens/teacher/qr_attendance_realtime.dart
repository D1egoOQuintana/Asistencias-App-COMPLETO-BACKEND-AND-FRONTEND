import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/attendance_models.dart';
import '../../providers/attendance_provider.dart';
import '../../services/attendance_repository.dart';

/// Pantalla de registro por QR en tiempo real
/// Integra con AttendanceProvider para actualizar la lista inmediatamente
class QRAttendanceRealtimeScreen extends StatelessWidget {
  final String classroomId;

  const QRAttendanceRealtimeScreen({super.key, required this.classroomId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          AttendanceProvider(AttendanceRepository())
            ..configure(classroomId: classroomId, day: DateTime.now()),
      child: const _QRAttendanceRealtimeView(),
    );
  }
}

class _QRAttendanceRealtimeView extends StatelessWidget {
  const _QRAttendanceRealtimeView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Registro por QR')),
      body: Column(
        children: [
          if (provider.isCheckingDuplicate)
            const LinearProgressIndicator(minHeight: 2),
          if (provider.hasDuplicate)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ya existe un registro hoy. Las marcas serán actualizaciones por estudiante.',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                // Forzar reconfig para reescuchar
                provider.configure(
                  classroomId:
                      (context.read<AttendanceProvider>()).classroomId!,
                  day: provider.selectedDay,
                );
              },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: provider.entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final e = provider.entries[i];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: _statusColor(
                        ctx,
                        e.status,
                      ).withOpacity(0.1),
                      child: Icon(
                        e.status == AttendanceStatus.presente
                            ? Icons.check
                            : e.status == AttendanceStatus.tarde
                            ? Icons.schedule
                            : Icons.close,
                        color: _statusColor(ctx, e.status),
                      ),
                    ),
                    title: Text(e.studentName ?? e.studentId),
                    subtitle: Text(
                      'Hora: ${TimeOfDay.fromDateTime(e.timestamp).format(ctx)}',
                    ),
                    trailing: DropdownButton<AttendanceStatus>(
                      value: e.status,
                      onChanged: (v) {
                        if (v != null) {
                          context.read<AttendanceProvider>().markAttendance(
                            studentId: e.studentId,
                            status: v,
                            studentName: e.studentName,
                          );
                        }
                      },
                      items: const [
                        DropdownMenuItem(
                          value: AttendanceStatus.presente,
                          child: Text('Presente'),
                        ),
                        DropdownMenuItem(
                          value: AttendanceStatus.tarde,
                          child: Text('Tarde'),
                        ),
                        DropdownMenuItem(
                          value: AttendanceStatus.ausente,
                          child: Text('Faltó'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          // Botón de prueba rápida para simular escaneo QR
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final id = DateTime.now().millisecondsSinceEpoch.toString();
                  await context.read<AttendanceProvider>().markAttendance(
                    studentId: 'std_$id',
                    status: AttendanceStatus.presente,
                    studentName: 'Estudiante $id',
                  );
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Simular escaneo QR'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.presente:
        return Colors.green.shade600;
      case AttendanceStatus.tarde:
        return Colors.orange.shade700;
      case AttendanceStatus.ausente:
        return Colors.red.shade600;
    }
  }
}
