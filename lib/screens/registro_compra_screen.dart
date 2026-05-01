import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/producto.dart';
import '../models/compra.dart';
import '../models/proveedor.dart';
import '../services/firebase_service.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';
import 'barcode_scanner_screen.dart';

class RegistroCompraScreen extends StatefulWidget {
  const RegistroCompraScreen({super.key});

  @override
  State<RegistroCompraScreen> createState() => _RegistroCompraScreenState();
}

class _RegistroCompraScreenState extends State<RegistroCompraScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  final List<DetalleCompra> _itemsCompra = [];
  final Map<String, Producto> _cacheProductos = {};
  
  String? _idProveedorSeleccionado;
  bool _procesando = false;

  // Omni-Box logic
  final _barcodeFocusNode = FocusNode();
  final _barcodeCtrl = TextEditingController();
  Timer? _debounceTimer;
  List<Producto> _resultadosBusqueda = [];
  bool _mostrandoBusqueda = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _barcodeFocusNode.dispose();
    _barcodeCtrl.dispose();
    super.dispose();
  }

  double get _totalCompra => _itemsCompra.fold(0, (sum, item) => sum + item.subtotal);

  void _agregarProducto(Producto p) {
    setState(() {
      // Auto-selección de proveedor si no hay uno elegido
      if (_idProveedorSeleccionado == null && p.proveedorId != null) {
        _idProveedorSeleccionado = p.proveedorId;
      }

      _cacheProductos[p.id] = p;
      final existingIndex = _itemsCompra.indexWhere((i) => i.productoId == p.id);
      
      if (existingIndex >= 0) {
        final oldItem = _itemsCompra[existingIndex];
        _itemsCompra[existingIndex] = DetalleCompra(
          productoId: oldItem.productoId,
          nombre: oldItem.nombre,
          cantidad: oldItem.cantidad + 1,
          costoUnitario: oldItem.costoUnitario,
        );
      } else {
        _itemsCompra.add(DetalleCompra(
          productoId: p.id,
          nombre: p.nombre,
          cantidad: 1,
          costoUnitario: p.costoActual,
        ));
      }
      _barcodeCtrl.clear();
      _resultadosBusqueda = [];
      _mostrandoBusqueda = false;
      _barcodeFocusNode.requestFocus();
    });
  }

  void _onOmniBoxChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _resultadosBusqueda = [];
        _mostrandoBusqueda = false;
      });
      return;
    }

    final soloDigitos = RegExp(r'^\d+$').hasMatch(value.trim());
    if (soloDigitos) return;

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final query = value.trim().toLowerCase();
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

  Future<void> _onOmniBoxSubmitted(String code) async {
    _debounceTimer?.cancel();
    setState(() {
      _resultadosBusqueda = [];
      _mostrandoBusqueda = false;
    });

    if (code.trim().isEmpty) return;

    try {
      final p = await _firebaseService.buscarVariantePorSKU(code.trim());
      if (p != null) {
        _agregarProducto(p);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto no encontrado'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      debugPrint('Error Omni-Box: $e');
    } finally {
      _barcodeCtrl.clear();
      _barcodeFocusNode.requestFocus();
    }
  }

  Future<void> _escanearBarcode() async {
    final String? codigo = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (codigo != null && codigo.isNotEmpty && mounted) {
      await _onOmniBoxSubmitted(codigo);
    }
  }

  Future<void> _registrarCompra() async {
    if (_idProveedorSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un proveedor'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_itemsCompra.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _procesando = true);
    try {
      final proveedor = (await _firebaseService.getProveedores().first)
          .firstWhere((p) => p.id == _idProveedorSeleccionado);

      final compra = Compra(
        id: '',
        proveedorId: proveedor.id,
        proveedorNombre: proveedor.nombre,
        fecha: DateTime.now(),
        costoTotal: _totalCompra,
        items: _itemsCompra,
      );

      await _firebaseService.registrarCompra(compra);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compra registrada y stock actualizado.'), backgroundColor: Colors.green),
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
    return ResponsiveScaffold(
      currentRoute: '/registro_compra',
      title: 'Registrar Compra',
      body: Column(
        children: [
          _buildTopPanel(),
          _buildOmniBox(),
          Expanded(child: _buildItemsList()),
          _buildSummaryPanel(),
        ],
      ),
    );
  }

  Widget _buildTopPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: StreamBuilder<List<Proveedor>>(
        stream: _firebaseService.getProveedores(),
        builder: (context, snapshot) {
          final proveedores = snapshot.data ?? [];
          return DropdownButtonFormField<String>(
            value: _idProveedorSeleccionado,
            decoration: const InputDecoration(
              labelText: 'Proveedor',
              prefixIcon: Icon(Icons.local_shipping_outlined),
              border: OutlineInputBorder(),
            ),
            items: proveedores.map((p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.nombre),
            )).toList(),
            onChanged: (val) => setState(() => _idProveedorSeleccionado = val),
          );
        },
      ),
    );
  }

  Widget _buildOmniBox() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeCtrl,
                  focusNode: _barcodeFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o escanear código...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _escanearBarcode,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: _onOmniBoxChanged,
                  onSubmitted: _onOmniBoxSubmitted,
                ),
              ),
            ],
          ),
          if (_mostrandoBusqueda)
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: Card(
                elevation: 4,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _resultadosBusqueda.length,
                  itemBuilder: (context, index) {
                    final p = _resultadosBusqueda[index];
                    return ListTile(
                      title: Text(p.nombre),
                      subtitle: Text('Stock: ${p.cantidad} - Costo: \$${p.costoActual.toStringAsFixed(2)}'),
                      onTap: () => _agregarProducto(p),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    if (_itemsCompra.isEmpty) {
      return const PremiumEmptyState(
        icon: Icons.add_shopping_cart,
        title: 'Lista de recepción vacía',
        subtitle: 'Escanea productos para ingresar mercancía.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _itemsCompra.length,
      itemBuilder: (context, index) {
        final item = _itemsCompra[index];
        return PremiumCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => setState(() => _itemsCompra.removeAt(index)),
                  ),
                ],
              ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cantidad', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.all(8),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            final c = double.tryParse(val) ?? 0.0;
                            setState(() {
                              _itemsCompra[index] = DetalleCompra(
                                productoId: item.productoId,
                                nombre: item.nombre,
                                cantidad: c,
                                costoUnitario: item.costoUnitario,
                              );
                            });
                          },
                          controller: TextEditingController(text: item.cantidad.toString())..selection = TextSelection.collapsed(offset: item.cantidad.toString().length),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Costo Unitario', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        TextField(
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.all(8),
                            border: OutlineInputBorder(),
                            prefixText: '\$',
                          ),
                          onChanged: (val) {
                            final cost = double.tryParse(val) ?? 0.0;
                            setState(() {
                              _itemsCompra[index] = DetalleCompra(
                                productoId: item.productoId,
                                nombre: item.nombre,
                                cantidad: item.cantidad,
                                costoUnitario: cost,
                              );
                            });
                          },
                          controller: TextEditingController(text: item.costoUnitario.toString())..selection = TextSelection.collapsed(offset: item.costoUnitario.toString().length),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Subtotal', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        Text(
                          '\$${item.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total de Compra:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              Text(
                '\$${_totalCompra.toStringAsFixed(2)}',
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
            height: 54,
            child: FilledButton(
              onPressed: _procesando ? null : _registrarCompra,
              child: _procesando
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Registrar Entrada de Stock', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
