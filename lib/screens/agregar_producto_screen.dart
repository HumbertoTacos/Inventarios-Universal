import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../services/firebase_service.dart';
import 'barcode_scanner_screen.dart';

class AgregarProductoScreen extends StatefulWidget {
  const AgregarProductoScreen({super.key});

  @override
  State<AgregarProductoScreen> createState() => _AgregarProductoScreenState();
}

class _AgregarProductoScreenState extends State<AgregarProductoScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();

  // Controladores
  final _nombreCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _codigoBarrasCtrl = TextEditingController();
  final _atributoCtrl = TextEditingController(); // color o diseño

  bool _guardando = false;

  // Selecciones de dropdowns en cascada
  Categoria? _categoriaSeleccionada;
  String? _tamanoSeleccionado;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _cantidadCtrl.dispose();
    _precioCtrl.dispose();
    _descripcionCtrl.dispose();
    _codigoBarrasCtrl.dispose();
    _atributoCtrl.dispose();
    super.dispose();
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
            return Center(child: Text('Error al cargar categorías: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final categorias = snapshot.data ?? [];

          return SingleChildScrollView(
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

                  // ── Categoría (Dropdown desde Firestore) ──
                  DropdownButtonFormField<Categoria>(
                    initialValue: _categoriaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoría *',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    items: categorias
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat.nombre),
                            ))
                        .toList(),
                    onChanged: (cat) {
                      setState(() {
                        _categoriaSeleccionada = cat;
                        _tamanoSeleccionado = null; // Reset tamaño
                        _atributoCtrl.clear();
                      });
                    },
                    validator: (v) => v == null ? 'Selecciona una categoría' : null,
                  ),
                  const SizedBox(height: 16),

                  // ── Tamaño (Dropdown dinámico según categoría) ──
                  if (_categoriaSeleccionada != null) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey('tamano_${_categoriaSeleccionada!.id}'),
                      initialValue: _tamanoSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Tamaño *',
                        prefixIcon: Icon(Icons.straighten),
                        border: OutlineInputBorder(),
                      ),
                      items: _categoriaSeleccionada!.tamanos
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _tamanoSeleccionado = value);
                      },
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Selecciona un tamaño' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Color o Diseño (dinámico según tipoAtributo) ──
                    TextFormField(
                      controller: _atributoCtrl,
                      decoration: InputDecoration(
                        labelText: _categoriaSeleccionada!.tipoAtributo == 'diseño'
                            ? 'Diseño *'
                            : 'Color *',
                        prefixIcon: Icon(
                          _categoriaSeleccionada!.tipoAtributo == 'diseño'
                              ? Icons.brush
                              : Icons.palette,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa un ${_categoriaSeleccionada!.tipoAtributo}'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Cantidad y Precio ──
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cantidadCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Cantidad *',
                            prefixIcon: Icon(Icons.numbers),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Requerido';
                            final n = int.tryParse(v.trim());
                            if (n == null || n < 0) return 'Número inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _precioCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Precio *',
                            prefixIcon: Icon(Icons.attach_money),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}'),
                            ),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Requerido';
                            final n = double.tryParse(v.trim());
                            if (n == null || n < 0) return 'Precio inválido';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Código de barras (cámara) ──
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

                  // ── Botón guardar ──
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
          );
        },
      ),
    );
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

  // ── Guardar producto ──────────────────────────────────────────────────────

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    final esDiseno = _categoriaSeleccionada!.tipoAtributo == 'diseño';

    final producto = Producto(
      id: '',
      nombre: _nombreCtrl.text.trim(),
      categoria: _categoriaSeleccionada!.nombre,
      tamano: _tamanoSeleccionado!,
      color: esDiseno ? null : _atributoCtrl.text.trim(),
      diseno: esDiseno ? _atributoCtrl.text.trim() : null,
      cantidad: int.parse(_cantidadCtrl.text.trim()),
      precio: double.parse(_precioCtrl.text.trim()),
      descripcion: _descripcionCtrl.text.trim(),
      codigoBarras: _codigoBarrasCtrl.text.trim().isNotEmpty
          ? _codigoBarrasCtrl.text.trim()
          : null,
    );

    try {
      await _firebaseService.agregarProducto(producto);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${producto.nombre}" agregado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
