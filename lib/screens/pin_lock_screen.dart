import 'package:flutter/material.dart';
import '../models/empleado.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({Key? key}) : super(key: key);

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';
  bool _isLoading = false;

  void _onKeypadPressed(String val) {
    if (_pin.length < 4) {
      setState(() {
        _pin += val;
      });
      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);
    try {
      final empleados = await FirebaseService().getEmpleados();
      final empleado = empleados.where((e) => e.pin == _pin && e.activo).firstOrNull;

      if (empleado != null) {
        AuthService().setEmpleadoActivo(empleado);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/pos'); // Ajustar según ruta del POS
        }
      } else {
        setState(() {
          _pin = '';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN incorrecto o empleado inactivo')),
        );
      }
    } catch (e) {
      setState(() {
        _pin = '';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: \$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_rounded, size: 80, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'Inventarios Universal',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    'Ingresa tu PIN de Acceso',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _pin.length ? Colors.blueAccent : Colors.grey.shade300,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 48),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    _buildNumpad(),
                ],
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await AuthService().logout();
                    if (mounted) Navigator.pushReplacementNamed(context, '/');
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text(
                    'Cerrar sesión de Administrador',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildKey('1'), _buildKey('2'), _buildKey('3'),
          _buildKey('4'), _buildKey('5'), _buildKey('6'),
          _buildKey('7'), _buildKey('8'), _buildKey('9'),
          const SizedBox(), _buildKey('0'), _buildBackspace(),
        ],
      ),
    );
  }

  Widget _buildKey(String value) {
    return InkWell(
      onTap: () => _onKeypadPressed(value),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Colors.blueGrey),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspace() {
    return InkWell(
      onTap: _onBackspace,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.backspace_outlined, size: 32, color: Colors.blueGrey),
        ),
      ),
    );
  }
}
