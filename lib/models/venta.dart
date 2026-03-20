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
  final double total;

  Venta({
    required this.id,
    required this.fecha,
    required this.items,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'fecha': fecha.toIso8601String(),
      'items': items.map((x) => x.toMap()).toList(),
      'total': total,
    };
  }

  factory Venta.fromMap(Map<String, dynamic> map, String id) {
    return Venta(
      id: id,
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
      items: List<VentaItem>.from(
        (map['items'] as List<dynamic>? ?? []).map<VentaItem>(
          (x) => VentaItem.fromMap(x as Map<String, dynamic>),
        ),
      ),
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
