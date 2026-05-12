import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/venta.dart';
import '../services/firebase_service.dart';
import '../services/impresion_service.dart';
import '../services/auth_service.dart';
import 'detalle_venta_screen.dart';
import '../widgets/premium_widgets.dart'; // [UI Polish]
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';
import '../controllers/configuracion_controller.dart';

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
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)), // Extendido para evitar errores de aserción
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

    return ResponsiveScaffold(
      currentRoute: 'historial',
      title: 'Historial de Pedidos',
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_month_outlined),
          tooltip: 'Seleccionar Periodo',
          onPressed: _seleccionarFecha,
        ),
      ],
      body: ResponsiveLayout(
        mobileBody: _buildBody(formatter, isDesktop: false),
        tabletBody: _buildBody(formatter, isDesktop: true),
        desktopBody: _buildBody(formatter, isDesktop: true),
      ),
    );
  }

  Widget _buildBody(DateFormat formatter, {bool isDesktop = false}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 800),
        child: Column(
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
                  return const PremiumEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Sin Ventas',
                    subtitle: 'No hay pedidos en el periodo seleccionado.',
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

    return PremiumCard(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withAlpha(26),
          child: Icon(statusIcon, color: statusColor),
        ),
      title: Text(
        'Venta: ${venta.id.length >= 8 ? venta.id.substring(0, 8).toUpperCase() : venta.id.toUpperCase()}',
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
          // Botón de imprimir ticket (Fallo de hardware / Red de seguridad)
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Reimprimir Ticket',
            color: Colors.blue,
            onPressed: () async {
              try {
                // [FinOps] Reutilizamos el negocio en memoria si existe para no hacer lecturas extra a Firestore
                final negocio = ConfiguracionController.instance.negocio ?? await _firebaseService.getDatosNegocio();
                await ImpresionService.imprimirTicketVenta(
                  venta: venta, 
                  negocio: negocio, 
                  pagoCliente: venta.total,
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al reimprimir: $e'), backgroundColor: Colors.red),
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
    ),
    );
  }
}
