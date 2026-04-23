import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/venta.dart';
import '../services/firebase_service.dart';
import 'agregar_producto_screen.dart';
import 'barcode_scanner_screen.dart';
import 'editar_producto_screen.dart';
import 'estadisticas_screen.dart';
import 'gestion_categorias_screen.dart';
import 'historial_ventas_screen.dart';
import 'ventas_screen.dart';
import 'mi_equipo_screen.dart';
import 'clientes_screen.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';
import '../utils/formatters.dart';
import '../services/impresion_service.dart';

class InventarioScreen extends StatefulWidget {
  final bool modoSeleccion;

  const InventarioScreen({super.key, this.modoSeleccion = false});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();

  // Rol y permisos del usuario activo
  String get _rol => AuthService().currentUserData?.rol ?? AuthService.rolEmpleado;
  bool get _esDueno => _rol == AuthService.rolDueno;

  bool get _puedeAjustarStock    => _esDueno || (AuthService().currentUserData?.permisos.puedeAjustarStock ?? true);
  bool get _puedeEditarProductos => _esDueno || (AuthService().currentUserData?.permisos.puedeEditarProductos ?? false);
  bool get _puedeEliminarProductos => _esDueno || (AuthService().currentUserData?.permisos.puedeEliminarProductos ?? false);
  bool get _puedeVerEstadisticas => _esDueno || (AuthService().currentUserData?.permisos.puedeVerEstadisticas ?? false);
  bool get _puedeVerHistorial    => _esDueno || (AuthService().currentUserData?.permisos.puedeVerHistorialVentas ?? true);
  bool get _puedeAgregarProductos => _esDueno || _puedeEditarProductos;


  // Estado de Datos
  List<Producto> _productos = [];
  DocumentSnapshot? _lastDoc;
  Producto? _searchResult; // Para mostrar un resultado exacto por SKU
  
  // Estado de Carga
  bool _isLoading = true;         // Carga inicial
  bool _isFetchingMore = false;   // Cargando página siguiente
  bool _hasMoreData = true;       // ¿Quedan más datos en Firebase?
  bool _isSearching = false;      // ¿Estamos en modo búsqueda/SKU?

  // Filtros
  Categoria? _filtroCategoria;

  @override
  void initState() {
    super.initState();
    _fetchInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Lógica de Datos ───────────────────────────────────────────────────────

  Future<void> _fetchInitial() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _productos = [];
      _lastDoc = null;
      _hasMoreData = true;
      _isSearching = false;
      _searchResult = null;
    });

    try {
      final result = await _firebaseService.getProductosPaginados(limite: 20);
      if (!mounted) return;
      setState(() {
        _productos = result.productos;
        _lastDoc = result.lastDoc;
        _isLoading = false;
        if (result.productos.length < 20) _hasMoreData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _fetchNext() async {
    if (_isFetchingMore || !_hasMoreData || _isSearching) return;

    if (!mounted) return;
    setState(() => _isFetchingMore = true);

    try {
      final result = await _firebaseService.getProductosPaginados(
        limite: 20, 
        startAfter: _lastDoc
      );

      if (!mounted) return;
      setState(() {
        _productos.addAll(result.productos);
        _lastDoc = result.lastDoc;
        _isFetchingMore = false;
        if (result.productos.length < 20) _hasMoreData = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Si llegamos al 90% del scroll, cargamos más
    if (currentScroll >= (maxScroll * 0.9)) {
      _fetchNext();
    }
  }

  /// Actualización Optimista (UI) tras una venta
  void _actualizarStockLocalmente(List<VentaItem> itemsVendidos) {
    setState(() {
      for (var item in itemsVendidos) {
        // Buscar en la lista principal
        final idx = _productos.indexWhere((p) => p.id == item.productoId);
        if (idx != -1) {
          final prod = _productos[idx];
          // Restamos cantidad (Optimista)
          _productos[idx] = prod.copyWith(cantidad: prod.cantidad - item.cantidad);
        }
        
        // Buscar en resultado de búsqueda por si acaso
        if (_searchResult != null && _searchResult!.id == item.productoId) {
          _searchResult = _searchResult!.copyWith(cantidad: _searchResult!.cantidad - item.cantidad);
        }
      }
    });
  }

  // ── Búsqueda y Scanner ────────────────────────────────────────────────────

  Future<void> _ejecutarBusqueda(String query) async {
    if (query.trim().isEmpty) {
      _fetchInitial();
      return;
    }

    setState(() {
      _isSearching = true;
      _isLoading = true;
      _searchResult = null;
    });

    try {
      // Intentamos buscar por SKU como prioridad (Lo que pide el POS/Senior)
      final res = await _firebaseService.buscarVariantePorSKU(query.trim());
      if (mounted) {
        setState(() {
          _searchResult = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                      'Inventarios Universal',
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
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push<List<VentaItem>>(
                        context, 
                        MaterialPageRoute(builder: (_) => const VentasScreen())
                      );
                      if (result != null && mounted) {
                        _actualizarStockLocalmente(result);
                      }
                    },
                  ),
                  if (_puedeVerHistorial)
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Historial de Pedidos'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const HistorialVentasScreen()));
                      },
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.people_outlined),
                    title: const Text('Clientes y Créditos'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientesScreen()));
                    },
                  ),
                  if (_puedeVerEstadisticas) ...[
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
                  // Solo dueño: categorías y equipo
                  if (_esDueno) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.category_outlined),
                      title: const Text('Gestionar Categorías'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionCategoriasScreen()));
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.people_alt_outlined),
                      title: const Text('Mi Equipo'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MiEquipoScreen()));
                      },
                    ),
                  ],
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      await AuthService().logout();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const AuthGate()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
      appBar: AppBar(
        title: const Text('Inventario', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    onSubmitted: _ejecutarBusqueda,
                    decoration: InputDecoration(
                      hintText: 'Buscar SKU / Código...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchCtrl.text.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _fetchInitial(); })
                        : IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: _escanearParaBuscar,
                          ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _filtroCategoria != null ? colorScheme.primary : Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.filter_list, color: _filtroCategoria != null ? colorScheme.onPrimary : colorScheme.onSurface),
                    onPressed: _mostrarModalFiltros,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: widget.modoSeleccion || !_puedeAgregarProductos
          ? null
          : FloatingActionButton.extended(
              onPressed: _navegarAAgregarProducto,
              icon: const Icon(Icons.add),
              label: const Text('Agregar'),
            ),
    );
  }

  Widget _buildBody() {
    Widget content;
    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_isSearching) {
      if (_searchResult == null) {
        content = _buildEstadoVacio('No encontrado', 'No hay productos con ese código.');
      } else {
        content = ListView(
          padding: const EdgeInsets.all(12),
          children: [_buildProductoCard(_searchResult!)],
        );
      }
    } else if (_productos.isEmpty) {
      content = _buildEstadoVacio('Sin productos', 'Toca el botón + para agregar.');
    } else {
      content = RefreshIndicator(
        onRefresh: _fetchInitial,
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _productos.length + (_hasMoreData ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _productos.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return _buildProductoCard(_productos[index]);
          },
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: content,
      ),
    );
  }

  // ── Widgets de Estado y Cards ─────────────────────────────────────────────

  Widget _buildEstadoVacio(String titulo, String subtitulo) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(titulo, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600)),
          Text(subtitulo, style: TextStyle(color: Colors.grey.shade500)),
          if (_isSearching) TextButton(onPressed: () { _searchCtrl.clear(); _fetchInitial(); }, child: const Text('Ver todo')),
        ],
      ),
    );
  }

  Widget _buildProductoCard(Producto producto) {
    final colorScheme = Theme.of(context).colorScheme;
    final inStock = producto.cantidad > 0;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4)
          ),
        ],
      ),
      child: ListTile(
        onTap: () => widget.modoSeleccion
            ? Navigator.pop(context, producto)
            : _abrirMenuAcciones(producto),
        leading: CircleAvatar(
          backgroundColor: inStock ? colorScheme.secondaryContainer : Colors.red.shade50,
          child: Text(producto.nombre[0].toUpperCase(),
              style: TextStyle(color: inStock ? colorScheme.onSecondaryContainer : Colors.red.shade700, fontWeight: FontWeight.bold)),
        ),
        title: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${producto.categoria} • ${producto.atributoVisual}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (producto.enPromocion && producto.precioPromocion != null) ...[
               Text(
                '\$${producto.precio.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(4)),
                    child: const Text('OFERTA', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  Text('\$${producto.precioPromocion!.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade700)),
                ],
              ),
            ] else
              Text('\$${producto.precio.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.primary)),
            Text('Stock: ${producto.cantidad.formatoInventario}',
                style: TextStyle(fontSize: 12, fontWeight: inStock ? FontWeight.normal : FontWeight.bold, color: inStock ? Colors.green.shade700 : Colors.red.shade700)),
          ],
        ),
      ),
    );
  }

  // ── Métodos de apoyo (Filtros, Modales, etc.) ──────────────────────────────
  
  void _mostrarModalFiltros() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FiltrosBottomSheet(
        filtroCategoriaInicial: _filtroCategoria,
        onApply: (cat) { setState(() => _filtroCategoria = cat); _fetchInitial(); },
      ),
    );
  }

  Future<void> _escanearParaBuscar() async {
    final result = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
    if (result != null) {
      _searchCtrl.text = result;
      _ejecutarBusqueda(result);
    }
  }

  void _navegarAAgregarProducto() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgregarProductoScreen())).then((_) => _fetchInitial());

  Future<void> _mostrarDialogoRestock(Producto producto) async {
    final TextEditingController ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stock: ${producto.nombre}'),
        content: TextField(
          controller: ctrl, 
          keyboardType: const TextInputType.numberWithOptions(decimal: true), 
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))],
          decoration: const InputDecoration(labelText: 'Cantidad a ajustar (ej. -0.5 o 10)')
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            final val = double.tryParse(ctrl.text) ?? 0.0;
            if (val == 0) return;
            await _firebaseService.ajustarInventario(producto.id, val, 'Ajuste manual rápido');
            if (mounted) { Navigator.pop(ctx); _fetchInitial(); }
          }, child: const Text('Guardar'))
        ],
      )
    );
  }

  // ── Menú de Acciones por Permisos ──────────────────────────────────────────

  void _abrirMenuAcciones(Producto producto) {
    final tieneAlgunaAccion = _puedeAjustarStock || _puedeEditarProductos || _puedeEliminarProductos;
    if (!tieneAlgunaAccion) return;

    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              // Info del producto
              ListTile(
                leading: CircleAvatar(
                    backgroundColor: cs.secondaryContainer,
                    child: Text(producto.nombre[0].toUpperCase(),
                        style: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.bold))),
                title: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('\$${producto.precio.toStringAsFixed(2)} • Stock: ${producto.cantidad.formatoInventario}'),
              ),
              const Divider(),
              if (_puedeAjustarStock)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Ajustar Stock'),
                  onTap: () { Navigator.pop(context); _mostrarDialogoRestock(producto); },
                ),
              if (_puedeEditarProductos)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar Producto'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => EditarProductoScreen(producto: producto)))
                        .then((_) => _fetchInitial());
                  },
                ),
              if (_puedeEliminarProductos)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Eliminar Producto', style: TextStyle(color: Colors.red)),
                  onTap: () { Navigator.pop(context); _confirmarEliminacion(producto); },
                ),
              if (producto.codigoBarras != null && producto.codigoBarras!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: const Text('Imprimir Etiqueta'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await ImpresionService.imprimirEtiquetaProducto(producto);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarEliminacion(Producto producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text(
            '¿Deseas eliminar "${producto.nombre}" permanentemente?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _firebaseService.eliminarProducto(producto.id);
      if (mounted) {
        _fetchInitial();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto eliminado'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}

// ── Bottom Sheet de Filtros ─────────────────────────────────────────────────

class _FiltrosBottomSheet extends StatefulWidget {
  final Categoria? filtroCategoriaInicial;
  final void Function(Categoria?) onApply;

  const _FiltrosBottomSheet({this.filtroCategoriaInicial, required this.onApply});

  @override
  State<_FiltrosBottomSheet> createState() => _FiltrosBottomSheetState();
}

class _FiltrosBottomSheetState extends State<_FiltrosBottomSheet> {
  final FirebaseService _firebaseService = FirebaseService();
  Categoria? _catSelect;

  @override
  void initState() {
    super.initState();
    _catSelect = widget.filtroCategoriaInicial;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: StreamBuilder<List<Categoria>>(
        stream: _firebaseService.getCategorias(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
          }
          final categorias = snapshot.data ?? [];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filtrar por Categoría', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              DropdownButtonFormField<Categoria>(
                value: _catSelect,
                decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<Categoria>(value: null, child: Text('Todas')),
                  ...categorias.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.nombre))),
                ],
                onChanged: (cat) => setState(() => _catSelect = cat),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () { widget.onApply(null); Navigator.pop(context); },
                      child: const Text('Limpiar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () { widget.onApply(_catSelect); Navigator.pop(context); },
                      child: const Text('Aplicar'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
