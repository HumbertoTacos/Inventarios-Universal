import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'auth_gate.dart';

class EsperaAprobacionScreen extends StatelessWidget {
  const EsperaAprobacionScreen({super.key});

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
                      color:  AppColors.warning.withAlpha(20),
                      shape:  BoxShape.circle,
                    ),
                    child: const Icon(Icons.hourglass_top_rounded, size: 40, color: AppColors.warning),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Cuenta en revisión',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Un administrador debe aprobar tu acceso antes de que puedas usar el sistema. Esto nos protege de accesos no autorizados.',
                    style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon:  const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Verificar estado'),
                    onPressed: () async {
                      await AuthService().reloadUserData();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon:  const Icon(Icons.logout_outlined, size: 18),
                    label: const Text('Cerrar sesión'),
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
