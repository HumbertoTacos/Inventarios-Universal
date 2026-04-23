enum TipoMovimiento { entrada, salida, ajuste }

class MovimientoInventario {
  final String id;
  final String productoId;
  final TipoMovimiento tipoMovimiento;
  final double cantidadAlterada; // Positiva para sumas, negativa para restas
  final double stockResultante;
  final String motivo; // Ej. "Merma", "Venta", "Devolución"
  final DateTime fecha;
  final String usuarioId;

  MovimientoInventario({
    required this.id,
    required this.productoId,
    required this.tipoMovimiento,
    required this.cantidadAlterada,
    required this.stockResultante,
    required this.motivo,
    required this.fecha,
    required this.usuarioId,
  });

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'tipoMovimiento': tipoMovimiento.name,
      'cantidadAlterada': cantidadAlterada,
      'stockResultante': stockResultante,
      'motivo': motivo,
      'fecha': fecha.toIso8601String(),
      'usuarioId': usuarioId,
    };
  }

  factory MovimientoInventario.fromMap(Map<String, dynamic> map, String id) {
    return MovimientoInventario(
      id: id,
      productoId: map['productoId'] as String? ?? '',
      tipoMovimiento: TipoMovimiento.values.firstWhere(
        (e) => e.name == map['tipoMovimiento'],
        orElse: () => TipoMovimiento.ajuste,
      ),
      cantidadAlterada: (map['cantidadAlterada'] as num?)?.toDouble() ?? 0.0,
      stockResultante: (map['stockResultante'] as num?)?.toDouble() ?? 0.0,
      motivo: map['motivo'] as String? ?? '',
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
      usuarioId: map['usuarioId'] as String? ?? '',
    );
  }
}
