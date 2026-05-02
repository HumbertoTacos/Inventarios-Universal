import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'inventario_screen.dart';
import 'ventas_screen.dart';
import 'login_screen.dart';
import 'espera_aprobacion_screen.dart';
import 'admin_dashboard_screen.dart';
import 'verificacion_correo_screen.dart';
import 'completar_registro_google_screen.dart';
import 'cuenta_inactiva_screen.dart';
import '../widgets/premium_splash.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const PremiumSplash();
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        if (!user.emailVerified) {
          return const VerificacionCorreoScreen();
        }

        return FutureBuilder<void>(
          future: AuthService().reloadUserData(),
          builder: (context, userSnapshot) {
            // Mientras carga los datos del usuario, mostramos splash
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const PremiumSplash(message: 'Cargando perfil...');
            }

            final userData = AuthService().currentUserData;
            
            // Si después de cargar no hay datos, es un usuario nuevo de Google
            if (userData == null) {
              return const CompletarRegistroGoogleScreen();
            }

            // Separación estricta por Roles Normalizados
            final rol = userData.rol;
            
            if (rol == AuthService.rolAdmin) {
              return const AdminDashboardScreen();
            }

            // Bloqueo por estatus
            if (userData.estatus == 'inactivo' || userData.estatus == 'despedido') {
              return const CuentaInactivaScreen();
            }

            if (userData.estatus != 'aprobado') {
              return const EsperaAprobacionScreen();
            }

            return const VentasScreen();
          },
        );
      },
    );
  }
}
