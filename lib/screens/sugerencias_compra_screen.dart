import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../services/firebase_service.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/responsive_scaffold.dart';

class SugerenciasCompraScreen extends StatefulWidget {
  const SugerenciasCompraScreen({super.key});

  @override
  State<SugerenciasCompraScreen> createState() => _SugerenciasCompraScreenState();
}

class _SugerenciasCompraScreenState extends State<SugerenciasCompraScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ResponsiveScaffold(
      currentRoute: 'sugerencias_compra',
      title: 'Sugerencias de Compra',
      body: StreamBuilder<List<Producto>>(
        // [FinOps] Bounded Stream: límite de 200 para cubrir catálogos grandes.
        // El filtrado a bajo stock se hace localmente — costo cero adicional.
        stream: _firebaseService.getProductosStreamLimitado(limite: 200),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProductos = snapshot.data ?? [];
          // Filtrar productos con stock bajo
          final bajoStock = allProductos.where((p) => p.cantidad <= p.stockMinimo).toList();

          if (bajoStock.isEmpty) {
            return const PremiumEmptyState(
              icon: Icons.check_circle_outline,
              title: 'Inventario Saludable',
              subtitle: 'Todos tus productos están por encima del stock mínimo.',
            );
          }

          // Agrupar por proveedor
          final Map<String, List<Producto>> agrupados = {};
          for (var p in bajoStock) {
            final key = p.proveedorNombre ?? 'Sin Proveedor Asignado';
            agrupados.putIfAbsent(key, () => []).add(p);
          }

          final proveedores = agrupados.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: proveedores.length,
            itemBuilder: (context, index) {
              final provNombre = proveedores[index];
              final productos = agrupados[provNombre]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping_outlined, color: colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          provNombre.toUpperCase(),
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Divider(color: colorScheme.primaryContainer)),
                      ],
                    ),
                  ),
                  ...productos.map((p) => PremiumCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(p.atributoVisual),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${p.cantidad}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                ' / ${p.stockMinimo}',
                                style: TextStyle(
                                  color: colorScheme.outline,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'STOCK ACTUAL vs MÍN',
                            style: TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
