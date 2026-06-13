import 'package:flutter/material.dart';
import '../models/venta.dart';
import '../services/firebase_service.dart';

class ReporteComisionesScreen extends StatelessWidget {
  const ReporteComisionesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporte de Comisiones'),
        centerTitle: true,
      ),
      body: Builder(
        builder: (context) {
          final hoy = DateTime.now();
          final inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1));
          final inicio = DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day);
          final fin = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);

          return StreamBuilder<List<Venta>>(
            stream: FirebaseService().getVentasPorRango(inicio, fin),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: \${snapshot.error}'));
              }

              final ventas = snapshot.data ?? [];
              final ventasSemana = ventas.where((v) => v.estado != 'cancelada').toList();

          // Agrupar por empleadoNombre
          final Map<String, double> comisionesPorEmpleado = {};
          for (var venta in ventasSemana) {
            final nombre = venta.empleadoNombre ?? 'Sin Empleado';
            comisionesPorEmpleado[nombre] = (comisionesPorEmpleado[nombre] ?? 0.0) + venta.comisionGenerada;
          }

          if (comisionesPorEmpleado.isEmpty) {
            return const Center(child: Text('No hay comisiones en esta semana.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: comisionesPorEmpleado.length,
            itemBuilder: (context, index) {
              final entry = comisionesPorEmpleado.entries.elementAt(index);
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: const Text('Comisión generada esta semana'),
                  trailing: Text(
                    '\$${entry.value.toStringAsFixed(2)} MXN',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              );
            },
          );
        },
      );
    },
    ),
    );
  }
}
