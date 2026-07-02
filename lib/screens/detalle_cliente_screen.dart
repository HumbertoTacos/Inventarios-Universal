import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente.dart';
import '../models/abono.dart';
import '../models/venta.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../widgets/premium_widgets.dart'; // [UI Polish]


class DetalleClienteScreen extends StatefulWidget {
  final Cliente cliente;

  const DetalleClienteScreen({super.key, required this.cliente});

  @override
  State<DetalleClienteScreen> createState() => _DetalleClienteScreenState();
}

class _DetalleClienteScreenState extends State<DetalleClienteScreen> {
  final FirebaseService _svc = FirebaseService();
  final _moneyFmt = NumberFormat.simpleCurrency(locale: 'es_MX');
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  // Cliente en tiempo real para que los números se actualicen tras un abono
  late Stream<List<Cliente>> _clienteStream;

  @override
  void initState() {
    super.initState();
    _clienteStream = _svc.getClientesStream();
  }

  Cliente _clienteActual(List<Cliente> todos) => todos.firstWhere(
    (c) => c.id == widget.cliente.id,
    orElse: () => widget.cliente,
  );

  void _mostrarModalAbono(Cliente cliente) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ModalAbono(
        cliente: cliente,
        onRegistrar: (abono) async => await _svc.registrarAbono(abono),
      ),
    );
  }

  void _mostrarModalDeudaManual(Cliente cliente) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ModalDeudaManual(
        cliente: cliente,
        onRegistrar: (monto, notas) async => await _svc.agregarDeudaManual(cliente.id, monto, notas),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Cliente>>(
      stream: _clienteStream,
      builder: (ctx, snap) {
        final cliente = snap.hasData
            ? _clienteActual(snap.data!)
            : widget.cliente;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              cliente.nombre,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            elevation: 0,
            actions: [
              if (AuthService().currentUserData?.rol == AuthService.rolDueno)
                IconButton(
                  icon: const Icon(Icons.add_card_outlined),
                  tooltip: 'Agregar Deuda Manual',
                  onPressed: () => _mostrarModalDeudaManual(cliente),
                ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar cliente',
                onPressed: () => _mostrarFormularioEditar(cliente),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header con métricas ─────────────────────────────────────
                  _buildHeader(cliente, cs),
                  // ── Historial de abonos ─────────────────────────────────────
                  Expanded(child: _buildHistorialAbonos(cs)),
                ],
              ),
            ),
          ),
          floatingActionButton: cliente.tieneDeuda
              ? FloatingActionButton.extended(
                  onPressed: () => _mostrarModalAbono(cliente),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Registrar Abono'),
                  backgroundColor: cs.primary,
                )
              : null,
        );
      },
    );
  }

  Widget _buildHeader(Cliente c, ColorScheme cs) {
    final porcentajeUsado = c.limiteCredito > 0
        ? c.saldoDeudor / c.limiteCredito
        : 0.0;
    final colorDeuda = porcentajeUsado >= 0.9
        ? Colors.red.shade600
        : porcentajeUsado >= 0.6
        ? Colors.orange.shade600
        : cs.primary;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info básica
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: cs.primary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: cs.primary,
                  child: Text(
                    c.nombre[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nombre,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (c.telefono.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: cs.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              c.telefono,
                              style: TextStyle(color: cs.outline),
                            ),
                          ],
                        ),
                      ),
                    if (c.email != null && c.email!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: cs.outline,
                            ),
                            const SizedBox(width: 4),
                            Text(c.email!, style: TextStyle(color: cs.outline)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Métricas de crédito
          if (c.creditoBloqueado)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.block, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    'Este cliente no tiene crédito asignado.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deuda actual',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _moneyFmt.format(c.saldoDeudor),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: colorDeuda,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (c.creditoDisponible > 0
                                    ? Colors.green
                                    : Colors.red)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Disponible',
                            style: TextStyle(
                              fontSize: 11,
                              color: cs.outline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _moneyFmt.format(c.creditoDisponible),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: c.creditoDisponible > 0
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: porcentajeUsado.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(colorDeuda),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$0',
                      style: TextStyle(fontSize: 10, color: cs.outline),
                    ),
                    Text(
                      'Límite: ${c.limiteCreditoTexto}',
                      style: TextStyle(fontSize: 10, color: cs.outline),
                    ),
                  ],
                ),
              ],
            ),
          if (c.notas != null && c.notas!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withAlpha(80),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 16,
                    color: cs.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.notas!,
                      style: TextStyle(color: cs.outline, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistorialAbonos(ColorScheme cs) {
    return StreamBuilder<List<Abono>>(
      stream: _svc.getAbonosPorCliente(widget.cliente.id),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final abonos = snap.data ?? [];
        if (abonos.isEmpty) {
          return const PremiumEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Sin abonos registrados',
            subtitle: 'Los pagos realizados aparecerán aquí',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Historial de Abonos',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: abonos.length,
                itemBuilder: (_, i) => PremiumCard(
                  child: _buildAbonoTile(abonos[i], cs),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAbonoTile(Abono a, ColorScheme cs) {
    final metodoLabel = switch (a.metodoPago) {
      MetodoPago.efectivo => 'Efectivo',
      MetodoPago.tarjeta => 'Tarjeta',
      MetodoPago.transferencia => 'Transferencia',
      MetodoPago.credito => 'Crédito',
    };
    final metodoColor = switch (a.metodoPago) {
      MetodoPago.efectivo => Colors.green.shade700,
      MetodoPago.tarjeta => Colors.blue.shade700,
      MetodoPago.transferencia => Colors.purple.shade700,
      MetodoPago.credito => Colors.orange.shade700,
    };

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.arrow_downward_rounded,
          color: Colors.green.shade700,
          size: 20,
        ),
      ),
      title: Text(
        _moneyFmt.format(a.monto),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.green.shade700,
          fontSize: 16,
        ),
      ),
      subtitle: Text(_dateFmt.format(a.fecha)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: metodoColor.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          metodoLabel,
          style: TextStyle(
            fontSize: 12,
            color: metodoColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _mostrarFormularioEditar(Cliente c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Editar Cliente',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Para editar el cliente, vuelve a la lista y usa la opción de edición.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modal de Abono ────────────────────────────────────────────────────────────

class _ModalAbono extends StatefulWidget {
  final Cliente cliente;
  final Future<void> Function(Abono) onRegistrar;

  const _ModalAbono({required this.cliente, required this.onRegistrar});

  @override
  State<_ModalAbono> createState() => _ModalAbonoState();
}

class _ModalAbonoState extends State<_ModalAbono> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  MetodoPago _metodoPago = MetodoPago.efectivo;
  DateTime _fechaAbono = DateTime.now();
  bool _guardando = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final abono = Abono(
        id: '',
        clienteId: widget.cliente.id,
        monto: double.parse(_montoCtrl.text.trim()),
        fecha: _fechaAbono,
        metodoPago: _metodoPago,
        cajeroId: AuthService().currentUser?.uid ?? 'unknown',
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      );
      await widget.onRegistrar(abono);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Abono registrado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moneyFmt = NumberFormat.simpleCurrency(locale: 'es_MX');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Registrar Abono',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Debe: ${moneyFmt.format(widget.cliente.saldoDeudor)}',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Monto del Abono (\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Ingresa un monto válido > 0';
                if (n > widget.cliente.saldoDeudor) {
                  return 'Supera la deuda (${moneyFmt.format(widget.cliente.saldoDeudor)})';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            // Selector de método de pago
            Text(
              'Método de pago',
              style: TextStyle(color: cs.outline, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                MetodoPago.efectivo,
                MetodoPago.tarjeta,
                MetodoPago.transferencia,
              ].map((m) {
                final isSelected = _metodoPago == m;
                final label = switch (m) {
                  MetodoPago.efectivo => 'Efectivo',
                  MetodoPago.tarjeta => 'Tarjeta',
                  MetodoPago.transferencia => 'Transf.',
                  _ => m.name,
                };
                final icon = switch (m) {
                  MetodoPago.efectivo => Icons.money,
                  MetodoPago.tarjeta => Icons.credit_card,
                  MetodoPago.transferencia => Icons.account_balance,
                  _ => Icons.payment,
                };
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: m != MetodoPago.transferencia ? 8.0 : 0.0,
                    ),
                    child: InkWell(
                      onTap: () => setState(() => _metodoPago = m),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? cs.primaryContainer : cs.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? cs.primary : cs.outlineVariant,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 20,
                              color: isSelected ? cs.primary : cs.onSurfaceVariant,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Fecha y Hora del Abono', style: TextStyle(fontSize: 14)),
              subtitle: Text(DateFormat('dd/MM/yyyy hh:mm a').format(_fechaAbono)),
              trailing: const Icon(Icons.edit, size: 20),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _fechaAbono,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null && mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_fechaAbono),
                  );
                  if (time != null && mounted) {
                    setState(() {
                      _fechaAbono = DateTime(
                        date.year, date.month, date.day, time.hour, time.minute
                      );
                    });
                  }
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notasCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _guardando ? null : _registrar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_guardando ? 'Registrando...' : 'Confirmar Abono'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modal de Deuda Manual ───────────────────────────────────────────────────

class _ModalDeudaManual extends StatefulWidget {
  final Cliente cliente;
  final Future<void> Function(double, String) onRegistrar;

  const _ModalDeudaManual({required this.cliente, required this.onRegistrar});

  @override
  State<_ModalDeudaManual> createState() => _ModalDeudaManualState();
}

class _ModalDeudaManualState extends State<_ModalDeudaManual> {
  final _formKey = GlobalKey<FormState>();
  final _montoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final monto = double.parse(_montoCtrl.text.trim());
      final notas = _notasCtrl.text.trim().isEmpty ? 'Deuda manual inicial' : _notasCtrl.text.trim();
      await widget.onRegistrar(monto, notas);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deuda registrada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Agregar Deuda Manual',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega un saldo inicial o deuda al cliente sin realizar una venta. Solo disponible para el dueño.',
              style: TextStyle(color: cs.outline, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Monto de la Deuda (\$)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Ingresa un monto válido > 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notasCtrl,
              decoration: const InputDecoration(
                labelText: 'Concepto / Notas',
                border: OutlineInputBorder(),
                hintText: 'Ej. Saldo inicial',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'El concepto es obligatorio';
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _guardando ? null : _registrar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_guardando ? 'Guardando...' : 'Confirmar Deuda'),
            ),
          ],
        ),
      ),
    );
  }
}
