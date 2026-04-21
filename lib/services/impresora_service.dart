import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/venta.dart';

/// Servicio de impresión multiplataforma.
/// Usa [Printing.layoutPdf] para delegar al SO:
/// - Web → abre preview en el navegador (Chrome Print Dialog)
/// - Android/iOS → abre selector de impresoras nativas
/// - Windows → diálogo de impresión de Windows
class ImpresoraService {
  static const _anchoTicketMm = 80.0; // 58mm o 80mm

  /// Genera e imprime el ticket de una [Venta].
  static Future<void> imprimirTicket({
    required Venta venta,
    required String negocioNombre,
    String? direccionNegocio,
    String? telefonoNegocio,
  }) async {
    final pdf = pw.Document();

    // Carga la fuente Helvetica (incluida en el paquete, no requiere assets externos)
    final fontData = await rootBundle.load('packages/pdf/fonts/opensans_regular.ttf').catchError((_) async {
      // Fallback: usa fuente interna del paquete pdf
      return ByteData(0);
    });

    final moneyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final fechaFmt = DateFormat('dd/MM/yyyy HH:mm');
    final ancho = PdfPageFormat(_anchoTicketMm * PdfPageFormat.mm, double.infinity);

    pdf.addPage(
      pw.Page(
        pageFormat: ancho,
        margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Encabezado ────────────────────────────────────────────
            pw.Center(
              child: pw.Text(
                negocioNombre,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (direccionNegocio != null) ...[
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text(direccionNegocio, style: const pw.TextStyle(fontSize: 9))),
            ],
            if (telefonoNegocio != null) ...[
              pw.Center(child: pw.Text(telefonoNegocio, style: const pw.TextStyle(fontSize: 9))),
            ],
            pw.SizedBox(height: 6),
            _divider(),
            pw.SizedBox(height: 4),

            // ── Datos de la venta ─────────────────────────────────────
            pw.Text('Folio: ${venta.id.substring(0, 8).toUpperCase()}',
                style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Fecha: ${fechaFmt.format(venta.fecha)}',
                style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Pago: ${_metodoPago(venta.metodoPago)}',
                style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 4),
            _divider(),
            pw.SizedBox(height: 4),

            // ── Encabezado de columnas ────────────────────────────────
            pw.Row(
              children: [
                pw.Expanded(flex: 5, child: pw.Text('Artículo', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 2, child: pw.Text('Cant', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                pw.Expanded(flex: 3, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
              ],
            ),
            pw.SizedBox(height: 4),
            _divider(),

            // ── Líneas de producto ────────────────────────────────────
            ...venta.items.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(flex: 5, child: pw.Text(item.nombre, style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(flex: 2, child: pw.Text('${item.cantidad}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9))),
                      pw.Expanded(flex: 3, child: pw.Text(moneyFmt.format(item.subtotal), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9))),
                    ],
                  ),
                  pw.Text('  @ ${moneyFmt.format(item.precioUnitario)} c/u', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            )),

            _divider(),
            pw.SizedBox(height: 4),

            // ── Totales ───────────────────────────────────────────────
            _filaTotal('Subtotal', moneyFmt.format(venta.subtotal)),
            if (venta.descuentoAplicado > 0)
              _filaTotal('Descuento', '-${moneyFmt.format(venta.descuentoAplicado)}'),
            if (venta.impuestos > 0)
              _filaTotal('IVA (${(venta.porcentajeImpuesto * 100).toInt()}%)', moneyFmt.format(venta.impuestos)),
            if (venta.costoEnvio > 0 && !venta.envioPagadoPorVendedor)
              _filaTotal('Envío', moneyFmt.format(venta.costoEnvio)),
            pw.SizedBox(height: 2),
            _divider(),
            pw.SizedBox(height: 2),
            _filaTotal('TOTAL', moneyFmt.format(venta.total), negrita: true, fontSize: 13),
            pw.SizedBox(height: 12),

            // ── Pie ───────────────────────────────────────────────────
            _divider(),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text('¡Gracias por su compra!',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Center(
              child: pw.Text('Conserve su comprobante',
                  style: const pw.TextStyle(fontSize: 8)),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'Ticket_${venta.id.substring(0, 8)}',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static pw.Widget _divider() => pw.Divider(height: 1, thickness: 0.5);

  static pw.Widget _filaTotal(String label, String valor,
      {bool negrita = false, double fontSize = 10}) {
    final style = negrita
        ? pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)
        : pw.TextStyle(fontSize: fontSize);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(valor, style: style),
      ],
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
