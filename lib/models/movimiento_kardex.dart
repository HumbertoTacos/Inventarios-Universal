class MovimientoKardex {
  final String id;
  final String productoId;
  final String nombreProducto;
  final String tipoMovimiento; // 'merma', 'daño', 'consumo_interno', 'extravio', 'ajuste_manual'
  final double cantidad; // Cantidad del ajuste
  final double costoUnitario; // Costo del producto al momento del ajuste (referencia)
  final DateTime fecha;
  final String usuarioId;
  final String notas;

  MovimientoKardex({
    required this.id,
    required this.productoId,
    required this.nombreProducto,
    required this.tipoMovimiento,
    required this.cantidad,
    required this.costoUnitario,
    required this.fecha,
    required this.usuarioId,
    required this.notas,
  });

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'nombreProducto': nombreProducto,
      'tipoMovimiento': tipoMovimiento,
      'cantidad': cantidad,
      'costoUnitario': costoUnitario,
      'fecha': fecha.toIso8601String(),
      'usuarioId': usuarioId,
      'notas': notas,
    };
  }

  factory MovimientoKardex.fromMap(Map<String, dynamic> map, String id) {
    return MovimientoKardex(
      id: id,
      productoId: map['productoId'] ?? '',
      nombreProducto: map['nombreProducto'] ?? '',
      tipoMovimiento: map['tipoMovimiento'] ?? 'ajuste_manual',
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0.0,
      costoUnitario: (map['costoUnitario'] as num?)?.toDouble() ?? 0.0,
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
      usuarioId: map['usuarioId'] ?? '',
      notas: map['notas'] ?? '',
    );
  }
}
