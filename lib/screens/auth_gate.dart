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

        return FutureBuilder(
          future: AuthService().reloadUserData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const PremiumSplash(message: 'Iniciando sesión...');
            }

            if (snapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Error al cargar datos: ${snapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => AuthService().logout(),
                        child: const Text('Cerrar Sesión'),
                      ),
                    ],
                  ),
                ),
              );
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

            // Dueño → acceso completo (inicia en Ventas por preferencia de flujo)
            if (rol == AuthService.rolDueno) {
              return const VentasScreen();
            }

            // Empleado → solo Punto de Venta (actúa como cajero)
            if (rol == AuthService.rolEmpleado) {
              return const VentasScreen();
            }

            // Fallback
            return const VentasScreen();
          },
        );
      },
    );
  }
}
