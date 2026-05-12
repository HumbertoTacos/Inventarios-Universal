import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../services/firebase_service.dart';
import '../widgets/responsive_scaffold.dart';
import '../widgets/premium_widgets.dart';

class ActualizacionPreciosScreen extends StatefulWidget {
  const ActualizacionPreciosScreen({super.key});

  @override
  State<ActualizacionPreciosScreen> createState() => _ActualizacionPreciosScreenState();
}

class _ActualizacionPreciosScreenState extends State<ActualizacionPreciosScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(Producto p) {
    if (!_controllers.containsKey(p.id)) {
      _controllers[p.id] = TextEditingController(text: p.precio.toString());
    }
    return _controllers[p.id]!;
  }

  Future<void> _actualizarPrecio(Producto p, String nuevoPrecioStr) async {
    final nuevoPrecio = double.tryParse(nuevoPrecioStr);
    if (nuevoPrecio == null || nuevoPrecio < 0) return;
    if (nuevoPrecio == p.precio) return;

    try {
      final productoEditado = p.copyWith(precio: nuevoPrecio);
      await _firebaseService.actualizarProducto(productoEditado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Precio de "${p.nombre}" actualizado a \$${nuevoPrecio.toStringAsFixed(2)}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentRoute: '/actualizacion_precios',
      title: 'Actualización Rápida de Precios',
      body: StreamBuilder<List<Producto>>(
        stream: _firebaseService.getProductos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final productos = snapshot.data ?? [];
          if (productos.isEmpty) {
            return const PremiumEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No hay productos',
              subtitle: 'Agrega productos para actualizar sus precios.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: productos.length,
            itemBuilder: (context, index) {
              final p = productos[index];
              final ctrl = _getController(p);

              return PremiumCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Costo Promedio: \$${p.costoPromedio.toStringAsFixed(2)}',
                            style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: ctrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Precio Venta',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onFieldSubmitted: (val) => _actualizarPrecio(p, val),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
