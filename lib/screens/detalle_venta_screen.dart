import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/venta.dart';
import '../services/firebase_service.dart';

class DetalleVentaScreen extends StatefulWidget {
  final Venta venta;

  const DetalleVentaScreen({super.key, required this.venta});

  @override
  State<DetalleVentaScreen> createState() => _DetalleVentaScreenState();
}

class _DetalleVentaScreenState extends State<DetalleVentaScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _procesando = false;

  Future<void> _confirmarCancelacion() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar Venta?'),
        content: const Text(
          'Esta acción marcará la venta como cancelada y devolverá todos los productos al inventario. No se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _procesando = true);
      try {
        await _firebaseService.cancelarVenta(widget.venta);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Venta cancelada con éxito.'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _procesando = false);
      }
    }
  }

  Future<void> _mostrarModalDevolucion() async {
    double costoEnvioDev = 0.0;
    bool volverAVender = true;

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.assignment_return, color: Colors.orange),
                SizedBox(width: 10),
                Text('Procesar Devolución'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¿Cuál es el destino de los productos?', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Opción Restock (Verde)
                  GestureDetector(
                    onTap: () => setModalState(() => volverAVender = true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: volverAVender ? Colors.green.shade50 : Colors.transparent,
                        border: Border.all(color: volverAVender ? Colors.green : Colors.grey.shade300, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.inventory_2, color: volverAVender ? Colors.green : Colors.grey),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Regresar a Inventario', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('El producto se sumará al stock disponible.', style: TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Opción Merma (Rojo)
                  GestureDetector(
                    onTap: () => setModalState(() => volverAVender = false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: !volverAVender ? Colors.red.shade50 : Colors.transparent,
                        border: Border.all(color: !volverAVender ? Colors.red : Colors.grey.shade300, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: !volverAVender ? Colors.red : Colors.grey),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Registrar como Merma', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('Producto dañado. NO se sumará al stock.', style: TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text('Gastos adicionales', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Costo envío de retorno (\$)',
                      hintText: '0.00',
                      prefixIcon: Icon(Icons.delivery_dining),
                      helperText: 'Gastos de mensajería para recuperar el paquete',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => costoEnvioDev = double.tryParse(val) ?? 0.0,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: volverAVender ? Colors.green : Colors.red),
                child: const Text('Finalizar Devolución'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      if (!mounted) return;
      setState(() => _procesando = true);
      try {
        await _firebaseService.devolverVenta(
          venta: widget.venta,
          costoEnvioDevolucion: costoEnvioDev,
          volverAVender: volverAVender,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Devolución registrada.'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _procesando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final venta = widget.venta;
    final esEditable = venta.estado == 'completada';

    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido: ${venta.id.substring(0, 8).toUpperCase()}'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _procesando
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCabeceraEstado(venta),
                      const SizedBox(height: 24),
                      const Text('Productos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: venta.items.length,
                          separatorBuilder: (ctx, idx) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final item = venta.items[idx];
                            return ListTile(
                              title: Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${item.cantidad} x \$${item.precioUnitario.toStringAsFixed(2)}'),
                              trailing: Text(
                                '\$${item.subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildResumenFinanciero(venta),
                      const SizedBox(height: 32),
                      if (esEditable) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _confirmarCancelacion,
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                label: const Text('Cancelar Venta', style: TextStyle(color: Colors.red)),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _mostrarModalDevolucion,
                                style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
                                icon: const Icon(Icons.assignment_return),
                                label: const Text('Devolución'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCabeceraEstado(Venta venta) {
    Color color;
    String texto;
    switch (venta.estado) {
      case 'cancelada':
        color = Colors.red;
        texto = 'ESTADO: CANCELADA';
        break;
      case 'devuelta':
        color = Colors.orange.shade800;
        texto = 'ESTADO: DEVUELTA';
        break;
      default:
        color = Colors.green;
        texto = 'ESTADO: COMPLETADA';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        border: Border.all(color: color.withAlpha(100), width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(DateFormat('EEEE d MMMM, yyyy - HH:mm').format(venta.fecha),
              style: TextStyle(color: color.withAlpha(204), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildResumenFinanciero(Venta venta) {
    final subtotalProductos = venta.items.fold(0.0, (sum, i) => sum + i.subtotal);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resumen de Pago', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal productos:'),
            Text('\$${subtotalProductos.toStringAsFixed(2)}'),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Envío (${venta.envioPagadoPorVendedor ? 'Vendedor' : 'Cliente'}):'),
            Text('\$${venta.costoEnvio.toStringAsFixed(2)}'),
          ],
        ),
        if (venta.estado == 'devuelta' && venta.costoEnvioDevolucion > 0) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Costo envío retorno (Pérdida):', style: TextStyle(color: Colors.red)),
              Text('\$${venta.costoEnvioDevolucion.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ],
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TOTAL:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(
              '\$${venta.total.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      ],
    );
  }
}
