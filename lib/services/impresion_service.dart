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
      print('Error al descargar logo para impresión: $e');
    }
    return null;
  }

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
  static Future<void> imprimirTicketVenta(Venta venta, Negocio negocio) async {
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
              if (logoImage != null)
                pw.Center(
                  child: pw.Container(
                    width: 120,
                    height: 70,
                    margin: const pw.EdgeInsets.only(bottom: 5),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                ),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(negocio.nombre.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                    if (negocio.rfc != null) pw.Text('RFC: ${negocio.rfc}', style: pw.TextStyle(fontSize: 7)),
                    if (negocio.direccion != null) pw.Text(negocio.direccion!, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7)),
                    if (negocio.telefono != null) pw.Text('Tel: ${negocio.telefono}', style: pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ),
              pw.Divider(thickness: 1),
              pw.Text('Ticket: ${venta.id.substring(0, 8).toUpperCase()}', style: pw.TextStyle(fontSize: 8)),
              pw.Text('Fecha: ${formatter.format(venta.fecha)}', style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 5),
              pw.Divider(thickness: 0.5),
              
              pw.Row(
                children: [
                  pw.Expanded(flex: 3, child: pw.Text('Prod', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 1, child: pw.Text('Cant', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 1, child: pw.Text('Sub', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.SizedBox(height: 2),

              ...venta.items.map((item) => pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 1),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text(item.nombre, style: pw.TextStyle(fontSize: 7))),
                    pw.Expanded(flex: 1, child: pw.Text(item.cantidad.toString(), style: pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 1, child: pw.Text(item.subtotal.toStringAsFixed(1), style: pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.right)),
                  ],
                ),
              )),

              pw.Divider(thickness: 0.5),
              _filaTotal('Subtotal:', '\$${venta.subtotal.toStringAsFixed(2)}'),
              if (venta.descuentoAplicado > 0)
                _filaTotal('Descuento:', '-\$${venta.descuentoAplicado.toStringAsFixed(2)}'),
              if (venta.costoEnvio > 0)
                _filaTotal('Envío:', '\$${venta.costoEnvio.toStringAsFixed(2)}'),
              pw.SizedBox(height: 2),
              _filaTotal('TOTAL:', '\$${venta.total.toStringAsFixed(2)}', boldness: pw.FontWeight.bold, size: 12),
              pw.SizedBox(height: 5),
              pw.Text('Pago: ${venta.metodoPago.name.toUpperCase()}', style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 10),
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
    final DateFormat fmt = DateFormat('dd/MM HH:mm');

    final pw.MemoryImage? logoImage = await _getLogoImage(negocio.logoUrl);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 3 * PdfPageFormat.mm),
        build: (pw.Context context) {
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
              pw.Center(child: pw.Text('CORTE DE CAJA (Z)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12))),
              pw.Center(child: pw.Text(negocio.nombre, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
              pw.Divider(),
              pw.Text('Apertura: ${fmt.format(turno.fechaApertura)}', style: pw.TextStyle(fontSize: 8)),
              if (turno.fechaCierre != null)
                pw.Text('Cierre: ${fmt.format(turno.fechaCierre!)}', style: pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 10),
              _filaResumen('FONDO INICIAL:', turno.fondoInicial),
              pw.Divider(thickness: 0.5),
              _filaResumen('Ventas Efectivo:', turno.ventasEfectivo),
              _filaResumen('Ventas Tarjeta:', turno.ventasTarjeta),
              _filaResumen('Ventas Transf:', turno.ventasTransferencia),
              _filaResumen('Ventas Crédito:', turno.ventasCredito),
              pw.Divider(thickness: 0.5),
              _filaResumen('RETIROS/GASTOS:', -turno.retirosEfectivo),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                child: pw.Column(
                  children: [
                    _filaResumen('ESPERADO CAJA:', turno.totalEsperadoEfectivo, boldness: pw.FontWeight.bold, size: 10),
                    if (turno.efectivoContado != null)
                      _filaResumen('CONTADO:', turno.efectivoContado!, boldness: pw.FontWeight.bold, size: 10),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('FIRMA RESPONSABLE', style: pw.TextStyle(fontSize: 7))),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'CorteZ_${turno.id}');
  }

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
