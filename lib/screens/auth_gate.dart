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
              return const CompletarRegistroGoogleScreen();
            }

            // Separación estricta por Roles Normalizados
            final rol = userData.rol; // Ya viene normalizado del AuthService
            
            if (rol == AuthService.rolAdmin) {
              return const AdminDashboardScreen();
            }

            // Bloqueo por estatus (Inactivo / Despedido) para Dueños y Empleados
            if (userData.estatus == 'inactivo' || userData.estatus == 'despedido') {
              return const CuentaInactivaScreen();
            }

            // Seguridad: Validar que el usuario esté APROBADO por el Admin
            if (userData.estatus != 'aprobado') {
              return const EsperaAprobacionScreen();
            }

            // Dueño → acceso completo al inventario
            if (rol == AuthService.rolDueno) {
              return const InventarioScreen();
            }

            // Empleado → solo Punto de Venta (actúa como cajero)
            if (rol == AuthService.rolEmpleado) {
              return const VentasScreen();
            }

            // Fallback
            return const InventarioScreen();
          },
        );
      },
    );
  }
}
