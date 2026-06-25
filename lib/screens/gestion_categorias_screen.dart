import 'package:flutter/material.dart';
import '../models/categoria.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';

class GestionCategoriasScreen extends StatelessWidget {
  const GestionCategoriasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (AuthService().currentUserData?.rol != AuthService.rolDueno) {
      return const Scaffold(body: Center(child: Text('Acceso Denegado. Solo el dueño puede gestionar categorías.')));
    }

    final colorScheme = Theme.of(context).colorScheme;
    final firebaseService = FirebaseService();

    return ResponsiveScaffold(
      currentRoute: 'categorias',
      title: 'Gestionar Categorías',
      body: ResponsiveLayout(
        mobileBody: _buildBody(context, firebaseService, isDesktop: false),
        tabletBody: _buildBody(context, firebaseService, isDesktop: true),
        desktopBody: _buildBody(context, firebaseService, isDesktop: true),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarDialogoAgregar(context, firebaseService),
        icon: const Icon(Icons.add),
        label: const Text('Agregar categoría'),
      ),
    );
  }

  Widget _buildBody(BuildContext context, FirebaseService firebaseService, {bool isDesktop = false}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 800),
        child: StreamBuilder<List<Categoria>>(
          stream: firebaseService.getCategorias(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final categorias = snapshot.data ?? [];

            if (categorias.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category_outlined, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Sin categorías',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toca el botón + para agregar una.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: categorias.length,
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final cat = categorias[index];
                return _CategoriaCard(
                  categoria: cat,
                  firebaseService: firebaseService,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoAgregar(
    BuildContext context,
    FirebaseService firebaseService,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CategoriaFormDialog(firebaseService: firebaseService),
    );
  }
}

// ── Card de categoría ──────────────────────────────────────────────────────

class _CategoriaCard extends StatelessWidget {
  final Categoria categoria;
  final FirebaseService firebaseService;

  const _CategoriaCard({
    required this.categoria,
    required this.firebaseService,
  });

  Future<void> _intentarEliminar(BuildContext context) async {
    final count =
        await firebaseService.contarProductosPorCategoria(categoria.nombre);

    if (!context.mounted) return;

    if (count > 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
          title: const Text('No se puede eliminar'),
          content: Text(
            'La categoría "${categoria.nombre}" tiene $count '
            '${count == 1 ? 'producto asociado' : 'productos asociados'}.\n\n'
            'Primero elimina o reasigna esos productos para poder '
            'borrar esta categoría.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text(
          '¿Eliminar "${categoria.nombre}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      await firebaseService.eliminarCategoria(categoria.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${categoria.nombre}" eliminada.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _mostrarDialogoEditar(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CategoriaFormDialog(
        firebaseService: firebaseService,
        categoria: categoria,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(categoria.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _intentarEliminar(context);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _mostrarDialogoEditar(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Text(
                    categoria.nombre.isNotEmpty
                        ? categoria.nombre[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoria.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${categoria.atributos.length} atributos configurados',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Eliminar categoría',
                  onPressed: () => _intentarEliminar(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Diálogo para agregar/editar categoría ───────────────────────────────────

class CategoriaFormDialog extends StatefulWidget {
  final FirebaseService firebaseService;
  final Categoria? categoria; // Si no es nulo, estamos editando

  const CategoriaFormDialog({
    required this.firebaseService,
    this.categoria,
  });

  @override
  State<CategoriaFormDialog> createState() => CategoriaFormDialogState();
}

class CategoriaFormDialogState extends State<CategoriaFormDialog> {
  final _nombreCtrl = TextEditingController();
  List<AtributoCategoria> _atributos = [];

  bool _guardando = false;
  String? _errorNombre;
  String? _errorAtributos;

  bool get _esEdicion => widget.categoria != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _nombreCtrl.text = widget.categoria!.nombre;
      _atributos = List<AtributoCategoria>.from(widget.categoria!.atributos);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _agregarAtributo() async {
    final resultado = await showDialog<AtributoCategoria>(
      context: context,
      builder: (ctx) => const _AtributoDialog(),
    );
    if (resultado != null) {
      setState(() {
        _atributos.add(resultado);
        _errorAtributos = null;
      });
    }
  }

  void _quitarAtributo(int index) {
    setState(() => _atributos.removeAt(index));
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();

    setState(() {
      _errorNombre = nombre.isEmpty ? 'El nombre no puede estar vacío.' : null;
      _errorAtributos =
          _atributos.isEmpty ? 'Agrega al menos un atributo.' : null;
    });

    if (_errorNombre != null || _errorAtributos != null) return;

    setState(() => _guardando = true);

    try {
      if (_esEdicion) {
        final editada = Categoria(
          id: widget.categoria!.id,
          nombre: nombre,
          atributos: List<AtributoCategoria>.from(_atributos),
          orden: widget.categoria!.orden,
        );

        // Verificar atributos eliminados
        final oldAttrs = widget.categoria!.atributos.map((e) => e.nombre).toSet();
        final newAttrs = editada.atributos.map((e) => e.nombre).toSet();
        final deletedAttrs = oldAttrs.difference(newAttrs);

        if (deletedAttrs.isNotEmpty) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Confirmar eliminación'),
              content: Text(
                'Al borrar ${deletedAttrs.length == 1 ? 'este atributo' : 'estos atributos'} (${deletedAttrs.join(', ')}), se perderá de TODOS los productos vinculados a esta categoría.\n\n¿Estás seguro?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sí, borrar'),
                ),
              ],
            ),
          );

          if (confirm != true) {
            setState(() => _guardando = false);
            return;
          }
        }

        await widget.firebaseService.actualizarCategoria(
          widget.categoria!,
          editada,
        );

        if (mounted) {
          Navigator.pop(context, editada);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$nombre" actualizada correctamente.')),
          );
        }
      } else {
        final nueva = Categoria(
          id: '',
          nombre: nombre,
          atributos: List<AtributoCategoria>.from(_atributos),
          orden: 0,
        );
        final id = await widget.firebaseService.agregarCategoria(nueva);
        final categoriaCreada = Categoria(
          id: id,
          nombre: nombre,
          atributos: List<AtributoCategoria>.from(_atributos),
          orden: 0,
        );

        if (mounted) {
          Navigator.pop(context, categoriaCreada);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$nombre" agregada correctamente.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Error al guardar'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(_esEdicion ? 'Editar categoría' : 'Nueva categoría'),
      scrollable: true,
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nombre de la categoría
            TextField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre de la categoría',
                hintText: 'Ej: Toallas, Sábanas, Cobertores...',
                border: const OutlineInputBorder(),
                errorText: _errorNombre,
              ),
              onChanged: (_) {
                if (_errorNombre != null) setState(() => _errorNombre = null);
              },
            ),
            const SizedBox(height: 20),

            // Sección de atributos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Atributos',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _agregarAtributo,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar atributo'),
                ),
              ],
            ),

            if (_errorAtributos != null) ...[
              const SizedBox(height: 2),
              Text(
                _errorAtributos!,
                style: TextStyle(
                    color: colorScheme.error, fontSize: 12),
              ),
            ],

            if (_atributos.isEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Sin atributos. Agrega al menos uno.\n'
                  'Ejemplos: Tamaño, Color, Material, Diseño...',
                  style: TextStyle(
                      color: colorScheme.onSurfaceVariant, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              ...List.generate(_atributos.length, (i) {
                final attr = _atributos[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(
                      children: [
                        Icon(
                          attr.esListaFija
                              ? Icons.list_alt_outlined
                              : Icons.edit_outlined,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(attr.nombre,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: attr.esListaFija
                                          ? colorScheme.primaryContainer
                                          : colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      attr.esListaFija ? 'Lista fija' : 'Texto libre',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: attr.esListaFija
                                            ? colorScheme.onPrimaryContainer
                                            : colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (attr.esListaFija &&
                                  attr.opciones.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  attr.opciones.join(', '),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _quitarAtributo(i),
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ── Diálogo para definir un atributo individual ────────────────────────────

class _AtributoDialog extends StatefulWidget {
  const _AtributoDialog();

  @override
  State<_AtributoDialog> createState() => _AtributoDialogState();
}

class _AtributoDialogState extends State<_AtributoDialog> {
  final _nombreCtrl = TextEditingController();
  final _opcionCtrl = TextEditingController();
  bool _esListaFija = false;
  final List<String> _opciones = [];
  String? _errorNombre;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _opcionCtrl.dispose();
    super.dispose();
  }

  void _agregarOpcion() {
    final val = _opcionCtrl.text.trim();
    if (val.isEmpty) return;
    if (_opciones.map((o) => o.toLowerCase()).contains(val.toLowerCase())) return;
    setState(() {
      _opciones.add(val);
      _opcionCtrl.clear();
    });
  }

  void _confirmar() {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      setState(() => _errorNombre = 'Escribe el nombre del atributo.');
      return;
    }
    Navigator.pop(
      context,
      AtributoCategoria(
        nombre: nombre,
        esListaFija: _esListaFija,
        opciones: _esListaFija ? List<String>.from(_opciones) : [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Nuevo atributo'),
      scrollable: true,
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nombre del atributo
            TextField(
              controller: _nombreCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre del atributo',
                hintText: 'Ej: Tamaño, Color, Material...',
                border: const OutlineInputBorder(),
                errorText: _errorNombre,
              ),
              onChanged: (_) {
                if (_errorNombre != null) setState(() => _errorNombre = null);
              },
            ),
            const SizedBox(height: 16),

            // Tipo de entrada
            Text(
              'Tipo de entrada',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Texto libre'),
                  icon: Icon(Icons.edit_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Lista de opciones'),
                  icon: Icon(Icons.list_alt_outlined),
                ),
              ],
              selected: {_esListaFija},
              onSelectionChanged: (sel) => setState(() {
                _esListaFija = sel.first;
              }),
            ),
            const SizedBox(height: 8),
            Text(
              _esListaFija
                  ? 'Al agregar un producto, aparecerá un combobox con las opciones que definas.'
                  : 'Al agregar un producto, el usuario escribirá el valor libremente.',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),

            // Opciones (solo si lista fija)
            if (_esListaFija) ...[
              const SizedBox(height: 16),
              Text(
                'Opciones',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _opcionCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Ej: Grande, Mediana, Única...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onSubmitted: (_) => _agregarOpcion(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _agregarOpcion,
                    icon: const Icon(Icons.add),
                    tooltip: 'Agregar opción',
                  ),
                ],
              ),
              if (_opciones.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _opciones
                      .map((o) => Chip(
                            label: Text(o),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () =>
                                setState(() => _opciones.remove(o)),
                            backgroundColor: colorScheme.secondaryContainer,
                            labelStyle: TextStyle(
                                color: colorScheme.onSecondaryContainer),
                          ))
                      .toList(),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  'Sin opciones todavía.',
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _confirmar,
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}
