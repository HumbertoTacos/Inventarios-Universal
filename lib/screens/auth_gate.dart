import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'inventario_screen.dart';
import 'login_screen.dart';
import 'espera_aprobacion_screen.dart';
import 'admin_dashboard_screen.dart';
import 'verificacion_correo_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        }

        if (!user.emailVerified) {
          return const VerificacionCorreoScreen();
        }

        return FutureBuilder(
          future: AuthService().reloadUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final userData = AuthService().currentUserData;
            
            if (userData == null) {
              return const LoginScreen();
            }

            if (userData.rol == 'admin') {
              return const AdminDashboardScreen();
            }

            if (userData.estatus == 'pendiente') {
              return const EsperaAprobacionScreen();
            }

            return const InventarioScreen();
          },
        );
      },
    );
  }
}
