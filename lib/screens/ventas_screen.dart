import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/producto.dart';
import '../models/venta.dart';
import '../services/firebase_service.dart';
import 'inventario_screen.dart';
import 'barcode_scanner_screen.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final List<VentaItem> _carrito = [];
  bool _procesando = false;

  double get _totalVenta => _carrito.fold(0, (sum, item) => sum + item.subtotal);

  // ── Agregar al carrito ──────────────────────────────────────────────────

  Future<void> _pedirCantidadYAgregar(Producto producto) async {
    if (!mounted) return; // Fix para context across async gaps warning
    final TextEditingController ctrl = TextEditingController(text: '1');
    
    final int? cantidad = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Vender: ${producto.nombre}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stock disponible: ${producto.cantidad}'),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Cantidad a vender',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final c = int.tryParse(ctrl.text) ?? 0;
                if (c > 0) {
                  Navigator.pop(ctx, c);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (cantidad != null && cantidad > 0) {
      if (cantidad > producto.cantidad) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay suficiente stock para esa cantidad.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        final existingIndex = _carrito.indexWhere((i) => i.productoId == producto.id);
        if (existingIndex >= 0) {
          // Si ya existe en el carrito, verificamos si sumando no pasamos del stock
          final nuevaCant = _carrito[existingIndex].cantidad + cantidad;
          if (nuevaCant > producto.cantidad) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No hay suficiente stock al sumar el carrito.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          final oldItem = _carrito[existingIndex];
          _carrito[existingIndex] = VentaItem(
            productoId: oldItem.productoId,
            nombre: oldItem.nombre,
            costoUnitario: oldItem.costoUnitario,
            precioUnitario: oldItem.precioUnitario,
            cantidad: nuevaCant,
          );
        } else {
          _carrito.add(VentaItem(
            productoId: producto.id,
            nombre: producto.nombre,
            costoUnitario: producto.costoPromedio,
            precioUnitario: producto.precio,
            cantidad: cantidad,
          ));
        }
      });
    }
  }

  Future<void> _buscarProducto() async {
    final Producto? prodSeleccionado = await Navigator.push<Producto?>(
      context,
      MaterialPageRoute(
        builder: (_) => const InventarioScreen(modoSeleccion: true),
      ),
    );

    if (prodSeleccionado != null && mounted) {
      await _pedirCantidadYAgregar(prodSeleccionado);
    }
  }

  Future<void> _escanearParaVender() async {
    final String? codigo = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (codigo != null && codigo.isNotEmpty && mounted) {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final productos = await _firebaseService.buscarPorCodigoBarras(codigo);
        if (mounted) Navigator.pop(context); // cerrar loading

        if (productos.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Producto no encontrado.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Si se encuentra, tomar el primero
        final p = productos.first;
        if (mounted) {
          await _pedirCantidadYAgregar(p);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // cerrar loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al buscar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ── Registrar Venta ───────────────────────────────────────────────────────

  Future<void> _confirmarVenta() async {
    if (_carrito.isEmpty) return;

    setState(() => _procesando = true);

    try {
      final nuevaVenta = Venta(
        id: '',
        fecha: DateTime.now(),
        items: List.from(_carrito),
        total: _totalVenta,
      );

      await _firebaseService.registrarVenta(nuevaVenta);

      setState(() {
        _carrito.clear();
        _procesando = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Venta completada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _procesando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar la venta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _intentarSalir() async {
    if (_carrito.isEmpty || _procesando) return true;

    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar Venta?'),
        content: const Text('Tienes productos en el carrito. Si sales, se perderá el carrito actual.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quedarme'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    return salir ?? false;
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // PopScope maneja el botón back físico y el del AppBar (en Android 14+)
    return PopScope(
      canPop: _carrito.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final mustLeave = await _intentarSalir();
        if (mustLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Punto de Venta'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Escanear producto',
              onPressed: _escanearParaVender,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Buscar en catálogo',
              onPressed: _buscarProducto,
            ),
          ],
        ),
        body: Column(
          children: [
            // Lista del carrito
            Expanded(
              child: _carrito.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('Carrito Vacío',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600)),
                          const SizedBox(height: 8),
                          Text('Escanea o busca un producto para agregar',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _carrito.length,
                      separatorBuilder: (ctx, idx) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _carrito[index];
                        return ListTile(
                          title: Text(item.nombre),
                          subtitle: Text('${item.cantidad} x \$${item.precioUnitario.toStringAsFixed(2)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '\$${item.subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => setState(() => _carrito.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            // Panel de resumen (Footer)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(
                          '\$${_totalVenta.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: (_carrito.isEmpty || _procesando) ? null : _confirmarVenta,
                        icon: _procesando
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline),
                        label: Text(_procesando ? 'Procesando...' : 'Confirmar Venta', style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
