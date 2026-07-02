import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:async';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/proveedor.dart';
import '../models/venta.dart';
import '../services/firebase_service.dart';
import '../services/exportacion_service.dart';
import '../widgets/dialogo_impresion_etiquetas.dart';
import 'agregar_producto_screen.dart';
import 'barcode_scanner_screen.dart';
import 'editar_producto_screen.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';
import '../services/impresion_service.dart';
import '../services/exportacion_service.dart';
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
  String get _rol =>
      AuthService().currentUserData?.rol ?? AuthService.rolEmpleado;
  bool get _esDueno => _rol == AuthService.rolDueno;

  bool get _puedeAjustarStock =>
      _esDueno ||
      (AuthService().currentUserData?.permisos.puedeAjustarStock ?? true);
  bool get _puedeEditarProductos =>
      _esDueno ||
      (AuthService().currentUserData?.permisos.puedeEditarProductos ?? false);
  bool get _puedeEliminarProductos =>
      _esDueno ||
      (AuthService().currentUserData?.permisos.puedeEliminarProductos ?? false);
  bool get _puedeVerEstadisticas =>
      _esDueno ||
      (AuthService().currentUserData?.permisos.puedeVerEstadisticas ?? false);
  bool get _puedeVerHistorial =>
      _esDueno ||
      (AuthService().currentUserData?.permisos.puedeVerHistorialVentas ?? true);
  bool get _puedeAgregarProductos => _esDueno || _puedeEditarProductos;

  // Estado de Datos
  List<Producto> _productos = [];
  List<Producto> _productosFiltradosNombre =
      []; // Resultados filtrados localmente por nombre
  DocumentSnapshot? _lastDoc;
  Producto? _searchResult; // Para mostrar un resultado exacto por SKU

  String? _atributoSeleccionado;
  Timer? _debounceTimer;

  // Optimización: Cached user data
  bool _isLoading = true; // Carga inicial
  bool _isFetchingMore = false; // Cargando página siguiente
  bool _hasMoreData = true; // ¿Quedan más datos en Firebase?
  bool _isSearching = false; // ¿Estamos en modo búsqueda/SKU?
  bool _isSearchingNombre = false; // Búsqueda por nombre activa

  // Filtros
  Categoria? _filtroCategoria;
  Proveedor? _filtroProveedor;
  Map<String, String> _filtroAtributos = {};
  List<Categoria> _categorias = [];
  double _totalInventario = 0;
  int _productosBajoStock = 0;

  @override
  void initState() {
    super.initState();
    _fetchInitial();
    _fetchCategorias();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _fetchCategorias() async {
    final cats = await _firebaseService.getCategorias().first;
    if (mounted) setState(() => _categorias = cats);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
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

        // Cálculo rápido de resumen (de la página actual)
        _totalInventario = _productos.fold(
          0,
          (sum, p) => sum + (p.precio * p.cantidad),
        );
        _productosBajoStock = _productos
            .where((p) => p.cantidad <= p.stockMinimo)
            .length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          _productos[idx] = prod.copyWith(
            cantidad: prod.cantidad - item.cantidad,
          );
        }

        // Buscar en resultado de búsqueda por si acaso
        if (_searchResult != null && _searchResult!.id == item.productoId) {
          _searchResult = _searchResult!.copyWith(
            cantidad: _searchResult!.cantidad - item.cantidad,
          );
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
          final remotos = await _firebaseService.buscarProductosPorNombre(
            queryLower,
          );
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
                  _debounceTimer?.cancel();
                  if (v.trim().isEmpty) {
                    setState(() {
                      _isSearching = false;
                      _isSearchingNombre = false;
                      _productosFiltradosNombre = [];
                    });
                    return;
                  }
                  if (!RegExp(r'^\d+$').hasMatch(v.trim())) {
                    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                      _ejecutarBusqueda(v);
                    });
                  }
                },
                onSubmitted: _ejecutarBusqueda,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o código de barras...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {
                              _isSearchingNombre = false;
                              _productosFiltradosNombre = [];
                              _isSearching = false;
                            });
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
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
                color: (_filtroCategoria != null || _filtroProveedor != null)
                    ? colorScheme.primary
                    : Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.filter_list,
                  color: (_filtroCategoria != null || _filtroProveedor != null)
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
                onPressed: _mostrarModalFiltros,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.sort),
                onSelected: (val) {
                  // Lógica de ordenamiento rápida (Local)
                  setState(() {
                    if (val == 'stock') {
                      _productos.sort(
                        (a, b) => a.cantidad.compareTo(b.cantidad),
                      );
                    } else if (val == 'precio') {
                      _productos.sort((a, b) => b.precio.compareTo(a.precio));
                    } else {
                      _productos.sort((a, b) => a.nombre.compareTo(b.nombre));
                    }
                  });
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'nombre',
                    child: Text('Nombre (A-Z)'),
                  ),
                  const PopupMenuItem(
                    value: 'stock',
                    child: Text('Menor Stock'),
                  ),
                  const PopupMenuItem(
                    value: 'precio',
                    child: Text('Mayor Precio'),
                  ),
                ],
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
          title: const Text(
            'Inventario',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
    // 1. Determinar el "Sliver Principal" según el estado
    Widget mainSliver;

    if (_isLoading && _productos.isEmpty) {
      mainSliver = const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_isSearchingNombre) {
      if (_productosFiltradosNombre.isEmpty) {
        mainSliver = SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEstadoVacio(
            'Sin resultados',
            'No hay coincidencias para "${_searchCtrl.text}".',
          ),
        );
      } else {
        mainSliver = _buildSliverGridOrList(
          _productosFiltradosNombre,
          isDesktop,
          isTablet,
        );
      }
    } else if (_isSearching) {
      if (_searchResult == null) {
        mainSliver = SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEstadoVacio(
            'No encontrado',
            'No existe el código buscado.',
          ),
        );
      } else {
        mainSliver = _buildSliverGridOrList(
          [_searchResult!],
          isDesktop,
          isTablet,
        );
      }
    } else if (_productos.isEmpty) {
      mainSliver = SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEstadoVacio(
          'Sin productos',
          'Toca el botón + para agregar el primero.',
        ),
      );
    } else {
      List<Producto> productosAMostrar = _productos;
      if (_filtroAtributos.isNotEmpty) {
        productosAMostrar = _productos.where((p) {
          for (var entry in _filtroAtributos.entries) {
            final val = p.atributos[entry.key]?.toString().toLowerCase() ?? '';
            final requiredVal = entry.value.toLowerCase();
            if (val != requiredVal && !val.contains(requiredVal)) return false;
          }
          return true;
        }).toList();
      }
      
      if (productosAMostrar.isEmpty && _hasMoreData) {
        // Fetch more if current page matches nothing
        WidgetsBinding.instance.addPostFrameCallback((_) => _fetchNext());
      }

      mainSliver = _buildSliverGridOrList(
        productosAMostrar,
        isDesktop,
        isTablet,
        hasMore: _hasMoreData,
      );
    }

    // 2. Componer el CustomScrollView con todas las secciones
    return RefreshIndicator(
      onRefresh: _fetchInitial,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Resumen de Inventario
          SliverToBoxAdapter(child: _buildInventorySummary(isDesktop)),

          // Chips de Categorías (Solo si no estamos buscando por nombre/SKU)
          if (!_isSearching && !_isSearchingNombre)
            SliverToBoxAdapter(child: _buildCategoryChips()),

          // Espaciado inicial
          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Lista o Grid de Productos
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: mainSliver,
          ),

          // Espaciado final para el FAB
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSliverGridOrList(
    List<Producto> lista,
    bool isDesktop,
    bool isTablet, {
    bool hasMore = false,
  }) {
    if (isDesktop) {
      return SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isTablet ? 3 : 5,
          childAspectRatio: 0.75,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == lista.length)
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          return _buildProductoGridCard(lista[index]);
        }, childCount: lista.length + (hasMore ? 1 : 0)),
      );
    } else {
      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == lista.length)
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _buildProductoCard(lista[index]),
          );
        }, childCount: lista.length + (hasMore ? 1 : 0)),
      );
    }
  }

  // ── Widgets de Estado y Cards ─────────────────────────────────────────────

  Widget _buildInventorySummary(bool isDesktop) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _summaryMiniCard(
            'Total Variedades',
            '${_productos.length}',
            Icons.inventory_2,
            Colors.blue,
          ),
          _summaryMiniCard(
            'Valor Inventario',
            _totalInventario.formatoMoneda,
            Icons.payments,
            Colors.green,
          ),
          _summaryMiniCard(
            'Stock Crítico',
            '$_productosBajoStock',
            Icons.warning_amber_rounded,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _summaryMiniCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final cs = Theme.of(context).colorScheme;
    return PremiumCard(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    if (_categorias.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Botón "Todo"
          FilterChip(
            selected: _filtroCategoria == null,
            label: const Text('Todo'),
            onSelected: (val) {
              if (val) {
                setState(() => _filtroCategoria = null);
                _fetchInitial();
              }
            },
          ),
          const SizedBox(width: 8),
          ..._categorias.map((cat) {
            final isSelected = _filtroCategoria?.id == cat.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Text(cat.nombre),
                onSelected: (val) {
                  setState(() => _filtroCategoria = val ? cat : null);
                  _fetchInitial();
                },
              ),
            );
          }),
        ],
      ),
    );
  }

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
    final cs = Theme.of(context).colorScheme;
    final bool bajoStock = producto.cantidad <= producto.stockMinimo;
    final bool agotado = producto.cantidad <= 0;

    return PremiumCard(
      margin: EdgeInsets.zero,
      onTap: () => widget.modoSeleccion
          ? Navigator.pop(context, producto)
          : _abrirMenuAcciones(producto),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Imagen o Placeholder
            Hero(
              tag: 'prod_${producto.id}',
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child:
                      (producto.imagenUrl != null &&
                          producto.imagenUrl!.isNotEmpty)
                      ? FadeInImage.assetNetwork(
                          placeholder:
                              'assets/images/placeholder_prod.png', // Asegúrate de tener un placeholder
                          image: producto.imagenUrl!,
                          fit: BoxFit.cover,
                          imageErrorBuilder: (_, __, ___) => Icon(
                            Icons.image_not_supported,
                            color: cs.onSurfaceVariant,
                          ),
                        )
                      : Icon(Icons.inventory_2_outlined, color: cs.primary),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Información
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    producto.categoria,
                    style: TextStyle(color: cs.outline, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  _stockBadge(producto.cantidad, agotado, bajoStock),
                ],
              ),
            ),
            // Precio y Acciones
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  producto.precio.formatoMoneda,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: cs.primary,
                  ),
                ),
                if (_esDueno) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Costo: ${producto.costoActual.formatoMoneda}',
                    style: TextStyle(fontSize: 10, color: cs.outline),
                  ),
                  Text(
                    'MG: ${(((producto.precio - producto.costoActual) / (producto.precio != 0 ? producto.precio : 1)) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockBadge(double cantidad, bool agotado, bool bajoStock) {
    Color color = Colors.green;
    String label = 'En Stock';
    if (agotado) {
      color = Colors.red;
      label = 'Agotado';
    } else if (bajoStock) {
      color = Colors.orange;
      label = 'Stock Bajo';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: ${cantidad.formatoInventario}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoGridCard(Producto producto) {
    final cs = Theme.of(context).colorScheme;
    final bool bajoStock = producto.cantidad <= producto.stockMinimo;
    final bool agotado = producto.cantidad <= 0;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () => widget.modoSeleccion
            ? Navigator.pop(context, producto)
            : _abrirMenuAcciones(producto),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: cs.surfaceVariant.withOpacity(0.5),
                    child:
                        (producto.imagenUrl != null &&
                            producto.imagenUrl!.isNotEmpty)
                        ? FadeInImage.assetNetwork(
                            placeholder: 'assets/images/placeholder_prod.png',
                            image: producto.imagenUrl!,
                            fit: BoxFit.cover,
                            imageErrorBuilder: (_, __, ___) => Icon(
                              Icons.image_not_supported,
                              color: cs.onSurfaceVariant,
                              size: 32,
                            ),
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            color: cs.primary,
                            size: 40,
                          ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _stockBadge(producto.cantidad, agotado, bajoStock),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          producto.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (_esDueno)
                          Text(
                            'MG: ${(((producto.precio - producto.costoActual) / (producto.precio != 0 ? producto.precio : 1)) * 100).toStringAsFixed(0)}% (${producto.costoActual.formatoMoneda})',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          producto.precio.formatoMoneda,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: cs.primary,
                          ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FiltrosBottomSheet(
        filtroCategoriaInicial: _filtroCategoria,
        filtroProveedorInicial: _filtroProveedor,
        atributosIniciales: _filtroAtributos,
        onApply: (cat, prov, atributos) {
          setState(() {
            _filtroCategoria = cat;
            _filtroProveedor = prov;
            _filtroAtributos = atributos;
          });
          _fetchInitial();
        },
      ),
    );
  }

  Future<void> _escanearParaBuscar() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null) {
      _searchCtrl.text = result;
      _ejecutarBusqueda(result);
    }
  }

  void _navegarAAgregarProducto() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AgregarProductoScreen()),
  ).then((_) => _fetchInitial());

  // ── Importación Masiva CSV ─────────────────────────────────────────────────

  Future<void> _importarCSV() async {
    try {
      // 1. Mostrar diálogo informativo y opción de descargar plantilla
      if (!mounted) return;
      final proceder = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.upload_file_outlined, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Importación Masiva',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sube un archivo CSV para cargar productos masivamente. El procesamiento se realizará localmente en tu dispositivo para mayor privacidad y ahorro de recursos.',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tip: Atributos Dinámicos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Usa la columna "Atributos" para detalles específicos separándolos por comas (ej. Talla:M, Color:Azul).',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('¿No tienes el formato?'),
              TextButton.icon(
                onPressed: () => ExportacionService.descargarPlantillaCSV(),
                icon: const Icon(Icons.download_for_offline_outlined),
                label: const Text('Descargar Plantilla CSV'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Seleccionar Archivo'),
            ),
          ],
        ),
      );

      if (proceder != true) return;

      // 2. Abrir selector de archivos
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: true, // Importante para Web y para leer el contenido
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('No se pudo leer el contenido del archivo.');
      }

      // 3. Mostrar loading de procesamiento local
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Procesando productos localmente...',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );

      // 4. Procesar CSV localmente
      final csvString = utf8.decode(bytes);
      final List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter()
          .convert(
            csvString,
            shouldParseNumbers:
                false, // Leemos todo como String para evitar problemas de tipos
          );

      if (rowsAsListOfValues.isEmpty) {
        if (mounted) Navigator.pop(context);
        throw Exception('El archivo CSV está vacío.');
      }

      // Extraer cabeceras y mapear filas
      final headers = rowsAsListOfValues[0]
          .map((e) => e.toString().trim())
          .toList();
      final List<Map<String, String>> filasMapeadas = [];

      for (int i = 1; i < rowsAsListOfValues.length; i++) {
        final row = rowsAsListOfValues[i];
        final Map<String, String> filaMap = {};
        for (int j = 0; j < headers.length; j++) {
          if (j < row.length) {
            filaMap[headers[j]] = row[j].toString().trim();
          }
        }
        if (filaMap.isNotEmpty) filasMapeadas.add(filaMap);
      }

      // 5. Enviar a FirebaseService (que usa WriteBatch)
      final totalImportados = await _firebaseService.importarProductosCSV(
        filasMapeadas,
      );

      if (mounted) Navigator.pop(context); // Cerrar loading

      if (mounted) {
        _fetchInitial();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Se importaron $totalImportados productos exitosamente.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pop(); // Cerrar loading si falló
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en la importación: $e'),
            backgroundColor: Colors.red,
          ),
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
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
          ],
          decoration: const InputDecoration(
            labelText: 'Cantidad a ajustar (ej. -0.5 o 10)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text) ?? 0.0;
              if (val == 0) return;
              await _firebaseService.ajustarInventario(
                producto.id,
                val,
                'Ajuste manual rápido',
              );
              if (mounted) {
                Navigator.pop(ctx);
                _fetchInitial();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ── Menú de Acciones por Permisos ──────────────────────────────────────────

  void _abrirMenuAcciones(Producto producto) {
    final tieneAlgunaAccion =
        _puedeAjustarStock || _puedeEditarProductos || _puedeEliminarProductos;
    if (!tieneAlgunaAccion) return;

    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              // Info del producto
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.secondaryContainer,
                  child: Text(
                    producto.nombre[0].toUpperCase(),
                    style: TextStyle(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  producto.nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '\$${producto.precio.toStringAsFixed(2)} • Stock: ${producto.cantidad.formatoInventario}',
                ),
              ),
              const Divider(),
              if (_puedeAjustarStock)
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Ajustar Stock'),
                  onTap: () {
                    Navigator.pop(context);
                    _mostrarDialogoRestock(producto);
                  },
                ),
              if (_puedeEditarProductos)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar Producto'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EditarProductoScreen(producto: producto),
                      ),
                    ).then((_) => _fetchInitial());
                  },
                ),
              if (_puedeEliminarProductos)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Eliminar Producto',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmarEliminacion(producto);
                  },
                ),
              if (producto.codigoBarras != null &&
                  producto.codigoBarras!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: const Text('Imprimir Etiqueta'),
                  onTap: () {
                    Navigator.pop(context);
                    DialogoImpresionEtiquetas.mostrar(context, producto);
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
          '¿Deseas eliminar "${producto.nombre}" permanentemente?\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _firebaseService.eliminarProducto(producto.id);
      if (mounted) {
        _fetchInitial();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Producto eliminado'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    }
  }
}

// ── Bottom Sheet de Filtros ─────────────────────────────────────────────────

class _FiltrosBottomSheet extends StatefulWidget {
  final Categoria? filtroCategoriaInicial;
  final Proveedor? filtroProveedorInicial;
  final Map<String, String> atributosIniciales;
  final void Function(Categoria?, Proveedor?, Map<String, String>) onApply;

  const _FiltrosBottomSheet({
    this.filtroCategoriaInicial,
    this.filtroProveedorInicial,
    this.atributosIniciales = const {},
    required this.onApply,
  });

  @override
  State<_FiltrosBottomSheet> createState() => _FiltrosBottomSheetState();
}

class _FiltrosBottomSheetState extends State<_FiltrosBottomSheet> {
  final FirebaseService _firebaseService = FirebaseService();
  Categoria? _catSelect;
  Proveedor? _provSelect;
  Map<String, String> _atributosValores = {};

  @override
  void initState() {
    super.initState();
    _catSelect = widget.filtroCategoriaInicial;
    _provSelect = widget.filtroProveedorInicial;
    _atributosValores = Map.from(widget.atributosIniciales);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.filter_alt_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Filtrar Inventario',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filtro de Categoría
            StreamBuilder<List<Categoria>>(
              stream: _firebaseService.getCategorias(),
              builder: (context, snapshot) {
                final categorias = snapshot.data ?? [];
                return DropdownButtonFormField<Categoria>(
isExpanded: true,
menuMaxHeight: 400,
                  onTap: () => FocusScope.of(context).unfocus(),
                  value: _catSelect,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<Categoria>(
                      value: null,
                      child: Text('Todas las categorías'),
                    ),
                    ...categorias.map(
                      (cat) =>
                          DropdownMenuItem(value: cat, child: Text(cat.nombre)),
                    ),
                  ],
                  onChanged: (cat) {
                    setState(() {
                      _catSelect = cat;
                      _atributosValores.clear(); // Limpiar atributos al cambiar
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // Atributos dinámicos
            if (_catSelect != null && _catSelect!.atributos.isNotEmpty) ...[
              const Text('Atributos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 8),
              ..._catSelect!.atributos.map((atr) {
                if (atr.esListaFija) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: DropdownButtonFormField<String>(
isExpanded: true,
menuMaxHeight: 400,
                      onTap: () => FocusScope.of(context).unfocus(),
                      value: _atributosValores[atr.nombre],
                      decoration: InputDecoration(
                        labelText: atr.nombre,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text('Cualquier ${atr.nombre}')),
                        ...atr.opciones.map((op) => DropdownMenuItem(value: op, child: Text(op))),
                      ],
                      onChanged: (val) {
                        setState(() {
                          if (val == null) {
                            _atributosValores.remove(atr.nombre);
                          } else {
                            _atributosValores[atr.nombre] = val;
                          }
                        });
                      },
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      initialValue: _atributosValores[atr.nombre],
                      decoration: InputDecoration(
                        labelText: atr.nombre,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) {
                        if (val.trim().isEmpty) {
                          _atributosValores.remove(atr.nombre);
                        } else {
                          _atributosValores[atr.nombre] = val.trim();
                        }
                      },
                    ),
                  );
                }
              }).toList(),
              const SizedBox(height: 4),
            ],

            // Filtro de Proveedor
            StreamBuilder<List<Proveedor>>(
              stream: _firebaseService.getProveedores(),
              builder: (context, snapshot) {
                final proveedores = snapshot.data ?? [];
                return DropdownButtonFormField<Proveedor>(
isExpanded: true,
menuMaxHeight: 400,
                  onTap: () => FocusScope.of(context).unfocus(),
                  value: _provSelect,
                  decoration: const InputDecoration(
                    labelText: 'Proveedor',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.local_shipping_outlined),
                  ),
                  items: [
                    const DropdownMenuItem<Proveedor>(
                      value: null,
                      child: Text('Todos los proveedores'),
                    ),
                    ...proveedores.map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.nombreComercial),
                      ),
                    ),
                  ],
                  onChanged: (p) => setState(() => _provSelect = p),
                );
              },
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      widget.onApply(null, null, {});
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Limpiar Todo'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      widget.onApply(_catSelect, _provSelect, _atributosValores);
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Aplicar Filtros'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
