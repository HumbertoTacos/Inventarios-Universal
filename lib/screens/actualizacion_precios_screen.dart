import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../services/firebase_service.dart';
import 'barcode_scanner_screen.dart';
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
  
  // ── Estado del Filtrado ───────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<String> _selectedCategories = [];
  List<String> _selectedStockStatuses = []; // 'disponible', 'bajo', 'agotado'

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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

  Future<void> _escanearCodigo() async {
    final String? codigo = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (codigo != null && codigo.isNotEmpty && mounted) {
      _searchCtrl.text = codigo;
      // El listener ya actualizará _searchQuery y disparará el setState
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FilterSheet(
        selectedCategories: _selectedCategories,
        selectedStockStatuses: _selectedStockStatuses,
        onApply: (categories, statuses) {
          setState(() {
            _selectedCategories = categories;
            _selectedStockStatuses = statuses;
          });
        },
      ),
    );
  }

  bool _cumpleFiltros(Producto p) {
    // 1. Filtro por Búsqueda (Nombre o Código de Barras)
    if (_searchQuery.isNotEmpty) {
      final nameMatch = p.nombre.toLowerCase().contains(_searchQuery);
      final skuMatch = (p.codigoBarras ?? '').toLowerCase().contains(_searchQuery);
      if (!nameMatch && !skuMatch) return false;
    }

    // 2. Filtro por Categorías (Multi-selección)
    if (_selectedCategories.isNotEmpty && !_selectedCategories.contains(p.categoria)) {
      return false;
    }

    // 3. Filtro por Stock
    if (_selectedStockStatuses.isNotEmpty) {
      String status = 'disponible';
      if (p.cantidad <= 0) {
        status = 'agotado';
      } else if (p.cantidad <= (p.stockMinimo ?? 5)) {
        status = 'bajo';
      }

      if (!_selectedStockStatuses.contains(status)) {
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ResponsiveScaffold(
      currentRoute: 'actualizacion_precios',
      title: 'Actualización Rápida de Precios',
      body: Column(
        children: [
          // ── Barra de Búsqueda y Botón de Filtros ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre o código...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchQuery.isNotEmpty) 
                            IconButton(
                              icon: const Icon(Icons.clear), 
                              onPressed: () => _searchCtrl.clear()
                            ),
                          IconButton(
                            icon: const Icon(Icons.qr_code_scanner),
                            onPressed: _escanearCodigo,
                            tooltip: 'Escanear código de barras',
                          ),
                        ],
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Stack(
                  children: [
                    IconButton.filledTonal(
                      onPressed: _showFilterSheet,
                      icon: const Icon(Icons.filter_list),
                      tooltip: 'Filtros avanzados',
                    ),
                    if (_selectedCategories.isNotEmpty || _selectedStockStatuses.isNotEmpty)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${_selectedCategories.length + _selectedStockStatuses.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Chips de Filtros Activos (Opcional, para UX) ──────────────────
          if (_selectedCategories.isNotEmpty || _selectedStockStatuses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ..._selectedCategories.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(c, style: const TextStyle(fontSize: 11)),
                        onDeleted: () => setState(() => _selectedCategories.remove(c)),
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
                    ..._selectedStockStatuses.map((s) {
                      final label = s == 'disponible' ? 'En Stock' : s == 'bajo' ? 'Bajo Stock' : 'Agotado';
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(label, style: const TextStyle(fontSize: 11)),
                          onDeleted: () => setState(() => _selectedStockStatuses.remove(s)),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    }),
                    TextButton(
                      onPressed: () => setState(() {
                        _selectedCategories.clear();
                        _selectedStockStatuses.clear();
                      }),
                      child: const Text('Limpiar Todo', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),

          // ── Lista de Productos ────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Producto>>(
              // [FinOps] Bounded Stream: límite de 100 docs para el modo Excel.
              // Filtrado de categorías/stock/búsqueda se ejecuta localmente — costo $0 adicional.
              stream: _firebaseService.getProductosStreamLimitado(limite: 100),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final allProductos = snapshot.data ?? [];
                final filteredProductos = allProductos.where(_cumpleFiltros).toList();

                if (filteredProductos.isEmpty) {
                  return const PremiumEmptyState(
                    icon: Icons.search_off,
                    title: 'Sin resultados',
                    subtitle: 'Intenta con otros filtros o términos de búsqueda.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: filteredProductos.length,
                  itemBuilder: (context, index) {
                    final p = filteredProductos[index];
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
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        p.categoria,
                                        style: TextStyle(fontSize: 10, color: colorScheme.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStockBadge(p, colorScheme),
                                  ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildStockBadge(Producto p, ColorScheme colorScheme) {
    Color color = Colors.green;
    String label = '${p.cantidad.toStringAsFixed(0)} disp.';
    
    if (p.cantidad <= 0) {
      color = Colors.red;
      label = 'Agotado';
    } else if (p.cantidad <= (p.stockMinimo ?? 5)) {
      color = Colors.orange;
      label = 'Bajo (${p.cantidad.toStringAsFixed(0)})';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final List<String> selectedCategories;
  final List<String> selectedStockStatuses;
  final Function(List<String>, List<String>) onApply;

  const _FilterSheet({
    required this.selectedCategories,
    required this.selectedStockStatuses,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late List<String> _tempCategories;
  late List<String> _tempStatuses;
  String _catSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempCategories = List.from(widget.selectedCategories);
    _tempStatuses = List.from(widget.selectedStockStatuses);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtros Avanzados',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _tempCategories.clear();
                      _tempStatuses.clear();
                    });
                  },
                  child: const Text('Limpiar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  // ── Estado de Stock ───────────────────────────────────────────────
                  const Text('Estado de Stock', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _statusChip('disponible', 'En Stock', Icons.check_circle_outline),
                      _statusChip('bajo', 'Bajo Stock', Icons.warning_amber_rounded),
                      _statusChip('agotado', 'Agotado', Icons.error_outline_rounded),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Categorías ────────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Categorías', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (_tempCategories.isNotEmpty)
                        Text(
                          '${_tempCategories.length} seleccionadas',
                          style: TextStyle(fontSize: 12, color: colorScheme.primary),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Mini-busqueda de categorias para cuando hay muchas (ej. 50)
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Filtrar categorías...',
                      prefixIcon: const Icon(Icons.filter_alt_outlined, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) => setState(() => _catSearchQuery = val.toLowerCase()),
                  ),
                  const SizedBox(height: 12),

                  StreamBuilder(
                    stream: FirebaseService().getCategorias(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      
                      final allCats = snapshot.data!;
                      final filteredCats = allCats.where((c) => 
                        c.nombre.toLowerCase().contains(_catSearchQuery)
                      ).toList();

                      return Wrap(
                        spacing: 8,
                        runSpacing: 0,
                        children: filteredCats.map((c) => FilterChip(
                          label: Text(c.nombre),
                          selected: _tempCategories.contains(c.nombre),
                          onSelected: (val) {
                            setState(() {
                              val ? _tempCategories.add(c.nombre) : _tempCategories.remove(c.nombre);
                            });
                          },
                        )).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  widget.onApply(_tempCategories, _tempStatuses);
                  Navigator.pop(context);
                },
                child: const Text('Aplicar Filtros'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status, String label, IconData icon) {
    final isSelected = _tempStatuses.contains(status);
    return FilterChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : null),
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          val ? _tempStatuses.add(status) : _tempStatuses.remove(status);
        });
      },
    );
  }
}
