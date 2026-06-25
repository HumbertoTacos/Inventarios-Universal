import 'package:flutter/material.dart';
import '../models/proveedor.dart';
import '../services/firebase_service.dart';
import '../widgets/premium_widgets.dart';
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';
import 'package:url_launcher/url_launcher.dart';

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
            width: 800,
            child: SingleChildScrollView(
              child: _ProveedorForm(
                proveedor: proveedor,
                onSave: (p) => _guardarProveedor(p),
              ),
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
        content: Text('¿Estás seguro de eliminar a ${proveedor.nombreComercial}?'),
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
        await _firebaseService.eliminarProveedor(proveedor.id, proveedor.nombreComercial);
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
      currentRoute: 'proveedores',
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
              crossAxisCount: 3,
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
          proveedor.nombreComercial,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(proveedor.nombreContacto ?? proveedor.tipoProveedor ?? 'Sin contacto asignado'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.message, color: Colors.green),
              onPressed: () => _abrirWhatsAppNumero(context, proveedor.telefono),
            ),
            IconButton(
              icon: const Icon(Icons.phone_outlined, color: Colors.blue),
              onPressed: () => _llamarNumero(context, proveedor.telefono),
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
        childAspectRatio: 1.4,
      ),
      itemCount: proveedores.length,
      itemBuilder: (context, index) {
        final p = proveedores[index];
        final colorScheme = Theme.of(context).colorScheme;
        
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nombreComercial,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (p.tipoProveedor != null)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withAlpha(100),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.tipoProveedor!,
                              style: TextStyle(fontSize: 10, color: colorScheme.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => onDelete(p),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (p.nombreContacto != null)
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: colorScheme.outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.nombreContacto!,
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const Spacer(),
              Row(
                children: [
                  InkWell(
                    onTap: () => _llamarNumero(context, p.telefono),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          Icon(Icons.phone_outlined, 
                            size: 14, 
                            color: colorScheme.primary
                          ),
                          const SizedBox(width: 4),
                          Text(p.telefono, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.message, color: Colors.green, size: 18),
                    onPressed: () => _abrirWhatsAppNumero(context, p.telefono),
                  ),
                  if (p.diasVisita != null) ...[
                    const Spacer(),
                    Icon(Icons.calendar_today_outlined, size: 14, color: colorScheme.secondary),
                    const SizedBox(width: 6),
                    Text(p.diasVisita!, style: TextStyle(fontSize: 12, color: colorScheme.secondary)),
                  ],
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
  late TextEditingController _razonSocialCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _correoCtrl;
  late TextEditingController _rfcCtrl;
  late TextEditingController _contactoCtrl;
  late TextEditingController _notasCtrl;
  late TextEditingController _otroTipoCtrl;
  String? _tipoSeleccionado;
  
  final List<String> _tipos = ["Abarrotes", "Papelería", "Tecnología", "Servicios", "Bebidas", "Limpieza", "Otro"];
  final List<String> _diasSemana = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];
  List<String> _diasSeleccionados = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.proveedor?.nombreComercial);
    _razonSocialCtrl = TextEditingController(text: widget.proveedor?.razonSocial);
    _telefonoCtrl = TextEditingController(text: widget.proveedor?.telefono);
    _correoCtrl = TextEditingController(text: widget.proveedor?.correo);
    _rfcCtrl = TextEditingController(text: widget.proveedor?.rfc_o_nit);
    _contactoCtrl = TextEditingController(text: widget.proveedor?.nombreContacto);
    _notasCtrl = TextEditingController(text: widget.proveedor?.notas);
    
    final d = widget.proveedor?.diasVisita ?? '';
    if (d.isNotEmpty) {
      _diasSeleccionados = d.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    
    final t = widget.proveedor?.tipoProveedor;
    if (t != null && !_tipos.contains(t)) {
      _tipoSeleccionado = "Otro";
      _otroTipoCtrl = TextEditingController(text: t);
    } else {
      _tipoSeleccionado = t;
      _otroTipoCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _razonSocialCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    _rfcCtrl.dispose();
    _contactoCtrl.dispose();
    _notasCtrl.dispose();
    _otroTipoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = ResponsiveLayout.isDesktop(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildResponsiveRow(isDesktop, [
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre Comercial *',
                prefixIcon: Icon(Icons.business),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _razonSocialCtrl,
              decoration: const InputDecoration(
                labelText: 'Razón Social (Opcional)',
                prefixIcon: Icon(Icons.gavel_outlined),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          
          _buildResponsiveRow(isDesktop, [
            TextFormField(
              controller: _telefonoCtrl,
              decoration: const InputDecoration(
                labelText: 'Teléfono *',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
            ),
            TextFormField(
              controller: _correoCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo Electrónico',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ]),
          const SizedBox(height: 16),

          _buildResponsiveRow(isDesktop, [
            TextFormField(
              controller: _rfcCtrl,
              decoration: const InputDecoration(
                labelText: 'RFC / NIT',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            DropdownButtonFormField<String>(
              value: _tipoSeleccionado,
              decoration: const InputDecoration(
                labelText: 'Tipo de Proveedor',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _tipoSeleccionado = val),
            ),
          ]),
          if (_tipoSeleccionado == 'Otro') ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _otroTipoCtrl,
              decoration: const InputDecoration(
                labelText: 'Especificar Tipo de Proveedor *',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              validator: (v) => _tipoSeleccionado == 'Otro' && (v == null || v.isEmpty) ? 'Especifica el tipo' : null,
            ),
          ],
          const SizedBox(height: 16),

          _buildResponsiveRow(isDesktop, [
            TextFormField(
              controller: _contactoCtrl,
              decoration: const InputDecoration(
                labelText: 'Persona de Contacto',
                prefixIcon: Icon(Icons.person_outline),
                hintText: 'Ej. Don Luis el preventista',
              ),
            ),
            const SizedBox(), // Spacer for alignment if needed, but we'll put the chips below
          ]),
          const SizedBox(height: 16),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Días de Visita (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _diasSemana.map((dia) {
                  final isSelected = _diasSeleccionados.contains(dia);
                  return FilterChip(
                    label: Text(dia),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _diasSeleccionados.add(dia);
                        } else {
                          _diasSeleccionados.remove(dia);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _notasCtrl,
            decoration: const InputDecoration(
              labelText: 'Notas adicionales',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 2,
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _loading ? null : () async {
                if (_formKey.currentState!.validate()) {
                  setState(() => _loading = true);
                  String? finalTipo = _tipoSeleccionado;
                  if (_tipoSeleccionado == 'Otro') {
                    finalTipo = _otroTipoCtrl.text.trim();
                  }
                  final String diasVisitaStr = _diasSeleccionados.join(', ');
                  final p = Proveedor(
                    id: widget.proveedor?.id ?? '',
                    nombreComercial: _nombreCtrl.text,
                    razonSocial: _razonSocialCtrl.text.isEmpty ? null : _razonSocialCtrl.text,
                    telefono: _telefonoCtrl.text,
                    correo: _correoCtrl.text.isEmpty ? null : _correoCtrl.text,
                    rfc_o_nit: _rfcCtrl.text.isEmpty ? null : _rfcCtrl.text,
                    nombreContacto: _contactoCtrl.text.isEmpty ? null : _contactoCtrl.text,
                    tipoProveedor: finalTipo,
                    diasVisita: diasVisitaStr.isEmpty ? null : diasVisitaStr,
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

  Widget _buildResponsiveRow(bool isDesktop, List<Widget> children) {
    if (!isDesktop) {
      return Column(
        children: children.asMap().entries.map((e) {
          return Padding(
            padding: EdgeInsets.only(bottom: e.key == children.length - 1 ? 0 : 16),
            child: e.value,
          );
        }).toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((w) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: w,
        ),
      )).toList(),
    );
  }
}

Future<void> _llamarNumero(BuildContext context, String telefono) async {
  if (telefono.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este proveedor no tiene teléfono registrado')),
    );
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  final cleanPhone = telefono.replaceAll(RegExp(r'\D'), '');
  final uri = Uri(scheme: 'tel', path: cleanPhone);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo iniciar la llamada')),
      );
    }
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo iniciar la llamada')),
    );
  }
}

Future<void> _abrirWhatsAppNumero(BuildContext context, String telefono) async {
  if (telefono.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Este proveedor no tiene teléfono registrado')),
    );
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  String cleanPhone = telefono.replaceAll(RegExp(r'\D'), '');
  if (cleanPhone.length == 10) {
    cleanPhone = '52$cleanPhone';
  }
  final uri = Uri.parse('https://wa.me/$cleanPhone');
  try {
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir WhatsApp')),
    );
  }
}
