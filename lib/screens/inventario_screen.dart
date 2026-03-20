import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/producto.dart';
import '../services/firebase_service.dart';
import 'agregar_producto_screen.dart';

class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Inventario',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
      ),
      body: StreamBuilder<List<Producto>>(
        stream: _firebaseService.getProductos(),
        builder: (context, snapshot) {
          // ── Estado de error ──
          if (snapshot.hasError) {
            return _buildEstadoError(snapshot.error.toString());
          }

          // ── Estado de carga ──
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final productos = snapshot.data ?? [];

          // ── Lista vacía ──
          if (productos.isEmpty) {
            return _buildEstadoVacio();
          }

          // ── Lista con datos ──
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: productos.length,
            itemBuilder: (context, index) {
              return _buildProductoCard(productos[index]);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navegarAAgregarProducto,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }

  // ── Widgets de estado ──────────────────────────────────────────────────────

  Widget _buildEstadoError(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Ocurrió un error',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Sin productos',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca el botón + para agregar tu primer producto',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  // ── Card del producto ─────────────────────────────────────────────────────

  Widget _buildProductoCard(Producto producto) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(producto.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) => _confirmarEliminacion(producto.nombre),
      onDismissed: (_) => _eliminarProducto(producto),
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          onTap: () => _mostrarDialogoRestock(producto),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: colorScheme.secondaryContainer,
            child: Text(
              producto.nombre.isNotEmpty
                  ? producto.nombre[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          title: Text(
            producto.nombre,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(producto.categoria),
              Text(
                '${producto.tamano}${producto.atributoVisual.isNotEmpty ? ' · ${producto.atributoVisual}' : ''}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              if (producto.codigoBarras != null &&
                  producto.codigoBarras!.isNotEmpty)
                Text(
                  'Código: ${producto.codigoBarras}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${producto.precio.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: producto.cantidad > 0
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Stock: ${producto.cantidad}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: producto.cantidad > 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Acciones ──────────────────────────────────────────────────────────────

  Future<bool> _confirmarEliminacion(String nombre) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Estás seguro de que deseas eliminar "$nombre"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return resultado ?? false;
  }

  Future<void> _eliminarProducto(Producto producto) async {
    try {
      await _firebaseService.eliminarProducto(producto.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${producto.nombre}" eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navegarAAgregarProducto() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgregarProductoScreen()),
    );
  }

  Future<void> _mostrarDialogoRestock(Producto producto) async {
    final TextEditingController ctrl = TextEditingController();
    bool sumando = true; // true: +, false: -

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Restock: ${producto.nombre}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Stock actual: ${producto.cantidad}'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Agregar'),
                        selected: sumando,
                        onSelected: (v) => setState(() => sumando = true),
                        selectedColor: Colors.green.shade100,
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Quitar'),
                        selected: !sumando,
                        onSelected: (v) => setState(() => sumando = false),
                        selectedColor: Colors.red.shade100,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
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
                  onPressed: () async {
                    if (ctrl.text.isEmpty) return;
                    final cantidadInput = int.tryParse(ctrl.text) ?? 0;
                    if (cantidadInput == 0) return;

                    final nuevaCantidad = sumando
                        ? producto.cantidad + cantidadInput
                        : producto.cantidad - cantidadInput;

                    if (nuevaCantidad < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No puedes tener stock negativo'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final updated = producto.copyWith(cantidad: nuevaCantidad);
                    await _firebaseService.actualizarProducto(updated);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Stock actualizado a $nuevaCantidad'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
