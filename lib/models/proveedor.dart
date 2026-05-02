class Proveedor {
  final String id;
  final String nombreComercial; // Antes 'nombre'
  final String? razonSocial;
  final String telefono;
  final String? correo;
  final String? rfc_o_nit;
  final String? nombreContacto;
  final String? tipoProveedor;
  final String? diasVisita;
  final String notas;

  Proveedor({
    required this.id,
    required this.nombreComercial,
    this.razonSocial,
    required this.telefono,
    this.correo,
    this.rfc_o_nit,
    this.nombreContacto,
    this.tipoProveedor,
    this.diasVisita,
    this.notas = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombreComercial, // Mantenemos 'nombre' en DB por compatibilidad
      'razonSocial': razonSocial,
      'telefono': telefono,
      'correo': correo,
      'rfc_o_nit': rfc_o_nit,
      'nombreContacto': nombreContacto,
      'tipoProveedor': tipoProveedor,
      'diasVisita': diasVisita,
      'notas': notas,
    };
  }

  factory Proveedor.fromMap(Map<String, dynamic> map, String id) {
    return Proveedor(
      id: id,
      nombreComercial: map['nombre'] ?? map['nombreComercial'] ?? '',
      razonSocial: map['razonSocial'],
      telefono: map['telefono'] ?? '',
      correo: map['correo'],
      rfc_o_nit: map['rfc_o_nit'],
      nombreContacto: map['nombreContacto'],
      tipoProveedor: map['tipoProveedor'],
      diasVisita: map['diasVisita'],
      notas: map['notas'] ?? '',
    );
  }

  Proveedor copyWith({
    String? nombreComercial,
    String? razonSocial,
    String? telefono,
    String? correo,
    String? rfc_o_nit,
    String? nombreContacto,
    String? tipoProveedor,
    String? diasVisita,
    String? notas,
  }) {
    return Proveedor(
      id: id,
      nombreComercial: nombreComercial ?? this.nombreComercial,
      razonSocial: razonSocial ?? this.razonSocial,
      telefono: telefono ?? this.telefono,
      correo: correo ?? this.correo,
      rfc_o_nit: rfc_o_nit ?? this.rfc_o_nit,
      nombreContacto: nombreContacto ?? this.nombreContacto,
      tipoProveedor: tipoProveedor ?? this.tipoProveedor,
      diasVisita: diasVisita ?? this.diasVisita,
      notas: notas ?? this.notas,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Proveedor && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
