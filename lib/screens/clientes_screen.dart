import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/cliente.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'detalle_cliente_screen.dart';
import '../widgets/responsive_scaffold.dart';
import '../widgets/premium_widgets.dart'; // [UI Polish]
import '../utils/responsive_layout.dart';

class ClientesScreen extends StatefulWidget {
  /// Si true, la pantalla actúa como selector y retorna un [Cliente] al cerrar.
  final bool modoSeleccion;

  const ClientesScreen({super.key, this.modoSeleccion = false});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

enum FiltroCliente {
  todos,
  conDeuda,
  sinDeuda,
  abonoMenos7Dias,  // <= 7 días
  abono7A15Dias,    // 8 a 15 días
  abono15A30Dias,   // 16 a 30 días
  abonoMas30Dias,   // > 30 días
  creditoBloqueado,
}


class _ClientesScreenState extends State<ClientesScreen> {
  final FirebaseService _svc = FirebaseService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Cliente> _resultadosBusqueda = [];
  bool _buscando = false;
  bool _enModoBusqueda = false;
  FiltroCliente _filtroActivo = FiltroCliente.todos;

  // Rol y permisos del usuario activo
  String get _rol => AuthService().currentUserData?.rol ?? AuthService.rolEmpleado;
  bool get _esDueno => _rol == AuthService.rolDueno;

  void _limpiarBusqueda() {
    _searchCtrl.clear();
    setState(() {
      _enModoBusqueda = false;
      _resultadosBusqueda = [];
    });
  }

  Future<void> _buscar(String query) async {
    if (query.trim().isEmpty) { _limpiarBusqueda(); return; }
    setState(() { _buscando = true; _enModoBusqueda = true; });
    try {
      final res = await _svc.buscarClientes(query.trim());
      if (mounted) setState(() { _resultadosBusqueda = res; _buscando = false; });
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _abrirDetalleOSeleccionar(Cliente cliente) {
    if (widget.modoSeleccion) {
      Navigator.pop(context, cliente);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetalleClienteScreen(cliente: cliente)),
    );
  }

  Future<void> _llamarCliente(String telefono) async {
    if (telefono.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este cliente no tiene teléfono registrado')),
      );
      return;
    }
    final cleanPhone = telefono.replaceAll(RegExp(r'\D'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo iniciar la llamada')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo iniciar la llamada')),
        );
      }
    }
  }

  Future<void> _abrirWhatsAppCliente(String telefono, String nombre) async {
    if (telefono.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este cliente no tiene teléfono registrado')),
      );
      return;
    }
    String cleanPhone = telefono.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '52$cleanPhone';
    }
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    try {
      final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  void _mostrarFormularioAgregar([Cliente? editar]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FormularioCliente(
        clienteInicial: editar,
        onGuardar: (c) async {
          if (editar == null) {
            final id = await _svc.agregarCliente(c);
            if (widget.modoSeleccion && mounted) {
              final nuevo = Cliente(
                id: id,
                nombre: c.nombre,
                telefono: c.telefono,
                email: c.email,
                notas: c.notas,
                saldoDeudor: c.saldoDeudor,
                limiteCredito: c.limiteCredito,
                fechaRegistro: DateTime.now(),
              );
              Navigator.pop(context); // Cierra modal
              Navigator.pop(context, nuevo); // Devuelve cliente a ventas
            }
          } else {
            await _svc.actualizarCliente(c);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ResponsiveScaffold(
      currentRoute: 'clientes',
      title: widget.modoSeleccion ? 'Seleccionar Cliente' : 'Clientes',
      hideDrawer: widget.modoSeleccion,
      appBarBottom: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _buscar,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _enModoBusqueda
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: _limpiarBusqueda)
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ResponsiveLayout(
        mobileBody: _buildBody(isDesktop: false),
        tabletBody: _buildBody(isDesktop: true),
        desktopBody: _buildBody(isDesktop: true),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioAgregar(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo Cliente'),
      ),
    );
  }

  Widget _buildBody({bool isDesktop = false}) {
    return Column(
      children: [
        // Dashboard de Clientes
        if (!widget.modoSeleccion) _buildSummaryBoard(),
        
        // Chips de Filtro
        if (!widget.modoSeleccion) _buildFilterChips(),

        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 800),
              child: _enModoBusqueda
                  ? _buildListaClientes(_resultadosBusqueda, loading: _buscando)
                  : StreamBuilder<List<Cliente>>(
                      stream: _svc.getClientesStream(),
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final clientes = snap.data ?? [];
                        return _buildListaClientes(clientes);
                      },
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBoard() {
    return StreamBuilder<List<Cliente>>(
      stream: _svc.getClientesStream(),
      builder: (context, snap) {
        final clientes = snap.data ?? [];
        final deudores = clientes.where((c) => c.tieneDeuda).length;
        final totalDeuda = clientes.fold(0.0, (sum, c) => sum + c.saldoDeudor);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              _summaryCard('Total Clientes', '${clientes.length}', Icons.people, Colors.blue),
              _summaryCard('Deudores', '$deudores', Icons.warning_amber_rounded, Colors.orange),
              _summaryCard('Total por Cobrar', '\$${totalDeuda.toStringAsFixed(0)}', Icons.monetization_on, Colors.green),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return PremiumCard(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip('Todos', FiltroCliente.todos),
          const SizedBox(width: 8),
          _buildChip('Con Deuda', FiltroCliente.conDeuda),
          const SizedBox(width: 8),
          _buildChip('Sin Deuda', FiltroCliente.sinDeuda),
          const SizedBox(width: 8),
          _buildChip('Abono < 7 días', FiltroCliente.abonoMenos7Dias),
          const SizedBox(width: 8),
          _buildChip('Abono 7-15 días', FiltroCliente.abono7A15Dias),
          const SizedBox(width: 8),
          _buildChip('Abono 15-30 días', FiltroCliente.abono15A30Dias),
          const SizedBox(width: 8),
          _buildChip('Abono > 30 días', FiltroCliente.abonoMas30Dias),
          const SizedBox(width: 8),
          _buildChip('Crédito Bloqueado', FiltroCliente.creditoBloqueado),
        ],
      ),
    );
  }

  Widget _buildChip(String label, FiltroCliente filtro) {
    return FilterChip(
      label: Text(label),
      selected: _filtroActivo == filtro,
      onSelected: (_) => setState(() => _filtroActivo = filtro),
    );
  }

  Widget _buildListaClientes(List<Cliente> clientes, {bool loading = false}) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (clientes.isEmpty) {
      return PremiumEmptyState(
        icon: Icons.people_outline,
        title: _enModoBusqueda ? 'Sin resultados' : 'Sin clientes registrados',
        subtitle: _enModoBusqueda ? 'Intenta buscar con otro término' : 'Agrega tu primer cliente para gestionar sus créditos.',
      );
    }

    // Aplicar Filtro de Chips
    final ahora = DateTime.now();
    final filtrados = clientes.where((c) {
      switch (_filtroActivo) {
        case FiltroCliente.todos:
          return true;
        case FiltroCliente.conDeuda:
          return c.tieneDeuda;
        case FiltroCliente.sinDeuda:
          return !c.tieneDeuda;
        case FiltroCliente.abonoMenos7Dias:
          if (c.ultimoAbonoFecha == null) return false;
          return ahora.difference(c.ultimoAbonoFecha!).inDays <= 7;
        case FiltroCliente.abono7A15Dias:
          if (c.ultimoAbonoFecha == null) return false;
          final diff = ahora.difference(c.ultimoAbonoFecha!).inDays;
          return diff > 7 && diff <= 15;
        case FiltroCliente.abono15A30Dias:
          if (c.ultimoAbonoFecha == null) return false;
          final diff = ahora.difference(c.ultimoAbonoFecha!).inDays;
          return diff > 15 && diff <= 30;
        case FiltroCliente.abonoMas30Dias:
          if (c.ultimoAbonoFecha == null) return false;
          return ahora.difference(c.ultimoAbonoFecha!).inDays > 30;
        case FiltroCliente.creditoBloqueado:
          return c.creditoBloqueado;
      }
    }).toList();

    // Clientes con deuda al inicio
    final ordenados = [...filtrados]
      ..sort((a, b) {
        if (a.tieneDeuda && !b.tieneDeuda) return -1;
        if (!a.tieneDeuda && b.tieneDeuda) return 1;
        return a.nombre.compareTo(b.nombre);
      });

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: ordenados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) => _buildClienteCard(ordenados[i]),
    );
  }

  Widget _buildClienteCard(Cliente c) {
    final cs = Theme.of(context).colorScheme;
    final tieneDeuda = c.tieneDeuda;
    final bool bajoLimite = tieneDeuda && (c.saldoDeudor >= c.limiteCredito * 0.8);

    return PremiumCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      onTap: () => _abrirDetalleOSeleccionar(c),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar con inicial y color dinámico
            CircleAvatar(
              radius: 24,
              backgroundColor: tieneDeuda ? (bajoLimite ? Colors.red.shade100 : Colors.orange.shade100) : cs.primaryContainer,
              child: Text(
                c.nombre[0].toUpperCase(),
                style: TextStyle(
                  color: tieneDeuda ? (bajoLimite ? Colors.red : Colors.orange.shade900) : cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  if (c.ultimoAbonoFecha != null && c.ultimoAbonoMonto != null)
                    Row(
                      children: [
                        Icon(Icons.payment, size: 12, color: cs.outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '\$${c.ultimoAbonoMonto!.toStringAsFixed(2)} el ${DateFormat('dd/MM/yy').format(c.ultimoAbonoFecha!)}',
                            style: TextStyle(color: cs.outline, fontSize: 12),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 12, color: cs.outline),
                        const SizedBox(width: 4),
                        Text('Sin abonos recientes', style: TextStyle(color: cs.outline, fontSize: 12)),
                      ],
                    ),
                  if (tieneDeuda) ...[
                    const SizedBox(height: 8),
                    _deudaBadge(c.saldoDeudor, bajoLimite),
                  ],
                ],
              ),
            ),
            // Acciones Rápidas (Solo si no es modo selección)
            if (!widget.modoSeleccion)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionIcon(Icons.message, Colors.green, () => _abrirWhatsAppCliente(c.telefono, c.nombre)),
                  const SizedBox(width: 8),
                  _actionIcon(Icons.call, Colors.blue, () => _llamarCliente(c.telefono)),
                ],
              )
            else
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _deudaBadge(double deuda, bool critico) {
    final color = critico ? Colors.red : Colors.orange.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_balance_wallet, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            'Debe: \$${deuda.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

// ── Formulario de Alta/Edición de Cliente ────────────────────────────────────

class _FormularioCliente extends StatefulWidget {
  final Cliente? clienteInicial;
  final Future<void> Function(Cliente) onGuardar;

  const _FormularioCliente({this.clienteInicial, required this.onGuardar});

  @override
  State<_FormularioCliente> createState() => _FormularioClienteState();
}

class _FormularioClienteState extends State<_FormularioCliente> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _limiteCreditoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final c = widget.clienteInicial;
    if (c != null) {
      _nombreCtrl.text = c.nombre;
      _telefonoCtrl.text = c.telefono;
      _emailCtrl.text = c.email ?? '';
      _limiteCreditoCtrl.text = c.limiteCredito.toStringAsFixed(2);
      _notasCtrl.text = c.notas ?? '';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _limiteCreditoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final c = widget.clienteInicial;
      final nuevo = Cliente(
        id: c?.id ?? '',
        nombre: _nombreCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
        limiteCredito: double.tryParse(_limiteCreditoCtrl.text) ?? 0.0,
        saldoDeudor: c?.saldoDeudor ?? 0.0,
        fechaRegistro: c?.fechaRegistro ?? DateTime.now(),
      );
      await widget.onGuardar(nuevo);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.clienteInicial != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(esEdicion ? 'Editar Cliente' : 'Nuevo Cliente',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nombre completo *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Teléfono', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _limiteCreditoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Límite de Crédito (\$)',
                  helperText: '0 = sin crédito. Usa ≥ 100,000 para crédito "Ilimitado".',
                  border: const OutlineInputBorder(),
                ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0) return 'Ingresa un número válido ≥ 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notasCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Notas internas', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(esEdicion ? 'Guardar Cambios' : 'Registrar Cliente'),
            ),
          ],
        ),
      ),
    );
  }
}
