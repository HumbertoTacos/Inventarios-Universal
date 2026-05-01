import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:barcode/barcode.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/producto.dart';
import '../models/venta.dart';
import '../models/turno_caja.dart';
import '../models/negocio.dart';

class ImpresionService {
  // Caché simple en memoria para el logo durante la sesión
  static Uint8List? _logoBytesCache;
  static String? _logoUrlCache;

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
          return pw.Column(
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
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                height: 40,
                width: 120,
                child: pw.BarcodeWidget(
                  barcode: Barcode.code128(),
                  data: producto.codigoBarras!,
                  drawText: true,
                  textStyle: pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Etiqueta_${producto.nombre}');
  }

  /// Genera e imprime el Ticket de Venta para el cliente
  /// [nombreCliente] se imprime si la venta es a CRÉDITO.
  static Future<void> imprimirTicketVenta(
    Venta venta,
    Negocio negocio, {
    String? nombreCliente,
  }) async {
    final pdf = pw.Document();
    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');
    
    final pw.MemoryImage? logoImage = await _getLogoImage(negocio.logoUrl);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Logo ────────────────────────────────────────────────
              if (logoImage != null)
                pw.Center(
                  child: pw.Container(
                    width: 120,
                    height: 70,
                    margin: const pw.EdgeInsets.only(bottom: 5),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                ),

              // ── Datos del negocio ────────────────────────────────────
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      negocio.nombre.toUpperCase(),
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13),
                      textAlign: pw.TextAlign.center,
                    ),
                    if (negocio.rfc != null)
                      pw.Text('RFC: ${negocio.rfc}', style: pw.TextStyle(fontSize: 7)),
                    if (negocio.direccion != null)
                      pw.Text(negocio.direccion!, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7)),
                    if (negocio.telefono != null)
                      pw.Text('Tel: ${negocio.telefono}', style: pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ),

              // ── Cliente (solo ventas a crédito) ─────────────────────
              if (venta.metodoPago == MetodoPago.credito && nombreCliente != null) ...[
                pw.SizedBox(height: 4),
                pw.Text(_lineaDelgada, style: pw.TextStyle(fontSize: 6)),
                pw.Text(
                  'Cliente: $nombreCliente',
                  style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                ),
              ],

              pw.SizedBox(height: 4),
              pw.Text(_linea, style: pw.TextStyle(fontSize: 6)),
              pw.Text('Ticket: ${venta.id.substring(0, 8).toUpperCase()}', style: pw.TextStyle(fontSize: 8)),
              pw.Text('Fecha : ${formatter.format(venta.fecha)}', style: pw.TextStyle(fontSize: 8)),
              pw.Text('Pago  : ${venta.metodoPago.name.toUpperCase()}', style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),
              pw.Text(_linea, style: pw.TextStyle(fontSize: 6)),

              // ── Encabezado tabla ────────────────────────────────────
              pw.Row(
                children: [
                  pw.SizedBox(
                    width: 24,
                    child: pw.Text('CANT', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.Expanded(
                    child: pw.Text('DESCRIPCIÓN', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(
                    width: 36,
                    child: pw.Text('TOTAL', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.Text(_lineaDelgada, style: pw.TextStyle(fontSize: 6)),

              // ── Filas de productos ───────────────────────────────────
              ...venta.items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.SizedBox(
                          width: 24,
                          child: pw.Text(
                            _formatCantidad(item.cantidad),
                            style: pw.TextStyle(fontSize: 7),
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            item.nombre,
                            style: pw.TextStyle(fontSize: 7),
                            maxLines: 2,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ),
                        pw.SizedBox(
                          width: 36,
                          child: pw.Text(
                            '\$${item.subtotal.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 7),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    // Precio unitario si aplica
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 24),
                      child: pw.Text(
                        '@\$${item.precioUnitario.toStringAsFixed(2)} c/u',
                        style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                      ),
                    ),
                  ],
                ),
              )),

              pw.Text(_linea, style: pw.TextStyle(fontSize: 6)),

              // ── Totales ──────────────────────────────────────────────
              _filaTotal('Subtotal:', '\$${venta.subtotal.toStringAsFixed(2)}'),
              if (venta.descuentoAplicado > 0)
                _filaTotal('Descuento:', '-\$${venta.descuentoAplicado.toStringAsFixed(2)}'),
              if (venta.costoEnvio > 0)
                _filaTotal('Envío:', '\$${venta.costoEnvio.toStringAsFixed(2)}'),
              pw.SizedBox(height: 2),
              pw.Text(_linea, style: pw.TextStyle(fontSize: 6)),
              _filaTotal('TOTAL:', '\$${venta.total.toStringAsFixed(2)}', boldness: pw.FontWeight.bold, size: 12),
              pw.Text(_linea, style: pw.TextStyle(fontSize: 6)),

              pw.SizedBox(height: 8),
              pw.Center(child: pw.BarcodeWidget(
                barcode: Barcode.qrCode(),
                data: venta.id,
                width: 40,
                height: 40,
              )),
              pw.SizedBox(height: 5),
              pw.Center(child: pw.Text('¡Gracias por su compra!', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Ticket_${venta.id}');
  }

  /// Genera e imprime el Corte Z (Cierre de Caja) para el administrador
  static Future<void> imprimirCorteZ(TurnoCaja turno, Negocio negocio) async {
    final pdf = pw.Document();
    final DateFormat fmt = DateFormat('dd/MM/yy HH:mm');

    final pw.MemoryImage? logoImage = await _getLogoImage(negocio.logoUrl);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm),
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

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'CorteZ_${turno.id}');
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
