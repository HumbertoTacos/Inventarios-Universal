class Producto {
  final String id;
  final String nombre;
  final String categoria;
  final double costoPromedio;
  final double precio;
  final double cantidad;
  final String descripcion;
  final String? codigoBarras;
  final bool activo;
  final String? imagenUrl;
  final Map<String, dynamic> atributos;
  final bool esBase;
  final String? baseId;

  // Mayoreo
  final int? cantidadMayoreo;
  final double? precioMayoreo;

  // Promociones
  final bool enPromocion;
  final double? precioPromocion;

  Producto({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.costoPromedio,
    required this.precio,
    required this.cantidad,
    required this.descripcion,
    this.codigoBarras,
    this.activo = true,
    this.imagenUrl,
    this.atributos = const {},
    this.esBase = true,
    this.baseId,
    this.cantidadMayoreo,
    this.precioMayoreo,
    this.enPromocion = false,
    this.precioPromocion,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'categoria': categoria,
      'costoPromedio': costoPromedio,
      'precio': precio,
      'cantidad': cantidad,
      'descripcion': descripcion,
      'codigoBarras': codigoBarras,
      'activo': activo,
      'imagenUrl': imagenUrl,
      'atributos': atributos,
      'esBase': esBase,
      'baseId': baseId,
      'cantidadMayoreo': cantidadMayoreo,
      'precioMayoreo': precioMayoreo,
      'enPromocion': enPromocion,
      'precioPromocion': precioPromocion,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map, String id) {
    return Producto(
      id: id,
      nombre: map['nombre'] ?? '',
      categoria: map['categoria'] ?? '',
      costoPromedio: (map['costoPromedio'] as num?)?.toDouble() ?? 0.0,
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0.0,
      descripcion: map['descripcion'] ?? '',
      codigoBarras: map['codigoBarras'],
      activo: map['activo'] ?? true,
      imagenUrl: map['imagenUrl'],
      atributos: map['atributos'] ?? {},
      esBase: map['esBase'] ?? true,
      baseId: map['baseId'],
      cantidadMayoreo: (map['cantidadMayoreo'] as num?)?.toInt(),
      precioMayoreo: (map['precioMayoreo'] as num?)?.toDouble(),
      enPromocion: map['enPromocion'] ?? false,
      precioPromocion: (map['precioPromocion'] as num?)?.toDouble(),
    );
  }

  String get atributoVisual {
    if (atributos.isEmpty) return 'General';
    return atributos.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  Producto copyWith({
    String? nombre,
    String? categoria,
    double? costoPromedio,
    double? precio,
    double? cantidad,
    String? descripcion,
    String? codigoBarras,
    bool? activo,
    String? imagenUrl,
    Map<String, dynamic>? atributos,
    bool? esBase,
    String? baseId,
    int? cantidadMayoreo,
    double? precioMayoreo,
    bool? enPromocion,
    double? precioPromocion,
  }) {
    return Producto(
      id: id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      costoPromedio: costoPromedio ?? this.costoPromedio,
      precio: precio ?? this.precio,
      cantidad: cantidad ?? this.cantidad,
      descripcion: descripcion ?? this.descripcion,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      activo: activo ?? this.activo,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      atributos: atributos ?? this.atributos,
      esBase: esBase ?? this.esBase,
      baseId: baseId ?? this.baseId,
      cantidadMayoreo: cantidadMayoreo ?? this.cantidadMayoreo,
      precioMayoreo: precioMayoreo ?? this.precioMayoreo,
      enPromocion: enPromocion ?? this.enPromocion,
      precioPromocion: precioPromocion ?? this.precioPromocion,
    );
  }
}
