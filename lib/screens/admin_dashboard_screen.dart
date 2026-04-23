import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Future<void> _aprobarUsuario(BuildContext context, String uid, String nombreUsuario) async {
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
        'estatus': 'aprobado',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comercio "$nombreUsuario" ha sido aprobado.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al aprobar: $e')),
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
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final uid = docs[index].id;
              final nombre = data['nombre'] ?? 'Sin nombre';
              final email = data['email'] ?? 'Sin correo';
              final negocio = data['negocioNombre'] ?? 'Desconocido';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.store, size: 40),
                  title: Text(negocio, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$nombre\n$email'),
                  isThreeLine: true,
                  trailing: ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Aprobar', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _aprobarUsuario(context, uid, negocio),
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
