import 'package:cloud_firestore/cloud_firestore.dart';

class CuentaPorPagar {
  final String id;
  final String proveedorId;
  final String nombreProveedor;
  final String compraId;
  final double montoTotal;
  final double saldoPendiente;
  final DateTime fechaCompra;
  final DateTime? fechaVencimiento;
  final String estado; // 'pendiente', 'parcial', 'pagada'

  CuentaPorPagar({
    required this.id,
    required this.proveedorId,
    required this.nombreProveedor,
    required this.compraId,
    required this.montoTotal,
    required this.saldoPendiente,
    required this.fechaCompra,
    this.fechaVencimiento,
    this.estado = 'pendiente',
  });

  Map<String, dynamic> toMap() {
    return {
      'proveedorId': proveedorId,
      'nombreProveedor': nombreProveedor,
      'compraId': compraId,
      'montoTotal': montoTotal,
      'saldoPendiente': saldoPendiente,
      'fechaCompra': fechaCompra.toIso8601String(),
      'fechaVencimiento': fechaVencimiento?.toIso8601String(),
      'estado': estado,
    };
  }

  factory CuentaPorPagar.fromMap(Map<String, dynamic> map, String id) {
    return CuentaPorPagar(
      id: id,
      proveedorId: map['proveedorId'] ?? '',
      nombreProveedor: map['nombreProveedor'] ?? '',
      compraId: map['compraId'] ?? '',
      montoTotal: (map['montoTotal'] as num?)?.toDouble() ?? 0.0,
      saldoPendiente: (map['saldoPendiente'] as num?)?.toDouble() ?? 0.0,
      fechaCompra: map['fechaCompra'] != null
          ? DateTime.parse(map['fechaCompra'])
          : DateTime.now(),
      fechaVencimiento: map['fechaVencimiento'] != null
          ? DateTime.parse(map['fechaVencimiento'])
          : null,
      estado: map['estado'] ?? 'pendiente',
    );
  }

  int get diasAtraso {
    if (estado == 'pagada' || fechaVencimiento == null) return 0;
    final hoy = DateTime.now();
    if (hoy.isBefore(fechaVencimiento!)) return 0;
    return hoy.difference(fechaVencimiento!).inDays;
  }
}
