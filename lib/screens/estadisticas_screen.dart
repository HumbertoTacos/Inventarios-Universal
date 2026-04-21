import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/producto.dart';
import '../models/dashboard_data.dart';
import '../services/firebase_service.dart';
import '../services/exportacion_service.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  final FirebaseService _svc = FirebaseService();
  int _diasSeleccionados = 7;
  bool _exportando = false;

  // Futures independientes para no bloquear uno por el otro
  late Future<DashboardData> _futDashboard;
  late Future<double> _futCapital;
  late Future<List<Producto>> _futAlertas;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    _futDashboard = _svc.getDashboardData(dias: _diasSeleccionados);
    _futCapital = _svc.getCapitalEnInventario();
    _futAlertas = _svc.getProductosBajoStock(umbral: 5);
  }

  void _cambiarPeriodo(int dias) {
    setState(() {
      _diasSeleccionados = dias;
      _cargar();
    });
  }

  Future<void> _exportarCSV() async {
    if (_exportando) return;
    setState(() => _exportando = true);
    try {
      final ventas = await _svc.getVentasPaginadas(limite: 500);
      final nombre = 'ventas_${_diasSeleccionados}d_${DateFormat('yyyyMMdd').format(DateTime.now())}';
      final archivo = await ExportacionService.exportarVentasCSV(ventas, nombreArchivo: nombre);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Exportado: $archivo'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        elevation: 0,
        actions: [
          // Botón de exportación CSV
          _exportando
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Exportar CSV',
                  onPressed: _exportarCSV,
                ),
          // Selector de período compacto
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<int>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 12),
              ),
              segments: const [
                ButtonSegment(value: 7, label: Text('7d')),
                ButtonSegment(value: 30, label: Text('30d')),
              ],
              selected: {_diasSeleccionados},
              onSelectionChanged: (s) => _cambiarPeriodo(s.first),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _cargar()),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: FutureBuilder<DashboardData>(
            future: _futDashboard,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 400,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return _buildError(snap.error.toString());
              }

              final data = snap.data ?? DashboardData.empty(_diasSeleccionados);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Tarjetas KPI ──────────────────────────────────────
                  _buildKpiGrid(data, cs, tt),
                  const SizedBox(height: 24),

                  // ── Gráfico de Barras ─────────────────────────────────
                  Text('Ingresos vs Costos',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Últimos $_diasSeleccionados días',
                      style: tt.bodySmall?.copyWith(color: cs.outline)),
                  const SizedBox(height: 12),
                  _buildGrafico(data, cs),
                  const SizedBox(height: 24),

                  // ── Top 5 Productos ───────────────────────────────────
                  Text('Top 5 Productos',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildTopProductos(data, cs, tt),
                  const SizedBox(height: 24),

                  // ── Capital Inventario ────────────────────────────────
                  FutureBuilder<double>(
                    future: _futCapital,
                    builder: (ctx, capSnap) {
                      final cap = capSnap.data ?? 0.0;
                      return _buildKpiCard(
                        'Capital Congelado en Inventario',
                        '\$${cap.toStringAsFixed(2)}',
                        Icons.inventory_2_outlined,
                        cs.tertiary,
                        cs,
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Alertas de Stock ──────────────────────────────────
                  Text('Alertas de Stock',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildAlertas(cs),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _buildKpiGrid(DashboardData data, ColorScheme cs, TextTheme tt) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _buildKpiCard('Ingresos', '\$${data.ingresosTotales.toStringAsFixed(2)}',
            Icons.trending_up, Colors.green.shade600, cs),
        _buildKpiCard('Costos', '\$${data.costosTotales.toStringAsFixed(2)}',
            Icons.trending_down, Colors.orange.shade600, cs),
        _buildKpiCard('Ganancia Bruta', '\$${data.gananciaBruta.toStringAsFixed(2)}',
            Icons.savings_outlined,
            data.gananciaBruta >= 0 ? Colors.blue.shade600 : Colors.red.shade600, cs),
        _buildKpiCard('Margen', '${data.margenPorcentaje.toStringAsFixed(1)}%',
            Icons.pie_chart_outline, Colors.purple.shade600, cs),
        _buildKpiCard('Ventas Completadas', '${data.totalVentas}',
            Icons.receipt_long_outlined, cs.primary, cs),
      ],
    );
  }

  Widget _buildKpiCard(String label, String valor, IconData icon, Color color,
      ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withAlpha(30), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: cs.outline)),
              Text(valor,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrafico(DashboardData data, ColorScheme cs) {
    if (data.ingresosPorDia.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
            color: cs.surface, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('Sin datos para el período seleccionado')),
      );
    }

    // Ordenar días cronológicamente
    final dias = data.ingresosPorDia.keys.toList()..sort();

    double maxY = 0;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < dias.length; i++) {
      final ing = data.ingresosPorDia[dias[i]] ?? 0;
      final cos = data.costosPorDia[dias[i]] ?? 0;
      if (ing > maxY) maxY = ing;
      if (cos > maxY) maxY = cos;
      groups.add(BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: [
          BarChartRodData(
            toY: ing,
            color: Colors.green.shade500,
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          BarChartRodData(
            toY: cos,
            color: Colors.orange.shade400,
            width: 10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ));
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
          color: cs.surface, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
      child: Column(
        children: [
          // Leyenda
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _legendDot(Colors.green.shade500, 'Ingresos'),
              const SizedBox(width: 16),
              _legendDot(Colors.orange.shade400, 'Costos'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceEvenly,
                maxY: maxY * 1.25,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBorderRadius: BorderRadius.circular(8),
                    getTooltipItem: (group, gi, rod, ri) {
                      final label = ri == 0 ? 'Ing' : 'Cos';
                      return BarTooltipItem(
                        '$label\n\$${rod.toY.toStringAsFixed(0)}',
                        TextStyle(
                            color: rod.color, fontWeight: FontWeight.bold, fontSize: 11),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= dias.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(dias[idx], style: const TextStyle(fontSize: 9)),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                  getDrawingHorizontalLine: (v) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                borderData: FlBorderData(show: false),
                barGroups: groups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildTopProductos(DashboardData data, ColorScheme cs, TextTheme tt) {
    if (data.topProductos.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
            color: cs.surface, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('Sin ventas en el período seleccionado')),
      );
    }

    final maxCant = data.topProductos.first.cantidadVendida.toDouble();
    final moneyFmt = NumberFormat.simpleCurrency(locale: 'es_MX');

    return Container(
      decoration:
          BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: data.topProductos.asMap().entries.map((e) {
          final i = e.key;
          final p = e.value;
          final pct = maxCant > 0 ? p.cantidadVendida / maxCant : 0.0;
          final colors = [
            Colors.amber.shade600,
            Colors.blueGrey.shade500,
            Colors.brown.shade400,
            cs.secondary,
            cs.outline,
          ];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                          color: colors[i].withAlpha(30), borderRadius: BorderRadius.circular(6)),
                      child: Center(
                          child: Text('#${i + 1}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colors[i]))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(p.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis)),
                    Text('${p.cantidadVendida} uds',
                        style: TextStyle(fontSize: 12, color: cs.outline)),
                    const SizedBox(width: 8),
                    Text(moneyFmt.format(p.ingresoGenerado),
                        style: TextStyle(fontWeight: FontWeight.bold, color: colors[i], fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: colors[i].withAlpha(25),
                    valueColor: AlwaysStoppedAnimation<Color>(colors[i]),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAlertas(ColorScheme cs) {
    return FutureBuilder<List<Producto>>(
      future: _futAlertas,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final criticos = snap.data ?? [];
        if (criticos.isEmpty) {
          return Container(
            decoration: BoxDecoration(
                color: Colors.green.shade50, borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green.shade600),
                const SizedBox(width: 12),
                const Expanded(
                    child: Text('Todo el inventario está saludable',
                        style: TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
              color: cs.surface, borderRadius: BorderRadius.circular(16)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: criticos.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
            itemBuilder: (ctx, i) {
              final p = criticos[i];
              final agotado = p.cantidad <= 0;
              final color = agotado ? Colors.red.shade600 : Colors.orange.shade600;
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                  child: Icon(agotado ? Icons.remove_shopping_cart : Icons.warning_amber_outlined,
                      color: color, size: 20),
                ),
                title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${p.categoria} · ${p.atributoVisual}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: color.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    agotado ? 'AGOTADO' : '${p.cantidad} uds',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildError(String msg) {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 8),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}
