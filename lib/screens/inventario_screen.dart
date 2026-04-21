import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
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
  String get _rol => AuthService().currentUserData?.rol ?? 'empleado';
  bool get _esDueno => _rol == 'dueño';

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
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const VentasScreen()));
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_isSearching) {
      if (_searchResult == null) return _buildEstadoVacio('No encontrado', 'No hay productos con ese código.');
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [_buildProductoCard(_searchResult!)],
      );
    }

    if (_productos.isEmpty) return _buildEstadoVacio('Sin productos', 'Toca el botón + para agregar.');

    return RefreshIndicator(
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
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => widget.modoSeleccion
            ? Navigator.pop(context, producto)
            : _abrirMenuAcciones(producto),
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          child: Text(producto.nombre[0].toUpperCase(),
              style: TextStyle(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold)),
        ),
        title: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${producto.categoria} • ${producto.atributoVisual}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('\$${producto.precio.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
            Text('Stock: ${producto.cantidad}',
                style: TextStyle(fontSize: 12, color: producto.cantidad > 0 ? Colors.green : Colors.red)),
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
          keyboardType: TextInputType.number, 
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))],
          decoration: const InputDecoration(labelText: 'Cantidad a ajustar (ej. -5 o 10)')
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            final val = int.tryParse(ctrl.text) ?? 0;
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
                subtitle: Text('\$${producto.precio.toStringAsFixed(2)} • Stock: ${producto.cantidad}'),
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
