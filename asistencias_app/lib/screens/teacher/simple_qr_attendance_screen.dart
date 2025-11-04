import 'package:flutter/material.dart';

class SimpleQRAttendanceScreen extends StatefulWidget {
  const SimpleQRAttendanceScreen({super.key});

  @override
  State<SimpleQRAttendanceScreen> createState() =>
      _SimpleQRAttendanceScreenState();
}

class _SimpleQRAttendanceScreenState extends State<SimpleQRAttendanceScreen> {
  bool _isScanning = false;

  void _startQRScan() {
    setState(() => _isScanning = true);

    // Simular escaneo QR (en implementación real usarías mobile_scanner)
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isScanning = false);

      // Simular QR encontrado
      _showQRResult('STU_123456');
    });
  }

  void _showQRResult(String qrCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Escaneado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            Text('Código QR: $qrCode'),
            const SizedBox(height: 16),
            const Text('¡Asistencia registrada!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistencia QR'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Instrucciones
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      size: 64,
                      color: Colors.purple.shade700,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Escanear QR de Estudiante',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Toca el botón para activar la cámara y escanear el código QR del estudiante',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Botón de escaneo
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isScanning ? null : _startQRScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isScanning
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text('Escaneando...', style: TextStyle(fontSize: 18)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Iniciar Escaneo',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 32),

            // Lista de asistencias recientes (simulada)
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asistencias de Hoy',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: ListView.builder(
                          itemCount: 5, // Simulado
                          itemBuilder: (context, index) {
                            final students = [
                              'Juan Pérez',
                              'María García',
                              'Carlos López',
                              'Ana Martínez',
                              'Luis Rodríguez',
                            ];

                            final times = [
                              '08:15 AM',
                              '08:16 AM',
                              '08:18 AM',
                              '08:20 AM',
                              '08:22 AM',
                            ];

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.shade100,
                                child: Icon(
                                  Icons.check,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              title: Text(students[index]),
                              subtitle: Text(
                                'Registrado a las ${times[index]}',
                              ),
                              trailing: const Icon(
                                Icons.qr_code,
                                color: Colors.grey,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
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
