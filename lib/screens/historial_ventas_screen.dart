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

  Future<void> _seleccionarFecha() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _fechaInicio, end: _fechaFin),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                  onPrimary: Theme.of(context).colorScheme.onPrimary,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _fechaInicio = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _fechaFin = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Pedidos'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Seleccionar Periodo',
            onPressed: _seleccionarFecha,
          ),
        ],
      ),
      body: Column(
        children: [
          // Visualizador de Rango
          GestureDetector(
            onTap: _seleccionarFecha,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.date_range, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    '${formatter.format(_fechaInicio)} - ${formatter.format(_fechaFin)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit, size: 14, color: Colors.grey),
                ],
              ),
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
