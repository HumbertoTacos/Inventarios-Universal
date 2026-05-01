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
    );
  }
}
