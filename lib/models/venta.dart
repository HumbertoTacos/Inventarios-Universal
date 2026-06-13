enum MetodoPago { efectivo, tarjeta, transferencia, credito }
enum TipoDescuento { ninguno, fijo, porcentaje }

class VentaItem {
  final String productoId;
  final String nombre;
  final double costoUnitario;
  final double precioUnitario;
  final double cantidad;
  final String? proveedorId;
  final String? proveedorNombre;

  double get subtotal => precioUnitario * cantidad;

  VentaItem({
    required this.productoId,
    required this.nombre,
    required this.costoUnitario,
    required this.precioUnitario,
    required this.cantidad,
    this.proveedorId,
    this.proveedorNombre,
  });

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'nombre': nombre,
      'costoUnitario': costoUnitario,
      'precioUnitario': precioUnitario,
      'cantidad': cantidad,
      'subtotal': subtotal,
      'proveedorId': proveedorId,
      'proveedorNombre': proveedorNombre,
    };
  }

  factory VentaItem.fromMap(Map<String, dynamic> map) {
    return VentaItem(
      productoId: map['productoId'] as String? ?? '',
      nombre: map['nombre'] as String? ?? '',
      costoUnitario: (map['costoUnitario'] as num?)?.toDouble() ?? 0.0,
      precioUnitario: (map['precioUnitario'] as num?)?.toDouble() ?? 0.0,
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0.0,
      proveedorId: map['proveedorId'] as String?,
      proveedorNombre: map['proveedorNombre'] as String?,
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

  // Rentabilidad
  final double costoTotal;
  final double utilidad;

  // Nuevos campos: Pago y Descuentos
  final MetodoPago metodoPago;
  final TipoDescuento tipoDescuento;
  final double valorDescuento; // $50.0 o 10.0 (10%)

  /// ID del cliente asociado. Requerido cuando metodoPago == credito.
  final String? clienteId;

  // Empleado que realizó la venta y su comisión
  final String? empleadoId;
  final String? empleadoNombre;
  final double comisionGenerada;

  // Valores calculados que se guardan fijos en Firestore
  final double subtotal; // Suma de items.subtotal
  final double descuentoAplicado; // Monto descontado sobre el subtotal
  final double total; // Subtotal - descuento + envio (si aplica)

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
    this.clienteId,
    this.empleadoId,
    this.empleadoNombre,
    this.comisionGenerada = 0.0,
    double? subtotalInyectado,
    double? descuentoInyectado,
    double? totalInyectado,
    double? costoTotalInyectado,
    double? utilidadInyectado,
  })  : subtotal = subtotalInyectado ?? _calcularSubtotal(items),
        descuentoAplicado = descuentoInyectado ??
            _calcularDescuento(
                _calcularSubtotal(items), tipoDescuento, valorDescuento),
        costoTotal = costoTotalInyectado ?? _calcularCostoTotal(items),
        total = totalInyectado ??
            _calcularTotal(
                _calcularSubtotal(items),
                _calcularDescuento(
                    _calcularSubtotal(items), tipoDescuento, valorDescuento),
                !envioPagadoPorVendedor ? costoEnvio : 0.0),
        utilidad = utilidadInyectado ??
            ((totalInyectado ??
                    _calcularTotal(
                        _calcularSubtotal(items),
                        _calcularDescuento(_calcularSubtotal(items),
                            tipoDescuento, valorDescuento),
                        !envioPagadoPorVendedor ? costoEnvio : 0.0)) -
                (costoTotalInyectado ?? _calcularCostoTotal(items)) -
                (envioPagadoPorVendedor ? costoEnvio : 0.0));

  static double _calcularSubtotal(List<VentaItem> items) {
    return items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  static double _calcularCostoTotal(List<VentaItem> items) {
    return items.fold(0.0, (sum, item) => sum + (item.costoUnitario * item.cantidad));
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

  static double _calcularTotal(double subtotal, double descuento, double costoEnvioCobrado) {
    final saldoBajoCero = subtotal - descuento;
    return (saldoBajoCero > 0 ? saldoBajoCero : 0.0) + costoEnvioCobrado;
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
      'subtotal': subtotal,
      'descuentoAplicado': descuentoAplicado,
      'total': total,
      'costoTotal': costoTotal,
      'utilidad': utilidad,
      if (clienteId != null) 'clienteId': clienteId,
      if (empleadoId != null) 'empleadoId': empleadoId,
      if (empleadoNombre != null) 'empleadoNombre': empleadoNombre,
      'comisionGenerada': comisionGenerada,
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
      subtotalInyectado: (map['subtotal'] as num?)?.toDouble(),
      descuentoInyectado: (map['descuentoAplicado'] as num?)?.toDouble(),
      totalInyectado: (map['total'] as num?)?.toDouble(),
      costoTotalInyectado: (map['costoTotal'] as num?)?.toDouble(),
      utilidadInyectado: (map['utilidad'] as num?)?.toDouble(),
      clienteId: map['clienteId'] as String?,
      empleadoId: map['empleadoId'] as String?,
      empleadoNombre: map['empleadoNombre'] as String?,
      comisionGenerada: (map['comisionGenerada'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
