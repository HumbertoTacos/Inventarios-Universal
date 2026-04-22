import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';

class VerificacionCorreoScreen extends StatefulWidget {
  const VerificacionCorreoScreen({super.key});

  @override
  State<VerificacionCorreoScreen> createState() => _VerificacionCorreoScreenState();
}

class _VerificacionCorreoScreenState extends State<VerificacionCorreoScreen> {
  bool _isSending = false;

  Future<void> _checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    
    if (FirebaseAuth.instance.currentUser?.emailVerified ?? false) {
      if (mounted) {
        setState(() => _isSending = true); // Usamos el loader
        try {
          // Fase Final: Mover de pre_registro a colecciones reales
          await AuthService().completarRegistroDesdeTemporal();
          
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AuthGate())
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al finalizar registro: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _isSending = false);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aún no vemos tu verificación. Revisa tu bandeja de entrada o spam y abre el enlace de Firebase.')),
        );
      }
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _isSending = true);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Te hemos enviado un nuevo correo de verificación.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al reenviar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Es posible que pasen unos segundos, damos opción cómoda de checar
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar Correo'),
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
              const Icon(Icons.mark_email_unread, size: 100, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text(
                'Verifica tu correo electrónico',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Hemos enviado un enlace de verificación a:\n${FirebaseAuth.instance.currentUser?.email ?? ''}\n\nPor favor, abre tu correo y haz clic en el enlace para validar que la dirección existe.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Ya lo verifiqué'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                onPressed: _checkEmailVerified,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isSending ? null : _resendVerification,
                child: _isSending
                    ? const CircularProgressIndicator()
                    : const Text('Reenviar correo de verificación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
