import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/venta.dart';
import '../services/firebase_service.dart';
import '../services/impresora_service.dart';
import '../services/auth_service.dart';
import 'detalle_venta_screen.dart';

class HistorialVentasScreen extends StatefulWidget {
  const HistorialVentasScreen({super.key});

  @override
  State<HistorialVentasScreen> createState() => _HistorialVentasScreenState();
}

class _HistorialVentasScreenState extends State<HistorialVentasScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  DateTime _fechaInicio = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  late DateTime _fechaFin;

  @override
  void initState() {
    super.initState();
    _fechaInicio = DateTime(_fechaInicio.year, _fechaInicio.month, _fechaInicio.day);
    _fechaFin = _fechaInicio.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  void _cambiarSemana(int semanas) {
    setState(() {
      _fechaInicio = _fechaInicio.add(Duration(days: semanas * 7));
      _fechaFin = _fechaInicio.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    });
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Pedidos'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          // Selector de Semana
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _cambiarSemana(-1),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Semana del',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        '${formatter.format(_fechaInicio)} - ${formatter.format(_fechaFin)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _cambiarSemana(1),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<Venta>>(
              stream: _firebaseService.getVentasPorRango(_fechaInicio, _fechaFin),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final ventas = snapshot.data ?? [];

                if (ventas.isEmpty) {
                  return const Center(
                    child: Text('No hay pedidos en esta semana.'),
                  );
                }

                return ListView.separated(
                  itemCount: ventas.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final venta = ventas[index];
                    return _buildVentaTile(venta);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVentaTile(Venta venta) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (venta.estado) {
      case 'cancelada':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_outlined;
        statusText = 'Cancelada';
        break;
      case 'devuelta':
        statusColor = Colors.orange;
        statusIcon = Icons.assignment_return_outlined;
        statusText = 'Devuelta';
        break;
      default:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Completada';
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withAlpha(26),
        child: Icon(statusIcon, color: statusColor),
      ),
      title: Text(
        'Venta: ${venta.id.substring(0, 8).toUpperCase()}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${DateFormat('dd/MM/yy HH:mm').format(venta.fecha)} • ${venta.items.length} items',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${venta.total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 4),
          // Botón de imprimir ticket
          if (venta.estado == 'completada')
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Imprimir ticket',
              color: Colors.blueGrey,
              onPressed: () async {
                try {
                  final negocio = AuthService().currentUserData?.negocioNombre ?? 'Mi Negocio';
                  await ImpresoraService.imprimirTicket(
                    venta: venta,
                    negocioNombre: negocio,
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al imprimir: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleVentaScreen(venta: venta),
          ),
        );
      },
    );
  }
}
