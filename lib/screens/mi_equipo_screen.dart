import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class MiEquipoScreen extends StatefulWidget {
  const MiEquipoScreen({super.key});

  @override
  State<MiEquipoScreen> createState() => _MiEquipoScreenState();
}

class _MiEquipoScreenState extends State<MiEquipoScreen> {
  String _codigoActual = '';
  bool _isLoadingCodigo = true;

  @override
  void initState() {
    super.initState();
    _cargarCodigo();
  }

  Future<void> _cargarCodigo() async {
    setState(() => _isLoadingCodigo = true);
    try {
      final code = await AuthService().obtenerCodigoInvitacionActual();
      if (mounted) setState(() => _codigoActual = code);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingCodigo = false);
    }
  }

  Future<void> _regenerarCodigo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Generar nuevo código?'),
        content: const Text('Esto invalidará el código actual. Quien intente usar el viejo código ya no podrá unirse.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, generar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoadingCodigo = true);
    try {
      final code = await AuthService().regenerarCodigoInvitacion();
      if (mounted) setState(() => _codigoActual = code);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingCodigo = false);
    }
  }

  Future<void> _despedirEmpleado(String uid, String nombreEmpleado) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Dar de baja?'),
        content: Text('¿Seguro que deseas revocar el acceso a $nombreEmpleado? Se bloqueará su entrada al inventario de inmediato.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, despedir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await AuthService().despedirEmpleado(uid);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empleado dado de baja')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService().currentUserData?.rol != 'dueño') {
      return const Scaffold(body: Center(child: Text('Acceso Denegado. Solo el dueño puede ver esta pantalla.')));
    }

    final currentNegocioId = AuthService().currentNegocioId;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Equipo y Accesos')),
      body: Column(
        children: [
          // Sección de Código
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.blue.withOpacity(0.1),
            width: double.infinity,
            child: Column(
              children: [
                const Text('Tu Código de Invitación para nuevos empleados:', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                _isLoadingCodigo 
                  ? const CircularProgressIndicator() 
                  : SelectableText(
                      _codigoActual, 
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.blueAccent),
                    ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerar Código'),
                  onPressed: _isLoadingCodigo ? null : _regenerarCodigo,
                )
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          // Lista de Empleados
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .where('negocioId', isEqualTo: currentNegocioId)
                  .where('rol', isNotEqualTo: 'dueño') // Filtramos a los empleados
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                
                // Firestore requiere filtros adicionales en memoria a veces si usamos múltiples wheres complejos
                final empleados = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['rol'] == 'empleado' || data['rol'] == 'usuario';
                }).toList();

                if (empleados.isEmpty) {
                  return const Center(child: Text('No tienes empleados registrados en tu equipo.'));
                }

                return ListView.builder(
                  itemCount: empleados.length,
                  itemBuilder: (context, index) {
                    final data = empleados[index].data() as Map<String, dynamic>;
                    final uid = empleados[index].id;
                    final nombre = data['nombre'] ?? 'Sin nombre';
                    final email = data['email'] ?? 'Sin correo';
                    final estatus = data['estatus'] ?? '';
                    final isActivo = estatus != 'despedido' && estatus != 'inactivo';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isActivo ? Colors.green : Colors.red,
                          child: Icon(isActivo ? Icons.person : Icons.person_off, color: Colors.white),
                        ),
                        title: Text(nombre, style: TextStyle(fontWeight: FontWeight.bold, decoration: isActivo ? null : TextDecoration.lineThrough)),
                        subtitle: Text('$email\nEstatus: ${estatus.toUpperCase()}'),
                        isThreeLine: true,
                        trailing: isActivo 
                          ? IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              tooltip: 'Despedir/Bloquear',
                              onPressed: () => _despedirEmpleado(uid, nombre),
                            )
                          : const Icon(Icons.block, color: Colors.red),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
