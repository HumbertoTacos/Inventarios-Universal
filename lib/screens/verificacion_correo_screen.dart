import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'auth_gate.dart';

class VerificacionCorreoScreen extends StatefulWidget {
  const VerificacionCorreoScreen({super.key});

  @override
  State<VerificacionCorreoScreen> createState() => _VerificacionCorreoScreenState();
}

class _VerificacionCorreoScreenState extends State<VerificacionCorreoScreen>
    with SingleTickerProviderStateMixin {
  bool _isSending = false;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();

    if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
      if (mounted) {
        setState(() => _isSending = true);
        try {
          await AuthService().completarRegistroDesdeTemporal();
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AuthGate()),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al finalizar registro: $e'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isSending = false);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aún no detectamos tu verificación. Revisa tu bandeja o spam.'),
          ),
        );
      }
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isSending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nuevo correo enviado. Revisa tu bandeja.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reenviar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          TextButton.icon(
            icon:  const Icon(Icons.logout_outlined, size: 18),
            label: const Text('Salir'),
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color:        AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border:       Border.all(color: AppColors.outline),
                boxShadow: [
                  BoxShadow(
                    color:     Colors.black.withAlpha(10),
                    blurRadius: 24,
                    offset:    const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono animado
                  ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color:        AppColors.primary.withAlpha(15),
                        shape:        BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_rounded,
                        size:  48,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'Verifica tu correo',
                    style: GoogleFonts.outfit(
                      fontSize:   24,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hemos enviado un enlace de activación a',
                    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    style: GoogleFonts.outfit(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Abre el enlace en tu correo y luego vuelve aquí.',
                    style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Steps visuales
                  _buildStepRow(1, 'Abre tu aplicación de correo', true),
                  _buildStepRow(2, 'Haz clic en el enlace de verificación', false),
                  _buildStepRow(3, 'Regresa aquí y toca el botón de abajo', false),
                  const SizedBox(height: 32),

                  if (_isSending)
                    const CircularProgressIndicator()
                  else ...[
                    FilledButton.icon(
                      icon:  const Icon(Icons.check_circle_outline),
                      label: const Text('Ya verifiqué mi correo'),
                      onPressed: _checkEmailVerified,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon:  const Icon(Icons.refresh, size: 18),
                      label: const Text('Reenviar correo'),
                      onPressed: _resendVerification,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(int step, String text, bool isFirst) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color:  AppColors.primary.withAlpha(20),
              shape:  BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: GoogleFonts.outfit(
                  fontSize:   13,
                  fontWeight: FontWeight.w700,
                  color:      AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
