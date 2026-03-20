import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../services/firebase_service.dart';
import 'agregar_producto_screen.dart';
import 'barcode_scanner_screen.dart';
import 'estadisticas_screen.dart';
import 'ventas_screen.dart';

class InventarioScreen extends StatefulWidget {
  final bool modoSeleccion;

  const InventarioScreen({super.key, this.modoSeleccion = false});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  // Estados de búsqueda y filtrado
  String _searchQuery = '';
  Categoria? _filtroCategoria;
  String? _filtroTamano;
  String? _filtroAtributo;

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filtrado Local ────────────────────────────────────────────────────────

  List<Producto> _filtrarProductos(List<Producto> productos) {
    return productos.where((p) {
      // Búsqueda por texto (nombre o código de barras)
      final query = _searchQuery.trim().toLowerCase();
      final matchQuery = query.isEmpty ||
          p.nombre.toLowerCase().contains(query) ||
          (p.codigoBarras != null && p.codigoBarras!.toLowerCase() == query);

      // Filtro por categoría
      final matchCat = _filtroCategoria == null || p.categoria == _filtroCategoria!.nombre;

      // Filtro por tamaño
      final matchTamano = _filtroTamano == null || p.tamano == _filtroTamano;

      // Filtro por atributo (color o diseño)
      final attrQuery = _filtroAtributo?.trim().toLowerCase() ?? '';
      final matchAttr = attrQuery.isEmpty ||
          (p.color != null && p.color!.toLowerCase().contains(attrQuery)) ||
          (p.diseno != null && p.diseno!.toLowerCase().contains(attrQuery));

      return matchQuery && matchCat && matchTamano && matchAttr;
    }).toList();
  }

  bool get _hayFiltrosActivos =>
      _filtroCategoria != null || _filtroTamano != null || (_filtroAtributo?.isNotEmpty ?? false);

  // ── UI Principal ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: widget.modoSeleccion
          ? null
          : Drawer(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(color: colorScheme.primary),
                    child: const Text(
                      'Blancos Gina',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: const Text('Inventario'),
                    onTap: () => Navigator.pop(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.point_of_sale),
                    title: const Text('Punto de Venta (Carrito)'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const VentasScreen()));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.bar_chart),
                    title: const Text('Estadísticas y Ganancias'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EstadisticasScreen()));
                    },
                  ),
                ],
              ),
            ),
      appBar: AppBar(
        title: const Text(
          'Inventario',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(76),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Buscar nombre o código...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        tooltip: 'Escanear con cámara',
                        onPressed: _escanearParaBuscar,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _hayFiltrosActivos ? colorScheme.primary : Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.filter_list,
                      color: _hayFiltrosActivos ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
                    tooltip: 'Filtrar',
                    onPressed: _mostrarModalFiltros,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Producto>>(
        stream: _firebaseService.getProductos(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildEstadoError(snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final productosRaw = snapshot.data ?? [];
          final productosFiltrados = _filtrarProductos(productosRaw);

          if (productosRaw.isEmpty) return _buildEstadoVacio('Sin productos', 'Toca el botón + para agregar.');
          if (productosFiltrados.isEmpty) return _buildEstadoVacio('Sin resultados', 'Intenta con otra búsqueda o limpia los filtros.');

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: productosFiltrados.length,
            itemBuilder: (context, index) {
              return _buildProductoCard(productosFiltrados[index]);
            },
          );
        },
      ),
      floatingActionButton: widget.modoSeleccion
          ? null
          : FloatingActionButton.extended(
              onPressed: _navegarAAgregarProducto,
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            ),
    );
  }

  // ── Widgets de Estado ─────────────────────────────────────────────────────

  Widget _buildEstadoError(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Ocurrió un error', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(mensaje, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoVacio(String titulo, String subtitulo) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(titulo, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(subtitulo, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // ── Card del producto ─────────────────────────────────────────────────────

  Widget _buildProductoCard(Producto producto) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(producto.id),
      direction: widget.modoSeleccion ? DismissDirection.none : DismissDirection.endToStart,
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
          onTap: () {
            if (widget.modoSeleccion) {
              Navigator.pop(context, producto);
            } else {
              _mostrarDialogoRestock(producto);
            }
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: colorScheme.secondaryContainer,
            child: Text(
              producto.nombre.isNotEmpty ? producto.nombre[0].toUpperCase() : '?',
              style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSecondaryContainer),
            ),
          ),
          title: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(producto.categoria),
              Text(
                '${producto.tamano}${producto.atributoVisual.isNotEmpty ? ' · ${producto.atributoVisual}' : ''}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              if (producto.codigoBarras != null && producto.codigoBarras!.isNotEmpty)
                Text('Código: ${producto.codigoBarras}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${producto.precio.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: producto.cantidad > 0 ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Stock: ${producto.cantidad}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: producto.cantidad > 0 ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              if (!widget.modoSeleccion) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_shopping_cart, color: Colors.blue),
                  tooltip: 'Reabastecer / Ingresar lote',
                  onPressed: () => _mostrarModalReabastecimiento(producto),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Modal de Filtros ──────────────────────────────────────────────────────

  void _mostrarModalFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _FiltrosBottomSheet(
          filtroCategoriaInicial: _filtroCategoria,
          filtroTamanoInicial: _filtroTamano,
          filtroAtributoInicial: _filtroAtributo,
          onApply: (cat, tamano, atributo) {
            setState(() {
              _filtroCategoria = cat;
              _filtroTamano = tamano;
              _filtroAtributo = atributo;
            });
          },
        );
      },
    );
  }

  // ── Acciones Secundarias ──────────────────────────────────────────────────

  Future<void> _escanearParaBuscar() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _searchCtrl.text = result;
        _searchQuery = result;
      });
    }
  }

  Future<bool> _confirmarEliminacion(String nombre) async {
    final resultado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Estás seguro de que deseas eliminar "$nombre"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${producto.nombre}" eliminado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red));
    }
  }

  void _navegarAAgregarProducto() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AgregarProductoScreen()));
  }

  // ── Diálogo Restock ──────────────────────────────────────────────────────

  Future<void> _mostrarDialogoRestock(Producto producto) async {
    final TextEditingController ctrl = TextEditingController();
    bool sumando = true;

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
                    decoration: const InputDecoration(labelText: 'Cantidad', border: OutlineInputBorder()),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () async {
                    if (ctrl.text.isEmpty) return;
                    final cantidadInput = int.tryParse(ctrl.text) ?? 0;
                    if (cantidadInput == 0) return;

                    final nuevaCantidad = sumando ? producto.cantidad + cantidadInput : producto.cantidad - cantidadInput;

                    if (nuevaCantidad < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No puedes tener stock negativo'), backgroundColor: Colors.red));
                      return;
                    }

                    final updated = producto.copyWith(cantidad: nuevaCantidad);
                    await _firebaseService.actualizarProducto(updated);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock actualizado')));
                    }
                  },
                  child: const Text('Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _mostrarModalReabastecimiento(Producto producto) async {
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Reabastecer: ${producto.nombre}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ingresa los datos del nuevo lote. El costo promedio se recalculará automáticamente.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Cantidad entrante', prefixIcon: Icon(Icons.add_box), border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: costCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                decoration: const InputDecoration(labelText: 'Costo unitario (compra)', prefixIcon: Icon(Icons.attach_money), prefixText: '\$ ', border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (qtyCtrl.text.isEmpty || costCtrl.text.isEmpty) return;
                final cantidadInput = int.tryParse(qtyCtrl.text) ?? 0;
                final costoInput = double.tryParse(costCtrl.text) ?? -1;

                if (cantidadInput <= 0 || costoInput < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Valores inválidos'), backgroundColor: Colors.red));
                  return;
                }

                Navigator.pop(ctx); 

                try {
                  await _firebaseService.reabastecerProducto(producto.id, cantidadInput, costoInput);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reabastecimiento exitoso y costo promediado.'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}

// ── Bottom Sheet de Filtros ─────────────────────────────────────────────────

class _FiltrosBottomSheet extends StatefulWidget {
  final Categoria? filtroCategoriaInicial;
  final String? filtroTamanoInicial;
  final String? filtroAtributoInicial;
  final Function(Categoria?, String?, String?) onApply;

  const _FiltrosBottomSheet({
    this.filtroCategoriaInicial,
    this.filtroTamanoInicial,
    this.filtroAtributoInicial,
    required this.onApply,
  });

  @override
  State<_FiltrosBottomSheet> createState() => _FiltrosBottomSheetState();
}

class _FiltrosBottomSheetState extends State<_FiltrosBottomSheet> {
  final FirebaseService _firebaseService = FirebaseService();

  Categoria? _catSelect;
  String? _tamSelect;
  final _attrCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _catSelect = widget.filtroCategoriaInicial;
    _tamSelect = widget.filtroTamanoInicial;
    _attrCtrl.text = widget.filtroAtributoInicial ?? '';
  }

  @override
  void dispose() {
    _attrCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Evita que el teclado del attrCtrl tape el modal
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: StreamBuilder<List<Categoria>>(
        stream: _firebaseService.getCategorias(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
          }

          final categorias = snapshot.data ?? [];

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filtros Avanzados', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              DropdownButtonFormField<Categoria>(
                initialValue: _catSelect,
                decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<Categoria>(value: null, child: Text('Cualquiera')),
                  ...categorias.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.nombre))),
                ],
                onChanged: (cat) {
                  setState(() {
                    _catSelect = cat;
                    _tamSelect = null; // resetear tamaño
                  });
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                key: ValueKey('tamano_${_catSelect?.id}'),
                initialValue: _tamSelect,
                decoration: const InputDecoration(labelText: 'Tamaño', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Cualquiera')),
                  if (_catSelect != null)
                    ..._catSelect!.tamanos.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                ],
                onChanged: (t) => setState(() => _tamSelect = t),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _attrCtrl,
                decoration: const InputDecoration(labelText: 'Color / Diseño', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () {
                        widget.onApply(null, null, null);
                        Navigator.pop(context);
                      },
                      child: const Text('Limpiar Filtros'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      onPressed: () {
                        widget.onApply(_catSelect, _tamSelect, _attrCtrl.text.trim());
                        Navigator.pop(context);
                      },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              )
            ],
          );
        },
      ),
    );
  }
}
