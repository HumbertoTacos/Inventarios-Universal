class Producto {
  final String id;
  final String nombre;
  final String categoria;
  final String tamano;       // Tamaño: Individual, Matrimonial, Queen, King, Unitalla
  final String? color;       // Aplica cuando tipoAtributo == "color"
  final String? diseno;      // Aplica cuando tipoAtributo == "diseño"
  final int cantidad;
  final double precio;
  final String descripcion;
  final String? codigoBarras;

  Producto({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.tamano,
    this.color,
    this.diseno,
    required this.cantidad,
    required this.precio,
    this.descripcion = '',
    this.codigoBarras,
  });

  /// Crea un [Producto] a partir de un documento de Firestore.
  factory Producto.fromMap(Map<String, dynamic> map, String id) {
    return Producto(
      id: id,
      nombre: map['nombre'] as String? ?? '',
      categoria: map['categoria'] as String? ?? '',
      tamano: map['tamaño'] as String? ?? 'Unitalla',
      color: map['color'] as String?,
      diseno: map['diseño'] as String?,
      cantidad: (map['cantidad'] as num?)?.toInt() ?? 0,
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      descripcion: map['descripcion'] as String? ?? '',
      codigoBarras: map['codigoBarras'] as String?,
    );
  }

  /// Convierte el producto a un mapa para guardarlo en Firestore.
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'categoria': categoria,
      'tamaño': tamano,
      if (color != null) 'color': color,
      if (diseno != null) 'diseño': diseno,
      'cantidad': cantidad,
      'precio': precio,
      'descripcion': descripcion,
      if (codigoBarras != null) 'codigoBarras': codigoBarras,
    };
  }

  /// Retorna el atributo visual (color o diseño) para mostrar en la UI.
  String get atributoVisual {
    if (color != null && color!.isNotEmpty) return color!;
    if (diseno != null && diseno!.isNotEmpty) return diseno!;
    return '';
  }

  Producto copyWith({
    String? id,
    String? nombre,
    String? categoria,
    String? tamano,
    String? color,
    String? diseno,
    int? cantidad,
    double? precio,
    String? descripcion,
    String? codigoBarras,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      tamano: tamano ?? this.tamano,
      color: color ?? this.color,
      diseno: diseno ?? this.diseno,
      cantidad: cantidad ?? this.cantidad,
      precio: precio ?? this.precio,
      descripcion: descripcion ?? this.descripcion,
      codigoBarras: codigoBarras ?? this.codigoBarras,
    );
  }

  @override
  String toString() =>
      'Producto(id: $id, nombre: $nombre, cat: $categoria, '
      'tamaño: $tamano, color: $color, diseño: $diseno, '
      'cant: $cantidad, precio: \$$precio)';
}
