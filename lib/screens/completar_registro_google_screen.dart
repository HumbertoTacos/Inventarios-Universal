import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';

class CompletarRegistroGoogleScreen extends StatefulWidget {
  const CompletarRegistroGoogleScreen({super.key});

  @override
  State<CompletarRegistroGoogleScreen> createState() =>
      _CompletarRegistroGoogleScreenState();
}

class _CompletarRegistroGoogleScreenState
    extends State<CompletarRegistroGoogleScreen> {
  final _negocioController = TextEditingController();
  final _codigoController = TextEditingController();
  bool _isCreatingBusiness = true;
  bool _isLoading = false;

  void _completar() async {
    final negocio = _negocioController.text.trim();
    final codigo = _codigoController.text.trim();

    if (_isCreatingBusiness && negocio.isEmpty) {
      _msg('Ingresa el nombre de tu negocio.');
      return;
    }
    if (!_isCreatingBusiness && codigo.isEmpty) {
      _msg('Ingresa el código de invitación.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await AuthService().completarRegistroGoogle(
        negocioNombre: _isCreatingBusiness
            ? _negocioController.text.trim()
            : null,
        codigoInvitacion: !_isCreatingBusiness
            ? _codigoController.text.trim()
            : null,
      );
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
      }
    } catch (e) {
      if (mounted) {
        _msg('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _msg(String m, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                'Hemos vinculado tu cuenta de Google. Selecciona si quieres crear un nuevo negocio o ingresar a uno usando un Código de Invitación:',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: Text(
                  _isCreatingBusiness
                      ? 'Soy Dueño (Crear Negocio)'
                      : 'Soy Empleado (Tengo Código)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                value: _isCreatingBusiness,
                activeThumbColor: Colors.blue,
                inactiveThumbColor: Colors.orange,
                inactiveTrackColor: Colors.orange.withOpacity(0.3),
                onChanged: (val) {
                  setState(() {
                    _isCreatingBusiness = val;
                    if (val) {
                      _codigoController.clear();
                    } else {
                      _negocioController.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_isCreatingBusiness)
                TextField(
                  controller: _negocioController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de tu Negocio',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                TextField(
                  controller: _codigoController,
                  decoration: const InputDecoration(
                    labelText: 'Código de Invitación (6 letras)',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _completar,
                      child: const Text(
                        'Completar y enviar solicitud',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await AuthService().logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AuthGate()),
                    );
                  }
                },
                child: const Text(
                  'Cancelar e iniciar con otra cuenta',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
