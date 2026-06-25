import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/proveedor.dart';
import '../services/firebase_service.dart';
import 'barcode_scanner_screen.dart';
import 'gestion_categorias_screen.dart';

class AgregarProductoScreen extends StatefulWidget {
  const AgregarProductoScreen({super.key});

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();

  // Controladores base
  final _nombreCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _codigoBarrasCtrl = TextEditingController();
  final _cantMayoreoCtrl = TextEditingController();
  final _precioMayoreoCtrl = TextEditingController();
  final _precioPromocionCtrl = TextEditingController();
  final _stockMinimoCtrl = TextEditingController();

  bool _guardando = false;
  bool _enPromocion = false;
  bool _permiteDecimales = false;
  Categoria? _categoriaSeleccionada;
  String? _idProveedorSeleccionado;
  String? _nombreProveedorSeleccionado;

  // Valores dinámicos por atributo: nombre → valor elegido/escrito
  final Map<String, String> _atributos = {};
  // Controladores de texto libre: nombre → controller
  final Map<String, TextEditingController> _atributoCtrl = {};

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    _costoCtrl.dispose();
    _precioCtrl.dispose();
    _descripcionCtrl.dispose();
    _codigoBarrasCtrl.dispose();
    _cantMayoreoCtrl.dispose();
    _precioMayoreoCtrl.dispose();
    _precioPromocionCtrl.dispose();
    _stockMinimoCtrl.dispose();
    for (final c in _atributoCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Reconstruye los controladores de atributos cuando cambia la categoría.
  void _alCambiarCategoria(Categoria? cat) {
    // Liberar controladores anteriores
    for (final c in _atributoCtrl.values) {
      c.dispose();
    }
    _atributoCtrl.clear();
    _atributos.clear();

    if (cat != null) {
      for (final attr in cat.atributos) {
        if (!attr.esListaFija) {
          _atributoCtrl[attr.nombre] = TextEditingController();
        }
      }
    }

    setState(() {
      _categoriaSeleccionada = cat;
    });
  }

  Future<void> _mostrarDialogoNuevaCategoria() async {
    final nueva = await showDialog<Categoria>(
      context: context,
      builder: (ctx) => CategoriaFormDialog(
        firebaseService: _firebaseService,
      ),
    );

    if (nueva != null) {
      setState(() {
        _categoriaSeleccionada = nueva;
      });
      _alCambiarCategoria(_categoriaSeleccionada);
    } else {
      setState(() {
        _categoriaSeleccionada = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agregar Producto',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 0,
      ),
      body: StreamBuilder<List<Categoria>>(
        stream: _firebaseService.getCategorias(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Error al cargar categorías: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final categorias = snapshot.data ?? [];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Nombre ──
                      TextFormField(
                        controller: _nombreCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del producto *',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Ingresa un nombre' : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Categoría ──
                      DropdownButtonFormField<Categoria>(
                        value: _categoriaSeleccionada,
                        decoration: const InputDecoration(
                          labelText: 'Categoría *',
                          prefixIcon: Icon(Icons.category_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          ...categorias.map((cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat.nombre),
                              )),
                          if (_categoriaSeleccionada != null && !categorias.any((c) => c.id == _categoriaSeleccionada!.id) && _categoriaSeleccionada!.id != 'NUEVA')
                            DropdownMenuItem(
                              value: _categoriaSeleccionada,
                              child: Text(_categoriaSeleccionada!.nombre),
                            ),
                          const DropdownMenuItem(
                            value: Categoria(id: 'NUEVA', nombre: '+ Crear Nueva Categoría', atributos: []),
                            child: Text('+ Crear Nueva Categoría', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                          )
                        ],
                        onChanged: (val) {
                          if (val?.id == 'NUEVA') {
                            _mostrarDialogoNuevaCategoria();
                          } else {
                            _alCambiarCategoria(val);
                          }
                        },
                        validator: (v) =>
                            (v == null || v.id == 'NUEVA') ? 'Selecciona una categoría' : null,
                      ),
                      const SizedBox(height: 16),

                      // ── Proveedor ──
                      StreamBuilder<List<Proveedor>>(
                        stream: _firebaseService.getProveedores(),
                        builder: (context, provSnap) {
                          final proveedores = provSnap.data ?? [];
                          return DropdownButtonFormField<String>(
                            value: _idProveedorSeleccionado,
                            decoration: const InputDecoration(
                              labelText: 'Proveedor Preferido (opcional)',
                              prefixIcon: Icon(Icons.local_shipping_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: proveedores.map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(p.nombreComercial),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final p = proveedores.firstWhere((element) => element.id == val);
                                setState(() {
                                  _idProveedorSeleccionado = val;
                                  _nombreProveedorSeleccionado = p.nombreComercial;
                                });
                              } else {
                                setState(() {
                                  _idProveedorSeleccionado = null;
                                  _nombreProveedorSeleccionado = null;
                                });
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Atributos dinámicos ──
                      if (_categoriaSeleccionada != null)
                        ..._buildAtributoFields(_categoriaSeleccionada!),

                      // ── Cantidad ──
                      TextFormField(
                        controller: _cantidadCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cantidad *',
                          prefixIcon: Icon(Icons.numbers),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if ((double.tryParse(v.trim()) ?? -1) < 0) return 'Inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Stock Mínimo ──
                      TextFormField(
                        controller: _stockMinimoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Stock Mínimo (Alerta de Reabastecimiento) *',
                          prefixIcon: Icon(Icons.warning_amber_outlined),
                          border: OutlineInputBorder(),
                          hintText: 'Ej. 5.0',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if ((double.tryParse(v.trim()) ?? -1) < 0) return 'Inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // ── Costo y Precio ──
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _costoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Costo *',
                                prefixText: '\$ ',
                                prefixIcon: Icon(Icons.money_off),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requerido';
                                if ((double.tryParse(v.trim()) ?? -1) < 0) {
                                  return 'Inválido';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _precioCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Precio venta *',
                                prefixText: '\$ ',
                                prefixIcon: Icon(Icons.sell),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d+\.?\d{0,2}')),
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Requerido';
                                final n = double.tryParse(v.trim());
                                if (n == null || n < 0) return 'Inválido';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Mayoreo ──
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cantMayoreoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Cant. Mayoreo',
                                prefixIcon: Icon(Icons.shopping_basket_outlined),
                                border: OutlineInputBorder(),
                                hintText: 'Ej. 12',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _precioMayoreoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Precio Mayoreo',
                                prefixText: '\$ ',
                                prefixIcon: Icon(Icons.discount_outlined),
                                border: OutlineInputBorder(),
                                hintText: 'Ej. 10.00',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Promociones ──
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.primaryContainer),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: const Text('Activar Promoción (Oferta)', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text('Muestra un precio especial tachado'),
                              value: _enPromocion,
                              onChanged: (v) => setState(() => _enPromocion = v),
                            ),
                            if (_enPromocion)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextFormField(
                                  controller: _precioPromocionCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Precio de Promoción *',
                                    prefixText: '\$ ',
                                    prefixIcon: Icon(Icons.star_outline),
                                    border: OutlineInputBorder(),
                                    hintText: 'Debe ser menor al precio regular',
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                  validator: (v) {
                                    if (!_enPromocion) return null;
                                    if (v == null || v.trim().isEmpty) return 'Requerido';
                                    final n = double.tryParse(v.trim());
                                    if (n == null || n <= 0) return 'Inválido';
                                    final precioReg = double.tryParse(_precioCtrl.text);
                                    if (precioReg != null && n >= precioReg) return 'Debe ser menor al precio normal';
                                    return null;
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Venta Fraccionada ──
                      SwitchListTile(
                        title: const Text('Venta fraccionada (permite decimales)', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Útil para vender por peso, metros o fracciones (ej. 0.5, 1.5)'),
                        value: _permiteDecimales,
                        onChanged: (v) => setState(() => _permiteDecimales = v),
                        secondary: const Icon(Icons.scale_outlined),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colorScheme.outline.withAlpha(50))),
                      ),
                      const SizedBox(height: 16),

                      // ── Código de barras ──
                      TextFormField(
                        controller: _codigoBarrasCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Código de barras (opcional)',
                          prefixIcon: const Icon(Icons.qr_code),
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_codigoBarrasCtrl.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () =>
                                      setState(() => _codigoBarrasCtrl.clear()),
                                ),
                              IconButton(
                                icon: const Icon(Icons.auto_fix_high),
                                tooltip: 'Autogenerar código',
                                onPressed: _generarCodigoInterno,
                              ),
                              IconButton(
                                icon: const Icon(Icons.camera_alt),
                                tooltip: 'Escanear con cámara',
                                onPressed: _escanearCodigoBarras,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Descripción ──
                      TextFormField(
                        controller: _descripcionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                          prefixIcon: Icon(Icons.description_outlined),
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 28),

                      // ── Guardar ──
                      FilledButton.icon(
                        onPressed: _guardando ? null : _guardarProducto,
                        icon: _guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_guardando ? 'Guardando...' : 'Guardar producto'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Genera los campos de formulario para cada atributo de la categoría.
  List<Widget> _buildAtributoFields(Categoria categoria) {
    return categoria.atributos.map((attr) {
      if (attr.esListaFija) {
        // Combobox con las opciones definidas al crear la categoría
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DropdownButtonFormField<String>(
            key: ValueKey('attr_${categoria.id}_${attr.nombre}'),
            value: _atributos[attr.nombre],
            decoration: InputDecoration(
              labelText: '${attr.nombre} *',
              prefixIcon: const Icon(Icons.list_alt_outlined),
              border: const OutlineInputBorder(),
            ),
            items: attr.opciones
                .map((op) => DropdownMenuItem(value: op, child: Text(op)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _atributos[attr.nombre] = val);
            },
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Selecciona ${attr.nombre}' : null,
          ),
        );
      } else {
        // Texto libre
        final ctrl = _atributoCtrl[attr.nombre]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            key: ValueKey('attr_${categoria.id}_${attr.nombre}'),
            controller: ctrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: '${attr.nombre} *',
              prefixIcon: const Icon(Icons.edit_outlined),
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa ${attr.nombre}' : null,
          ),
        );
      }
    }).toList();
  }

  // ── Escanear código de barras ─────────────────────────────────────────────

  Future<void> _escanearCodigoBarras() async {
    final resultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (resultado != null && mounted) {
      setState(() => _codigoBarrasCtrl.text = resultado);
    }
  }

  void _generarCodigoInterno() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    // Tomamos los últimos 10 dígitos para un código limpio
    final code = timestamp.substring(timestamp.length - 10);
    setState(() => _codigoBarrasCtrl.text = '750$code'); // Prefijo interno ficticio
  }

  // ── Guardar producto ──────────────────────────────────────────────────────

  Future<void> _guardarProducto() async {
    // Recolectar valores de texto libre antes de validar
    for (final attr in _categoriaSeleccionada!.atributos) {
      if (!attr.esListaFija) {
        _atributos[attr.nombre] = _atributoCtrl[attr.nombre]!.text.trim();
      }
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    final producto = Producto(
      id: '',
      nombre: _nombreCtrl.text.trim(),
      categoria: _categoriaSeleccionada!.nombre,
      atributos: Map<String, String>.from(_atributos),
      cantidad: double.parse(_cantidadCtrl.text.trim()),
      costoPromedio: double.parse(_costoCtrl.text.trim()),
      precio: double.parse(_precioCtrl.text.trim()),
      descripcion: _descripcionCtrl.text.trim(),
      codigoBarras: _codigoBarrasCtrl.text.trim().isNotEmpty
          ? _codigoBarrasCtrl.text.trim()
          : null,
      cantidadMayoreo: int.tryParse(_cantMayoreoCtrl.text),
      precioMayoreo: double.tryParse(_precioMayoreoCtrl.text),
      enPromocion: _enPromocion,
      precioPromocion: _enPromocion ? double.tryParse(_precioPromocionCtrl.text) : null,
      proveedorId: _idProveedorSeleccionado,
      proveedorNombre: _nombreProveedorSeleccionado,
      stockMinimo: double.tryParse(_stockMinimoCtrl.text.trim()) ?? 0.0,
      permiteDecimales: _permiteDecimales,
    );

    try {
      final id = await _firebaseService.agregarProducto(producto);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${producto.nombre}" agregado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        final nuevoProducto = producto.copyWith(id: id);
        Navigator.pop(context, nuevoProducto);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

}
