import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';

class CompletarRegistroGoogleScreen extends StatefulWidget {
  const CompletarRegistroGoogleScreen({super.key});

  @override
  State<CompletarRegistroGoogleScreen> createState() => _CompletarRegistroGoogleScreenState();
}

class _CompletarRegistroGoogleScreenState extends State<CompletarRegistroGoogleScreen> {
  final _negocioController = TextEditingController();
  bool _isLoading = false;

  void _completar() async {
    if (_negocioController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      await AuthService().completarRegistroGoogle(
        negocioNombre: _negocioController.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthGate())
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completar Registro')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.store, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 16),
              const Text(
                '¡Ya casi terminamos!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hemos vinculado tu cuenta de Google. Ahora, para configurar tu base de datos y aislarla correctamente, dinos cómo se llama tu negocio:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _negocioController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de tu Negocio',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _completar,
                      child: const Text('Completar y enviar solicitud', style: TextStyle(fontSize: 16)),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await AuthService().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AuthGate())
                    );
                  }
                },
                child: const Text('Cancelar e iniciar con otra cuenta', style: TextStyle(color: Colors.red)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
