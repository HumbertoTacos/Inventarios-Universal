class Producto {
  final String id;
  final String nombre;
  final String categoria;
  final double costoPromedio;
  final double costoActual;
  final double precio;
  final double cantidad;
  final String descripcion;
  final String? codigoBarras;
  final bool activo;
  final String? imagenUrl;
  final Map<String, dynamic> atributos;
  final bool esBase;
  final String? baseId;
  final String? proveedorId;
  final String? proveedorNombre;
  final DateTime? ultimaCompraFecha; // Fecha de la última vez que se compró
  final double? ultimoCostoCompra;   // Precio unitario de la última compra

  // Mayoreo
  final int? cantidadMayoreo;
  final double? precioMayoreo;

  // Promociones
  final bool enPromocion;
  final double? precioPromocion;
  final double stockMinimo;
  final bool permiteDecimales;

  Producto({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.costoPromedio,
    this.costoActual = 0.0,
    required this.precio,
    required this.cantidad,
    required this.descripcion,
    this.codigoBarras,
    this.activo = true,
    this.imagenUrl,
    this.atributos = const {},
    this.esBase = true,
    this.baseId,
    this.proveedorId,
    this.proveedorNombre,
    this.ultimaCompraFecha,
    this.ultimoCostoCompra,
    this.cantidadMayoreo,
    this.precioMayoreo,
    this.enPromocion = false,
    this.precioPromocion,
    this.stockMinimo = 0.0,
    this.permiteDecimales = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'nombreLower': nombre.toLowerCase(),
      'categoria': categoria,
      'costoPromedio': costoPromedio,
      'costoActual': costoActual,
      'precio': precio,
      'cantidad': cantidad,
      'descripcion': descripcion,
      'codigoBarras': codigoBarras,
      'activo': activo,
      'imagenUrl': imagenUrl,
      'atributos': atributos,
      'esBase': esBase,
      'baseId': baseId,
      'proveedorId': proveedorId,
      'proveedorNombre': proveedorNombre,
      'ultimaCompraFecha': ultimaCompraFecha?.toIso8601String(),
      'ultimoCostoCompra': ultimoCostoCompra,
      'cantidadMayoreo': cantidadMayoreo,
      'precioMayoreo': precioMayoreo,
      'enPromocion': enPromocion,
      'precioPromocion': precioPromocion,
      'stockMinimo': stockMinimo,
      'permiteDecimales': permiteDecimales,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map, String id) {
    return Producto(
      id: id,
      nombre: map['nombre'] ?? '',
      categoria: map['categoria'] ?? '',
      costoPromedio: (map['costoPromedio'] as num?)?.toDouble() ?? 0.0,
      costoActual: (map['costoActual'] as num?)?.toDouble() ?? 0.0,
      precio: (map['precio'] as num?)?.toDouble() ?? 0.0,
      cantidad: (map['cantidad'] as num?)?.toDouble() ?? 0.0,
      descripcion: map['descripcion'] ?? '',
      codigoBarras: map['codigoBarras'],
      activo: map['activo'] ?? true,
      imagenUrl: map['imagenUrl'],
      atributos: map['atributos'] ?? {},
      esBase: map['esBase'] ?? true,
      baseId: map['baseId'],
      proveedorId: map['proveedorId'],
      proveedorNombre: map['proveedorNombre'],
      ultimaCompraFecha: map['ultimaCompraFecha'] != null ? DateTime.tryParse(map['ultimaCompraFecha']) : null,
      ultimoCostoCompra: (map['ultimoCostoCompra'] as num?)?.toDouble(),
      cantidadMayoreo: (map['cantidadMayoreo'] as num?)?.toInt(),
      precioMayoreo: (map['precioMayoreo'] as num?)?.toDouble(),
      enPromocion: map['enPromocion'] ?? false,
      precioPromocion: (map['precioPromocion'] as num?)?.toDouble(),
      stockMinimo: (map['stockMinimo'] as num?)?.toDouble() ?? 0.0,
      permiteDecimales: map['permiteDecimales'] ?? false,
    );
  }

  String get atributoVisual {
    if (atributos.isEmpty) return 'General';
    return atributos.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  }

  Producto copyWith({
    String? id,
    String? nombre,
    String? categoria,
    double? costoPromedio,
    double? costoActual,
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
    String? proveedorId,
    String? proveedorNombre,
    DateTime? ultimaCompraFecha,
    double? ultimoCostoCompra,
    double? stockMinimo,
    bool? permiteDecimales,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      costoPromedio: costoPromedio ?? this.costoPromedio,
      costoActual: costoActual ?? this.costoActual,
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
      proveedorId: proveedorId ?? this.proveedorId,
      proveedorNombre: proveedorNombre ?? this.proveedorNombre,
      ultimaCompraFecha: ultimaCompraFecha ?? this.ultimaCompraFecha,
      ultimoCostoCompra: ultimoCostoCompra ?? this.ultimoCostoCompra,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      permiteDecimales: permiteDecimales ?? this.permiteDecimales,
    );
  }
}
