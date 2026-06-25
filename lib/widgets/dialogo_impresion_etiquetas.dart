import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/producto.dart';
import '../services/impresion_service.dart';

class DialogoImpresionEtiquetas extends StatefulWidget {
  final Producto producto;

  const DialogoImpresionEtiquetas({super.key, required this.producto});

  @override
  State<DialogoImpresionEtiquetas> createState() => _DialogoImpresionEtiquetasState();

  static Future<void> mostrar(BuildContext context, Producto producto) {
    return showDialog(
      context: context,
      builder: (ctx) => DialogoImpresionEtiquetas(producto: producto),
    );
  }
}

class _DialogoImpresionEtiquetasState extends State<DialogoImpresionEtiquetas> {
  bool _esFormatoA4 = true;
  final TextEditingController _cantidadCtrl = TextEditingController(text: '1');
  final TextEditingController _posicionCtrl = TextEditingController(text: '1');
  bool _imprimiendo = false;

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _posicionCtrl.dispose();
    super.dispose();
  }

  Future<void> _imprimir() async {
    final cantidad = int.tryParse(_cantidadCtrl.text) ?? 1;
    final posicion = int.tryParse(_posicionCtrl.text) ?? 1;

    if (cantidad < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La cantidad debe ser al menos 1')),
      );
      return;
    }

    if (_esFormatoA4 && (posicion < 1 || posicion > 24)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La posición inicial debe estar entre 1 y 24')),
      );
      return;
    }

    setState(() => _imprimiendo = true);

    try {
      if (_esFormatoA4) {
        await ImpresionService.imprimirPlanillaEtiquetasA4(
          producto: widget.producto,
          cantidad: cantidad,
          posicionInicial: posicion,
        );
      } else {
        // Para impresora térmica imprimimos N veces (o le delegamos generar un PDF con N páginas)
        // Actualmente el imprimirEtiquetaProducto hace 1 página. 
        // Si el usuario quiere 5 etiquetas térmicas seguidas, habría que modificar ImpresionService.
        // Por simplicidad, llamamos N veces o le decimos que desde el diálogo de impresión ponga "Copias".
        // Lo mejor es dejarle que ponga "Copias" en el diálogo del sistema para térmica.
        await ImpresionService.imprimirEtiquetaProducto(widget.producto);
      }
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al imprimir: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Imprimir Etiquetas'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Producto: ${widget.producto.nombre}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // Selector de formato
            Text('Formato de impresión', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Planilla A4 (4x6)'), icon: Icon(Icons.grid_on)),
                ButtonSegment(value: false, label: Text('Térmica'), icon: Icon(Icons.receipt_long)),
              ],
              selected: {_esFormatoA4},
              onSelectionChanged: (set) => setState(() => _esFormatoA4 = set.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: colorScheme.primaryContainer,
              ),
            ),
            const SizedBox(height: 24),

            // Campos dinámicos
            if (_esFormatoA4) ...[
              const Text('Se generará un PDF tamaño A4 con una cuadrícula de 4 columnas por 6 filas (24 etiquetas por hoja).', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cantidadCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Cantidad a imprimir',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _posicionCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Posición Inicial (1-24)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        helperText: 'Aprovecha hojas ya empezadas',
                        helperMaxLines: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text('Se generará un PDF de tamaño pequeño ideal para impresoras térmicas de etiquetas (58x40mm).', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('Nota: Para imprimir varias, cambia el número de "Copias" en la ventana de impresión del sistema.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _imprimiendo ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _imprimiendo ? null : _imprimir,
          icon: _imprimiendo ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.print),
          label: Text(_imprimiendo ? 'Generando...' : 'Imprimir'),
        ),
      ],
    );
  }
}
