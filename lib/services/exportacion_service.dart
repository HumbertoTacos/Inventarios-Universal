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

  /// Genera y descarga una plantilla CSV vacía para la importación de productos.
  static Future<void> descargarPlantillaCSV() async {
    final filas = <List<dynamic>>[
      // ── Cabeceras ──────────────────────────────────────────────────────────
      [
        'Nombre',
        'Categoria',
        'Precio',
        'Costo Base',
        'Cantidad',
        'Unidad',
        'CodigoBarras',
        'Atributos',
        'Proveedor',
      ],
      // ── Ejemplo 1: producto en piezas con atributos y código de barras ─────
      [
        'Sábana King Blanca',
        'Sábanas',
        '350.00',
        '220.00',
        '15',
        'pza',
        '7501234567890',
        'Tamaño:King, Color:Blanco',
        '',
      ],
      // ── Ejemplo 2: producto en piezas sin código de barras ────────────────
      [
        'Cobertor Matrimonial Gris',
        'Cobertores Lisos',
        '480.00',
        '310.00',
        '8',
        'pza',
        '',
        'Tamaño:Matrimonial, Color:Gris',
        '',
      ],
      // ── Ejemplo 3: producto fraccionado en kg ─────────────────────────────
      [
        'Tela de algodón',
        'Materiales',
        '45.50',
        '28.00',
        '12.75',
        'kg',
        '',
        '',
        '',
      ],
      // ── Ejemplo 4: producto fraccionado en litros ─────────────────────────
      [
        'Suavizante concentrado',
        'Limpieza',
        '85.00',
        '55.00',
        '6.5',
        'lt',
        '7509876543210',
        '',
        '',
      ],
      // ── Ejemplo 5: producto con proveedor (debe existir en el sistema) ─────
      [
        'Toalla de baño individual',
        'Toallas',
        '120.00',
        '75.00',
        '20',
        'pza',
        '',
        'Tamaño:Individual, Color:Azul',
        'Proveedor Ejemplo SA',
      ],
      // ── Notas (estas filas serán ignoradas si el Nombre está vacío) ────────
      ['', '', '', '', '', '', '', '', ''],
      ['--- NOTAS ---', '', '', '', '', '', '', '', ''],
      ['Unidad puede ser: pza, kg, lt, mt, caja, par u otro texto libre.', '', '', '', '', '', '', '', ''],
      ['Cantidad acepta decimales: 0.5 = media pieza, 1.75 = 1 kilo 750g.', '', '', '', '', '', '', '', ''],
      ['Atributos: Clave:Valor separados por comas. Ej: Talla:M, Color:Azul', '', '', '', '', '', '', '', ''],
      ['Proveedor: debe existir en el sistema, o dejar vacío.', '', '', '', '', '', '', '', ''],
      ['CodigoBarras: opcional, dejar vacío si no aplica.', '', '', '', '', '', '', '', ''],
    ];

    const converter = ListToCsvConverter();
    final csvString = converter.convert(filas);
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csvString)]);

    await FileSaver.instance.saveFile(
      name: 'plantilla_importacion_productos',
      bytes: bytes,
      ext: 'csv',
      mimeType: MimeType.csv,
    );
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
