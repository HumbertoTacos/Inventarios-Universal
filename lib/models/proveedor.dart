class Proveedor {
  final String id;
  final String nombre;
  final String telefono;
  final String? rfc_o_nit;
  final String notas;

  Proveedor({
    required this.id,
    required this.nombre,
    required this.telefono,
    this.rfc_o_nit,
    this.notas = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'rfc_o_nit': rfc_o_nit,
      'notas': notas,
    };
  }

  factory Proveedor.fromMap(Map<String, dynamic> map, String id) {
    return Proveedor(
      id: id,
      nombre: map['nombre'] ?? '',
      telefono: map['telefono'] ?? '',
      rfc_o_nit: map['rfc_o_nit'],
      notas: map['notas'] ?? '',
    );
  }

  Proveedor copyWith({
    String? nombre,
    String? telefono,
    String? rfc_o_nit,
    String? notas,
  }) {
    return Proveedor(
      id: id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      rfc_o_nit: rfc_o_nit ?? this.rfc_o_nit,
      notas: notas ?? this.notas,
    );
  }
}
