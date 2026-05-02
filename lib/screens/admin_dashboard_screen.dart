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
            debugPrint('Error en Stream de Admin: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text('Error de conexión: ${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay cuentas pendientes por aprobar.'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final uid = doc.id;
              
              final nombre = data['nombre'] ?? 'Sin nombre';
              final email = data['email'] ?? 'Sin correo';
              final negocio = data['negocioNombre'] ?? 'Negocio Desconocido';
              final String rolRaw = (data['rol'] as String? ?? 'dueño').toLowerCase().trim();
              final bool esDueno = rolRaw == 'dueño' || rolRaw == 'dueno';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: esDueno ? Colors.blue.shade100 : Colors.orange.shade100,
                    child: Icon(
                      esDueno ? Icons.business : Icons.person,
                      color: esDueno ? Colors.blue : Colors.orange,
                    ),
                  ),
                  title: Text(
                    email,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$negocio - $nombre (${esDueno ? 'Dueño' : 'Empleado'})',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _aprobarUsuario(context, uid, nombre),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Aprobar'),
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
