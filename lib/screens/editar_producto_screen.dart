import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/producto.dart';
import '../models/proveedor.dart';
import '../services/firebase_service.dart';
import 'barcode_scanner_screen.dart';
import '../services/impresion_service.dart';

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
  late final TextEditingController _cantMayoreoCtrl;
  late final TextEditingController _precioMayoreoCtrl;
  late final TextEditingController _precioPromocionCtrl;
  late final TextEditingController _stockMinimoCtrl;

  bool _guardando = false;
  bool _enPromocion = false;
  String? _idProveedorSeleccionado;
  String? _nombreProveedorSeleccionado;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.producto.nombre);
    _costoCtrl = TextEditingController(text: widget.producto.costoPromedio.toStringAsFixed(2));
    _precioCtrl = TextEditingController(text: widget.producto.precio.toStringAsFixed(2));
    _descripcionCtrl = TextEditingController(text: widget.producto.descripcion);
    _codigoBarrasCtrl = TextEditingController(text: widget.producto.codigoBarras ?? '');
    _cantMayoreoCtrl = TextEditingController(text: widget.producto.cantidadMayoreo?.toString() ?? '');
    _precioMayoreoCtrl = TextEditingController(text: widget.producto.precioMayoreo?.toString() ?? '');
    _enPromocion = widget.producto.enPromocion;
    _precioPromocionCtrl = TextEditingController(text: widget.producto.precioPromocion?.toString() ?? '');
    _idProveedorSeleccionado = widget.producto.proveedorId;
    _nombreProveedorSeleccionado = widget.producto.proveedorNombre;
    _stockMinimoCtrl = TextEditingController(text: widget.producto.stockMinimo.toString());
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _costoCtrl.dispose();
    _precioCtrl.dispose();
    _descripcionCtrl.dispose();
    _codigoBarrasCtrl.dispose();
    _cantMayoreoCtrl.dispose();
    _precioMayoreoCtrl.dispose();
    _precioPromocionCtrl.dispose();
    _stockMinimoCtrl.dispose();
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

  void _generarCodigoInterno() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final code = timestamp.substring(timestamp.length - 10);
    setState(() => _codigoBarrasCtrl.text = '750$code');
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
        cantidadMayoreo: int.tryParse(_cantMayoreoCtrl.text),
        precioMayoreo: double.tryParse(_precioMayoreoCtrl.text),
        enPromocion: _enPromocion,
        precioPromocion: _enPromocion ? double.tryParse(_precioPromocionCtrl.text) : null,
        proveedorId: _idProveedorSeleccionado,
        proveedorNombre: _nombreProveedorSeleccionado,
        stockMinimo: double.tryParse(_stockMinimoCtrl.text.trim()) ?? 0.0,
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
        actions: [
          if (widget.producto.codigoBarras != null && widget.producto.codigoBarras!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print_outlined),
              tooltip: 'Imprimir Etiqueta',
              onPressed: () async {
                try {
                  await ImpresionService.imprimirEtiquetaProducto(widget.producto);
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

                        // ── Historial de Última Compra ──
                        if (widget.producto.ultimaCompraFecha != null)
                          Card(
                            elevation: 0,
                            color: Colors.blue.shade50,
                            margin: const EdgeInsets.only(bottom: 24),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.history, color: Colors.blue.shade800, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Última Compra',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Fecha', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          Text(
                                            DateFormat('dd/MM/yyyy HH:mm').format(widget.producto.ultimaCompraFecha!),
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          const Text('Costo Unitario', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          Text(
                                            '\$${widget.producto.ultimoCostoCompra?.toStringAsFixed(2) ?? "0.00"}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
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

                        // ── Proveedor ──
                        StreamBuilder<List<Proveedor>>(
                          stream: _firebaseService.getProveedores(),
                          builder: (context, snapshot) {
                            final proveedores = snapshot.data ?? [];
                            return DropdownButtonFormField<String>(
                              value: _idProveedorSeleccionado,
                              decoration: const InputDecoration(
                                labelText: 'Proveedor Preferido',
                                prefixIcon: Icon(Icons.local_shipping_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: proveedores.map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.nombreComercial),
                              )).toList(),
                              onChanged: (val) {
                                final p = proveedores.firstWhere((element) => element.id == val);
                                setState(() {
                                  _idProveedorSeleccionado = val;
                                  _nombreProveedorSeleccionado = p.nombreComercial;
                                });
                              },
                            );
                          },
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
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _cantMayoreoCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Cant. Mayoreo',
                                  prefixIcon: Icon(Icons.shopping_basket_outlined),
                                  border: OutlineInputBorder(),
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
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stock Mínimo
                        TextFormField(
                          controller: _stockMinimoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Stock Mínimo (Alerta de Reabastecimiento) *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.warning_amber_outlined),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Requerido';
                            if ((double.tryParse(v.trim()) ?? -1) < 0) return 'Invalido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ── Promociones ──
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Theme.of(context).colorScheme.primaryContainer),
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
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                    validator: (v) {
                                      if (!_enPromocion) return null;
                                      if (v == null || v.trim().isEmpty) return 'Requerido';
                                      final n = double.tryParse(v.trim());
                                      final precioReg = double.tryParse(_precioCtrl.text);
                                      if (n == null || n <= 0) return 'Inválido';
                                      if (precioReg != null && n >= precioReg) return 'Debe ser menor al normal';
                                      return null;
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Código de Barras
                        TextFormField(
                          controller: _codigoBarrasCtrl,
                          decoration: InputDecoration(
                            labelText: 'Código de barras',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.qr_code),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.auto_fix_high),
                                  onPressed: _generarCodigoInterno,
                                  tooltip: 'Autogenerar código',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.camera_alt),
                                  onPressed: _escanearCodigo,
                                  tooltip: 'Escanear con la cámara',
                                ),
                              ],
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
