import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/dashboard_data.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/exportacion_service.dart';
import '../widgets/premium_widgets.dart';
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
  int _touchedIndex = -1;

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

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ResponsiveScaffold(
      currentRoute: 'estadisticas',
      title: 'Panel Financiero',
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
      body: FutureBuilder<DashboardData>(
        future: _futDashboard,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error al cargar datos: ${snap.error}'));
          }

          final data = snap.data ?? DashboardData.empty(_diasSeleccionados);

          return ResponsiveLayout(
            mobileBody: _buildContent(data, cs, tt, isDesktop: false, isTablet: false),
            tabletBody: _buildContent(data, cs, tt, isDesktop: false, isTablet: true),
            desktopBody: _buildContent(data, cs, tt, isDesktop: true, isTablet: false),
          );
        },
      ),
    );
  }

  Widget _buildContent(DashboardData data, ColorScheme cs, TextTheme tt, {bool isDesktop = false, bool isTablet = false}) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── CABECERA: BIENVENIDA Y SELECTOR ──────────────────────────
              _buildHeader(tt, cs),
              const SizedBox(height: 24),

              // ── SECCIÓN 1: KPI CARDS (CON DEGRADADOS) ─────────────────────
              _buildKpiGrid(data, cs, tt, isDesktop: isDesktop, isTablet: isTablet),
              const SizedBox(height: 32),

              // ── SECCIÓN 2: FLUJO DE CAJA (BAR CHART PRO) ──────────────────
              _buildSectionTitle(tt, 'Flujo de Caja Mensual', 'Rendimiento operativo diario'),
              const SizedBox(height: 16),
              _buildCashFlowChart(data, cs, isDesktop),
              const SizedBox(height: 32),

              // ── SECCIÓN 3: RENDIMIENTO Y CATEGORÍAS ───────────────────────
              _buildPerformanceGrids(data, cs, tt, isDesktop),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(TextTheme tt, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(subtitle, style: tt.bodySmall?.copyWith(color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildHeader(TextTheme tt, ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool narrow = constraints.maxWidth < 500;
        return Flex(
          direction: narrow ? Axis.vertical : Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: narrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dashboard Financiero', style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1, fontSize: narrow ? 24 : null)),
                Text('Análisis en tiempo real', style: tt.bodyMedium?.copyWith(color: Colors.grey)),
              ],
            ),
            if (narrow) const SizedBox(height: 16),
            _buildPeriodSelector(cs, isNarrow: narrow),
          ],
        );
      }
    );
  }

  Widget _buildPeriodSelector(ColorScheme cs, {bool isNarrow = false}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Crítico para evitar overflow
        children: [7, 30, 90].map((d) {
          bool isSel = _diasSeleccionados == d;
          return GestureDetector(
            onTap: () => _cambiarPeriodo(d),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSel ? [BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
              ),
              child: Text(
                '${d}D', 
                style: TextStyle(color: isSel ? cs.onPrimary : cs.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 12)
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiGrid(DashboardData data, ColorScheme cs, TextTheme tt, {bool isDesktop = false, bool isTablet = false}) {
    // 4 columnas en Desktop, 2 en Tablet y Móvil
    final int crossAxisCount = isDesktop ? 4 : 2;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: isDesktop ? 1.5 : 1.15,
      children: [
        _kpiCardPro('Ventas', data.ingresosTotales.formatoMoneda, Icons.trending_up, [Colors.blue.shade700, Colors.blue.shade400], cs, trend: 15.2),
        _kpiCardPro('Gastos', data.costosTotales.formatoMoneda, Icons.trending_down, [Colors.orange.shade700, Colors.orange.shade400], cs, trend: -2.1),
        _kpiCardPro('Utilidad', data.gananciaBruta.formatoMoneda, Icons.account_balance, [Colors.teal.shade700, Colors.teal.shade400], cs, trend: 8.5),
        _kpiCardPro('Margen', '${data.margenPorcentaje.toStringAsFixed(1)}%', Icons.pie_chart, [Colors.indigo.shade700, Colors.indigo.shade400], cs),
      ],
    );
  }

  Widget _kpiCardPro(String label, String value, IconData icon, List<Color> gradient, ColorScheme cs, {double? trend}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: gradient[0].withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              if (trend != null)
                Text(
                  '${trend >= 0 ? "+" : ""}$trend%',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCashFlowChart(DashboardData data, ColorScheme cs, bool isDesktop) {
    final dias = data.ingresosPorDia.keys.toList()..sort();
    if (dias.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('Sin datos')));

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
            gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade700], begin: Alignment.bottomCenter, end: Alignment.topCenter),
            width: isDesktop ? 14 : 10, 
            borderRadius: BorderRadius.circular(4)
          ),
          BarChartRodData(
            toY: cos, 
            gradient: LinearGradient(colors: [Colors.orange.shade300, Colors.orange.shade600], begin: Alignment.bottomCenter, end: Alignment.topCenter),
            width: isDesktop ? 14 : 10, 
            borderRadius: BorderRadius.circular(4)
          ),
        ],
        barsSpace: 4,
      );
    });

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(16, 32, 24, 16),
      child: RepaintBoundary(
        child: SizedBox(
          height: isDesktop ? 300 : 250,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              barGroups: groups,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: cs.surfaceVariant, strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, meta) {
                      int i = v.toInt();
                      if (i < 0 || i >= dias.length) return const SizedBox();
                      if (!isDesktop && i % 2 != 0 && dias.length > 7) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(dias[i], style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceGrids(DashboardData data, ColorScheme cs, TextTheme tt, bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildRankingCard(data, cs, tt)),
          const SizedBox(width: 24),
          Expanded(child: _buildAlertsCard(cs, tt)),
        ],
      );
    } else {
      return Column(
        children: [
          _buildRankingCard(data, cs, tt),
          const SizedBox(height: 24),
          _buildAlertsCard(cs, tt),
        ],
      );
    }
  }

  Widget _buildRankingCard(DashboardData data, ColorScheme cs, TextTheme tt) {
    return PremiumCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(tt, 'Rendimiento por Producto', 'Los más vendidos del periodo'),
          const SizedBox(height: 24),
          _buildPieChart(data, [Colors.blue, Colors.purple, Colors.amber, Colors.teal, Colors.pink]),
          const SizedBox(height: 24),
          _buildLegend(data, [Colors.blue, Colors.purple, Colors.amber, Colors.teal, Colors.pink]),
        ],
      ),
    );
  }

  Widget _buildAlertsCard(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(tt, 'Alertas de Stock', 'Reposición inmediata recomendada'),
        const SizedBox(height: 16),
        _buildStockAlertsSection(cs, tt),
      ],
    );
  }

  Widget _buildStockAlertsSection(ColorScheme cs, TextTheme tt) {
    return FutureBuilder<List<dynamic>>(
      future: _svc.getProductosBajoStock(umbral: 5),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        final criticos = snap.data ?? [];
        if (criticos.isEmpty) return Container(padding: const EdgeInsets.all(32), child: const Center(child: Text('✅ Inventario saludable')));
        
        return PremiumCard(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: criticos.take(4).map((p) => ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              ),
              title: Text(p.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              subtitle: Text('${p.cantidad} unidades restantes', style: TextStyle(fontSize: 11, color: Colors.red.shade700)),
              trailing: const Icon(Icons.chevron_right, size: 16),
            )).toList(),
          ),
        );
      }
    );
  }

  Widget _buildPieChart(DashboardData data, List<Color> colors) {
    return RepaintBoundary(
      child: SizedBox(
        height: 250,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            pieTouchData: PieTouchData(enabled: false),
            sections: List.generate(data.topProductos.length, (i) {
              final p = data.topProductos[i];
              return PieChartSectionData(
                color: colors[i % colors.length],
                value: p.ingresoGenerado,
                title: '',
                radius: 40,
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(DashboardData data, List<Color> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(data.topProductos.length, (i) {
        final p = data.topProductos[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(p.nombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 12),
              Text(p.ingresoGenerado.formatoMoneda, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        );
      }),
    );
  }
}
