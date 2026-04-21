import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cliente.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'detalle_cliente_screen.dart';

class ClientesScreen extends StatefulWidget {
  /// Si true, la pantalla actúa como selector y retorna un [Cliente] al cerrar.
  final bool modoSeleccion;

  const ClientesScreen({super.key, this.modoSeleccion = false});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final FirebaseService _svc = FirebaseService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Cliente> _resultadosBusqueda = [];
  bool _buscando = false;
  bool _enModoBusqueda = false;

  String get _rol => AuthService().currentUserData?.rol ?? 'empleado';
  bool get _esDueno => _rol == 'dueño';

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
            await _svc.agregarCliente(c);
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.modoSeleccion ? 'Seleccionar Cliente' : 'Clientes',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: _enModoBusqueda
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioAgregar(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo Cliente'),
      ),
    );
  }

  Widget _buildListaClientes(List<Cliente> clientes, {bool loading = false}) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (clientes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_enModoBusqueda ? 'Sin resultados' : 'Sin clientes registrados',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          ],
        ),
      );
    }

    // Clientes con deuda al inicio
    final ordenados = [...clientes]
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
    final moneyFmt = NumberFormat.simpleCurrency(locale: 'es_MX');

    final tieneDeuda = c.tieneDeuda;
    final bloqueado = c.creditoBloqueado;

    Color cardColor = cs.surface;
    Color deudaColor = Colors.green.shade700;
    IconData trailingIcon = Icons.check_circle_outline;

    if (bloqueado) {
      deudaColor = Colors.grey.shade600;
      trailingIcon = Icons.block;
    } else if (tieneDeuda) {
      final pct = c.saldoDeudor / c.limiteCredito;
      if (pct >= 0.9) {
        cardColor = Colors.red.shade50;
        deudaColor = Colors.red.shade700;
        trailingIcon = Icons.warning_amber_rounded;
      } else if (pct >= 0.6) {
        cardColor = Colors.orange.shade50;
        deudaColor = Colors.orange.shade700;
        trailingIcon = Icons.warning_outlined;
      } else {
        cardColor = Colors.amber.shade50;
        deudaColor = Colors.amber.shade800;
        trailingIcon = Icons.info_outline;
      }
    }

    return Card(
      elevation: tieneDeuda ? 2 : 1,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: tieneDeuda
            ? BorderSide(color: deudaColor.withAlpha(80), width: 1)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: () => _abrirDetalleOSeleccionar(c),
        leading: CircleAvatar(
          backgroundColor: tieneDeuda ? deudaColor.withAlpha(30) : cs.secondaryContainer,
          child: Text(c.nombre[0].toUpperCase(),
              style: TextStyle(
                  color: tieneDeuda ? deudaColor : cs.onSecondaryContainer,
                  fontWeight: FontWeight.bold)),
        ),
        title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(c.telefono.isEmpty ? 'Sin teléfono' : c.telefono),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (bloqueado)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('Sin crédito',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              )
            else if (tieneDeuda) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(trailingIcon, size: 14, color: deudaColor),
                  const SizedBox(width: 4),
                  Text('Debe', style: TextStyle(fontSize: 11, color: deudaColor)),
                ],
              ),
              Text(
                moneyFmt.format(c.saldoDeudor),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: deudaColor),
              ),
            ] else
              Icon(trailingIcon, color: deudaColor, size: 20),
          ],
        ),
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
                helperText: '0 = sin crédito. Usa un valor alto para crédito ilimitado.',
                border: OutlineInputBorder(),
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
