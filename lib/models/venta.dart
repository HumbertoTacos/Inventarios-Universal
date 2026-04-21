enum MetodoPago { efectivo, tarjeta, transferencia, credito }
enum TipoDescuento { ninguno, fijo, porcentaje }

class VentaItem {
  final String productoId;
  final String nombre;
  final double costoUnitario;
  final double precioUnitario;
  final int cantidad;

  double get subtotal => precioUnitario * cantidad;

  VentaItem({
    required this.productoId,
    required this.nombre,
    required this.costoUnitario,
    required this.precioUnitario,
    required this.cantidad,
  });

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'nombre': nombre,
      'costoUnitario': costoUnitario,
      'precioUnitario': precioUnitario,
      'cantidad': cantidad,
      'subtotal': subtotal,
    };
  }

  factory VentaItem.fromMap(Map<String, dynamic> map) {
    return VentaItem(
      productoId: map['productoId'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      costoUnitario: (map['costoUnitario'] as num?)?.toDouble() ?? 0.0,
      precioUnitario: (map['precioUnitario'] as num?)?.toDouble() ?? 0.0,
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
    );
  }
}

class Venta {
  final String id;
  final DateTime fecha;
  final List<VentaItem> items;
  final double costoEnvio;
  final bool envioPagadoPorVendedor;
  final String estado; // 'completada', 'cancelada', 'devuelta'
  final double costoEnvioDevolucion;
  final bool devueltoAlInventario;

  // Nuevos campos: Pago, Descuentos e Impuestos
  final MetodoPago metodoPago;
  final TipoDescuento tipoDescuento;
  final double valorDescuento; // $50.0 o 10.0 (10%)
  final double porcentajeImpuesto; // ej. 0.16 para 16%

  /// ID del cliente asociado. Requerido cuando metodoPago == credito.
  final String? clienteId;

  // Valores calculados que se guardan fijos en Firestore
  final double subtotal; // Suma de items.subtotal
  final double descuentoAplicado; // Monto descontado sobre el subtotal
  final double impuestos; // (Subtotal - descuento)*porcImpuesto
  final double total; // Subtotal - descuento + impuestos + envio (si aplica)

  Venta({
    required this.id,
    required this.fecha,
    required this.items,
    this.costoEnvio = 0.0,
    this.envioPagadoPorVendedor = true,
    this.estado = 'completada',
    this.costoEnvioDevolucion = 0.0,
    this.devueltoAlInventario = true,
    this.metodoPago = MetodoPago.efectivo,
    this.tipoDescuento = TipoDescuento.ninguno,
    this.valorDescuento = 0.0,
    this.porcentajeImpuesto = 0.16,
    this.clienteId,
    double? subtotalInyectado,
    double? descuentoInyectado,
    double? impuestosInyectado,
    double? totalInyectado,
  })  : subtotal = subtotalInyectado ?? _calcularSubtotal(items),
        descuentoAplicado = descuentoInyectado ??
            _calcularDescuento(
                _calcularSubtotal(items), tipoDescuento, valorDescuento),
        impuestos = impuestosInyectado ??
            _calcularImpuestos(
                _calcularSubtotal(items),
                _calcularDescuento(
                    _calcularSubtotal(items), tipoDescuento, valorDescuento),
                porcentajeImpuesto),
        total = totalInyectado ??
            _calcularTotal(
                _calcularSubtotal(items),
                _calcularDescuento(
                    _calcularSubtotal(items), tipoDescuento, valorDescuento),
                porcentajeImpuesto,
                !envioPagadoPorVendedor ? costoEnvio : 0.0);

  static double _calcularSubtotal(List<VentaItem> items) {
    return items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  static double _calcularDescuento(
      double subtotal, TipoDescuento tipo, double valor) {
    if (tipo == TipoDescuento.fijo) {
      return valor > subtotal ? subtotal : valor; // No descontar más que subtotal
    } else if (tipo == TipoDescuento.porcentaje) {
      return subtotal * (valor / 100);
    }
    return 0.0;
  }

  static double _calcularImpuestos(
      double subtotal, double descuento, double porcentajeImpuesto) {
    final baseGravable = subtotal - descuento;
    return baseGravable > 0 ? baseGravable * porcentajeImpuesto : 0.0;
  }

  static double _calcularTotal(double subtotal, double descuento,
      double porcentajeImpuesto, double costoEnvioCobrado) {
    final baseGravable = subtotal - descuento;
    final impuestos = baseGravable > 0 ? baseGravable * porcentajeImpuesto : 0.0;
    return (baseGravable > 0 ? baseGravable : 0.0) + impuestos + costoEnvioCobrado;
  }

  Map<String, dynamic> toMap() {
    return {
      'fecha': fecha.toIso8601String(),
      'items': items.map((i) => i.toMap()).toList(),
      'costoEnvio': costoEnvio,
      'envioPagadoPorVendedor': envioPagadoPorVendedor,
      'estado': estado,
      'costoEnvioDevolucion': costoEnvioDevolucion,
      'devueltoAlInventario': devueltoAlInventario,
      'metodoPago': metodoPago.name,
      'tipoDescuento': tipoDescuento.name,
      'valorDescuento': valorDescuento,
      'porcentajeImpuesto': porcentajeImpuesto,
      'subtotal': subtotal,
      'descuentoAplicado': descuentoAplicado,
      'impuestos': impuestos,
      'total': total,
      if (clienteId != null) 'clienteId': clienteId,
    };
  }

  factory Venta.fromMap(Map<String, dynamic> map, String id) {
    // Protección para retrocompatibilidad con ventas antiguas:
    final itemsMap = (map['items'] as List<dynamic>?)
            ?.map((i) => VentaItem.fromMap(i as Map<String, dynamic>))
            .toList() ??
        [];
        
    return Venta(
      id: id,
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
      items: itemsMap,
      costoEnvio: (map['costoEnvio'] as num?)?.toDouble() ?? 0.0,
      envioPagadoPorVendedor: map['envioPagadoPorVendedor'] as bool? ?? true,
      estado: map['estado'] as String? ?? 'completada',
      costoEnvioDevolucion: (map['costoEnvioDevolucion'] as num?)?.toDouble() ?? 0.0,
      devueltoAlInventario: map['devueltoAlInventario'] as bool? ?? true,
      metodoPago: MetodoPago.values.firstWhere(
          (e) => e.name == map['metodoPago'],
          orElse: () => MetodoPago.efectivo),
      tipoDescuento: TipoDescuento.values.firstWhere(
          (e) => e.name == map['tipoDescuento'],
          orElse: () => TipoDescuento.ninguno),
      valorDescuento: (map['valorDescuento'] as num?)?.toDouble() ?? 0.0,
      porcentajeImpuesto: (map['porcentajeImpuesto'] as num?)?.toDouble() ?? 0.16,
      subtotalInyectado: (map['subtotal'] as num?)?.toDouble(),
      descuentoInyectado: (map['descuentoAplicado'] as num?)?.toDouble(),
      impuestosInyectado: (map['impuestos'] as num?)?.toDouble(),
      totalInyectado: (map['total'] as num?)?.toDouble(),
      clienteId: map['clienteId'] as String?,
    );
  }
}
