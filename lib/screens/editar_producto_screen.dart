import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/producto.dart';
import '../services/firebase_service.dart';
import 'barcode_scanner_screen.dart';

class EditarProductoScreen extends StatefulWidget {
  final Producto producto;

  const EditarProductoScreen({super.key, required this.producto});

  @override
  State<EditarProductoScreen> createState() => _EditarProductoScreenState();
}

class _EditarProductoScreenState extends State<EditarProductoScreen> {
  final _firebaseService = FirebaseService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _costoCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _descripcionCtrl;
  late final TextEditingController _codigoBarrasCtrl;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.producto.nombre);
    _costoCtrl = TextEditingController(text: widget.producto.costoPromedio.toStringAsFixed(2));
    _precioCtrl = TextEditingController(text: widget.producto.precio.toStringAsFixed(2));
    _descripcionCtrl = TextEditingController(text: widget.producto.descripcion);
    _codigoBarrasCtrl = TextEditingController(text: widget.producto.codigoBarras ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _costoCtrl.dispose();
    _precioCtrl.dispose();
    _descripcionCtrl.dispose();
    _codigoBarrasCtrl.dispose();
    super.dispose();
  }

  Future<void> _escanearCodigo() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _codigoBarrasCtrl.text = result;
      });
    }
  }

  Future<void> _guardarCambios() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final productoEditado = widget.producto.copyWith(
        nombre: _nombreCtrl.text.trim(),
        costoPromedio: double.parse(_costoCtrl.text.trim()),
        precio: double.parse(_precioCtrl.text.trim()),
        descripcion: _descripcionCtrl.text.trim(),
        codigoBarras: _codigoBarrasCtrl.text.trim().isNotEmpty ? _codigoBarrasCtrl.text.trim() : null,
      );

      await _firebaseService.actualizarProducto(productoEditado);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto actualizado'), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Regresar al inventario
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Producto'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _guardando
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Información no editable (como recordatorio)
                        Card(
                          elevation: 0,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Categoría: ${widget.producto.categoria}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                ...widget.producto.atributos.entries.map(
                                  (e) => Text('${e.key}: ${e.value}'),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Estos valores estructurales no se pueden editar. Elimina el producto y crea uno nuevo si necesitas cambiar su categoría.',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.5),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Nombre
                        TextFormField(
                          controller: _nombreCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del producto *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 16),

                        // Costo Modificable
                        TextFormField(
                          controller: _costoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Costo base de compra (Unitario) *',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Requerido';
                            if ((double.tryParse(v.trim()) ?? -1) < 0) return 'Invalido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Precio Moficable
                        TextFormField(
                          controller: _precioCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Precio de venta al público *',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.sell),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Requerido';
                            if ((double.tryParse(v.trim()) ?? -1) < 0) return 'Invalido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Código de Barras
                        TextFormField(
                          controller: _codigoBarrasCtrl,
                          decoration: InputDecoration(
                            labelText: 'Código de barras',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.qr_code),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.camera_alt),
                              onPressed: _escanearCodigo,
                              tooltip: 'Escanear con la cámara',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Descripción
                        TextFormField(
                          controller: _descripcionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Descripción adicional (opcional)',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 32),

                        FilledButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar Cambios', style: TextStyle(fontSize: 16)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _guardarCambios,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
