import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';

class CuentaInactivaScreen extends StatelessWidget {
  const CuentaInactivaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso Restringido'),
        backgroundColor: Colors.red,
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
              const Icon(Icons.block, size: 100, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Acceso a la Flotilla Desactivado',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Ya no formas parte del negocio o tu cuenta ha sido dada de baja por el administrador/dueño. Por lo tanto, no puedes ver ni editar la base de datos de esta empresa.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.arrow_back),
                label: const Text('Cerrar sesión e iniciar con otra cuenta'),
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
        ),
      ),
    );
  }
}
