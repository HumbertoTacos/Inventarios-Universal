class Categoria {
  final String id;
  final String nombre;
  final String tipoAtributo; // "color" | "diseño"
  final List<String> tamanos;
  final int orden;

  Categoria({
    required this.id,
    required this.nombre,
    required this.tipoAtributo,
    required this.tamanos,
    this.orden = 0,
  });

  factory Categoria.fromMap(Map<String, dynamic> map, String id) {
    return Categoria(
      id: id,
      nombre: map['nombre'] as String? ?? '',
      tipoAtributo: map['tipoAtributo'] as String? ?? 'color',
      tamanos: List<String>.from(map['tamaños'] ?? []),
      orden: (map['orden'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'tipoAtributo': tipoAtributo,
      'tamaños': tamanos,
      'orden': orden,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Categoria && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Categoria(id: $id, nombre: $nombre, tipo: $tipoAtributo, '
      'tamaños: $tamanos)';
}
