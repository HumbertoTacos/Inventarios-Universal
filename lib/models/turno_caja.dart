enum EstadoTurno { abierto, cerrado }

class TurnoCaja {
  final String id;
  final DateTime fechaApertura;
  final DateTime? fechaCierre;
  final double fondoInicial;
  final double ventasEfectivo;
  final double ventasTarjeta;
  final double ventasTransferencia;
  final double ventasCredito;
  final double? efectivoContado;
  final double retirosEfectivo;
  final List<Map<String, dynamic>> historialRetiros;
  final EstadoTurno estado;

  TurnoCaja({
    required this.id,
    required this.fechaApertura,
    this.fechaCierre,
    required this.fondoInicial,
    this.ventasEfectivo = 0.0,
    this.ventasTarjeta = 0.0,
    this.ventasTransferencia = 0.0,
    this.ventasCredito = 0.0,
    this.efectivoContado,
    this.retirosEfectivo = 0.0,
    this.historialRetiros = const [],
    this.estado = EstadoTurno.abierto,
  });

  /// Total esperado en la caja = (Fondo Inicial + Ventas en Efectivo) - Retiros
  double get totalEsperadoEfectivo => (fondoInicial + ventasEfectivo) - retirosEfectivo;

  /// Diferencia entre el físico contado y lo esperado en sistema
  double get diferenciaEfectivo =>
      (efectivoContado ?? 0.0) - totalEsperadoEfectivo;

  Map<String, dynamic> toMap() {
    return {
      'fechaApertura': fechaApertura.toIso8601String(),
      'fechaCierre': fechaCierre?.toIso8601String(),
      'fondoInicial': fondoInicial,
      'ventasEfectivo': ventasEfectivo,
      'ventasTarjeta': ventasTarjeta,
      'ventasTransferencia': ventasTransferencia,
      'ventasCredito': ventasCredito,
      'efectivoContado': efectivoContado,
      'retirosEfectivo': retirosEfectivo,
      'historialRetiros': historialRetiros,
      'estado': estado.name,
    };
  }

  factory TurnoCaja.fromMap(Map<String, dynamic> map, String id) {
    return TurnoCaja(
      id: id,
      fechaApertura: map['fechaApertura'] != null
          ? DateTime.parse(map['fechaApertura'])
          : DateTime.now(),
      fechaCierre: map['fechaCierre'] != null
          ? DateTime.parse(map['fechaCierre'])
          : null,
      fondoInicial: (map['fondoInicial'] as num?)?.toDouble() ?? 0.0,
      ventasEfectivo: (map['ventasEfectivo'] as num?)?.toDouble() ?? 0.0,
      ventasTarjeta: (map['ventasTarjeta'] as num?)?.toDouble() ?? 0.0,
      ventasTransferencia:
          (map['ventasTransferencia'] as num?)?.toDouble() ?? 0.0,
      ventasCredito: (map['ventasCredito'] as num?)?.toDouble() ?? 0.0,
      efectivoContado: (map['efectivoContado'] as num?)?.toDouble(),
      retirosEfectivo: (map['retirosEfectivo'] as num?)?.toDouble() ?? 0.0,
      historialRetiros: (map['historialRetiros'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      estado: map['estado'] == EstadoTurno.cerrado.name
          ? EstadoTurno.cerrado
          : EstadoTurno.abierto,
    );
  }

  TurnoCaja copyWith({
    String? id,
    DateTime? fechaApertura,
    DateTime? fechaCierre,
    double? fondoInicial,
    double? ventasEfectivo,
    double? ventasTarjeta,
    double? ventasTransferencia,
    double? ventasCredito,
    double? efectivoContado,
    double? retirosEfectivo,
    List<Map<String, dynamic>>? historialRetiros,
    EstadoTurno? estado,
  }) {
    return TurnoCaja(
      id: id ?? this.id,
      fechaApertura: fechaApertura ?? this.fechaApertura,
      fechaCierre: fechaCierre ?? this.fechaCierre,
      fondoInicial: fondoInicial ?? this.fondoInicial,
      ventasEfectivo: ventasEfectivo ?? this.ventasEfectivo,
      ventasTarjeta: ventasTarjeta ?? this.ventasTarjeta,
      ventasTransferencia: ventasTransferencia ?? this.ventasTransferencia,
      ventasCredito: ventasCredito ?? this.ventasCredito,
      efectivoContado: efectivoContado ?? this.efectivoContado,
      retirosEfectivo: retirosEfectivo ?? this.retirosEfectivo,
      historialRetiros: historialRetiros ?? this.historialRetiros,
      estado: estado ?? this.estado,
    );
  }
}
