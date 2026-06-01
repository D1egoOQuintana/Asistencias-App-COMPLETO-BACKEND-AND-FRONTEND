import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

/// Pantalla de bloqueo para sesiones administrador en la app móvil.
///
/// La app móvil está reservada al rol docente. Cuando una cuenta admin queda
/// autenticada en móvil, se muestra esta pantalla en lugar del panel,
/// invitando a usar el panel web y a cerrar sesión.
///
/// No toca pantallas de docente, lógica QR, servicios ni Firestore: sólo lee
/// [AuthProvider] para cerrar sesión.
class MobileRoleBlockedScreen extends StatelessWidget {
  const MobileRoleBlockedScreen({super.key});

  static const Color _brandBlue = Color(0xFF1976D2);
  static const Color _surface = Color(0xFFF8FAFB);
  static const Color _darkText = Color(0xFF0B1F3B);
  static const Color _outline = Color(0xFF5F6470);

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _brandBlue.withValues(alpha: 0.16)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: _brandBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.desktop_windows_rounded,
                        size: 40,
                        color: _brandBlue,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Acceso administrador desde el panel web',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _darkText,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'El acceso administrador está disponible desde el panel web.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: _outline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed:
                            auth.isLoading ? null : () => auth.signOut(),
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _brandBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _brandBlue.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: auth.isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.logout_rounded, size: 20),
                        label: const Text(
                          'Cerrar sesión',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
