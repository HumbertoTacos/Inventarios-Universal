import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'auth_gate.dart';

class CuentaInactivaScreen extends StatelessWidget {
  const CuentaInactivaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color:        AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border:       Border.all(color: AppColors.outline),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color:  AppColors.error.withAlpha(15),
                      shape:  BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_off_rounded, size: 40, color: AppColors.error),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Acceso desactivado',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tu cuenta ha sido dada de baja por el dueño o administrador del negocio. Contacta a tu encargado para más información.',
                    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon:  const Icon(Icons.logout_outlined, size: 18),
                    label: const Text('Cerrar sesión'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                    onPressed: () async {
                      await AuthService().logout();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
