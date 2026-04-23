class Producto {
  final String id;
  final String nombre;
  final String categoria;

  /// Valores de los atributos dinámicos definidos por la categoría.
  /// Clave = nombre del atributo (ej: "Tamaño"), valor = valor elegido (ej: "Queen").
  final Map<String, String> atributos;

  // Estrategia de Variantes en NoSQL
  final bool esBase; // true si es el producto padre/resumen
  final String? grupoId; // Si no esBase, el ID del documento padre correspondiente
  
  /// Documento padre: guarda info vitalísima de los hijos para no quemar lecturas en Firestore
  /// ej: [{"id": "abc", "atributos": "Azul Matrimonial", "stock": 5}]
  final List<Map<String, dynamic>> variantesResumen;

  final double cantidad; // Cantidad total del padre si agrupa, o la específica de la variante
  final double costoPromedio;
  final double precio;
  final String descripcion;
  final String? codigoBarras;
  final bool activo; // Campo para Soft Delete
  final int? cantidadMayoreo;
  final double? precioMayoreo;

  Producto({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.atributos,
    required this.cantidad,
    required this.costoPromedio,
    required this.precio,
    this.descripcion = '',
    this.codigoBarras,
    this.esBase = true,
    this.grupoId,
    this.variantesResumen = const [],
    this.activo = true,
    this.cantidadMayoreo,
    this.precioMayoreo,
  });

  /// Crea un [Producto] a partir de un documento de Firestore.
  /// Migra documentos viejos (tamaño / color / diseño) al nuevo formato.
  factory Producto.fromMap(Map<String, dynamic> map, String id) {
    Map<String, String> atributos;

    final rawAtributos = map['atributos'];
    if (rawAtributos != null && rawAtributos is Map && rawAtributos.isNotEmpty) {
      atributos = Map<String, String>.from(
        rawAtributos.map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    } else {
      // Documento viejo: migrar campos planos al mapa
      atributos = {};
      final tamano = map['tamaño'] as String?;
      final color = map['color'] as String?;
      final diseno = map['diseño'] as String?;

      if (tamano != null && tamano.isNotEmpty) atributos['Tamaño'] = tamano;
      if (color != null && color.isNotEmpty) atributos['Color'] = color;
      if (diseno != null && diseno.isNotEmpty) atributos['Diseño'] = diseno;
    }

    return Producto(
      id: id,
      nombre: map['nombre'] as String? ?? '',
      categoria: map['categoria'] as String? ?? '',
      atributos: atributos,
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0.0,
      costoPromedio:
          (map['costo_promedio'] as num? ?? map['costo'] as num?)?.toDouble() ??
              0.0,
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      descripcion: map['descripcion'] as String? ?? '',
      codigoBarras: map['codigoBarras'] as String?,
      esBase: map['esBase'] as bool? ?? true,
      grupoId: map['grupoId'] as String?,
      variantesResumen: (map['variantesResumen'] as List<dynamic>?)
              ?.map((item) => item as Map<String, dynamic>)
              .toList() ??
          const [],
      activo: map['activo'] as bool? ?? true,
      cantidadMayoreo: (map['cantidadMayoreo'] as num?)?.toInt(),
      precioMayoreo: (map['precioMayoreo'] as num?)?.toDouble(),
    );
  }

  /// Convierte el producto a un mapa para guardarlo en Firestore.
  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'categoria': categoria,
        'atributos': atributos,
        'cantidad': cantidad,
        'costo_promedio': costoPromedio,
        'precio': precio,
        'descripcion': descripcion,
        if (codigoBarras != null) 'codigoBarras': codigoBarras,
        'esBase': esBase,
        if (grupoId != null) 'grupoId': grupoId,
        'variantesResumen': variantesResumen,
        'activo': activo,
        'cantidadMayoreo': cantidadMayoreo,
        'precioMayoreo': precioMayoreo,
      };

  /// Resumen de todos los atributos para mostrar en la UI (ej: "Queen · Rojo").
  String get atributoVisual => atributos.values
      .where((v) => v.isNotEmpty)
      .join(' · ');

  Producto copyWith({
    String? id,
    String? nombre,
    String? categoria,
    Map<String, String>? atributos,
    double? cantidad,
    double? costoPromedio,
    double? precio,
    String? descripcion,
    String? codigoBarras,
    bool? esBase,
    String? grupoId,
    List<Map<String, dynamic>>? variantesResumen,
    bool? activo,
    int? cantidadMayoreo,
    double? precioMayoreo,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      atributos: atributos ?? Map<String, String>.from(this.atributos),
      cantidad: cantidad ?? this.cantidad,
      costoPromedio: costoPromedio ?? this.costoPromedio,
      precio: precio ?? this.precio,
      descripcion: descripcion ?? this.descripcion,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      esBase: esBase ?? this.esBase,
      grupoId: grupoId ?? this.grupoId,
      variantesResumen: variantesResumen ?? List.from(this.variantesResumen),
      activo: activo ?? this.activo,
      cantidadMayoreo: cantidadMayoreo ?? this.cantidadMayoreo,
      precioMayoreo: precioMayoreo ?? this.precioMayoreo,
    );
  }

  @override
  String toString() =>
      'Producto(id: $id, nombre: $nombre, cat: $categoria, '
      'atributos: $atributos, cant: $cantidad, '
      'costoPromedio: \$$costoPromedio, precio: \$$precio, activo: $activo)';
}
