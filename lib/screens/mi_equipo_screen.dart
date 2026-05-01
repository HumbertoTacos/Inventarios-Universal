import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../widgets/premium_widgets.dart'; // [UI Polish]
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';


class MiEquipoScreen extends StatefulWidget {
  const MiEquipoScreen({super.key});

  @override
  State<MiEquipoScreen> createState() => _MiEquipoScreenState();
}

class _MiEquipoScreenState extends State<MiEquipoScreen> {
  String _codigoActual = '';
  bool _isLoadingCodigo = true;

  @override
  void initState() {
    super.initState();
    _cargarCodigo();
  }

  Future<void> _cargarCodigo() async {
    setState(() => _isLoadingCodigo = true);
    try {
      final code = await AuthService().obtenerCodigoInvitacionActual();
      if (mounted) setState(() => _codigoActual = code);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingCodigo = false);
    }
  }

  Future<void> _regenerarCodigo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Generar nuevo código?'),
        content: const Text('Esto invalidará el código actual. Quien intente usar el viejo código ya no podrá unirse.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, generar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _isLoadingCodigo = true);
    try {
      final code = await AuthService().regenerarCodigoInvitacion();
      if (mounted) setState(() => _codigoActual = code);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingCodigo = false);
    }
  }

  Future<void> _despedirEmpleado(String uid, String nombreEmpleado) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Dar de baja?'),
        content: Text('¿Seguro que deseas revocar el acceso a $nombreEmpleado?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, despedir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await AuthService().despedirEmpleado(uid);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empleado dado de baja')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _abrirPanelPermisos(String uid, String nombre, String email, Map<String, dynamic> data) {
    final permisosMap = data['permisos'] as Map<String, dynamic>?;
    final permisos = permisosMap != null
        ? PermisosEmpleado.fromMap(permisosMap)
        : const PermisosEmpleado();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PanelPermisosEmpleado(
        uid: uid,
        nombre: nombre,
        email: email,
        permisosIniciales: permisos,
        onDespedir: () => _despedirEmpleado(uid, nombre),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService().currentUserData?.rol != AuthService.rolDueno) {
      return const Scaffold(body: Center(child: Text('Acceso Denegado. Solo el dueño puede ver esta pantalla.')));
    }

    final cs = Theme.of(context).colorScheme;
    final currentNegocioId = AuthService().currentNegocioId;

    return ResponsiveScaffold(
      currentRoute: 'equipo',
      title: 'Mi Equipo',
      body: ResponsiveLayout(
        mobileBody: _buildBody(cs, currentNegocioId, isDesktop: false),
        tabletBody: _buildBody(cs, currentNegocioId, isDesktop: true),
        desktopBody: _buildBody(cs, currentNegocioId, isDesktop: true),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, String? currentNegocioId, {bool isDesktop = false}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 800),
        child: Column(
          children: [
            // ── Código de Invitación ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primaryContainer, cs.primary.withAlpha(20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.primary.withAlpha(50)),
                  boxShadow: [
                    BoxShadow(color: cs.primary.withAlpha(15), blurRadius: 24, offset: const Offset(0, 8)),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                width: double.infinity,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.badge_outlined, color: cs.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Text('Código para emplear',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
                      ],
                    ),
                    const SizedBox(height: 16),
              _isLoadingCodigo
                  ? const CircularProgressIndicator()
                  : SelectableText(
                      _codigoActual,
                      style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 10,
                          color: cs.primary),
                    ),
              const SizedBox(height: 4),
                      Text('Comparte este código con tus empleados para que se puedan unir temporalmente.',
                          style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer.withAlpha(180)),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Regenerar Código'),
                        onPressed: _isLoadingCodigo ? null : _regenerarCodigo,
                        style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            // ── Lista de Empleados ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(children: [
            Icon(Icons.people_outlined, color: cs.outline, size: 18),
            const SizedBox(width: 8),
            Text('Empleados activos',
                style: TextStyle(fontWeight: FontWeight.w600, color: cs.outline)),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('usuarios')
                .where('negocioId', isEqualTo: currentNegocioId)
                .where('rol', isNotEqualTo: AuthService.rolDueno)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final docs = (snapshot.data?.docs ?? []).where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['rol'] == AuthService.rolEmpleado || data['rol'] == 'usuario';
              }).toList();

              if (docs.isEmpty) {
                return const PremiumEmptyState(
                  icon: Icons.people_outline,
                  title: 'Sin Empleados',
                  subtitle: 'No tienes empleados registrados.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final uid = docs[index].id;
                  final nombre = data['nombre'] as String? ?? 'Sin nombre';
                  final email = data['email'] as String? ?? '';
                  final estatus = data['estatus'] as String? ?? '';
                  final isActivo = estatus != 'despedido' && estatus != 'inactivo';

                  // Contar permisos activos
                  final permisosMap = data['permisos'] as Map<String, dynamic>?;
                  final permisos = permisosMap != null
                      ? PermisosEmpleado.fromMap(permisosMap)
                      : const PermisosEmpleado();
                  final permisosActivos = [
                    permisos.puedeAjustarStock,
                    permisos.puedeEditarProductos,
                    permisos.puedeEliminarProductos,
                    permisos.puedeVerEstadisticas,
                    permisos.puedeVerHistorialVentas,
                    permisos.puedeAbrirCerrarCaja,
                  ].where((v) => v).length;

                  return PremiumCard(
                    color: isActivo ? null : Colors.grey.shade100,
                    child: ListTile(
                      onTap: isActivo
                          ? () => _abrirPanelPermisos(uid, nombre, email, data)
                          : null,
                      leading: CircleAvatar(
                        backgroundColor: isActivo ? cs.primaryContainer : Colors.grey.shade300,
                        child: Text(nombre[0].toUpperCase(),
                            style: TextStyle(
                                color: isActivo ? cs.onPrimaryContainer : Colors.grey,
                                fontWeight: FontWeight.bold)),
                      ),
                      title: Text(nombre,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: isActivo ? null : TextDecoration.lineThrough)),
                      subtitle: Text(email),
                      trailing: isActivo
                          ? Row(mainAxisSize: MainAxisSize.min, children: [
                              // Badge de permisos
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('$permisosActivos/6 permisos',
                                    style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer)),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.chevron_right, color: cs.outline),
                            ])
                          : const Icon(Icons.block, color: Colors.red),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  ),
);
}
}

// ── Panel de Permisos por Empleado ────────────────────────────────────────────

class _PanelPermisosEmpleado extends StatefulWidget {
  final String uid;
  final String nombre;
  final String email;
  final PermisosEmpleado permisosIniciales;
  final VoidCallback onDespedir;

  const _PanelPermisosEmpleado({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.permisosIniciales,
    required this.onDespedir,
  });

  @override
  State<_PanelPermisosEmpleado> createState() => _PanelPermisosEmpleadoState();
}

class _PanelPermisosEmpleadoState extends State<_PanelPermisosEmpleado> {
  late bool _ajustarStock;
  late bool _editarProductos;
  late bool _eliminarProductos;
  late bool _verEstadisticas;
  late bool _verHistorial;
  late bool _abrirCaja;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _ajustarStock = widget.permisosIniciales.puedeAjustarStock;
    _editarProductos = widget.permisosIniciales.puedeEditarProductos;
    _eliminarProductos = widget.permisosIniciales.puedeEliminarProductos;
    _verEstadisticas = widget.permisosIniciales.puedeVerEstadisticas;
    _verHistorial = widget.permisosIniciales.puedeVerHistorialVentas;
    _abrirCaja = widget.permisosIniciales.puedeAbrirCerrarCaja;
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final nuevos = PermisosEmpleado(
        puedeAjustarStock: _ajustarStock,
        puedeEditarProductos: _editarProductos,
        puedeEliminarProductos: _eliminarProductos,
        puedeVerEstadisticas: _verEstadisticas,
        puedeVerHistorialVentas: _verHistorial,
        puedeAbrirCerrarCaja: _abrirCaja,
      );
      await AuthService().actualizarPermisosEmpleado(widget.uid, nuevos);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permisos actualizados'), backgroundColor: Colors.green));
      }
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
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sc) => Column(
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          // Cabecera del empleado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.primaryContainer,
                  child: Text(widget.nombre[0].toUpperCase(),
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(widget.email, style: TextStyle(color: cs.outline, fontSize: 13)),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          // Lista scrollable de permisos
          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                _seccion('Inventario', Icons.inventory_2_outlined),
                _permiso('Ajustar Stock (manual)', 'Puede sumar o restar unidades al inventario.',
                    _ajustarStock, (v) => setState(() => _ajustarStock = v)),
                _permiso('Editar Productos', 'Puede cambiar nombre, precio y código de barras.',
                    _editarProductos, (v) => setState(() => _editarProductos = v)),
                _permiso('Eliminar Productos', 'Puede borrar productos del catálogo.',
                    _eliminarProductos, (v) => setState(() => _eliminarProductos = v)),
                const Divider(indent: 16, endIndent: 16, height: 8),
                _seccion('Reportes', Icons.bar_chart_outlined),
                _permiso('Ver Estadísticas y Ganancias', 'Acceso al dashboard de análisis.',
                    _verEstadisticas, (v) => setState(() => _verEstadisticas = v)),
                _permiso('Ver Historial de Pedidos', 'Consultar el listado de ventas.',
                    _verHistorial, (v) => setState(() => _verHistorial = v)),
                const Divider(indent: 16, endIndent: 16, height: 8),
                _seccion('Caja', Icons.point_of_sale_outlined),
                _permiso('Abrir y Cerrar Caja', 'Puede iniciar y cerrar turnos de caja.',
                    _abrirCaja, (v) => setState(() => _abrirCaja = v)),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Botones de acción
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDespedir();
                  },
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('Dar de baja'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_guardando ? 'Guardando...' : 'Guardar Permisos'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccion(String titulo, IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
        child: Row(children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(titulo.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.primary)),
        ]),
      );

  Widget _permiso(String titulo, String subtitulo, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(subtitulo, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      );
}
