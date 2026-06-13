import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/dashboard_data.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/exportacion_service.dart';
import '../utils/formatters.dart';
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  final FirebaseService _svc = FirebaseService();
  int _diasSeleccionados = 7;
  bool _exportando = false;
  late Future<DashboardData> _futDashboard;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _futDashboard = _svc.getDashboardData(dias: _diasSeleccionados);
  }

  void _cambiarPeriodo(int dias) {
    setState(() {
      _diasSeleccionados = dias;
      _cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService().currentUserData?.rol != AuthService.rolDueno) {
      return const Scaffold(
        body: Center(child: Text('Acceso Denegado. Solo el dueño puede ver estadísticas.')),
      );
    }

    return ResponsiveScaffold(
      currentRoute: 'estadisticas',
      title: 'Dashboard Financiero',
      actions: [
        if (_exportando)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            tooltip: 'Exportar Reporte',
            onPressed: () async {
              setState(() => _exportando = true);
              try {
                final ventas = await _svc.getVentasPaginadas(limite: 500);
                final nombre = 'reporte_financiero_${DateFormat('yyyyMMdd').format(DateTime.now())}';
                await ExportacionService.exportarVentasCSV(ventas, nombreArchivo: nombre);
              } finally {
                setState(() => _exportando = false);
              }
            },
          ),
      ],
      body: Container(
        color: Colors.grey.shade50, // Fondo gris/neutro
        child: FutureBuilder<DashboardData>(
          future: _futDashboard,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.blueAccent,
                  strokeWidth: 3,
                ),
              );
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }

            final data = snap.data ?? DashboardData.empty(_diasSeleccionados);

            return ResponsiveLayout(
              mobileBody: _buildContent(data, isDesktop: false),
              tabletBody: _buildContent(data, isDesktop: false),
              desktopBody: _buildContent(data, isDesktop: true),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(DashboardData data, {bool isDesktop = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDesktop),
              const SizedBox(height: 24),
              _buildKpiSection(data, isDesktop),
              const SizedBox(height: 32),
              _buildBarChartSection(data, isDesktop),
              const SizedBox(height: 32),
              _buildPieChartSection(data, isDesktop),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDesktop) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Análisis Financiero',
          style: TextStyle(
            fontSize: isDesktop ? 28 : 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        DropdownButton<int>(
          value: _diasSeleccionados,
          items: const [
            DropdownMenuItem(value: 7, child: Text('Últimos 7 días')),
            DropdownMenuItem(value: 30, child: Text('Últimos 30 días')),
            DropdownMenuItem(value: 90, child: Text('Últimos 90 días')),
          ],
          onChanged: (val) {
            if (val != null) _cambiarPeriodo(val);
          },
          underline: const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildKpiSection(DashboardData data, bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = isDesktop ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
        double childAspectRatio = isDesktop ? 1.8 : (constraints.maxWidth > 600 ? 2.0 : 2.5);
        
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          children: [
            _buildKpiCard(
              title: 'Ingresos Totales',
              value: data.ingresosTotales.formatoMoneda,
              icon: Icons.arrow_upward,
              iconColor: Colors.green,
            ),
            _buildKpiCard(
              title: 'Costos Totales',
              value: data.costosTotales.formatoMoneda,
              icon: Icons.arrow_downward,
              iconColor: Colors.red,
            ),
            _buildKpiCard(
              title: 'Ganancia Bruta',
              value: data.gananciaBruta.formatoMoneda,
              valueColor: data.gananciaBruta >= 0 ? Colors.green.shade700 : Colors.red.shade700,
              isProminent: true,
            ),
            _buildKpiCard(
              title: 'Margen de Ganancia',
              value: '${data.margenPorcentaje.toStringAsFixed(1)}%',
              icon: Icons.percent,
              iconColor: Colors.blue,
            ),
          ],
        );
      }
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    IconData? icon,
    Color? iconColor,
    Color? valueColor,
    bool isProminent = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.black87,
                  fontSize: isProminent ? 28 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartSection(DashboardData data, bool isDesktop) {
    final dias = data.ingresosPorDia.keys.toList()..sort();
    double maxY = 0;
    
    final groups = List.generate(dias.length, (i) {
      final ing = data.ingresosPorDia[dias[i]] ?? 0;
      final cos = data.costosPorDia[dias[i]] ?? 0;
      if (ing > maxY) maxY = ing;
      if (cos > maxY) maxY = cos;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: ing,
            color: Colors.green,
            width: isDesktop ? 16 : 12,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: cos,
            color: Colors.deepOrange,
            width: isDesktop ? 16 : 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flujo de Efectivo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: dias.isEmpty
                  ? const Center(child: Text('Sin datos en este periodo'))
                  : BarChart(
                      BarChartData(
                        maxY: maxY * 1.2,
                        barGroups: groups,
                        alignment: BarChartAlignment.spaceAround,
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '\$${NumberFormat.compact().format(value)}',
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, meta) {
                                int i = v.toInt();
                                if (i < 0 || i >= dias.length) return const SizedBox();
                                final dateParts = dias[i].split('-');
                                final label = dateParts.length >= 3 ? '${dateParts[2]}/${dateParts[1]}' : dias[i];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.blueGrey.shade800,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final isIngreso = rodIndex == 0;
                              return BarTooltipItem(
                                '${isIngreso ? "Ingreso" : "Costo"}\n\$${NumberFormat("#,##0.00").format(rod.toY)}',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartSection(DashboardData data, bool isDesktop) {
    if (data.topProductos.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = [
      Colors.indigoAccent,
      Colors.pinkAccent,
      Colors.amber,
      Colors.teal,
      Colors.cyan,
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 5 Productos (Por Ingreso)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: List.generate(data.topProductos.length, (i) {
                          final p = data.topProductos[i];
                          return PieChartSectionData(
                            color: colors[i % colors.length],
                            value: p.ingresoGenerado,
                            title: '${((p.ingresoGenerado / data.ingresosTotales) * 100).toStringAsFixed(1)}%',
                            radius: 50,
                            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 32),
                  Expanded(child: _buildLegend(data, colors)),
                ]
              ],
            ),
            if (!isDesktop) ...[
              const SizedBox(height: 24),
              _buildLegend(data, colors),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(DashboardData data, List<Color> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(data.topProductos.length, (i) {
        final p = data.topProductos[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p.nombre,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                p.ingresoGenerado.formatoMoneda,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        );
      }),
    );
  }
}

