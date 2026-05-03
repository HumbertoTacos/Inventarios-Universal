import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:io';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/proveedor.dart';
import '../models/venta.dart';
import '../services/firebase_service.dart';
import 'agregar_producto_screen.dart';
import 'barcode_scanner_screen.dart';
import 'editar_producto_screen.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';
import '../services/impresion_service.dart';
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';
import '../widgets/premium_widgets.dart'; // [UI Polish]
import 'package:firebase_storage/firebase_storage.dart';

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
  List<Producto> _productosFiltradosNombre = []; // Resultados filtrados localmente por nombre
  DocumentSnapshot? _lastDoc;
  Producto? _searchResult; // Para mostrar un resultado exacto por SKU
  
  // Estado de Carga
  bool _isLoading = true;         // Carga inicial
  bool _isFetchingMore = false;   // Cargando página siguiente
  bool _hasMoreData = true;       // ¿Quedan más datos en Firebase?
  bool _isSearching = false;      // ¿Estamos en modo búsqueda/SKU?
  bool _isSearchingNombre = false; // Búsqueda por nombre activa

  // Filtros
  Categoria? _filtroCategoria;
  Proveedor? _filtroProveedor;

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
      final result = await _firebaseService.getProductosPaginados(
        limite: 20,
        categoriaId: _filtroCategoria?.id,
        proveedorId: _filtroProveedor?.id,
      );
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
        startAfter: _lastDoc,
        categoriaId: _filtroCategoria?.id,
        proveedorId: _filtroProveedor?.id,
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

    final q = query.trim();
    final soloDigitos = RegExp(r'^\d+$').hasMatch(q);

    if (soloDigitos) {
      // Búsqueda por SKU/código de barras (lógica original)
      setState(() {
        _isSearching = true;
        _isSearchingNombre = false;
        _isLoading = true;
        _searchResult = null;
        _productosFiltradosNombre = [];
      });

      try {
        final res = await _firebaseService.buscarVariantePorSKU(q);
        if (mounted) {
          setState(() {
            _searchResult = res;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // Búsqueda por nombre: primero filtrado local, luego Firestore
      setState(() {
        _isSearching = false;
        _isSearchingNombre = true;
        _isLoading = false;
      });

      final queryLower = q.toLowerCase();

      // 1. Filtro local inmediato
      final locales = _productos
          .where((p) => p.nombre.toLowerCase().contains(queryLower))
          .toList();

      setState(() => _productosFiltradosNombre = locales);

      // 2. Si pocos resultados, buscar en Firestore
      if (locales.length < 5) {
        try {
          final remotos = await _firebaseService.buscarProductosPorNombre(queryLower);
          if (mounted) {
            final ids = locales.map((p) => p.id).toSet();
            final fusionados = [...locales];
            for (final r in remotos) {
              if (!ids.contains(r.id)) fusionados.add(r);
            }
            setState(() => _productosFiltradosNombre = fusionados);
          }
        } catch (_) {}
      }
    }
  }

  // ── UI Principal ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final appBarBottom = PreferredSize(
      preferredSize: const Size.fromHeight(76),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  // Búsqueda en tiempo real si tiene letras, o al submit si solo dígitos
                  if (v.trim().isEmpty) { _fetchInitial(); return; }
                  if (!RegExp(r'^\d+$').hasMatch(v.trim())) _ejecutarBusqueda(v);
                },
                onSubmitted: _ejecutarBusqueda,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o código de barras...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _isSearchingNombre = false;
                          _productosFiltradosNombre = [];
                        });
                        _fetchInitial();
                      })
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
                color: (_filtroCategoria != null || _filtroProveedor != null) ? colorScheme.primary : Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.filter_list, color: (_filtroCategoria != null || _filtroProveedor != null) ? colorScheme.onPrimary : colorScheme.onSurface),
                onPressed: _mostrarModalFiltros,
              ),
            ),
          ],
        ),
      ),
    );

    final actions = [
      if (!widget.modoSeleccion && _esDueno)
        IconButton(
          icon: const Icon(Icons.upload_file_outlined),
          tooltip: 'Importar CSV',
          onPressed: _importarCSV,
        ),
    ];

    final floatingActionButton = widget.modoSeleccion || !_puedeAgregarProductos
        ? null
        : FloatingActionButton.extended(
            onPressed: _navegarAAgregarProducto,
            icon: const Icon(Icons.add),
            label: const Text('Agregar'),
          );

    final bodyContent = ResponsiveLayout(
      mobileBody: _buildBody(isDesktop: false),
      tabletBody: _buildBody(isDesktop: true, isTablet: true),
      desktopBody: _buildBody(isDesktop: true, isTablet: false),
    );

    if (widget.modoSeleccion) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Inventario', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          elevation: 0,
          actions: actions,
          bottom: appBarBottom,
        ),
        body: bodyContent,
        floatingActionButton: floatingActionButton,
      );
    }

    return ResponsiveScaffold(
      currentRoute: 'inventario',
      title: 'Inventario',
      actions: actions,
      appBarBottom: appBarBottom,
      body: bodyContent,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildBody({bool isDesktop = false, bool isTablet = false}) {
    Widget content;
    
    Widget buildListOrGrid(int itemCount, Widget Function(int) itemBuilder) {
      if (isDesktop) {
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTablet ? 3 : 5,
            childAspectRatio: 0.8,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) => itemBuilder(index),
        );
      } else {
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: itemCount,
          itemBuilder: (context, index) => itemBuilder(index),
        );
      }
    }

    if (_isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_isSearchingNombre) {
      if (_productosFiltradosNombre.isEmpty) {
        content = _buildEstadoVacio('Sin resultados', 'No hay productos que coincidan con "${_searchCtrl.text}".');
      } else {
        content = buildListOrGrid(
          _productosFiltradosNombre.length,
          (index) => isDesktop ? _buildProductoGridCard(_productosFiltradosNombre[index]) : _buildProductoCard(_productosFiltradosNombre[index])
        );
      }
    } else if (_isSearching) {
      if (_searchResult == null) {
        content = _buildEstadoVacio('No encontrado', 'No hay productos con ese código.');
      } else {
        content = buildListOrGrid(
          1,
          (index) => isDesktop ? _buildProductoGridCard(_searchResult!) : _buildProductoCard(_searchResult!)
        );
      }
    } else if (_productos.isEmpty) {
      content = _buildEstadoVacio('Sin productos', 'Toca el botón + para agregar.');
    } else {
      content = RefreshIndicator(
        onRefresh: _fetchInitial,
        child: buildListOrGrid(
          _productos.length + (_hasMoreData ? 1 : 0),
          (index) {
            if (index == _productos.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return isDesktop ? _buildProductoGridCard(_productos[index]) : _buildProductoCard(_productos[index]);
          }
        ),
      );
    }

    return isDesktop ? content : Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: content,
      ),
    );
  }

  // ── Widgets de Estado y Cards ─────────────────────────────────────────────

  Widget _buildEstadoVacio(String titulo, String subtitulo) {
    return PremiumEmptyState(
      icon: Icons.inventory_2_outlined,
      title: titulo,
      subtitle: subtitulo,
      action: (_isSearching || _isSearchingNombre)
          ? TextButton(
              onPressed: () {
                _searchCtrl.clear();
                _fetchInitial();
              },
              child: const Text('Ver todo el inventario'),
            )
          : null,
    );
  }

  Widget _buildProductoCard(Producto producto) {
    final colorScheme = Theme.of(context).colorScheme;
    final inStock = producto.cantidad > 0;
    
    return PremiumCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      onTap: () => widget.modoSeleccion
          ? Navigator.pop(context, producto)
          : _abrirMenuAcciones(producto),
      child: ListTile(
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

  Widget _buildProductoGridCard(Producto producto) {
    final colorScheme = Theme.of(context).colorScheme;
    final inStock = producto.cantidad > 0;
    
    return Card(
      elevation: 1,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => widget.modoSeleccion
            ? Navigator.pop(context, producto)
            : _abrirMenuAcciones(producto),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: inStock ? colorScheme.secondaryContainer : Colors.red.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Text(producto.nombre[0].toUpperCase(), 
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: inStock ? colorScheme.onSecondaryContainer : Colors.red.shade700)),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text((producto.codigoBarras?.isNotEmpty ?? false) ? 'SKU: ${producto.codigoBarras}' : 'Sin SKU', style: TextStyle(fontSize: 10, color: colorScheme.outline)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Stock', style: TextStyle(fontSize: 10, color: colorScheme.outline)),
                            Text(producto.cantidad.formatoInventario, 
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: inStock ? Colors.green.shade700 : Colors.red.shade700)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (producto.enPromocion && producto.precioPromocion != null)
                              Text('\$${producto.precioPromocion!.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade700))
                            else
                              Text('\$${producto.precio.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.primary)),
                          ],
                        ),
                      ],
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

  // ── Métodos de apoyo (Filtros, Modales, etc.) ──────────────────────────────
  
  void _mostrarModalFiltros() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FiltrosBottomSheet(
        filtroCategoriaInicial: _filtroCategoria,
        filtroProveedorInicial: _filtroProveedor,
        onApply: (cat, prov) { 
          setState(() {
            _filtroCategoria = cat;
            _filtroProveedor = prov;
          }); 
          _fetchInitial(); 
        },
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

  // ── Importación Masiva CSV ─────────────────────────────────────────────────

  Future<void> _importarCSV() async {
    try {
      // 1. Abrir selector de archivos
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      // 2. Confirmación
      if (!mounted) return;
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.cloud_upload_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('Importación Masiva'),
          ]),
          content: const Text(
            'El archivo será procesado de forma segura en el servidor.\n\n'
            'Esto permite cargar grandes volúmenes de productos sin agotar los recursos de tu dispositivo.\n'
            '¿Deseas subir el archivo ahora?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Subir y Procesar'),
            ),
          ],
        ),
      );

      if (confirmar != true || !mounted) return;

      // 3. Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Subiendo archivo al servidor...'),
          ]),
        ),
      );

      // 4. Subir a Firebase Storage
      final negocioId = AuthService().currentNegocioId;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('importaciones/$negocioId/productos_$timestamp.csv');

      if (file.bytes != null) {
        // Para Web
        await storageRef.putData(file.bytes!);
      } else if (file.path != null) {
        // Para Mobile/Desktop
        await storageRef.putFile(File(file.path!));
      }

      if (mounted) Navigator.pop(context); // Cerrar loading

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ El archivo se está procesando en el servidor. Los productos aparecerán en unos momentos.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Cerrar loading si falló
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir archivo: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

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
  final Proveedor? filtroProveedorInicial;
  final void Function(Categoria?, Proveedor?) onApply;

  const _FiltrosBottomSheet({
    this.filtroCategoriaInicial, 
    this.filtroProveedorInicial,
    required this.onApply
  });

  @override
  State<_FiltrosBottomSheet> createState() => _FiltrosBottomSheetState();
}

class _FiltrosBottomSheetState extends State<_FiltrosBottomSheet> {
  final FirebaseService _firebaseService = FirebaseService();
  Categoria? _catSelect;
  Proveedor? _provSelect;

  @override
  void initState() {
    super.initState();
    _catSelect = widget.filtroCategoriaInicial;
    _provSelect = widget.filtroProveedorInicial;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt_outlined),
              const SizedBox(width: 8),
              Text('Filtrar Inventario', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          
          // Filtro de Categoría
          StreamBuilder<List<Categoria>>(
            stream: _firebaseService.getCategorias(),
            builder: (context, snapshot) {
              final categorias = snapshot.data ?? [];
              return DropdownButtonFormField<Categoria>(
                value: _catSelect,
                decoration: const InputDecoration(
                  labelText: 'Categoría', 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem<Categoria>(value: null, child: Text('Todas las categorías')),
                  ...categorias.map((cat) => DropdownMenuItem(value: cat, child: Text(cat.nombre))),
                ],
                onChanged: (cat) => setState(() => _catSelect = cat),
              );
            }
          ),
          const SizedBox(height: 16),

          // Filtro de Proveedor
          StreamBuilder<List<Proveedor>>(
            stream: _firebaseService.getProveedores(),
            builder: (context, snapshot) {
              final proveedores = snapshot.data ?? [];
              return DropdownButtonFormField<Proveedor>(
                value: _provSelect,
                decoration: const InputDecoration(
                  labelText: 'Proveedor', 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
                items: [
                  const DropdownMenuItem<Proveedor>(value: null, child: Text('Todos los proveedores')),
                  ...proveedores.map((p) => DropdownMenuItem(value: p, child: Text(p.nombreComercial))),
                ],
                onChanged: (p) => setState(() => _provSelect = p),
              );
            }
          ),

          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () { widget.onApply(null, null); Navigator.pop(context); },
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Limpiar Todo'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: () { widget.onApply(_catSelect, _provSelect); Navigator.pop(context); },
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Aplicar Filtros'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
