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
  final _confirmPasswordController = TextEditingController();
  final _negocioController = TextEditingController();
  final _codigoController = TextEditingController();
  
  bool _isCreatingBusiness = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void _registrar() async {
    final nombre = _nombreController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validaciones básicas de UX
    if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
      _mostrarMensaje('Por favor, llena todos los campos obligatorios.');
      return;
    }

    if (password != confirmPassword) {
      _mostrarMensaje('Las contraseñas no coinciden.');
      return;
    }

    if (password.length < 6) {
      _mostrarMensaje('La contraseña debe tener al menos 6 caracteres.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().registerAuthOnly(
        nombre: nombre,
        email: email,
        password: password,
        negocioNombre: _isCreatingBusiness ? _negocioController.text.trim() : null,
        codigoInvitacion: !_isCreatingBusiness ? _codigoController.text.trim() : null,
      );
      if (mounted) {
        // Al NO crear el documento en Firestore aún, el AuthGate detectará emailVerified == false
        // y mandará al usuario a VerificacionCorreoScreen automáticamente.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) _mostrarMensaje('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarMensaje(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                decoration: const InputDecoration(labelText: 'Tu Nombre Completo', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Correo Electrónico', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña', 
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirmar Contraseña', 
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(
                  _isCreatingBusiness ? 'Soy Dueño (Crear Negocio)' : 'Soy Empleado (Tengo Código)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                value: _isCreatingBusiness,
                activeColor: Colors.blue,
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
                  decoration: const InputDecoration(labelText: 'Nombre de tu Negocio', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
                )
              else
                TextField(
                  controller: _codigoController,
                  decoration: const InputDecoration(labelText: 'Código de Invitación', border: OutlineInputBorder(), prefixIcon: Icon(Icons.vpn_key_outlined)),
                  textCapitalization: TextCapitalization.characters,
                ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _registrar,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Completar Registro', style: TextStyle(fontSize: 16)),
                    ),
              const SizedBox(height: 16),
              if (!_isLoading)
                OutlinedButton.icon(
                  icon: const Icon(Icons.login, color: Colors.blue),
                  label: const Text('Continuar con Google'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
                      if (mounted) _mostrarMensaje('Error: $e');
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
