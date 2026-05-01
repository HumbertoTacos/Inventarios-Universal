import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/turno_caja.dart';
import '../models/movimiento_caja.dart';
import '../services/firebase_service.dart';
import '../services/impresion_service.dart';
import '../widgets/premium_widgets.dart'; // [UI Polish]
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';

class CajaScreen extends StatefulWidget {
  const CajaScreen({super.key});

  @override
  _CajaScreenState createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  TurnoCaja? _turnoActivo;
  bool _isLoading = true;

  final TextEditingController _fondoInicialController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarTurnoActivo();
  }

  Future<void> _cargarTurnoActivo() async {
    setState(() => _isLoading = true);
    try {
      final turno = await _firebaseService.getTurnoActivo();
      setState(() => _turnoActivo = turno);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar caja: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _abrirCaja() async {
    final fondoInicial = double.tryParse(_fondoInicialController.text) ?? 0.0;

    final nuevoTurno = TurnoCaja(
      id: '',
      usuarioId: '',
      fechaApertura: DateTime.now(),
      fondoInicial: fondoInicial,
    );

    setState(() => _isLoading = true);
    try {
      await _firebaseService.abrirTurnoCaja(nuevoTurno);
      await _cargarTurnoActivo();
      _fondoInicialController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Caja abierta exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _mostrarDialogoMovimiento() async {
    if (_turnoActivo == null) return;

    final montoCtrl = TextEditingController();
    final conceptoCtrl = TextEditingController();
    String tipoMovimiento = 'egreso';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Registrar Movimiento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tipoMovimiento,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Movimiento',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ingreso', child: Text('Ingreso (+)')),
                    DropdownMenuItem(value: 'egreso', child: Text('Egreso/Retiro (-)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setStateDialog(() => tipoMovimiento = val);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: montoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Monto (\$)',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: conceptoCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Concepto (ej. Pago de agua)',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final monto = double.tryParse(montoCtrl.text) ?? 0.0;
                  final concepto = conceptoCtrl.text.trim();
                  if (monto <= 0 || concepto.isEmpty) return;

                  Navigator.pop(ctx);
                  setState(() => _isLoading = true);
                  try {
                    final mov = MovimientoCaja(
                      id: '',
                      turnoId: _turnoActivo!.id,
                      tipo: tipoMovimiento,
                      monto: monto,
                      concepto: concepto,
                      fecha: DateTime.now(),
                    );
                    await _firebaseService.registrarMovimientoCaja(mov);
                    await _cargarTurnoActivo();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Movimiento registrado')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      setState(() => _isLoading = false);
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _iniciarArqueoCiego() async {
    if (_turnoActivo == null) return;
    final efectivoCtrl = TextEditingController();

    final resultado = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Arqueo de Caja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa el efectivo físico total contado en la caja.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: efectivoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Efectivo Físico Contado (\$)',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(efectivoCtrl.text);
              if (val != null && val >= 0) {
                Navigator.pop(ctx, val);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Calcular y Cerrar'),
          ),
        ],
      ),
    );

    if (resultado != null) {
      await _cerrarCaja(resultado);
    }
  }

  Future<void> _cerrarCaja(double efectivoContado) async {
    setState(() => _isLoading = true);
    try {
      final turnoAntesDeCerrar = _turnoActivo!;
      await _firebaseService.cerrarTurnoCaja(_turnoActivo!.id, efectivoContado);
      
      final esperado = turnoAntesDeCerrar.totalEsperadoEfectivo;
      final diferencia = efectivoContado - esperado;

      await _cargarTurnoActivo();

      if (mounted) {
        await _mostrarFeedbackArqueo(diferencia, esperado, efectivoContado);
        _preguntarImprimirCorteZ(
          turnoAntesDeCerrar.copyWith(
            efectivoContado: efectivoContado,
            fechaCierre: DateTime.now(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cerrar caja: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _mostrarFeedbackArqueo(double diferencia, double esperado, double contado) async {
    String titulo = 'Cuadre Exacto';
    Color color = Colors.green;
    String mensaje = 'El efectivo contado coincide perfectamente con el sistema.';

    if (diferencia > 0) {
      titulo = 'Sobrante en Caja';
      color = Colors.blue;
      mensaje = 'Hay un sobrante de \$${diferencia.toStringAsFixed(2)}.\nEsperado: \$${esperado.toStringAsFixed(2)}\nContado: \$${contado.toStringAsFixed(2)}';
    } else if (diferencia < 0) {
      titulo = 'Faltante en Caja';
      color = Colors.red;
      mensaje = 'Hay un faltante de \$${diferencia.abs().toStringAsFixed(2)}.\nEsperado: \$${esperado.toStringAsFixed(2)}\nContado: \$${contado.toStringAsFixed(2)}';
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(titulo, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        content: Text(mensaje),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          )
        ],
      ),
    );
  }

  Future<void> _preguntarImprimirCorteZ(TurnoCaja turno) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Caja Cerrada'),
        content: const Text(
          '¿Deseas imprimir el comprobante de Corte Z para administración?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No, gracias'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.print),
            onPressed: () async {
              Navigator.pop(ctx);
              final negocio = await _firebaseService.getDatosNegocio();
              ImpresionService.imprimirCorteZ(turno, negocio);
            },
            label: const Text('Imprimir Ticket'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentRoute: 'caja',
      title: 'Arqueo de Caja',
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ResponsiveLayout(
            mobileBody: _buildContent(isDesktop: false),
            tabletBody: _buildContent(isDesktop: true),
            desktopBody: _buildContent(isDesktop: true),
          ),
    );
  }

  Widget _buildContent({required bool isDesktop}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _turnoActivo == null
              ? _buildAbrirCaja()
              : _buildCerrarCaja(),
        ),
      ),
    );
  }

  Widget _buildAbrirCaja() {
    return SingleChildScrollView(
      child: PremiumEmptyState(
        icon: Icons.lock_outline,
        title: 'La caja está cerrada',
        subtitle: 'Inicia un nuevo turno para registrar ventas en efectivo.',
        action: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _fondoInicialController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto de Fondo Inicial (\$)',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _abrirCaja,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'ABRIR MI TURNO',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCerrarCaja() {
    final turno = _turnoActivo!;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Estado
          PremiumCard(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: 16,
            child: Row(
              children: [
                const Icon(Icons.lock_open_rounded, color: Colors.green),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Turno de Caja Abierto',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
                Text(
                  'Desde: ${DateFormat('HH:mm').format(turno.fechaApertura)}',
                  style: TextStyle(color: Colors.green.shade800, fontSize: 13),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Grid de Métricas Principales
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _MetricCard(
                    title: 'Fondo Inicial',
                    value: turno.fondoInicial,
                    icon: Icons.account_balance_wallet_outlined,
                    color: Colors.blue,
                  ),
                  _MetricCard(
                    title: 'Ventas Efectivo',
                    value: turno.ventasEfectivo,
                    icon: Icons.payments_outlined,
                    color: Colors.green,
                  ),
                  _MetricCard(
                    title: 'Entradas Extra',
                    value: turno.entradasEfectivo,
                    icon: Icons.add_circle_outline,
                    color: Colors.teal,
                  ),
                  _MetricCard(
                    title: 'Egresos/Retiros',
                    value: turno.egresosEfectivo,
                    icon: Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                  _MetricCard(
                    title: 'En Caja (Esperado)',
                    value: turno.totalEsperadoEfectivo,
                    icon: Icons.point_of_sale_outlined,
                    color: cs.primary,
                    isHighlight: true,
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Otros Métodos de Pago
          PremiumCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Otros Métodos de Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                _PaymentRow(label: 'Tarjeta', value: turno.ventasTarjeta, icon: Icons.credit_card),
                _PaymentRow(label: 'Transferencia', value: turno.ventasTransferencia, icon: Icons.account_balance),
                _PaymentRow(label: 'Crédito', value: turno.ventasCredito, icon: Icons.timer_outlined),
              ],
            ),
          ),

          const SizedBox(height: 32),
          
          // Acciones
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _mostrarDialogoMovimiento,
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('MOVIMIENTO MANUAL'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _iniciarArqueoCiego,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('CERRAR CAJA'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: const EdgeInsets.all(20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final double value;
  final IconData icon;
  final Color color;
  final bool isHighlight;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      color: isHighlight ? color.withValues(alpha: 0.1) : null,
      border: isHighlight ? Border.all(color: color, width: 2) : null,
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(
                title,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isHighlight ? color : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;

  const _PaymentRow({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text('\$${value.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
