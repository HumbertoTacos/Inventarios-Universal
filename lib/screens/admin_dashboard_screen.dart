import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _aprobarUsuario(BuildContext context, String uid, String nombreUsuario) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      if (!userDoc.exists) throw Exception('El usuario ya no existe.');

      final data = userDoc.data()!;
      final rol = data['rol'] as String? ?? 'dueño';
      final negocioId = data['negocioId'] as String?;

      final batch = FirebaseFirestore.instance.batch();

      // 1. Aprobar al usuario
      batch.update(FirebaseFirestore.instance.collection('usuarios').doc(uid), {
        'estatus': 'aprobado',
        'rol': rol == AuthService.rolDueno ? AuthService.rolDueno : 'cajero',
      });

      // 2. Si es empleado, limpiar la solicitud del negocio
      if (negocioId != null && rol != AuthService.rolDueno) {
        batch.delete(FirebaseFirestore.instance
            .collection('negocios')
            .doc(negocioId)
            .collection('solicitudes')
            .doc(uid));
      }

      await batch.commit();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Acceso para "$nombreUsuario" aprobado correctamente.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aprobar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService().currentUserData?.rol != AuthService.rolAdmin) {
      return const Scaffold(body: Center(child: Text('Acceso Denegado. Solo administradores de plataforma.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administrador'),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .where('estatus', isEqualTo: 'pendiente')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No hay cuentas pendientes por aprobar.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final uid = docs[index].id;
              final nombre = data['nombre'] ?? 'Sin nombre';
              final email = data['email'] ?? 'Sin correo';
              final negocio = data['negocioNombre'] ?? 'Negocio Desconocido';
              final rol = data['rol'] ?? 'Dueño';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: (rol == 'dueño' || rol == 'dueno') ? Colors.blue.shade100 : Colors.orange.shade100,
                        child: Icon(
                          (rol == 'dueño' || rol == 'dueno') ? Icons.business : Icons.person,
                          color: (rol == 'dueño' || rol == 'dueno') ? Colors.blue : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              negocio,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$nombre ($rol)',
                              style: const TextStyle(fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              email,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _aprobarUsuario(context, uid, nombre),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Aprobar'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
