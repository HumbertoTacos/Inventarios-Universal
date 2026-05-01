enum EstadoTurno { abierto, cerrado }

class TurnoCaja {
  final String id;
  final DateTime fechaApertura;
  final DateTime? fechaCierre;
  final String usuarioId;
  final double fondoInicial;
  final double ventasEfectivo;
  final double ventasTarjeta;
  final double ventasTransferencia;
  final double ventasCredito;
  final double entradasEfectivo; // Ingresos manuales
  final double egresosEfectivo;  // Retiros/gastos
  final double? efectivoContado;
  final List<Map<String, dynamic>> historialRetiros;
  final EstadoTurno estado;

  TurnoCaja({
    required this.id,
    required this.fechaApertura,
    required this.usuarioId,
    this.fechaCierre,
    required this.fondoInicial,
    this.ventasEfectivo = 0.0,
    this.ventasTarjeta = 0.0,
    this.ventasTransferencia = 0.0,
    this.ventasCredito = 0.0,
    this.entradasEfectivo = 0.0,
    this.egresosEfectivo = 0.0,
    this.efectivoContado,
    this.historialRetiros = const [],
    this.estado = EstadoTurno.abierto,
  });

  /// Total esperado en la caja = (Fondo Inicial + Ventas en Efectivo + Entradas) - Egresos
  double get totalEsperadoEfectivo => (fondoInicial + ventasEfectivo + entradasEfectivo) - egresosEfectivo;

  /// Diferencia entre el físico contado y lo esperado en sistema
  double get diferenciaEfectivo => (efectivoContado ?? 0.0) - totalEsperadoEfectivo;

  // Compatibilidad hacia atrás (por si alguna parte del código antiguo lo usa antes de migrar todo)
  double get retirosEfectivo => egresosEfectivo;

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'fechaApertura': fechaApertura.toIso8601String(),
      'fechaCierre': fechaCierre?.toIso8601String(),
      'fondoInicial': fondoInicial,
      'ventasEfectivo': ventasEfectivo,
      'ventasTarjeta': ventasTarjeta,
      'ventasTransferencia': ventasTransferencia,
      'ventasCredito': ventasCredito,
      'entradasEfectivo': entradasEfectivo,
      'egresosEfectivo': egresosEfectivo,
      'efectivoContado': efectivoContado,
      'historialRetiros': historialRetiros,
      'estado': estado.name,
    };
  }

  factory TurnoCaja.fromMap(Map<String, dynamic> map, String id) {
    return TurnoCaja(
      id: id,
      usuarioId: map['usuarioId'] as String? ?? '',
      fechaApertura: map['fechaApertura'] != null
          ? DateTime.parse(map['fechaApertura'])
          : DateTime.now(),
      fechaCierre: map['fechaCierre'] != null
          ? DateTime.parse(map['fechaCierre'])
          : null,
      fondoInicial: (map['fondoInicial'] as num?)?.toDouble() ?? 0.0,
      ventasEfectivo: (map['ventasEfectivo'] as num?)?.toDouble() ?? 0.0,
      ventasTarjeta: (map['ventasTarjeta'] as num?)?.toDouble() ?? 0.0,
      ventasTransferencia: (map['ventasTransferencia'] as num?)?.toDouble() ?? 0.0,
      ventasCredito: (map['ventasCredito'] as num?)?.toDouble() ?? 0.0,
      entradasEfectivo: (map['entradasEfectivo'] as num?)?.toDouble() ?? 0.0,
      // Retrocompatibilidad: leer de 'retirosEfectivo' si 'egresosEfectivo' no existe
      egresosEfectivo: (map['egresosEfectivo'] as num?)?.toDouble() ?? (map['retirosEfectivo'] as num?)?.toDouble() ?? 0.0,
      efectivoContado: (map['efectivoContado'] as num?)?.toDouble(),
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
    String? usuarioId,
    DateTime? fechaCierre,
    double? fondoInicial,
    double? ventasEfectivo,
    double? ventasTarjeta,
    double? ventasTransferencia,
    double? ventasCredito,
    double? entradasEfectivo,
    double? egresosEfectivo,
    double? efectivoContado,
    List<Map<String, dynamic>>? historialRetiros,
    EstadoTurno? estado,
  }) {
    return TurnoCaja(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      fechaApertura: fechaApertura ?? this.fechaApertura,
      fechaCierre: fechaCierre ?? this.fechaCierre,
      fondoInicial: fondoInicial ?? this.fondoInicial,
      ventasEfectivo: ventasEfectivo ?? this.ventasEfectivo,
      ventasTarjeta: ventasTarjeta ?? this.ventasTarjeta,
      ventasTransferencia: ventasTransferencia ?? this.ventasTransferencia,
      ventasCredito: ventasCredito ?? this.ventasCredito,
      entradasEfectivo: entradasEfectivo ?? this.entradasEfectivo,
      egresosEfectivo: egresosEfectivo ?? this.egresosEfectivo,
      efectivoContado: efectivoContado ?? this.efectivoContado,
      historialRetiros: historialRetiros ?? this.historialRetiros,
      estado: estado ?? this.estado,
    );
  }
}
