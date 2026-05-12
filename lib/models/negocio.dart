class Negocio {
  final String id;
  final String nombre;
  final String? logoUrl;
  final String? rfc;
  final String? telefono;
  final String? direccion;
  final String? pinAutorizacion;
  final bool usaCajaRegistradora;
  final bool manejaEnvios;

  // [FinOps] Campos de Lazy Cache para getCapitalEnInventario()
  final double? capitalInventarioCache;
  final DateTime? ultimaActualizacionCapital;

  Negocio({
    required this.id,
    required this.nombre,
    this.logoUrl,
    this.rfc,
    this.telefono,
    this.direccion,
    this.pinAutorizacion,
    this.usaCajaRegistradora = true,
    this.manejaEnvios = false,
    this.capitalInventarioCache,
    this.ultimaActualizacionCapital,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'logoUrl': logoUrl,
      'rfc': rfc,
      'telefono': telefono,
      'direccion': direccion,
      'pinAutorizacion': pinAutorizacion,
      'usaCajaRegistradora': usaCajaRegistradora,
      'manejaEnvios': manejaEnvios,
      // Solo incluimos los campos de cache si no son nulos (no sobreescribir con null)
      if (capitalInventarioCache != null) 'capitalInventarioCache': capitalInventarioCache,
      if (ultimaActualizacionCapital != null)
        'ultimaActualizacionCapital': ultimaActualizacionCapital!.toIso8601String(),
    };
  }

  factory Negocio.fromMap(Map<String, dynamic> map, String id) {
    return Negocio(
      id: id,
      nombre: map['nombre'] as String? ?? 'Mi Negocio',
      logoUrl: map['logoUrl'] as String?,
      rfc: map['rfc'] as String?,
      telefono: map['telefono'] as String?,
      direccion: map['direccion'] as String?,
      pinAutorizacion: map['pinAutorizacion'] as String?,
      usaCajaRegistradora: map['usaCajaRegistradora'] as bool? ?? true,
      manejaEnvios: map['manejaEnvios'] as bool? ?? false,
      capitalInventarioCache: (map['capitalInventarioCache'] as num?)?.toDouble(),
      ultimaActualizacionCapital: map['ultimaActualizacionCapital'] != null
          ? DateTime.tryParse(map['ultimaActualizacionCapital'] as String)
          : null,
    );
  }

  Negocio copyWith({
    String? nombre,
    String? logoUrl,
    String? rfc,
    String? telefono,
    String? direccion,
    String? pinAutorizacion,
    bool? usaCajaRegistradora,
    bool? manejaEnvios,
    double? capitalInventarioCache,
    DateTime? ultimaActualizacionCapital,
  }) {
    return Negocio(
      id: id,
      nombre: nombre ?? this.nombre,
      logoUrl: logoUrl ?? this.logoUrl,
      rfc: rfc ?? this.rfc,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      pinAutorizacion: pinAutorizacion ?? this.pinAutorizacion,
      usaCajaRegistradora: usaCajaRegistradora ?? this.usaCajaRegistradora,
      manejaEnvios: manejaEnvios ?? this.manejaEnvios,
      capitalInventarioCache: capitalInventarioCache ?? this.capitalInventarioCache,
      ultimaActualizacionCapital: ultimaActualizacionCapital ?? this.ultimaActualizacionCapital,
    );
  }
}
