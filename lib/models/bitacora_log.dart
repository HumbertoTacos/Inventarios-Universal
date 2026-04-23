class BitacoraLog {
  final String id;
  final DateTime fecha;
  final String usuarioId;
  final String nombreUsuario;
  final String modulo; // 'CAJA', 'INVENTARIO', 'VENTAS', 'CREDITOS', 'NEGOCIO'
  final String descripcion;

  BitacoraLog({
    required this.id,
    required this.fecha,
    required this.usuarioId,
    required this.nombreUsuario,
    required this.modulo,
    required this.descripcion,
  });

  Map<String, dynamic> toMap() {
    return {
      'fecha': fecha.toIso8601String(),
      'usuarioId': usuarioId,
      'nombreUsuario': nombreUsuario,
      'modulo': modulo,
      'descripcion': descripcion,
    };
  }

  factory BitacoraLog.fromMap(Map<String, dynamic> map, String id) {
    return BitacoraLog(
      id: id,
      fecha: DateTime.parse(map['fecha']),
      usuarioId: map['usuarioId'] ?? 'desconocido',
      nombreUsuario: map['nombreUsuario'] ?? 'Usuario',
      modulo: map['modulo'] ?? 'GENERAL',
      descripcion: map['descripcion'] ?? '',
    );
  }
}
