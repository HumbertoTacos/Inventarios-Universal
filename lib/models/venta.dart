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

  // Si el cliente paga el envío, se suma al total a cobrar. 
  // Si el vendedor lo paga (envío gratis), no se le cobra al cliente.
  double get total =>
      items.fold(0.0, (sum, item) => sum + item.subtotal) +
      (!envioPagadoPorVendedor ? costoEnvio : 0.0);

  Venta({
    required this.id,
    required this.fecha,
    required this.items,
    this.costoEnvio = 0.0,
    this.envioPagadoPorVendedor = true,
    this.estado = 'completada',
    this.costoEnvioDevolucion = 0.0,
    this.devueltoAlInventario = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'fecha': fecha.toIso8601String(),
      'items': items.map((i) => i.toMap()).toList(),
      'costoEnvio': costoEnvio,
      'envioPagadoPorVendedor': envioPagadoPorVendedor,
      'estado': estado,
      'costoEnvioDevolucion': costoEnvioDevolucion,
      'devueltoAlInventario': devueltoAlInventario,
    };
  }

  factory Venta.fromMap(Map<String, dynamic> map, String id) {
    return Venta(
      id: id,
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
      items: (map['items'] as List<dynamic>?)
              ?.map((i) => VentaItem.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      costoEnvio: (map['costoEnvio'] as num?)?.toDouble() ?? 0.0,
      envioPagadoPorVendedor: map['envioPagadoPorVendedor'] as bool? ?? true,
      estado: map['estado'] as String? ?? 'completada',
      costoEnvioDevolucion: (map['costoEnvioDevolucion'] as num?)?.toDouble() ?? 0.0,
      devueltoAlInventario: map['devueltoAlInventario'] as bool? ?? true,
    );
  }
}
