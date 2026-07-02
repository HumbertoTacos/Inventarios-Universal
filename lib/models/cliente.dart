class Cliente {
  final String id;
  final String nombre;
  final String telefono;
  final String? email;
  final String? notas;

  /// Límite de crédito en moneda. 0 = crédito BLOQUEADO.
  final double limiteCredito;

  /// Deuda actual acumulada (suma de ventas a crédito - abonos).
  final double saldoDeudor;

  final double? ultimoAbonoMonto;
  final DateTime? ultimoAbonoFecha;

  final DateTime fechaRegistro;

  Cliente({
    required this.id,
    required this.nombre,
    required this.telefono,
    this.email,
    this.notas,
    required this.limiteCredito,
    this.saldoDeudor = 0.0,
    this.ultimoAbonoMonto,
    this.ultimoAbonoFecha,
    required this.fechaRegistro,
  });

  /// Crédito disponible restante. Negativo si excede el límite.
  double get creditoDisponible => limiteCredito - saldoDeudor;

  /// True si el cliente no puede recibir más crédito.
  bool get creditoBloqueado => limiteCredito <= 0;

  /// True si tiene deuda activa.
  bool get tieneDeuda => saldoDeudor > 0;

  /// Retorna el texto del límite de crédito (numérico o "Ilimitado")
  String get limiteCreditoTexto {
    if (limiteCredito >= 100000) return 'Ilimitado';
    return '\$${limiteCredito.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'telefono': telefono,
        'email': email ?? '',
        'notas': notas ?? '',
        'limiteCredito': limiteCredito,
        'saldoDeudor': saldoDeudor,
        'ultimoAbonoMonto': ultimoAbonoMonto,
        'ultimoAbonoFecha': ultimoAbonoFecha?.toIso8601String(),
        'fechaRegistro': fechaRegistro.toIso8601String(),
      };

  factory Cliente.fromMap(Map<String, dynamic> map, String id) => Cliente(
        id: id,
        nombre: map['nombre'] as String? ?? '',
        telefono: map['telefono'] as String? ?? '',
        email: map['email'] as String?,
        notas: map['notas'] as String?,
        limiteCredito: (map['limiteCredito'] as num?)?.toDouble() ?? 0.0,
        saldoDeudor: (map['saldoDeudor'] as num?)?.toDouble() ?? 0.0,
        ultimoAbonoMonto: (map['ultimoAbonoMonto'] as num?)?.toDouble(),
        ultimoAbonoFecha: map['ultimoAbonoFecha'] != null
            ? DateTime.parse(map['ultimoAbonoFecha'])
            : null,
        fechaRegistro: map['fechaRegistro'] != null
            ? DateTime.parse(map['fechaRegistro'])
            : DateTime.now(),
      );

  Cliente copyWith({
    String? nombre,
    String? telefono,
    String? email,
    String? notas,
    double? limiteCredito,
    double? saldoDeudor,
    double? ultimoAbonoMonto,
    DateTime? ultimoAbonoFecha,
  }) =>
      Cliente(
        id: id,
        nombre: nombre ?? this.nombre,
        telefono: telefono ?? this.telefono,
        email: email ?? this.email,
        notas: notas ?? this.notas,
        limiteCredito: limiteCredito ?? this.limiteCredito,
        saldoDeudor: saldoDeudor ?? this.saldoDeudor,
        ultimoAbonoMonto: ultimoAbonoMonto ?? this.ultimoAbonoMonto,
        ultimoAbonoFecha: ultimoAbonoFecha ?? this.ultimoAbonoFecha,
        fechaRegistro: fechaRegistro,
      );
}
