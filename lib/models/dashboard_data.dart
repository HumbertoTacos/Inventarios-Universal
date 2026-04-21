/// Modelo de datos para el Dashboard Analítico del Administrador/Dueño.
class TopProducto {
  final String productoId;
  final String nombre;
  final int cantidadVendida;
  final double ingresoGenerado;

  const TopProducto({
    required this.productoId,
    required this.nombre,
    required this.cantidadVendida,
    required this.ingresoGenerado,
  });
}

class DashboardData {
  /// Ingresos por día. Key: 'MM/dd', Value: total ingresado.
  final Map<String, double> ingresosPorDia;

  /// Costos por día. Key: 'MM/dd', Value: total en costos.
  final Map<String, double> costosPorDia;

  final double ingresosTotales;
  final double costosTotales;
  final double gananciaBruta;
  final double margenPorcentaje;
  final int totalVentas;
  final List<TopProducto> topProductos;
  final int diasConsultados;

  double get capitalCongelado => 0; // Se carga por separado

  const DashboardData({
    required this.ingresosPorDia,
    required this.costosPorDia,
    required this.ingresosTotales,
    required this.costosTotales,
    required this.gananciaBruta,
    required this.margenPorcentaje,
    required this.totalVentas,
    required this.topProductos,
    required this.diasConsultados,
  });

  factory DashboardData.empty(int dias) => DashboardData(
        ingresosPorDia: {},
        costosPorDia: {},
        ingresosTotales: 0,
        costosTotales: 0,
        gananciaBruta: 0,
        margenPorcentaje: 0,
        totalVentas: 0,
        topProductos: [],
        diasConsultados: dias,
      );
}
