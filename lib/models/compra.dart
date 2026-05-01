class DetalleCompra {
  final String productoId;
  final String nombre;
  final double cantidad;
  final double costoUnitario;

  DetalleCompra({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    required this.costoUnitario,
  });

  double get subtotal => cantidad * costoUnitario;

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'nombre': nombre,
      'cantidad': cantidad,
      'costoUnitario': costoUnitario,
      'subtotal': subtotal,
    };
  }

  factory DetalleCompra.fromMap(Map<String, dynamic> map) {
    return DetalleCompra(
      productoId: map['productoId'] ?? '',
      nombre: map['nombre'] ?? '',
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0.0,
      costoUnitario: (map['costoUnitario'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Compra {
  final String id;
  final String proveedorId;
  final String? proveedorNombre;
  final DateTime fecha;
  final double costoTotal;
  final List<DetalleCompra> items;
  final String notas;

  Compra({
    required this.id,
    required this.proveedorId,
    this.proveedorNombre,
    required this.fecha,
    required this.costoTotal,
    required this.items,
    this.notas = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'proveedorId': proveedorId,
      'proveedorNombre': proveedorNombre,
      'fecha': fecha.toIso8601String(),
      'costoTotal': costoTotal,
      'items': items.map((i) => i.toMap()).toList(),
      'notas': notas,
    };
  }

  factory Compra.fromMap(Map<String, dynamic> map, String id) {
    return Compra(
      id: id,
      proveedorId: map['proveedorId'] ?? '',
      proveedorNombre: map['proveedorNombre'],
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
      costoTotal: (map['costoTotal'] as num?)?.toDouble() ?? 0.0,
      items: (map['items'] as List<dynamic>?)
              ?.map((i) => DetalleCompra.fromMap(i as Map<String, dynamic>))
              .toList() ??
          [],
      notas: map['notas'] ?? '',
    );
  }
}
