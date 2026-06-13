class Empleado {
  final String id;
  final String nombre;
  final String pin;
  final String rol;
  final double comisionPorcentaje;
  final bool activo;

  Empleado({
    required this.id,
    required this.nombre,
    required this.pin,
    required this.rol,
    required this.comisionPorcentaje,
    this.activo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'pin': pin,
      'rol': rol,
      'comisionPorcentaje': comisionPorcentaje,
      'activo': activo,
    };
  }

  factory Empleado.fromMap(Map<String, dynamic> map, String id) {
    return Empleado(
      id: id,
      nombre: map['nombre'] as String? ?? '',
      pin: map['pin'] as String? ?? '',
      rol: map['rol'] as String? ?? 'vendedor',
      comisionPorcentaje: (map['comisionPorcentaje'] as num?)?.toDouble() ?? 0.0,
      activo: map['activo'] as bool? ?? true,
    );
  }
}
