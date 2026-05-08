import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import '../models/venta.dart';

/// Servicio de exportación multiplataforma.
/// Funciona en Web (descarga del navegador), Android/iOS (carpeta Descargas) y Windows (diálogo Guardar como).
/// NO usa path_provider directamente, ce delega todo a [FileSaver].
class ExportacionService {
  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');
  static final _moneyFmt = NumberFormat('#,##0.00', 'es_MX');

  /// Exporta una lista de [Venta] a CSV y la guarda/descarga según la plataforma.
  /// Retorna el nombre del archivo generado.
  static Future<String> exportarVentasCSV(
    List<Venta> ventas, {
    String? nombreArchivo,
  }) async {
    final archivo = nombreArchivo ?? 'ventas_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';

    // ── Cabeceras ─────────────────────────────────────────────────────────
    final filas = <List<dynamic>>[
      [
        'Folio',
        'Fecha',
        'Estado',
        'Método de Pago',
        'Productos',
        'Subtotal',
        'Descuento',
        'Total',
      ]
    ];

    // ── Filas de datos ────────────────────────────────────────────────────
    for (final v in ventas) {
      final productos = v.items
          .map((i) => '${i.nombre} x${i.cantidad} @ \$${_moneyFmt.format(i.precioUnitario)}')
          .join(' | ');

      filas.add([
        v.id.length >= 8 ? v.id.substring(0, 8).toUpperCase() : v.id.toUpperCase(),
        _dateFmt.format(v.fecha),
        v.estado,
        _metodoPago(v.metodoPago),
        productos,
        _moneyFmt.format(v.subtotal),
        _moneyFmt.format(v.descuentoAplicado),
        _moneyFmt.format(v.total),
      ]);
    }

    // ── Resumen al final ──────────────────────────────────────────────────
    final totalVentas = ventas
        .where((v) => v.estado == 'completada')
        .fold(0.0, (sum, v) => sum + v.total);
    filas.addAll([
      [], // línea vacía
      ['', '', '', '', 'TOTAL INGRESOS', '', '', _moneyFmt.format(totalVentas)],
    ]);

    // ── Conversión a CSV ──────────────────────────────────────────────────
    const converter = ListToCsvConverter();
    final csvString = converter.convert(filas);

    // BOM UTF-8 para que Excel lo abra correctamente con acentos
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csvString)]);

    // ── Guardado multiplataforma ──────────────────────────────────────────
    // FileSaver decide automáticamente:
    //   Web → <a download> en el navegador
    //   Android → MediaStore (sin permisos necesarios en API 29+)
    //   Windows/Linux/macOS → diálogo "Guardar como"
    await FileSaver.instance.saveFile(
      name: archivo,
      bytes: bytes,
      ext: 'csv',
      mimeType: MimeType.csv,
    );

    return '$archivo.csv';
  }

  /// Exporta inventario de productos a CSV.
  static Future<String> exportarInventarioCSV(
    List<Map<String, dynamic>> productos, {
    String? nombreArchivo,
  }) async {
    final archivo = nombreArchivo ?? 'inventario_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';

    final filas = <List<dynamic>>[
      ['Nombre', 'Categoría', 'Código de Barras', 'Stock', 'Precio Venta', 'Costo Promedio'],
      ...productos.map((p) => [
            p['nombre'] ?? '',
            p['categoria'] ?? '',
            p['codigoBarras'] ?? '',
            p['cantidad'] ?? 0,
            _moneyFmt.format((p['precio'] as num?)?.toDouble() ?? 0),
            _moneyFmt.format((p['costo_promedio'] as num? ?? p['costo'] as num?)?.toDouble() ?? 0),
          ]),
    ];

    const converter = ListToCsvConverter();
    final csvString = converter.convert(filas);
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csvString)]);

    await FileSaver.instance.saveFile(
      name: archivo,
      bytes: bytes,
      ext: 'csv',
      mimeType: MimeType.csv,
    );

    return '$archivo.csv';
  }

  static String _metodoPago(MetodoPago m) {
    return switch (m) {
      MetodoPago.efectivo => 'Efectivo',
      MetodoPago.tarjeta => 'Tarjeta',
      MetodoPago.transferencia => 'Transferencia',
      MetodoPago.credito => 'Crédito',
    };
  }
}
