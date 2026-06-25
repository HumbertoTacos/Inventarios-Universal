import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/producto.dart';
import '../models/venta.dart';
import '../models/turno_caja.dart';
import '../models/negocio.dart';
import 'auth_service.dart';

class ImpresionService {
  // Caché simple en memoria para el logo durante la sesión
  static Uint8List? _logoBytesCache;
  static String? _logoUrlCache;
  static pw.Font? _fontCache;

  static Future<pw.Font> _getFont() async {
    _fontCache ??= await PdfGoogleFonts.robotoRegular();
    return _fontCache!;
  }

  static String _getSafeId(String id) {
    if (id.isEmpty) return 'N/A';
    return id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  static Future<pw.MemoryImage?> _getLogoImage(String? logoUrl) async {
    if (logoUrl == null || logoUrl.isEmpty) return null;

    try {
      // Si ya lo tenemos en caché y la URL no ha cambiado, usarlo directamente
      if (_logoBytesCache != null && _logoUrlCache == logoUrl) {
        return pw.MemoryImage(_logoBytesCache!);
      }

      // Descargar imagen
      final response = await http.get(Uri.parse(logoUrl));
      if (response.statusCode == 200) {
        _logoBytesCache = response.bodyBytes;
        _logoUrlCache = logoUrl;
        return pw.MemoryImage(_logoBytesCache!);
      }
    } catch (e) {
      // ignore logo download errors
    }
    return null;
  }

  static const String _linea = '--------------------------------';
  static const String _lineaDelgada = '- - - - - - - - - - - - - - - -';

  /// Genera e imprime una etiqueta para un producto (Formato Térmico 58x40mm aprox)
  static Future<void> imprimirEtiquetaProducto(Producto producto) async {
    if (producto.codigoBarras == null || producto.codigoBarras!.isEmpty) {
      throw Exception('El producto no tiene código de barras configurado.');
    }

    final pdf = pw.Document();

    const double width = 58 * PdfPageFormat.mm;
    const double height = 40 * PdfPageFormat.mm;
    final format = PdfPageFormat(width, height, marginAll: 2 * PdfPageFormat.mm);

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  producto.nombre.toUpperCase(),
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                  maxLines: 2,
                  overflow: pw.TextOverflow.clip,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '\$${producto.precio.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.SizedBox(
                  height: 40,
                  width: 140, // Aumentamos un poco el ancho para el código de barras
                  child: pw.BarcodeWidget(
                    barcode: Barcode.code128(),
                    data: producto.codigoBarras!,
                    drawText: true,
                    textStyle: pw.TextStyle(fontSize: 8),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (kIsWeb) {
      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'Etiqueta_${producto.nombre}.pdf');
    } else {
      await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Etiqueta_${producto.nombre}');
    }
  }

  /// Genera e imprime etiquetas en formato Planilla A4 (ej. 4x6 etiquetas por hoja)
  /// Permite seleccionar en qué posición iniciar (para aprovechar hojas parcialmente usadas)
  static Future<void> imprimirPlanillaEtiquetasA4({
    required Producto producto,
    required int cantidad,
    required int posicionInicial, // 1-indexed
  }) async {
    if (producto.codigoBarras == null || producto.codigoBarras!.isEmpty) {
      throw Exception('El producto no tiene código de barras configurado.');
    }

    final pdf = pw.Document();
    
    // Formato A4 estándar
    const format = PdfPageFormat.a4;
    
    // Configuración de cuadrícula 4 columnas x 6 filas = 24 etiquetas por hoja
    const int columnas = 4;
    const int filas = 6;
    const int etiquetasPorHoja = columnas * filas;

    // Márgenes de la hoja (1 cm aprox)
    const double margin = 10 * PdfPageFormat.mm;
    
    // Dimensiones de cada etiqueta
    final double cellWidth = (format.width - (margin * 2)) / columnas;
    final double cellHeight = (format.height - (margin * 2)) / filas;

    int etiquetasImpresas = 0;
    int posicionActual = posicionInicial - 1; // 0-indexed para lógica interna

    // Calcular cuántas hojas necesitamos
    final int posicionesTotales = posicionActual + cantidad;
    final int hojasNecesarias = (posicionesTotales / etiquetasPorHoja).ceil();

    for (int hoja = 0; hoja < hojasNecesarias; hoja++) {
      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.all(margin),
          build: (pw.Context context) {
            final List<pw.Widget> gridChildren = [];

            for (int f = 0; f < filas; f++) {
              for (int c = 0; c < columnas; c++) {
                final int indexAbsoluto = (hoja * etiquetasPorHoja) + (f * columnas) + c;
                
                pw.Widget contenidoCelda = pw.SizedBox(); // Vacío por defecto

                // Si estamos en el rango de etiquetas a imprimir
                if (indexAbsoluto >= posicionActual && etiquetasImpresas < cantidad) {
                  contenidoCelda = pw.Container(
                    width: cellWidth,
                    height: cellHeight,
                    padding: const pw.EdgeInsets.all(4 * PdfPageFormat.mm),
                    // Border opcional para ver el corte, lo dejamos transparente o muy suave
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5, style: pw.BorderStyle.dashed),
                    ),
                    child: pw.Center(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text(
                            producto.nombre.toUpperCase(),
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center,
                            maxLines: 2,
                            overflow: pw.TextOverflow.clip,
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            '\$${producto.precio.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center,
                          ),
                          pw.SizedBox(height: 4),
                          pw.SizedBox(
                            height: 30,
                            width: cellWidth * 0.85,
                            child: pw.BarcodeWidget(
                              barcode: Barcode.code128(),
                              data: producto.codigoBarras!,
                              drawText: true,
                              textStyle: pw.TextStyle(fontSize: 7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  etiquetasImpresas++;
                }

                gridChildren.add(
                  pw.Positioned(
                    left: c * cellWidth,
                    top: f * cellHeight,
                    child: contenidoCelda,
                  )
                );
              }
            }

            return pw.Stack(children: gridChildren);
          },
        ),
      );
    }

    if (kIsWeb) {
      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'Planilla_Etiquetas_${producto.nombre}.pdf');
    } else {
      await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Planilla_Etiquetas_${producto.nombre}');
    }
  }

  /// Genera e imprime el Ticket de Venta Profesional para impresoras térmicas (58mm/80mm)
  static Future<void> imprimirTicketVenta({
    required Venta venta,
    required Negocio negocio,
    required double pagoCliente,
    TurnoCaja? turno,
  }) async {
    final pdf = pw.Document();
    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');
    final font = await _getFont();
    final fontBold = await PdfGoogleFonts.robotoBold();
    
    // Obtenemos el nombre del usuario actual para el pie de página
    final String atendidoPor = AuthService().currentUserData?.nombre ?? 'Sistema';
    final double cambio = (pagoCliente - venta.total).clamp(0.0, double.infinity);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── CABECERA ───────────────────────────────────────────
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      negocio.nombre.toUpperCase(),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (negocio.direccion != null && negocio.direccion!.isNotEmpty)
                      pw.Text(negocio.direccion!, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7)),
                    if (negocio.telefono != null && negocio.telefono!.isNotEmpty)
                      pw.Text('Tel: ${negocio.telefono}', style: pw.TextStyle(fontSize: 7)),
                    pw.SizedBox(height: 4),
                    pw.Text(_linea, style: pw.TextStyle(fontSize: 6)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Folio: ${_getSafeId(venta.id)}', style: pw.TextStyle(fontSize: 7)),
                        pw.Text(formatter.format(venta.fecha), style: pw.TextStyle(fontSize: 7)),
                      ],
                    ),
                    pw.Text(_linea, style: pw.TextStyle(fontSize: 6)),
                  ],
                ),
              ),

              pw.SizedBox(height: 4),

              // ── CUERPO (PRODUCTOS) ──────────────────────────────────
              pw.Row(
                children: [
                  pw.SizedBox(width: 20, child: pw.Text('CT', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(child: pw.Text('DESCRIPCION', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(width: 40, child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.Text(_lineaDelgada, style: pw.TextStyle(fontSize: 6)),

              ...venta.items.map((item) {
                // Truncamos el nombre si es muy largo para que no rompa la línea de forma desordenada
                String nombreCorto = item.nombre;
                if (nombreCorto.length > 22) {
                  nombreCorto = '${nombreCorto.substring(0, 19)}...';
                }

                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(width: 20, child: pw.Text(_formatCantidad(item.cantidad), style: pw.TextStyle(fontSize: 7))),
                      pw.Expanded(child: pw.Text(nombreCorto, style: pw.TextStyle(fontSize: 7))),
                      pw.SizedBox(width: 40, child: pw.Text('\$${item.subtotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 4),
              pw.Text(_linea, style: pw.TextStyle(fontSize: 6)),

              // ── TOTALES ─────────────────────────────────────────────
              _filaTotal('SUBTOTAL:', '\$${venta.subtotal.toStringAsFixed(2)}', size: 8),
              if (venta.descuentoAplicado > 0)
                _filaTotal('DESCUENTO:', '-\$${venta.descuentoAplicado.toStringAsFixed(2)}', size: 8),
              if (venta.costoEnvio > 0)
                _filaTotal('ENVÍO:', '\$${venta.costoEnvio.toStringAsFixed(2)}', size: 8),
              
              pw.SizedBox(height: 2),
              _filaTotal('TOTAL A PAGAR:', '\$${venta.total.toStringAsFixed(2)}', boldness: pw.FontWeight.bold, size: 11),
              
              pw.SizedBox(height: 2),
              pw.Text(_lineaDelgada, style: pw.TextStyle(fontSize: 6)),
              _filaTotal('EFECTIVO RECIBIDO:', '\$${pagoCliente.toStringAsFixed(2)}', size: 8),
              _filaTotal('CAMBIO:', '\$${cambio.toStringAsFixed(2)}', boldness: pw.FontWeight.bold, size: 9),
              
              pw.SizedBox(height: 4),
              pw.Text(_linea, style: pw.TextStyle(fontSize: 6)),

              // ── PIE DE PÁGINA ───────────────────────────────────────
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('¡GRACIAS POR SU COMPRA!', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Vuelva pronto', style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
                    pw.SizedBox(height: 6),
                    pw.Text('Atendido por: $atendidoPor', style: pw.TextStyle(fontSize: 7)),
                    pw.SizedBox(height: 4),
                    pw.BarcodeWidget(
                      barcode: Barcode.qrCode(),
                      data: 'Ticket-${venta.id}',
                      width: 35,
                      height: 35,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
            ],
          );
        },
      ),
    );

    if (kIsWeb) {
      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'Ticket_${venta.id}.pdf');
    } else {
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(), 
        name: 'Ticket_${venta.id}',
        // Forzamos un formato de página que las impresoras térmicas entiendan bien si están instaladas como genéricas
        format: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
      );
    }
  }

  /// Genera e imprime el Corte Z (Cierre de Caja) para el administrador
  static Future<void> imprimirCorteZ(TurnoCaja turno, Negocio negocio) async {
    final pdf = pw.Document();
    final DateFormat fmt = DateFormat('dd/MM/yy HH:mm');
    final font = await _getFont();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final pw.MemoryImage? logoImage = await _getLogoImage(negocio.logoUrl);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          final double diferencia = turno.diferenciaEfectivo;
          String textoDiferencia = 'CUADRE EXACTO';
          if (diferencia < 0) {
            textoDiferencia = 'FALTANTE';
          } else if (diferencia > 0) {
            textoDiferencia = 'SOBRANTE';
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null)
                 pw.Center(
                  child: pw.Container(
                    width: 100,
                    height: 50,
                    margin: const pw.EdgeInsets.only(bottom: 5),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                ),
              pw.Center(child: pw.Text('CORTE Z', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
              pw.Center(child: pw.Text(negocio.nombre, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 5),
              pw.Text('Apertura: ${fmt.format(turno.fechaApertura)}', style: pw.TextStyle(fontSize: 9)),
              if (turno.fechaCierre != null)
                pw.Text('Cierre: ${fmt.format(turno.fechaCierre!)}', style: pw.TextStyle(fontSize: 9)),
              
              pw.SizedBox(height: 5),
              pw.Text('--------------------------------'),
              pw.SizedBox(height: 5),
              
              _filaResumen('Fondo Inicial:', turno.fondoInicial),
              _filaResumen('Ventas en Efectivo:', turno.ventasEfectivo),
              _filaResumen('Entradas de Dinero:', turno.entradasEfectivo),
              _filaResumen('Salidas/Retiros:', -turno.egresosEfectivo),
              
              pw.SizedBox(height: 5),
              pw.Text('--------------------------------'),
              pw.SizedBox(height: 5),
              
              _filaResumen('EFECTIVO ESPERADO:', turno.totalEsperadoEfectivo, boldness: pw.FontWeight.bold, size: 10),
              if (turno.efectivoContado != null)
                _filaResumen('EFECTIVO CONTADO:', turno.efectivoContado!, boldness: pw.FontWeight.bold, size: 10),
              
              if (turno.efectivoContado != null) ...[
                pw.SizedBox(height: 5),
                _filaResumen('DIFERENCIA:', diferencia, boldness: pw.FontWeight.bold, size: 10),
                pw.Center(
                  child: pw.Text(
                    textoDiferencia,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
              
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('-------------------------', style: pw.TextStyle(fontSize: 8))),
              pw.Center(child: pw.Text('FIRMA RESPONSABLE', style: pw.TextStyle(fontSize: 8))),
            ],
          );
        },
      ),
    );

    if (kIsWeb) {
      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'CorteZ_${turno.id}.pdf');
    } else {
      await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'CorteZ_${turno.id}');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _formatCantidad(double c) =>
      c == c.truncateToDouble() ? c.toInt().toString() : c.toStringAsFixed(2);

  static pw.Widget _filaTotal(String label, String valor, {pw.FontWeight? boldness, double size = 8}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: size, fontWeight: boldness)),
        pw.Text(valor, style: pw.TextStyle(fontSize: size, fontWeight: boldness)),
      ],
    );
  }

  static pw.Widget _filaResumen(String label, double monto, {pw.FontWeight? boldness, double size = 8}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: size, fontWeight: boldness)),
          pw.Text('\$${monto.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: size, fontWeight: boldness)),
        ],
      ),
    );
  }
}
