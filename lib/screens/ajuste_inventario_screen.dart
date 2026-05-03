import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/producto.dart';
import '../models/movimiento_kardex.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';

class AjusteInventarioScreen extends StatefulWidget {
  const AjusteInventarioScreen({super.key});

  @override
  State<AjusteInventarioScreen> createState() => _AjusteInventarioScreenState();
}

class _AjusteInventarioScreenState extends State<AjusteInventarioScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();
  
  // Producto seleccionado
  Producto? _productoSeleccionado;
  
  // Controladores del formulario
  final _cantidadCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  String? _motivoSeleccionado;
  
  final List<Map<String, String>> _motivos = [
    {'val': 'merma', 'label': 'Merma'},
    {'val': 'daño', 'label': 'Daño'},
    {'val': 'consumo_interno', 'label': 'Consumo del dueño'},
    {'val': 'extravio', 'label': 'Extravío'},
    {'val': 'ajuste_manual', 'label': 'Ajuste Manual'},
  ];

  bool _procesando = false;

  // Omni-Box logic
  final _searchFocusNode = FocusNode();
  final _searchCtrl = TextEditingController();
  Timer? _debounceTimer;
  List<Producto> _resultadosBusqueda = [];
  bool _mostrandoBusqueda = false;
  final Map<String, Producto> _cacheProductos = {};
  List<Producto> _productosGlobales = []; // Para búsqueda local

  @override
  void initState() {
    super.initState();
    _cargarCatalogoInicial();
  }

  Future<void> _cargarCatalogoInicial() async {
    try {
      final res = await _firebaseService.getProductosPaginados(limite: 50);
      if (mounted) {
        setState(() {
          _productosGlobales = res.productos;
          for (var p in res.productos) {
            _cacheProductos[p.id] = p;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _cantidadCtrl.dispose();
    _notasCtrl.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _resultadosBusqueda = [];
        _mostrandoBusqueda = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final query = value.trim().toLowerCase();
      
      // 1. Búsqueda en locales primero (más flexible: contains)
      final locales = _cacheProductos.values
          .where((p) => p.nombre.toLowerCase().contains(query))
          .toList();

      List<Producto> remotos = [];
      if (locales.length < 5) {
        remotos = await _firebaseService.buscarProductosPorNombre(query);
      }

      final ids = locales.map((p) => p.id).toSet();
      for (final r in remotos) {
        if (!ids.contains(r.id)) {
          locales.add(r);
          _cacheProductos[r.id] = r;
        }
      }

      if (mounted) {
        setState(() {
          _resultadosBusqueda = locales.take(10).toList();
          _mostrandoBusqueda = locales.isNotEmpty;
        });
      }
    });
  }

  Future<void> _onSearchSubmitted(String code) async {
    if (code.trim().isEmpty) return;
    try {
      // 1. Intentar por SKU
      final p = await _firebaseService.buscarVariantePorSKU(code.trim());
      if (p != null) {
        _seleccionarProducto(p);
        return;
      }

      // 2. Si no es SKU, intentar por nombre en los resultados actuales
      if (_resultadosBusqueda.isNotEmpty) {
        _seleccionarProducto(_resultadosBusqueda.first);
      } else {
        // 3. O buscar remotamente por nombre si no hay resultados locales
        final remotos = await _firebaseService.buscarProductosPorNombre(code.trim());
        if (remotos.isNotEmpty) {
          _seleccionarProducto(remotos.first);
        }
      }
    } catch (e) {
      debugPrint('Error search: $e');
    }
  }

  void _seleccionarProducto(Producto p) {
    setState(() {
      _productoSeleccionado = p;
      _mostrandoBusqueda = false;
      _searchCtrl.clear();
      _resultadosBusqueda = [];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _registrarAjuste() async {
    if (_productoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona un producto')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final cantidad = double.tryParse(_cantidadCtrl.text) ?? 0.0;
    if (cantidad <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad debe ser mayor a cero')),
      );
      return;
    }

    setState(() => _procesando = true);

    try {
      final movimiento = MovimientoKardex(
        id: '',
        productoId: _productoSeleccionado!.id,
        nombreProducto: _productoSeleccionado!.nombre,
        tipoMovimiento: _motivoSeleccionado!,
        cantidad: cantidad,
        costoUnitario: _productoSeleccionado!.costoPromedio,
        fecha: DateTime.now(),
        usuarioId: AuthService().currentUser?.uid ?? 'unknown',
        notas: _notasCtrl.text.trim(),
      );

      await _firebaseService.registrarAjusteInventario(movimiento);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ajuste registrado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveLayout.isDesktop(context);

    return ResponsiveScaffold(
      currentRoute: '/ajuste_inventario',
      title: 'Ajuste de Inventario (Mermas)',
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
          child: Column(
            children: [
              _buildSearchSection(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _productoSeleccionado == null 
                      ? _buildEmptyState() 
                      : (isDesktop ? _buildWideLayout() : _buildNarrowLayout()),
                ),
              ),
              _buildBottomAction(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Buscar producto por nombre o código...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _searchCtrl.text.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchCtrl.clear(); _mostrandoBusqueda = false; }))
                : null,
            ),
            onChanged: _onSearchChanged,
            onSubmitted: _onSearchSubmitted,
          ),
          if (_mostrandoBusqueda)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 250),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10)],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _resultadosBusqueda.length,
                itemBuilder: (context, index) {
                  final p = _resultadosBusqueda[index];
                  return ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(p.nombre),
                    subtitle: Text('Stock: ${p.cantidad} ${p.atributos.isNotEmpty ? "- ${p.atributoVisual}" : ""}'),
                    onTap: () => _seleccionarProducto(p),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.search_rounded, size: 80, color: Theme.of(context).colorScheme.outline.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            'Busca un producto para empezar',
            style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProductCard(),
        const SizedBox(height: 24),
        _buildForm(),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _buildProductCard()),
        const SizedBox(width: 24),
        Expanded(flex: 3, child: PremiumCard(padding: const EdgeInsets.all(24), child: _buildForm())),
      ],
    );
  }

  Widget _buildProductCard() {
    if (_productoSeleccionado == null) return const SizedBox.shrink();
    
    return PremiumCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.inventory_2_rounded, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_productoSeleccionado!.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(_productoSeleccionado!.categoria, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _productoSeleccionado = null),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem('Stock Actual', _productoSeleccionado!.cantidad.toString(), Icons.inventory_2_outlined),
                _buildInfoItem('Precio', '\$${_productoSeleccionado!.precio.toStringAsFixed(2)}', Icons.payments_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detalles del Ajuste', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          TextFormField(
            controller: _cantidadCtrl,
            decoration: const InputDecoration(
              labelText: 'Cantidad a ajustar',
              prefixIcon: Icon(Icons.tune_outlined),
              suffixText: 'Unidades',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _motivoSeleccionado,
            decoration: const InputDecoration(
              labelText: 'Motivo del ajuste',
              prefixIcon: Icon(Icons.report_problem_outlined),
            ),
            items: _motivos.map((m) => DropdownMenuItem(value: m['val'], child: Text(m['label']!))).toList(),
            onChanged: (val) => setState(() => _motivoSeleccionado = val),
            validator: (v) => v == null ? 'Selecciona un motivo' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notasCtrl,
            decoration: const InputDecoration(
              labelText: 'Comentarios / Razón',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.notes),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton.icon(
          onPressed: (_procesando || _productoSeleccionado == null) ? null : _registrarAjuste,
          icon: _procesando ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline),
          label: _procesando 
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3) 
            : const Text('Procesar Ajuste', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
