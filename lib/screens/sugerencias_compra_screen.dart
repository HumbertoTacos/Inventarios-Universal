import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/producto.dart';
import '../services/firebase_service.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/responsive_scaffold.dart';

class SugerenciasCompraScreen extends StatefulWidget {
  const SugerenciasCompraScreen({super.key});

  @override
  State<SugerenciasCompraScreen> createState() =>
      _SugerenciasCompraScreenState();
}

class _SugerenciasCompraScreenState extends State<SugerenciasCompraScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Producto> _productosBajoStock = [];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ResponsiveScaffold(
      currentRoute: 'sugerencias_compra',
      title: 'Sugerencias de Compra',
      actions: [
        if (_productosBajoStock.isNotEmpty)
          IconButton(
            onPressed: _enviarPedidoPorWhatsApp,
            icon: const Icon(Icons.send),
            tooltip: 'Enviar Pedido por WhatsApp',
          ),
      ],
      body: StreamBuilder<List<Producto>>(
        stream: _firebaseService.getProductosStreamLimitado(limite: 200),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('Error al cargar sugerencias:',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProductos = snapshot.data ?? [];
          // Filtrar productos con stock bajo
          final bajoStock =
              allProductos.where((p) => p.cantidad <= p.stockMinimo).toList();

          // Actualizar la lista para el botón de WhatsApp de forma segura
          if (_productosBajoStock.length != bajoStock.length) {
            Future.delayed(Duration.zero, () {
              if (mounted) {
                setState(() => _productosBajoStock = bajoStock);
              }
            });
          }

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
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.local_shipping_outlined,
                            color: colorScheme.primary, size: 20),
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
                        Expanded(
                            child: Divider(color: colorScheme.primaryContainer)),
                      ],
                    ),
                  ),
                  ...productos.map((p) => PremiumCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(p.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
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
                                style:
                                    TextStyle(fontSize: 9, color: Colors.grey),
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

  Future<void> _enviarPedidoPorWhatsApp() async {
    if (_productosBajoStock.isEmpty) return;

    // 1. Extraer nombres de proveedores únicos
    final proveedoresSet = _productosBajoStock
        .map((p) => p.proveedorNombre ?? 'Sin Proveedor Asignado')
        .toSet();
    final proveedores = proveedoresSet.toList()..sort();

    // 2. Mostrar BottomSheet de selección de proveedor
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿A qué proveedor deseas enviarle el pedido?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: proveedores.length,
                  itemBuilder: (ctx2, index) {
                    final prov = proveedores[index];
                    return ListTile(
                      leading: const Icon(Icons.local_shipping_outlined,
                          color: Colors.green),
                      title: Text(prov,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(ctx);
                        _generarYEnviarMensaje(prov);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _generarYEnviarMensaje(String proveedorSeleccionado) async {
    // 3. Filtrar productos específicos de ese proveedor
    final productosFiltrados = _productosBajoStock
        .where((p) =>
            (p.proveedorNombre ?? 'Sin Proveedor Asignado') ==
            proveedorSeleccionado)
        .toList();

    if (productosFiltrados.isEmpty) return;

    // Construcción del mensaje formateado
    String textoFormateado = "📦 *ORDEN DE COMPRA SUGERIDA*\n";
    textoFormateado += "🚩 *Proveedor: $proveedorSeleccionado*\n\n";
    textoFormateado += "Hola, necesito el siguiente pedido de mercancía:\n";

    for (var p in productosFiltrados) {
      // Sugerencia: reabastecer para llegar al doble del stock mínimo
      final sugerido = (p.stockMinimo * 2) - p.cantidad;
      textoFormateado +=
          "- ${sugerido.toInt()}x ${p.nombre} (${p.atributoVisual})\n";
    }

    textoFormateado += "\n_Generado por: Inventarios Universal_";

    final url = Uri.parse(
        "https://wa.me/?text=${Uri.encodeComponent(textoFormateado)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No se pudo abrir WhatsApp'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}
