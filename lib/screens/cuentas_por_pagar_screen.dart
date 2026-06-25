import 'package:flutter/material.dart';
import '../models/cuenta_por_pagar.dart';
import '../services/firebase_service.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/responsive_scaffold.dart';

class CuentasPorPagarScreen extends StatefulWidget {
  const CuentasPorPagarScreen({super.key});

  @override
  State<CuentasPorPagarScreen> createState() => _CuentasPorPagarScreenState();
}

class _CuentasPorPagarScreenState extends State<CuentasPorPagarScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  Stream<List<CuentaPorPagar>> _streamCuentas() {
    return FirebaseService().getCuentasPorPagar();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ResponsiveScaffold(
      currentRoute: 'cuentas_por_pagar',
      title: 'Cuentas por Pagar',
      body: StreamBuilder<List<CuentaPorPagar>>(
        stream: _streamCuentas(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final cuentas = snapshot.data ?? [];
          final pendientes = cuentas.where((c) => c.saldoPendiente > 0).toList();

          if (pendientes.isEmpty) {
            return const PremiumEmptyState(
              icon: Icons.check_circle_outline,
              title: '¡Todo al día!',
              subtitle: 'No tienes cuentas por pagar pendientes.',
            );
          }

          // Ordenar por fecha de vencimiento (más próximas primero)
          pendientes.sort((a, b) {
            if (a.fechaVencimiento == null) return 1;
            if (b.fechaVencimiento == null) return -1;
            return a.fechaVencimiento!.compareTo(b.fechaVencimiento!);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pendientes.length,
            itemBuilder: (context, index) {
              final cpp = pendientes[index];
              final dias = cpp.diasAtraso;
              final esUrgente = dias > 0;

              return PremiumCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cpp.nombreProveedor,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                Text(
                                  'Compra: ${cpp.fechaCompra.day}/${cpp.fechaCompra.month}/${cpp.fechaCompra.year}',
                                  style: TextStyle(
                                      color: colorScheme.outline, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: esUrgente
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              esUrgente ? 'VENCIDA' : 'PENDIENTE',
                              style: TextStyle(
                                color: esUrgente ? Colors.red : Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vencimiento',
                                style: TextStyle(
                                    color: colorScheme.outline, fontSize: 12),
                              ),
                              Text(
                                cpp.fechaVencimiento == null
                                    ? 'Sin fecha'
                                    : '${cpp.fechaVencimiento!.day}/${cpp.fechaVencimiento!.month}/${cpp.fechaVencimiento!.year}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: esUrgente ? Colors.red : null,
                                ),
                              ),
                            ],
                          ),
                          if (esUrgente)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Días Atraso',
                                  style: TextStyle(color: Colors.red, fontSize: 12),
                                ),
                                Text(
                                  '$dias',
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text(
                                'Saldo Pendiente',
                                style: TextStyle(fontSize: 12),
                              ),
                              Text(
                                '\$${cpp.saldoPendiente.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _mostrarDialogoAbono(cpp),
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text('Registrar Abono / Pago'),
                        ),
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

  void _mostrarDialogoAbono(CuentaPorPagar cpp) {
    final TextEditingController montoCtrl = TextEditingController();
    bool procesando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Registrar Abono'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Proveedor: ${cpp.nombreProveedor}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Saldo Pendiente: \$${cpp.saldoPendiente.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.blue)),
              const Divider(height: 24),
              TextField(
                controller: montoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto del Abono',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: procesando ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: procesando
                  ? null
                  : () async {
                      final monto = double.tryParse(montoCtrl.text) ?? 0;
                      if (monto <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Ingresa un monto válido')),
                        );
                        return;
                      }
                      if (monto > cpp.saldoPendiente) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('El abono no puede superar el saldo')),
                        );
                        return;
                      }

                      setDialogState(() => procesando = true);
                      try {
                        await _firebaseService.registrarAbonoProveedor(
                            cpp.id, monto);
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Abono registrado con éxito'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setDialogState(() => procesando = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: procesando
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator())
                  : const Text('Confirmar Pago'),
            ),
          ],
        ),
      ),
    );
  }
}
