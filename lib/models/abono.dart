import 'venta.dart';

class Abono {
  final String id;
  final String clienteId;

  /// Referencia opcional a una venta específica que se está abonando.
  final String? ventaId;

  final double monto;
  final DateTime fecha;
  final MetodoPago metodoPago;
  final String cajeroId;
  final String? notas;

  Abono({
    required this.id,
    required this.clienteId,
    this.ventaId,
    required this.monto,
    required this.fecha,
    required this.metodoPago,
    required this.cajeroId,
    this.notas,
  });

  Map<String, dynamic> toMap() => {
        'clienteId': clienteId,
        'ventaId': ventaId,
        'monto': monto,
        'fecha': fecha.toIso8601String(),
        'metodoPago': metodoPago.name,
        'cajeroId': cajeroId,
        'notas': notas ?? '',
      };

  factory Abono.fromMap(Map<String, dynamic> map, String id) => Abono(
        id: id,
        clienteId: map['clienteId'] as String? ?? '',
        ventaId: map['ventaId'] as String?,
        monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
        fecha: map['fecha'] != null
            ? DateTime.parse(map['fecha'])
            : DateTime.now(),
        metodoPago: MetodoPago.values.firstWhere(
          (e) => e.name == map['metodoPago'],
          orElse: () => MetodoPago.efectivo,
        ),
        cajeroId: map['cajeroId'] as String? ?? '',
        notas: map['notas'] as String?,
      );
}
