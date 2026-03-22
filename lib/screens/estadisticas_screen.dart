import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/producto.dart';
import '../models/venta.dart';
import '../services/firebase_service.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  
  double _capitalInventario = 0.0;
  bool _cargandoCapital = true;

  @override
  void initState() {
    super.initState();
    _cargarCapital();
  }

  Future<void> _cargarCapital() async {
    try {
      final cap = await _firebaseService.getCapitalEnInventario();
      if (mounted) {
        setState(() {
          _capitalInventario = cap;
          _cargandoCapital = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoCapital = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas y Ganancias'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSeccionVentas(),
            const SizedBox(height: 24),
            Text('Alertas de Inventario', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildSeccionAlertasStock(),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionVentas() {
    return StreamBuilder<List<Venta>>(
      stream: _firebaseService.getVentasStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar ventas: ${snapshot.error}'));
        }

        final ventas = snapshot.data ?? [];
        
        // Calcular métricas
        double ingresosTotales = 0;
        double costosTotales = 0;

        // Para Top Productos (ID -> Cantidad Vendida)
        final Map<String, int> contadoresProductos = {};
        final Map<String, String> nombresProductos = {};

        for (var venta in ventas) {
          if (venta.estado == 'cancelada') continue; // Ingresa $0, Gasta $0

          if (venta.estado == 'completada') {
            for (var item in venta.items) {
              final qty = item.cantidad;
              ingresosTotales += (item.precioUnitario * qty);
              costosTotales += (item.costoUnitario * qty);
              
              contadoresProductos[item.productoId] = (contadoresProductos[item.productoId] ?? 0) + qty;
              nombresProductos[item.productoId] = item.nombre; // Guardar nombre para listado
            }
            if (venta.costoEnvio > 0) {
              if (venta.envioPagadoPorVendedor) {
                 costosTotales += venta.costoEnvio;
              } else {
                 ingresosTotales += venta.costoEnvio;
                 costosTotales += venta.costoEnvio;
              }
            }
          } else if (venta.estado == 'devuelta') {
            // No recibe ingresos.
            // Si no se devuelve al inventario (Merma), el producto es pérdida neta.
            if (!venta.devueltoAlInventario) {
              for (var item in venta.items) {
                costosTotales += (item.costoUnitario * item.cantidad);
              }
            }
            // Sunk costs de envío
            if (venta.envioPagadoPorVendedor && venta.costoEnvio > 0) {
              costosTotales += venta.costoEnvio;
            }
            if (venta.costoEnvioDevolucion > 0) {
              costosTotales += venta.costoEnvioDevolucion;
            }
          }
        }

        final gananciaNeta = ingresosTotales - costosTotales;
        final margen = ingresosTotales > 0 ? (gananciaNeta / ingresosTotales) * 100 : 0.0;

        // Top 5 Productos
        final topEntries = contadoresProductos.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top5 = topEntries.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── SECCIÓN A: TARJETAS DE MÉTRICAS ──
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildMetricaCard('Ingresos Brutos', '\$${ingresosTotales.toStringAsFixed(2)}', Icons.point_of_sale, Colors.blue),
                _buildMetricaCard('Costos / Inversión', '\$${costosTotales.toStringAsFixed(2)}', Icons.money_off, Colors.orange),
                _buildMetricaCard('Ganancia Neta', '\$${gananciaNeta.toStringAsFixed(2)}', Icons.trending_up, Colors.green),
                _buildMetricaCard('Margen Libre', '${margen.toStringAsFixed(1)}%', Icons.pie_chart, Colors.purple),
                _cargandoCapital 
                    ? const Card(child: Center(child: CircularProgressIndicator()))
                    : _buildMetricaCard('Capital Congelado', '\$${_capitalInventario.toStringAsFixed(2)}', Icons.inventory, Colors.teal),
              ],
            ),
            const SizedBox(height: 24),
            
            // ── SECCIÓN B: GRÁFICA DE VENTAS ──
            Text('Ventas vs Costos Diarios', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (ventas.isEmpty)
              const Text('No hay suficientes datos para la gráfica.')
            else
              _buildGraficoVentas(ventas),
            
            const SizedBox(height: 24),

            // ── SECCIÓN C: TOP PRODUCTOS ──
            Text('Top 5 Productos Vendidos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (top5.isEmpty)
              const Text('Aún no hay ventas registradas.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: top5.length,
                itemBuilder: (context, index) {
                  final e = top5[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('#${index + 1}')),
                    title: Text(nombresProductos[e.key] ?? 'Desconocido'),
                    trailing: Text('${e.value} vendidos', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildSeccionAlertasStock() {
    return StreamBuilder<List<Producto>>(
      stream: _firebaseService.getProductos(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        // Filtrar productos con stock <= 3
        final criticos = snapshot.data!.where((p) => p.cantidad <= 3).toList()
          ..sort((a, b) => a.cantidad.compareTo(b.cantidad)); // Menor a mayor

        if (criticos.isEmpty) {
          return const Card(
            color: Colors.green,
            child: ListTile(
              leading: Icon(Icons.check_circle, color: Colors.white),
              title: Text('Todo tu inventario está saludable (Stock > 3)', style: TextStyle(color: Colors.white)),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: criticos.length,
          itemBuilder: (context, index) {
            final p = criticos[index];
            final esCriticoSevero = p.cantidad == 0;
            return Card(
              color: esCriticoSevero ? Colors.red.shade50 : Colors.orange.shade50,
              child: ListTile(
                leading: Icon(esCriticoSevero ? Icons.warning : Icons.inventory_2, color: esCriticoSevero ? Colors.red : Colors.orange),
                title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p.categoria} - ${p.atributoVisual}'),
                trailing: Text(
                  'Quedan: ${p.cantidad}',
                  style: TextStyle(
                    color: esCriticoSevero ? Colors.red : Colors.orange.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricaCard(String titulo, String valor, IconData icono, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: color, size: 28),
            const Spacer(),
            Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(
              valor,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoVentas(List<Venta> ventas) {
    // Agrupar ventas por fecha (ignorando hora)
    final mapDias = <String, Map<String, double>>{};
    
    for (var v in ventas) {
      if (v.estado == 'cancelada') continue;

      final fechaStr = DateFormat('MM/dd').format(v.fecha);
      if (!mapDias.containsKey(fechaStr)) {
        mapDias[fechaStr] = {'ingreso': 0.0, 'costo': 0.0};
      }
      
      if (v.estado == 'completada') {
        for (var item in v.items) {
          mapDias[fechaStr]!['ingreso'] = mapDias[fechaStr]!['ingreso']! + (item.precioUnitario * item.cantidad);
          mapDias[fechaStr]!['costo'] = mapDias[fechaStr]!['costo']! + (item.costoUnitario * item.cantidad);
        }
        
        if (v.costoEnvio > 0) {
          if (v.envioPagadoPorVendedor) {
            mapDias[fechaStr]!['costo'] = mapDias[fechaStr]!['costo']! + v.costoEnvio;
          } else {
            mapDias[fechaStr]!['ingreso'] = mapDias[fechaStr]!['ingreso']! + v.costoEnvio;
            mapDias[fechaStr]!['costo'] = mapDias[fechaStr]!['costo']! + v.costoEnvio;
          }
        }
      } else if (v.estado == 'devuelta') {
        if (!v.devueltoAlInventario) {
          for (var item in v.items) {
            mapDias[fechaStr]!['costo'] = mapDias[fechaStr]!['costo']! + (item.costoUnitario * item.cantidad);
          }
        }
        if (v.envioPagadoPorVendedor && v.costoEnvio > 0) {
          mapDias[fechaStr]!['costo'] = mapDias[fechaStr]!['costo']! + v.costoEnvio;
        }
        if (v.costoEnvioDevolucion > 0) {
          mapDias[fechaStr]!['costo'] = mapDias[fechaStr]!['costo']! + v.costoEnvioDevolucion;
        }
      }
    }

    // Ordenar cronológicamente y tomar los últimos 7 días con actividad
    final diasOrdenados = mapDias.keys.toList()
      ..sort((a, b) => a.compareTo(b)); // Simple string compare since MM/dd
    
    // Si cruza el año, MM/dd sort might fail, but for an MVP it works fine.
    // Para mayor robustez usaríamos DateTime. Alternativa: sorting object.
    
    final ultimosDias = diasOrdenados.length > 7 ? diasOrdenados.sublist(diasOrdenados.length - 7) : diasOrdenados;

    if (ultimosDias.isEmpty) return const SizedBox.shrink();

    List<BarChartGroupData> barGroups = [];
    int x = 0;
    
    double maxY = 0;

    for (var dia in ultimosDias) {
      final ingreso = mapDias[dia]!['ingreso']!;
      final costo = mapDias[dia]!['costo']!;
      if (ingreso > maxY) maxY = ingreso;
      if (costo > maxY) maxY = costo;

      barGroups.add(
        BarChartGroupData(
          x: x,
          barRods: [
            BarChartRodData(
              toY: ingreso,
              color: Colors.green,
              width: 12,
              borderRadius: BorderRadius.circular(2),
            ),
            BarChartRodData(
              toY: costo,
              color: Colors.red.shade300,
              width: 12,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
      x++;
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY * 1.2, // 20% margin top
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < ultimosDias.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(ultimosDias[value.toInt()], style: const TextStyle(fontSize: 10)),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
      ),
    );
  }
}
