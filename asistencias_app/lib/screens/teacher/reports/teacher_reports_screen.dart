import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_design_system.dart';

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}

class TeacherReportsScreen extends StatefulWidget {
  final bool showAppBar;

  const TeacherReportsScreen({super.key, this.showAppBar = false});

  @override
  State<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> {
  static const Color _brandBlue = Color(0xFF1976D2);
  static const Color _outline = Color(0xFF5F6470);
  static const Color _outlineVariant = Color(0xFFC5C6D2);

  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  final _auth = FirebaseAuth.instance;

  String? selectedClassroomId;
  // Normalizar fechas al inicio y fin del día
  DateTime startDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day - 30,
    0,
    0,
    0,
    0, // Inicio del día (00:00:00)
  );
  DateTime endDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
    23,
    59,
    59,
    999, // Fin del día (23:59:59)
  );

  // Variables para reportes mensuales (PDF y Excel)
  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  bool isLoading = false;
  String loadingMessage = 'Analizando...';
  Map<String, dynamic>? aiInsights;
  List<Map<String, dynamic>> classrooms = [];
  bool isApplyingFilters = false;
  String? overviewError;
  Map<String, dynamic>? overviewData;
  int activeTab = 0;

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('DEBUG: No hay usuario autenticado');
        return;
      }

      print('DEBUG: Usuario autenticado: ${user.uid}');

      final querySnapshot = await _firestore
          .collection('classrooms')
          .where('teacherUid', isEqualTo: user.uid)
          .where('isActive', isEqualTo: true)
          .get();

      print('DEBUG: Documentos encontrados: ${querySnapshot.docs.length}');

      if (!mounted) return;
      setState(() {
        classrooms = querySnapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList();

        print('DEBUG: Aulas cargadas: ${classrooms.length}');
        if (classrooms.isNotEmpty) {
          print('DEBUG: Primera aula: ${classrooms[0]}');
        }

        if (classrooms.isNotEmpty && selectedClassroomId == null) {
          selectedClassroomId = classrooms[0]['id'];
        }
      });

      if (selectedClassroomId != null) {
        await _applyFilters();
      }
    } catch (e) {
      print('DEBUG: Error al cargar aulas: $e');
      _showError('Error al cargar aulas: $e');
    }
  }

  Future<void> _applyFilters() async {
    if (selectedClassroomId == null) {
      setState(() {
        overviewData = null;
        overviewError = 'Selecciona un aula para ver el reporte.';
      });
      return;
    }

    setState(() {
      isApplyingFilters = true;
      overviewError = null;
    });

    try {
      final data = await _getAttendanceData();
      final attendances = _asMapList(data['attendances']);
      final studentSummaries = _asMapList(data['studentSummaries']);

      final totalRecords = attendances.length;
      final presentCount = attendances
          .where((a) => (a['status'] ?? '') == 'present')
          .length;
      final lateCount = attendances
          .where((a) => (a['status'] ?? '') == 'late')
          .length;
      final effectivePresent = presentCount + lateCount;
      final averageAttendance = totalRecords > 0
          ? (effectivePresent / totalRecords) * 100
          : 0.0;

      final chronicAbsenteeism = studentSummaries.where((student) {
        final total = student['totalClasses'] as int? ?? 0;
        final absent = student['absent'] as int? ?? 0;
        if (total == 0) return false;
        return (absent / total) >= 0.2;
      }).length;

      final sessionsByDate = <String>{};
      for (final attendance in attendances) {
        final date = (attendance['date'] ?? '').toString();
        if (date.isNotEmpty) {
          sessionsByDate.add(date);
        }
      }

      final weekTotal = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};
      final weekPresent = <int, int>{1: 0, 2: 0, 3: 0, 4: 0};

      for (final attendance in attendances) {
        final dateText = (attendance['date'] ?? '').toString();
        if (dateText.isEmpty) continue;

        final parts = dateText.split('/');
        if (parts.length != 3) continue;
        final day = int.tryParse(parts[0]) ?? 1;
        int week = ((day - 1) ~/ 7) + 1;
        if (week > 4) week = 4;

        weekTotal[week] = (weekTotal[week] ?? 0) + 1;
        final status = (attendance['status'] ?? '').toString();
        if (status == 'present' || status == 'late') {
          weekPresent[week] = (weekPresent[week] ?? 0) + 1;
        }
      }

      final trend = List<double>.generate(4, (index) {
        final week = index + 1;
        final total = weekTotal[week] ?? 0;
        final present = weekPresent[week] ?? 0;
        if (total == 0) return 0;
        return (present / total) * 100;
      });

      if (!mounted) return;
      setState(() {
        overviewData = {
          'averageAttendance': averageAttendance,
          'chronicAbsenteeism': chronicAbsenteeism,
          'totalSessions': sessionsByDate.length,
          'trend': trend,
          'raw': data,
        };
        isApplyingFilters = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        overviewError = 'No se pudo cargar el resumen: $e';
        isApplyingFilters = false;
      });
    }
  }

  Map<String, dynamic> _asStringDynamicMap(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, val) => MapEntry(key.toString(), val));
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map<Map<String, dynamic>>(_asStringDynamicMap)
        .toList();
  }

  Future<void> _generateAIInsights() async {
    if (selectedClassroomId == null) {
      _showError('Selecciona un aula primero');
      return;
    }

    _setStateIfMounted(() {
      isLoading = true;
      loadingMessage = 'Sincronizando datos...';
      aiInsights = null;
    });

    try {
      // Esperar 2 segundos para asegurar sincronización de Firestore
      await Future.delayed(const Duration(seconds: 2));

      _setStateIfMounted(() {
        loadingMessage = 'Obteniendo asistencias...';
      });

      final attendanceResult = await _functions
          .httpsCallable('getAttendanceReportData')
          .call({
            'classroomId': selectedClassroomId,
            'startDate': startDate.toIso8601String(),
            'endDate': endDate.toIso8601String(),
          });

      if (attendanceResult.data['success'] != true) {
        throw Exception(
          attendanceResult.data['message'] ?? 'Error obteniendo datos',
        );
      }

      final attendanceData = attendanceResult.data['data'];

      _setStateIfMounted(() {
        loadingMessage = 'Generando análisis con IA...';
      });

      // Ahora generar el análisis con IA usando esos datos
      final result = await _functions
          .httpsCallable('generateReportWithAI')
          .call({
            'classroomId': selectedClassroomId,
            'startDate': startDate.toIso8601String(),
            'endDate': endDate.toIso8601String(),
            'attendanceData': attendanceData,
          });

      _setStateIfMounted(() {
        aiInsights = result.data as Map<String, dynamic>;
        isLoading = false;
        loadingMessage = 'Analizando...';
      });
    } catch (e) {
      _setStateIfMounted(() {
        isLoading = false;
        loadingMessage = 'Analizando...';
      });
      _showError('Error al generar análisis con IA: $e');
    }
  }

  /// Obtener datos de asistencia usando la API profesional del backend
  Future<Map<String, dynamic>> _getAttendanceData({
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final startDateToUse = customStart ?? startDate;
    final endDateToUse = customEnd ?? endDate;

    print('🔍 Obteniendo datos de asistencia:');
    print('   Aula: $selectedClassroomId');
    print(
      '   Inicio: ${DateFormat('dd/MM/yyyy HH:mm').format(startDateToUse)}',
    );
    print('   Fin: ${DateFormat('dd/MM/yyyy HH:mm').format(endDateToUse)}');

    try {
      // Llamar a la función de backend para obtener datos estructurados
      final result = await _functions.httpsCallable('exportReportData').call({
        'classroomId': selectedClassroomId,
        'startDate': startDateToUse.toIso8601String(),
        'endDate': endDateToUse.toIso8601String(),
        'format': 'structured',
      });

      if (result.data['success'] == true) {
        // Convertir explícitamente los datos a Map<String, dynamic>
        final data = result.data['data'];
        final resultData = Map<String, dynamic>.from(data as Map);

        return resultData;
      } else {
        throw Exception('Error en respuesta del servidor');
      }
    } catch (e) {
      // Fallback: obtener datos directamente de Firestore
      print('⚠️ Usando fallback para obtener datos: $e');
      // Obtener todas las asistencias del aula y filtrar por fecha en memoria
      final attendanceSnapshot = await _firestore
          .collection('attendances')
          .where('classroomId', isEqualTo: selectedClassroomId)
          .get();

      final studentsSnapshot = await _firestore
          .collection('students')
          .where('classroomId', isEqualTo: selectedClassroomId)
          .get();

      // Filtrar por fecha en memoria
      final records = attendanceSnapshot.docs
          .map((doc) {
            final data = doc.data();
            final timestamp = (data['timestamp'] as Timestamp).toDate();
            return {
              'id': doc.id,
              'studentId': data['studentId'],
              'studentName': data['studentName'] ?? 'N/A',
              'status': data['status'],
              'date': DateFormat('dd/MM/yyyy').format(timestamp),
              'time': DateFormat('HH:mm').format(timestamp),
              'timestamp': timestamp,
              'method': data['method'] ?? 'manual',
              'notes': data['notes'] ?? '',
            };
          })
          .where((record) {
            final timestamp = record['timestamp'] as DateTime;
            return timestamp.isAfter(
                  startDateToUse.subtract(const Duration(days: 1)),
                ) &&
                timestamp.isBefore(endDateToUse.add(const Duration(days: 1)));
          })
          .map((record) {
            // Convertir timestamp a string para el resultado final
            return {
              ...record,
              'timestamp': (record['timestamp'] as DateTime).toIso8601String(),
            };
          })
          .toList();

      final students = studentsSnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      // Calcular resumen por estudiante
      final studentSummaries = students.map((student) {
        final studentAttendances = records
            .where((r) => r['studentId'] == student['id'])
            .toList();
        final present = studentAttendances
            .where((a) => a['status'] == 'present')
            .length;
        final absent = studentAttendances
            .where((a) => a['status'] == 'absent')
            .length;
        final late = studentAttendances
            .where((a) => a['status'] == 'late')
            .length;
        final justified = studentAttendances
            .where((a) => a['status'] == 'justified')
            .length;
        final total = studentAttendances.length;
        final attendanceRate = total > 0
            ? ((present + late) / total * 100).toStringAsFixed(2)
            : '0.00';

        return {
          'studentId': student['id'],
          'studentName':
              '${student['lastName'] ?? ''}, ${student['firstName'] ?? ''}',
          'dni': student['dni'] ?? '',
          'totalClasses': total,
          'present': present,
          'absent': absent,
          'late': late,
          'justified': justified,
          'attendanceRate': '$attendanceRate%',
        };
      }).toList();

      print('📝 Fallback - Datos procesados:');
      print('   Asistencias filtradas: ${records.length}');
      print('   Estudiantes: ${students.length}');
      print('   Resúmenes de estudiantes: ${studentSummaries.length}');

      return {
        'metadata': {'totalRecords': records.length},
        'summary': {
          'totalStudents': students.length,
          'totalClasses': records.length,
        },
        'studentSummaries': studentSummaries,
        'attendances': records,
        'students': students,
      };
    }
  }

  Future<void> _generateExcelReport() async {
    if (selectedClassroomId == null) {
      _showError('Selecciona un aula primero');
      return;
    }

    _setStateIfMounted(() => isLoading = true);

    try {
      // Calcular fechas del mes completo
      final monthStart = DateTime(selectedYear, selectedMonth, 1);
      final monthEnd = DateTime(selectedYear, selectedMonth + 1, 0, 23, 59, 59);
      final daysInMonth = monthEnd.day;

      print(
        '📅 Generando reporte Excel UGEL 06 para: ${DateFormat('MMMM yyyy', 'es').format(monthStart)}',
      );

      // Obtener datos del mes completo
      final data = await _getAttendanceData(
        customStart: monthStart,
        customEnd: monthEnd,
      );

      final students = data['students'] as List?;
      final attendances = data['attendances'] as List?;
      // Convertir explícitamente metadata
      final metadataRaw = data['metadata'];
      final metadata = metadataRaw != null
          ? Map<String, dynamic>.from(metadataRaw as Map)
          : null;

      if (students == null || students.isEmpty) {
        _setStateIfMounted(() => isLoading = false);
        _showError('No hay estudiantes en esta aula');
        return;
      }

      // Crear Excel desde cero
      final excel = excel_pkg.Excel.createExcel();
      final sheetName =
          'Asistencia ${DateFormat('MMM yyyy', 'es').format(monthStart)}';
      excel.rename('Sheet1', sheetName);
      final sheet = excel[sheetName];

      // Agrupar asistencias por estudiante y día
      final attendanceByStudent = <String, Map<int, String>>{};
      for (var student in students) {
        attendanceByStudent[student['id']] = {};
      }

      if (attendances != null) {
        for (var attendance in attendances) {
          final studentId = attendance['studentId'];
          final dateStr = attendance['date'] as String?;
          if (dateStr != null && attendanceByStudent.containsKey(studentId)) {
            try {
              final parts = dateStr.split('/');
              if (parts.length == 3) {
                final day = int.parse(parts[0]);
                final status = attendance['status'] as String;
                attendanceByStudent[studentId]![day] = status;
              }
            } catch (e) {
              print('Error parseando fecha: $dateStr - $e');
            }
          }
        }
      }

      final monthName = DateFormat(
        'MMMM yyyy',
        'es',
      ).format(monthStart).toUpperCase();

      // Estilos profesionales - usando solo propiedades soportadas por excel 4.x
      final headerStyle = excel_pkg.CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: excel_pkg.ExcelColor.white,
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#1F4E78'),
      );

      final subHeaderStyle = excel_pkg.CellStyle(
        bold: true,
        fontSize: 11,
        fontColorHex: excel_pkg.ExcelColor.white,
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#2E75B6'),
      );

      final dayHeaderStyle = excel_pkg.CellStyle(
        bold: true,
        fontSize: 9,
        fontColorHex: excel_pkg.ExcelColor.white,
        backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#4472C4'),
      );

      final dataStyle = excel_pkg.CellStyle(fontSize: 10);

      final nameStyle = excel_pkg.CellStyle(fontSize: 10);

      // Fila 1: Título principal
      var cell = sheet.cell(excel_pkg.CellIndex.indexByString('A1'));
      cell.value = excel_pkg.TextCellValue(
        'REGISTRO DE ASISTENCIA - UGEL 06 LIMA',
      );
      cell.cellStyle = headerStyle;
      sheet.merge(
        excel_pkg.CellIndex.indexByString('A1'),
        excel_pkg.CellIndex.indexByColumnRow(
          columnIndex: daysInMonth + 1,
          rowIndex: 0,
        ),
      );

      // Fila 2: Información del mes y aula
      cell = sheet.cell(excel_pkg.CellIndex.indexByString('A2'));
      cell.value = excel_pkg.TextCellValue('MES: $monthName');
      cell.cellStyle = subHeaderStyle;
      sheet.merge(
        excel_pkg.CellIndex.indexByString('A2'),
        excel_pkg.CellIndex.indexByString('E2'),
      );

      cell = sheet.cell(excel_pkg.CellIndex.indexByString('F2'));
      cell.value = excel_pkg.TextCellValue(
        'AULA: ${metadata?['classroom'] ?? 'N/A'}',
      );
      cell.cellStyle = subHeaderStyle;
      sheet.merge(
        excel_pkg.CellIndex.indexByString('F2'),
        excel_pkg.CellIndex.indexByColumnRow(
          columnIndex: daysInMonth + 1,
          rowIndex: 1,
        ),
      );

      // Fila 3: Espacio

      // Fila 4: Encabezados de columnas
      int currentRow = 3;

      // Encabezado N°
      cell = sheet.cell(
        excel_pkg.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: currentRow,
        ),
      );
      cell.value = excel_pkg.TextCellValue('N°');
      cell.cellStyle = dayHeaderStyle;

      // Encabezado Apellidos y Nombres
      cell = sheet.cell(
        excel_pkg.CellIndex.indexByColumnRow(
          columnIndex: 1,
          rowIndex: currentRow,
        ),
      );
      cell.value = excel_pkg.TextCellValue('APELLIDOS Y NOMBRES');
      cell.cellStyle = dayHeaderStyle;

      // Encabezados de días (1-30/31)
      for (int day = 1; day <= daysInMonth; day++) {
        cell = sheet.cell(
          excel_pkg.CellIndex.indexByColumnRow(
            columnIndex: day + 1,
            rowIndex: currentRow,
          ),
        );
        cell.value = excel_pkg.IntCellValue(day);
        cell.cellStyle = dayHeaderStyle;
      }

      // Filas de estudiantes
      currentRow++;
      for (int i = 0; i < students.length; i++) {
        final student = students[i];
        final studentId = student['id'] as String;
        final lastName = student['lastName'] ?? '';
        final firstName = student['firstName'] ?? '';

        // Columna N°
        cell = sheet.cell(
          excel_pkg.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: currentRow,
          ),
        );
        cell.value = excel_pkg.IntCellValue(i + 1);
        cell.cellStyle = dataStyle;

        // Columna Apellidos y Nombres
        cell = sheet.cell(
          excel_pkg.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: currentRow,
          ),
        );
        cell.value = excel_pkg.TextCellValue('$lastName, $firstName');
        cell.cellStyle = nameStyle;

        // Columnas de días
        for (int day = 1; day <= daysInMonth; day++) {
          final status = attendanceByStudent[studentId]?[day];
          final symbol = _getStatusSymbol(status);

          cell = sheet.cell(
            excel_pkg.CellIndex.indexByColumnRow(
              columnIndex: day + 1,
              rowIndex: currentRow,
            ),
          );
          cell.value = excel_pkg.TextCellValue(symbol);

          // Color según estado
          if (status != null) {
            cell.cellStyle = excel_pkg.CellStyle(
              fontSize: 10,
              bold: true,
              fontColorHex: _getStatusColor(status),
            );
          } else {
            cell.cellStyle = dataStyle;
          }
        }

        currentRow++;
      }

      // Espacio
      currentRow += 2;

      // Leyenda
      cell = sheet.cell(
        excel_pkg.CellIndex.indexByColumnRow(
          columnIndex: 0,
          rowIndex: currentRow,
        ),
      );
      cell.value = excel_pkg.TextCellValue('LEYENDA:');
      cell.cellStyle = excel_pkg.CellStyle(bold: true, fontSize: 10);

      currentRow++;
      final legendItems = [
        '✓ = Presente',
        'T = Tardanza',
        'F = Falta',
        'J = Justificada',
      ];

      for (int i = 0; i < legendItems.length; i++) {
        cell = sheet.cell(
          excel_pkg.CellIndex.indexByColumnRow(
            columnIndex: i,
            rowIndex: currentRow,
          ),
        );
        cell.value = excel_pkg.TextCellValue(legendItems[i]);
        cell.cellStyle = excel_pkg.CellStyle(fontSize: 9);
      }

      // Ajustar anchos de columnas
      sheet.setColumnWidth(0, 5); // N°
      sheet.setColumnWidth(1, 30); // Nombres
      for (int i = 2; i <= daysInMonth + 1; i++) {
        sheet.setColumnWidth(i, 4); // Días
      }

      // Guardar archivo
      final directory = await getApplicationDocumentsDirectory();
      final filename =
          'Asistencia_UGEL06_${monthName.replaceAll(' ', '_')}.xlsx';
      final file = File('${directory.path}/$filename');
      final excelBytes = excel.encode();

      if (excelBytes != null) {
        await file.writeAsBytes(excelBytes);
        await Share.shareXFiles([
          XFile(file.path),
        ], text: 'Reporte de Asistencia UGEL 06');
      }

      _setStateIfMounted(() => isLoading = false);
      _showSuccess('Reporte Excel generado exitosamente');
    } catch (e) {
      _setStateIfMounted(() => isLoading = false);
      _showError('Error al generar Excel: $e');
      print('Error detallado Excel: $e');
    }
  }

  // Helper para obtener color según estado
  excel_pkg.ExcelColor _getStatusColor(String status) {
    switch (status) {
      case 'present':
        return excel_pkg.ExcelColor.fromHexString('#00B050'); // Verde
      case 'late':
        return excel_pkg.ExcelColor.fromHexString('#FFC000'); // Naranja
      case 'absent':
        return excel_pkg.ExcelColor.fromHexString('#FF0000'); // Rojo
      case 'justified':
        return excel_pkg.ExcelColor.fromHexString('#0070C0'); // Azul
      default:
        return excel_pkg.ExcelColor.black;
    }
  }

  Future<void> _generatePDFReport() async {
    if (selectedClassroomId == null) {
      _showError('Selecciona un aula primero');
      return;
    }

    _setStateIfMounted(() => isLoading = true);

    try {
      // Calcular fechas del mes completo
      final monthStart = DateTime(selectedYear, selectedMonth, 1);
      final monthEnd = DateTime(selectedYear, selectedMonth + 1, 0, 23, 59, 59);
      final daysInMonth = monthEnd.day;

      print(
        '📅 Generando reporte PDF SIAGIE para: ${DateFormat('MMMM yyyy', 'es').format(monthStart)}',
      );

      final data = await _getAttendanceData(
        customStart: monthStart,
        customEnd: monthEnd,
      );

      // Validar que tengamos datos
      final students = data['students'] as List?;
      final attendances = data['attendances'] as List?;
      // Convertir explícitamente metadata
      final metadataRaw = data['metadata'];
      final metadata = metadataRaw != null
          ? Map<String, dynamic>.from(metadataRaw as Map)
          : null;

      print('📊 Datos obtenidos:');
      print('   Estudiantes: ${students?.length ?? 0}');
      print('   Registros de asistencia: ${attendances?.length ?? 0}');

      if (students == null || students.isEmpty) {
        _setStateIfMounted(() => isLoading = false);
        _showError('No hay estudiantes en esta aula');
        return;
      }

      // Agrupar asistencias por estudiante y día
      final attendanceByStudent = <String, Map<int, String>>{};
      for (var student in students) {
        attendanceByStudent[student['id']] = {};
      }

      if (attendances != null) {
        for (var attendance in attendances) {
          final studentId = attendance['studentId'];
          final dateStr = attendance['date'] as String?;
          if (dateStr != null && attendanceByStudent.containsKey(studentId)) {
            try {
              final parts = dateStr.split('/');
              if (parts.length == 3) {
                final day = int.parse(parts[0]);
                final status = attendance['status'] as String;
                attendanceByStudent[studentId]![day] = status;
              }
            } catch (e) {
              print('Error parseando fecha: $dateStr - $e');
            }
          }
        }
      }

      final pdf = pw.Document();
      final monthName = DateFormat(
        'MMMM yyyy',
        'es',
      ).format(monthStart).toUpperCase();

      // Página en formato horizontal para más espacio
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(15),
          build: (context) => [
            // Encabezado estilo SIAGIE
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'REGISTRO DE ASISTENCIA',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Mes: $monthName',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'Aula: ${metadata?['classroom'] ?? 'N/A'}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'UGEL 06 - LIMA',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 8),
              ],
            ),

            // Tabla de asistencia estilo SIAGIE
            pw.Table(
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
              columnWidths: {
                0: const pw.FixedColumnWidth(30), // N°
                1: const pw.FlexColumnWidth(3), // Apellidos y Nombres
                // Días del 1-31 tendrán ancho flexible
              },
              children: [
                // Fila de encabezado con días
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildHeaderCell('N°'),
                    _buildHeaderCell('APELLIDOS Y NOMBRES'),
                    ...List.generate(
                      daysInMonth,
                      (i) => _buildHeaderCell('${i + 1}'),
                    ),
                  ],
                ),

                // Filas de estudiantes
                ...students.asMap().entries.map((entry) {
                  final index = entry.key;
                  final student = entry.value;
                  final studentId = student['id'] as String;
                  final lastName = student['lastName'] ?? '';
                  final firstName = student['firstName'] ?? '';

                  return pw.TableRow(
                    children: [
                      _buildDataCell('${index + 1}'),
                      _buildDataCell(
                        '$lastName, $firstName',
                        align: pw.TextAlign.left,
                      ),
                      ...List.generate(daysInMonth, (day) {
                        final status = attendanceByStudent[studentId]?[day + 1];
                        return _buildDataCell(_getStatusSymbol(status));
                      }),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 15),

            // Leyenda
            pw.Row(
              children: [
                pw.Text(
                  'LEYENDA: ',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Text('✓ = Presente', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(width: 10),
                pw.Text('T = Tardanza', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(width: 10),
                pw.Text('F = Falta', style: const pw.TextStyle(fontSize: 8)),
                pw.SizedBox(width: 10),
                pw.Text(
                  'J = Justificada',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            // Firmas
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Container(height: 40),
                    pw.Divider(thickness: 1),
                    pw.Text('Docente', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Container(height: 40),
                    pw.Divider(thickness: 1),
                    pw.Text(
                      'Director(a)',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );

      // Compartir PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'asistencia_${monthName.replaceAll(' ', '_')}.pdf',
      );

      _setStateIfMounted(() => isLoading = false);
      _showSuccess('Reporte PDF generado exitosamente');
    } catch (e) {
      _setStateIfMounted(() => isLoading = false);
      _showError('Error al generar PDF: $e');
      print('Error detallado: $e');
    }
  }

  // Helpers para construir celdas del PDF
  pw.Widget _buildHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      alignment: pw.Alignment.center,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildDataCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      alignment: align == pw.TextAlign.left
          ? pw.Alignment.centerLeft
          : pw.Alignment.center,
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 7),
        textAlign: align,
      ),
    );
  }

  String _getStatusSymbol(String? status) {
    if (status == null) return '';
    switch (status) {
      case 'present':
        return '✓';
      case 'late':
        return 'T';
      case 'absent':
        return 'F';
      case 'justified':
        return 'J';
      default:
        return '';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
    );

    if (picked == null) return;

    _setStateIfMounted(() {
      startDate = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
        0,
        0,
        0,
      );
      endDate = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
        999,
      );
    });
  }

  Widget _buildTabButton({
    required String label,
    required int index,
    required Color primaryColor,
  }) {
    final selected = activeTab == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _setStateIfMounted(() => activeTab = index),
          hoverColor: const Color(0xFFEEF2FF),
          highlightColor: const Color(0xFFE0E7FF),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? primaryColor : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.25,
                color: selected ? primaryColor : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? helper,
    String? trend,
    double? progress,
    Color trendColor = const Color(0xFF16A34A),
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              if (trend != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up, color: trendColor, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        trend,
                        style: TextStyle(
                          color: trendColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF1976D2)),
              ),
            ),
          ],
          if (helper != null) ...[
            const SizedBox(height: 10),
            Text(
              helper,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrendChart(List<double> trend) {
    final normalized = trend
        .map((v) => v <= 0 ? 0.08 : (v / 100).clamp(0.08, 1.0))
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tendencia mensual de asistencia',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _LegendDot(color: Color(0xFF1976D2), label: 'Real'),
              SizedBox(width: 14),
              _LegendDot(color: Color(0xFFCBD5E1), label: 'Meta (95%)'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(4, (index) {
                final color = index == 2
                    ? const Color(0xFF1976D2)
                    : const Color(
                        0xFF1976D2,
                      ).withValues(alpha: 0.35 + (index * 0.15));

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${trend[index].toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          height: 150 * normalized[index],
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Semana ${index + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightsPanel() {
    if (aiInsights == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'Aún no hay insights generados. Presiona "Generar análisis con IA".',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text(
                'Análisis con IA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E1B4B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (aiInsights!['summary'] != null) ...[
            const Text(
              'Resumen',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(aiInsights!['summary'].toString()),
            const SizedBox(height: 14),
          ],
          if (aiInsights!['patterns'] != null) ...[
            const Text(
              'Patrones detectados',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...((aiInsights!['patterns'] as List).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(item.toString())),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 12),
          ],
          if (aiInsights!['recommendations'] != null) ...[
            const Text(
              'Recomendaciones',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...((aiInsights!['recommendations'] as List).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFFF59E0B),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item.toString())),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewContent() {
    final primaryColor = const Color(0xFF1976D2);

    final avg = (overviewData?['averageAttendance'] as num?)?.toDouble() ?? 0;
    final chronic = (overviewData?['chronicAbsenteeism'] as int?) ?? 0;
    final sessions = (overviewData?['totalSessions'] as int?) ?? 0;
    final trend =
        (overviewData?['trend'] as List?)?.cast<double>() ?? [0, 0, 0, 0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;

                  final classSelector = DropdownButtonFormField<String>(
                    value: selectedClassroomId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Grupo / Aula',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    items: classrooms
                        .map(
                          (classroom) => DropdownMenuItem<String>(
                            value: classroom['id'] as String,
                            child: Text(
                              (classroom['name'] ?? 'Sin nombre').toString(),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: classrooms.isEmpty
                        ? null
                        : (value) {
                            _setStateIfMounted(() {
                              selectedClassroomId = value;
                              aiInsights = null;
                            });
                          },
                  );

                  final dateSelector = InkWell(
                    onTap: _pickDateRange,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Rango de fechas',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(
                        '${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  );

                  final applyButton = ElevatedButton(
                    onPressed: isApplyingFilters ? null : _applyFilters,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.disabled)) {
                          return primaryColor.withValues(alpha: 0.55);
                        }
                        if (states.contains(WidgetState.pressed)) {
                          return const Color(0xFF111A66);
                        }
                        if (states.contains(WidgetState.hovered)) {
                          return const Color(0xFF202B9A);
                        }
                        return primaryColor;
                      }),
                      foregroundColor: const WidgetStatePropertyAll(
                        Colors.white,
                      ),
                      elevation: const WidgetStatePropertyAll(0),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    child: isApplyingFilters
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Aplicar filtros',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: classSelector),
                        const SizedBox(width: 12),
                        Expanded(child: dateSelector),
                        const SizedBox(width: 12),
                        SizedBox(width: 180, child: applyButton),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      classSelector,
                      const SizedBox(height: 12),
                      dateSelector,
                      const SizedBox(height: 12),
                      SizedBox(width: double.infinity, child: applyButton),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 700;

                  final monthField = DropdownButtonFormField<int>(
                    value: selectedMonth,
                    decoration: InputDecoration(
                      labelText: 'Mes de exportación',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    items: [
                      for (int i = 1; i <= 12; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            DateFormat('MMMM', 'es').format(DateTime(2024, i)),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _setStateIfMounted(() => selectedMonth = value);
                      }
                    },
                  );

                  final yearField = DropdownButtonFormField<int>(
                    value: selectedYear,
                    decoration: InputDecoration(
                      labelText: 'Año',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    items: [
                      for (
                        int year = DateTime.now().year - 2;
                        year <= DateTime.now().year;
                        year++
                      )
                        DropdownMenuItem(value: year, child: Text('$year')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _setStateIfMounted(() => selectedYear = value);
                      }
                    },
                  );

                  if (isWide) {
                    return Row(
                      children: [
                        Expanded(flex: 2, child: monthField),
                        const SizedBox(width: 12),
                        Expanded(child: yearField),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      monthField,
                      const SizedBox(height: 12),
                      yearField,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (overviewError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text(
              overviewError!,
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (overviewError != null) const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _buildStatCard(
                title: 'Asistencia promedio',
                value: '${avg.toStringAsFixed(1)}%',
                trend: '2.4%',
                progress: avg / 100,
              ),
              _buildStatCard(
                title: 'Ausentismo crónico',
                value: '$chronic',
                helper: 'Estudiantes en zona de riesgo',
              ),
              _buildStatCard(
                title: 'Total de sesiones',
                value: '$sessions',
                helper: 'En el período seleccionado',
              ),
            ];

            const gap = 12.0;
            final width = constraints.maxWidth;
            final cardWidth = (width - (gap * 2)) / 3;
            final needsScroll = cardWidth < 220;

            final statsRow = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: needsScroll ? 220 : cardWidth, child: cards[0]),
                const SizedBox(width: gap),
                SizedBox(width: needsScroll ? 220 : cardWidth, child: cards[1]),
                const SizedBox(width: gap),
                SizedBox(width: needsScroll ? 220 : cardWidth, child: cards[2]),
              ],
            );

            if (!needsScroll) {
              return statsRow;
            }

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: statsRow,
            );
          },
        ),
        const SizedBox(height: 16),
        _buildTrendChart(trend),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF0F172A), Color(0xFF1F2A8A)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              const SizedBox(
                width: 380,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generar análisis predictivo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'La IA analiza patrones de asistencia para identificar estudiantes que requieren intervención temprana.',
                      style: TextStyle(
                        color: Color(0xFFCBD5E1),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _generateAIInsights,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  isLoading ? loadingMessage : 'Generar análisis con IA',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.disabled)) {
                      return const Color(0xFFA855F7).withValues(alpha: 0.55);
                    }
                    if (states.contains(WidgetState.pressed)) {
                      return const Color(0xFF7E22CE);
                    }
                    if (states.contains(WidgetState.hovered)) {
                      return const Color(0xFF9333EA);
                    }
                    return const Color(0xFFA855F7);
                  }),
                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  elevation: const WidgetStatePropertyAll(0),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedListContent() {
    final raw = _asStringDynamicMap(overviewData?['raw']);
    final summaries = _asMapList(raw['studentSummaries']);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Listado detallado',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          if (summaries.isEmpty)
            const Text(
              'No hay datos para el rango seleccionado. Aplica filtros para refrescar.',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            )
          else
            ...summaries.take(40).map((student) {
              final name = (student['studentName'] ?? 'N/A').toString();
              final present = student['present'] ?? 0;
              final absent = student['absent'] ?? 0;
              final late = student['late'] ?? 0;
              final rate = (student['attendanceRate'] ?? '0%').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'P: $present · T: $late · A: $absent',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
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
                        rate,
                        style: const TextStyle(
                          color: Color(0xFF1976D2),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildInsightsContent() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : _generateAIInsights,
            icon: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              isLoading ? loadingMessage : 'Generar análisis con IA',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return const Color(0xFFA855F7).withValues(alpha: 0.55);
                }
                if (states.contains(WidgetState.pressed)) {
                  return const Color(0xFF7E22CE);
                }
                if (states.contains(WidgetState.hovered)) {
                  return const Color(0xFF9333EA);
                }
                return const Color(0xFFA855F7);
              }),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              elevation: const WidgetStatePropertyAll(0),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 14),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildAIInsightsPanel(),
      ],
    );
  }

  Widget _buildTopGlassBar(BuildContext context, String subtitle) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppDesignSystem.getSpaceMD(context),
            vertical: AppDesignSystem.getSpaceSM(context),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(
                color: _outlineVariant.withValues(alpha: 0.55),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _brandBlue,
                backgroundImage:
                    (_auth.currentUser?.photoURL?.isNotEmpty ?? false)
                    ? NetworkImage(_auth.currentUser!.photoURL!)
                    : null,
                child: (_auth.currentUser?.photoURL?.isNotEmpty ?? false)
                    ? null
                    : const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
              SizedBox(width: AppDesignSystem.getSpaceSM(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Asistencias',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesignSystem.titleLarge(context).copyWith(
                        color: _brandBlue,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesignSystem.bodySmall(context).copyWith(
                        color: _outline,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: AppDesignSystem.paddingSymmetric(
        context,
        horizontal: AppDesignSystem.spaceMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppDesignSystem.headlineLarge(context).copyWith(
              color: _brandBlue,
              fontSize: 40,
              height: 0.95,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
            ),
          ),
          SizedBox(height: AppDesignSystem.getSpaceSM(context)),
          Text(
            subtitle,
            style: AppDesignSystem.bodyMedium(
              context,
            ).copyWith(color: _outline, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1976D2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F6),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopGlassBar(context, 'Centro de reportes'),
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  SizedBox(height: AppDesignSystem.getSpaceMD(context)),
                  _buildDashboardHeader(
                    context,
                    title: 'Reportes',
                    subtitle: 'Gestión de asistencia y recursos curriculares.',
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 760;

                            final exportButtons = Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SizedBox(
                                  width: 118,
                                  child: OutlinedButton.icon(
                                    onPressed: isLoading
                                        ? null
                                        : _generatePDFReport,
                                    icon: const Icon(
                                      Icons.picture_as_pdf_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('PDF'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F172A),
                                      side: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 118,
                                  child: OutlinedButton.icon(
                                    onPressed: isLoading
                                        ? null
                                        : _generateExcelReport,
                                    icon: const Icon(
                                      Icons.table_view_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Excel'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF0F172A),
                                      side: const BorderSide(
                                        color: Color(0xFFE2E8F0),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );

                            if (isNarrow) {
                              return Align(
                                alignment: Alignment.centerRight,
                                child: exportButtons,
                              );
                            }

                            return Row(
                              children: [const Spacer(), exportButtons],
                            );
                          },
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            _buildTabButton(
                              label: 'Resumen',
                              index: 0,
                              primaryColor: primaryColor,
                            ),
                            _buildTabButton(
                              label: 'Listado',
                              index: 1,
                              primaryColor: primaryColor,
                            ),
                            _buildTabButton(
                              label: 'Análisis IA',
                              index: 2,
                              primaryColor: primaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Builder(
                  builder: (_) {
                    if (classrooms.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFB45309),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No hay aulas asignadas a este profesor.',
                                style: TextStyle(
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (activeTab == 0) return _buildOverviewContent();
                    if (activeTab == 1) return _buildDetailedListContent();
                    return _buildInsightsContent();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
