import 'package:flutter/material.dart';
import '../models/proveedor.dart';
import '../services/firebase_service.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';

class GestionProveedoresScreen extends StatefulWidget {
  const GestionProveedoresScreen({super.key});

  @override
  State<GestionProveedoresScreen> createState() => _GestionProveedoresScreenState();
}

class _GestionProveedoresScreenState extends State<GestionProveedoresScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isSaving = false;

  void _abrirFormulario({Proveedor? proveedor}) {
    final bool isDesktop = ResponsiveLayout.isDesktop(context);
    
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(proveedor == null ? 'Nuevo Proveedor' : 'Editar Proveedor'),
          content: SizedBox(
            width: 500,
            child: _ProveedorForm(
              proveedor: proveedor,
              onSave: (p) => _guardarProveedor(p),
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: _ProveedorForm(
                    proveedor: proveedor,
                    onSave: (p) => _guardarProveedor(p),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<void> _guardarProveedor(Proveedor proveedor) async {
    setState(() => _isSaving = true);
    try {
      if (proveedor.id.isEmpty) {
        await _firebaseService.agregarProveedor(proveedor);
      } else {
        await _firebaseService.actualizarProveedor(proveedor);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _eliminarProveedor(Proveedor proveedor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Proveedor?'),
        content: Text('¿Estás seguro de eliminar a ${proveedor.nombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firebaseService.eliminarProveedor(proveedor.id, proveedor.nombre);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      currentRoute: '/proveedores',
      title: 'Gestión de Proveedores',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Proveedor'),
      ),
      body: StreamBuilder<List<Proveedor>>(
        stream: _firebaseService.getProveedores(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final proveedores = snapshot.data ?? [];

          if (proveedores.isEmpty) {
            return PremiumEmptyState(
              icon: Icons.contact_phone_outlined,
              title: 'Aún no tienes proveedores registrados',
              subtitle: 'Agrega a tus proveedores para gestionar compras y costos de inventario.',
              action: FilledButton.icon(
                onPressed: () => _abrirFormulario(),
                icon: const Icon(Icons.add),
                label: const Text('Agregar mi primer proveedor'),
              ),
            );
          }

          return ResponsiveLayout(
            mobileBody: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: proveedores.length,
              itemBuilder: (context, index) => _ProveedorListTile(
                proveedor: proveedores[index],
                onEdit: () => _abrirFormulario(proveedor: proveedores[index]),
                onDelete: () => _eliminarProveedor(proveedores[index]),
              ),
            ),
            tabletBody: _ProveedorGrid(
              proveedores: proveedores,
              crossAxisCount: 2,
              onEdit: (p) => _abrirFormulario(proveedor: p),
              onDelete: (p) => _eliminarProveedor(p),
            ),
            desktopBody: _ProveedorGrid(
              proveedores: proveedores,
              crossAxisCount: 4,
              onEdit: (p) => _abrirFormulario(proveedor: p),
              onDelete: (p) => _eliminarProveedor(p),
            ),
          );
        },
      ),
    );
  }
}

class _ProveedorListTile extends StatelessWidget {
  final Proveedor proveedor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProveedorListTile({
    required this.proveedor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onEdit,
      child: ListTile(
        title: Text(
          proveedor.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(proveedor.rfc_o_nit ?? 'Sin RFC/NIT'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.phone_outlined),
              onPressed: () {
                // Acción de llamada (requiere url_launcher)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Llamando a ${proveedor.telefono}...')),
                );
              },
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
              onSelected: (val) {
                if (val == 'edit') onEdit();
                if (val == 'delete') onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProveedorGrid extends StatelessWidget {
  final List<Proveedor> proveedores;
  final int crossAxisCount;
  final Function(Proveedor) onEdit;
  final Function(Proveedor) onDelete;

  const _ProveedorGrid({
    required this.proveedores,
    required this.crossAxisCount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: proveedores.length,
      itemBuilder: (context, index) {
        final p = proveedores[index];
        return PremiumCard(
          padding: const EdgeInsets.all(20),
          onTap: () => onEdit(p),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      p.nombre,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => onDelete(p),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                p.rfc_o_nit ?? 'Sin identificación',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.phone_outlined, 
                    size: 16, 
                    color: Theme.of(context).colorScheme.primary
                  ),
                  const SizedBox(width: 8),
                  Text(p.telefono),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProveedorForm extends StatefulWidget {
  final Proveedor? proveedor;
  final Function(Proveedor) onSave;

  const _ProveedorForm({this.proveedor, required this.onSave});

  @override
  State<_ProveedorForm> createState() => _ProveedorFormState();
}

class _ProveedorFormState extends State<_ProveedorForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _rfcCtrl;
  late TextEditingController _notasCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.proveedor?.nombre);
    _telefonoCtrl = TextEditingController(text: widget.proveedor?.telefono);
    _rfcCtrl = TextEditingController(text: widget.proveedor?.rfc_o_nit);
    _notasCtrl = TextEditingController(text: widget.proveedor?.notas);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _rfcCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nombreCtrl,
            decoration: const InputDecoration(
              labelText: 'Nombre Comercial',
              prefixIcon: Icon(Icons.business),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _telefonoCtrl,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _rfcCtrl,
            decoration: const InputDecoration(
              labelText: 'RFC / NIT',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notasCtrl,
            decoration: const InputDecoration(
              labelText: 'Notas adicionales',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _loading ? null : () async {
                if (_formKey.currentState!.validate()) {
                  setState(() => _loading = true);
                  final p = Proveedor(
                    id: widget.proveedor?.id ?? '',
                    nombre: _nombreCtrl.text,
                    telefono: _telefonoCtrl.text,
                    rfc_o_nit: _rfcCtrl.text,
                    notas: _notasCtrl.text,
                  );
                  await widget.onSave(p);
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: _loading 
                ? const SizedBox(
                    height: 20, 
                    width: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                : Text(widget.proveedor == null ? 'Registrar Proveedor' : 'Guardar Cambios'),
            ),
          ),
        ],
      ),
    );
  }
}
