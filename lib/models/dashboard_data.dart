/// Modelo de datos para el Dashboard Analítico del Administrador/Dueño.
class TopProducto {
  final String productoId;
  final String nombre;
  final double cantidadVendida;
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
  final List<TopProducto> peoresProductos;
  final List<TopProducto> productosBajoStock;
  final List<TopProducto> sugerenciasCompra;
  final int diasConsultados;
  
  /// Utilidad neta acumulada por proveedor.
  final Map<String, double> utilidadPorProveedor;
  /// Mapa de IDs a Nombres de proveedores para el reporte.
  final Map<String, String> nombresProveedores;

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
    required this.peoresProductos,
    required this.productosBajoStock,
    required this.sugerenciasCompra,
    required this.diasConsultados,
    required this.utilidadPorProveedor,
    required this.nombresProveedores,
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
        peoresProductos: [],
        productosBajoStock: [],
        sugerenciasCompra: [],
        diasConsultados: dias,
        utilidadPorProveedor: {},
        nombresProveedores: {},
      );
}
