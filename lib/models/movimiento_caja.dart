class MovimientoCaja {
  final String id;
  final String turnoId;
  final String tipo; // 'ingreso' o 'egreso'
  final double monto;
  final String concepto;
  final DateTime fecha;

  MovimientoCaja({
    required this.id,
    required this.turnoId,
    required this.tipo,
    required this.monto,
    required this.concepto,
    required this.fecha,
  });

  Map<String, dynamic> toMap() {
    return {
      'turnoId': turnoId,
      'tipo': tipo,
      'monto': monto,
      'concepto': concepto,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory MovimientoCaja.fromMap(Map<String, dynamic> map, String id) {
    return MovimientoCaja(
      id: id,
      turnoId: map['turnoId'] ?? '',
      tipo: map['tipo'] ?? 'egreso',
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      concepto: map['concepto'] ?? '',
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
    );
  }
}
