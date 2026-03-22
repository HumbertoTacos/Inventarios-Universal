import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';

class EsperaAprobacionScreen extends StatelessWidget {
  const EsperaAprobacionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuenta Pendiente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const AuthGate())
                );
              }
            },
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_empty, size: 100, color: Colors.orange),
              const SizedBox(height: 24),
              const Text(
                'Tu registro está en revisión',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Para proteger la seguridad de la plataforma, un administrador debe aprobar tu cuenta antes de que puedas acceder a la base de datos de tu negocio.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar estado'),
                onPressed: () async {
                  await AuthService().reloadUserData();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AuthGate())
                    );
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
