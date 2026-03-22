import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _negocioController = TextEditingController();
  final _codigoController = TextEditingController();
  bool _isCreatingBusiness = true;
  bool _isLoading = false;

  void _registrar() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().register(
        nombre: _nombreController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        negocioNombre: _isCreatingBusiness ? _negocioController.text.trim() : null,
        codigoInvitacion: !_isCreatingBusiness ? _codigoController.text.trim() : null,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
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
      appBar: AppBar(title: const Text('Registrar Negocio')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Crea tu cuenta', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: 'Tu Nombre Completo', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Contraseña', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(
                  _isCreatingBusiness ? 'Soy Dueño (Crear Negocio)' : 'Soy Empleado (Tengo Código)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                value: _isCreatingBusiness,
                activeColor: Colors.blue,
                inactiveThumbColor: Colors.orange,
                inactiveTrackColor: Colors.orange.withOpacity(0.3),
                onChanged: (val) {
                  setState(() {
                    _isCreatingBusiness = val;
                    if (val) _codigoController.clear();
                    else _negocioController.clear();
                  });
                },
              ),
              const SizedBox(height: 8),
              if (_isCreatingBusiness)
                TextField(
                  controller: _negocioController,
                  decoration: const InputDecoration(labelText: 'Nombre de tu Negocio', border: OutlineInputBorder()),
                )
              else
                TextField(
                  controller: _codigoController,
                  decoration: const InputDecoration(labelText: 'Código de Invitación (Proporcionado por dueño)', border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.characters,
                ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _registrar,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                      child: const Text('Completar Registro', style: TextStyle(fontSize: 16)),
                    ),
              const SizedBox(height: 16),
              if (!_isLoading)
                OutlinedButton.icon(
                  icon: const Icon(Icons.login, color: Colors.red),
                  label: const Text('Continuar con Google'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: () async {
                    setState(() => _isLoading = true);
                    try {
                      await AuthService().loginWithGoogle();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AuthGate()),
                          (route) => false,
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
