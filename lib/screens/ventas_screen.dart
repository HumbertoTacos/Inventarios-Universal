import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/producto.dart';
import '../models/venta.dart';
import '../models/cliente.dart';
import '../services/firebase_service.dart';
import 'inventario_screen.dart';
import 'barcode_scanner_screen.dart';
import 'clientes_screen.dart';
import '../services/auth_service.dart';
import 'auth_gate.dart';
import 'historial_ventas_screen.dart';
import 'estadisticas_screen.dart';
import 'mi_equipo_screen.dart';
import 'gestion_categorias_screen.dart';
import '../utils/formatters.dart';
import '../services/impresion_service.dart';
import '../models/negocio.dart';
import 'configuracion_negocio_screen.dart';
import 'bitacora_screen.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final List<VentaItem> _carrito = [];
  final Map<String, Producto> _cacheProductos = {};
  bool _procesando = false;

  final _barcodeFocusNode = FocusNode();
  final _barcodeCtrl = TextEditingController();

  final _costoEnvioCtrl = TextEditingController(text: '0');
  bool _envioPagadoPorVendedor = true;

  // Crédito / Método de pago
  MetodoPago _metodoPago = MetodoPago.efectivo;
  Cliente? _clienteSeleccionado;

  // Descuentos Globales
  TipoDescuento _tipoDescuento = TipoDescuento.ninguno;
  final _valorDescuentoCtrl = TextEditingController(text: '0');
  bool _descuentoAutorizado = false;

  @override
  void dispose() {
    _costoEnvioCtrl.dispose();
    _barcodeFocusNode.dispose();
    _barcodeCtrl.dispose();
    _valorDescuentoCtrl.dispose();
    super.dispose();
  }

  double get _subtotalVenta => _carrito.fold(0, (sum, item) => sum + item.subtotal);

  double get _montoDescuento {
    if (_tipoDescuento == TipoDescuento.fijo) {
      double val = double.tryParse(_valorDescuentoCtrl.text) ?? 0.0;
      return val > _subtotalVenta ? _subtotalVenta : val;
    } else if (_tipoDescuento == TipoDescuento.porcentaje) {
      double porc = double.tryParse(_valorDescuentoCtrl.text) ?? 0.0;
      return (_subtotalVenta * (porc / 100)).clamp(0.0, _subtotalVenta);
    }
    return 0.0;
  }

  double get _totalVenta {
    double envio = double.tryParse(_costoEnvioCtrl.text.trim()) ?? 0.0;
    double total = (_subtotalVenta - _montoDescuento) + (!_envioPagadoPorVendedor ? envio : 0.0);
    return total.clamp(0.0, double.infinity);
  }

  // ── Agregar al carrito ──────────────────────────────────────────────────

  Future<void> _pedirCantidadYAgregar(Producto producto) async {
    if (!mounted) return; // Fix para context across async gaps warning
    final TextEditingController ctrl = TextEditingController(text: '1');
    
    final double? cantidad = await showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Vender: ${producto.nombre}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stock disponible: ${producto.cantidad.formatoInventario}'),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Cantidad a vender',
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
                final c = double.tryParse(ctrl.text) ?? 0.0;
                if (c > 0) {
                  Navigator.pop(ctx, c);
                }
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );

    if (cantidad != null && cantidad > 0) {
      setState(() {
        _cacheProductos[producto.id] = producto;
        final existingIndex = _carrito.indexWhere((i) => i.productoId == producto.id);
        if (existingIndex >= 0) {
          final oldItem = _carrito[existingIndex];
          final nuevaCant = oldItem.cantidad + cantidad;
          
          double precioFinal = _calcularPrecioUnitario(producto, nuevaCant);

          _carrito[existingIndex] = VentaItem(
            productoId: oldItem.productoId,
            nombre: oldItem.nombre,
            costoUnitario: oldItem.costoUnitario,
            precioUnitario: precioFinal,
            cantidad: nuevaCant,
          );
        } else {
          double precioFinal = _calcularPrecioUnitario(producto, cantidad);

          _carrito.add(VentaItem(
            productoId: producto.id,
            nombre: producto.nombre,
            costoUnitario: producto.costoPromedio,
            precioUnitario: precioFinal,
            cantidad: cantidad,
          ));
        }
        _barcodeCtrl.clear();
        _barcodeFocusNode.requestFocus();
      });
    }
  }

  double _calcularPrecioUnitario(Producto p, double cant) {
    // 1. Prioridad Promoción
    if (p.enPromocion && p.precioPromocion != null) {
      return p.precioPromocion!;
    }
    // 2. Mayoreo si aplica
    if (p.cantidadMayoreo != null && p.precioMayoreo != null && cant >= p.cantidadMayoreo!) {
      return p.precioMayoreo!;
    }
    // 3. Precio Base
    return p.precio;
  }

  Future<void> _editarCantidadItem(int index) async {
    final item = _carrito[index];
    final producto = _cacheProductos[item.productoId];
    if (producto == null) return;

    final TextEditingController ctrl = TextEditingController(text: item.cantidad.toString());
    
    final double? nuevaCantidad = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar: ${item.nombre}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nueva cantidad', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? 0.0;
              Navigator.pop(ctx, val);
            }, 
            child: const Text('Actualizar')
          ),
        ],
      ),
    );

    if (nuevaCantidad != null) {
      setState(() {
        if (nuevaCantidad <= 0) {
          _carrito.removeAt(index);
        } else {
          final nuevoPrecio = _calcularPrecioUnitario(producto, nuevaCantidad);
          _carrito[index] = VentaItem(
            productoId: item.productoId,
            nombre: item.nombre,
            costoUnitario: item.costoUnitario,
            precioUnitario: nuevoPrecio,
            cantidad: nuevaCantidad,
          );
        }
      });
    }
  }

  Future<void> _intentarCambiarTipoDescuento(TipoDescuento nuevoTipo) async {
    final userData = AuthService().currentUserData;
    final bool esDueno = userData?.rol == AuthService.rolDueno;

    if (esDueno || _descuentoAutorizado) {
      setState(() => _tipoDescuento = nuevoTipo);
    } else {
      final autorizado = await _solicitarPinAutorizacion();
      if (autorizado) {
        setState(() {
          _descuentoAutorizado = true;
          _tipoDescuento = nuevoTipo;
        });
      } else {
        setState(() {
          _tipoDescuento = TipoDescuento.ninguno;
          _valorDescuentoCtrl.text = '0';
        });
      }
    }
  }

  Future<bool> _solicitarPinAutorizacion() async {
    final TextEditingController pinCtrl = TextEditingController();
    final negocio = await _firebaseService.getDatosNegocio();
    final pinCorrecto = negocio.pinAutorizacion;

    if (pinCorrecto == null || pinCorrecto.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN no configurado. El dueño debe definirlo en Configuración.'), backgroundColor: Colors.orange),
        );
      }
      return false;
    }

    final String? inputPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_person_outlined, color: Colors.blue),
            SizedBox(width: 10),
            Text('Autorización'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Se requiere el PIN de administración para aplicar este descuento.'),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 10),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              decoration: const InputDecoration(
                hintText: '****',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, pinCtrl.text), 
            child: const Text('Verificar')
          ),
        ],
      ),
    );

    if (inputPin == pinCorrecto) {
      return true;
    } else if (inputPin != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN Incorrecto'), backgroundColor: Colors.red),
        );
      }
    }
    return false;
  }

  Future<void> _procesarCodigoEscaneado(String code) async {
    if (code.isEmpty) return;
    
    // Mostrar feedback visual de carga si es necesario, o buscar directo
    try {
      final p = await _firebaseService.buscarVariantePorSKU(code);
      if (p != null) {
        // En modo scanner laser (rápido), asumimos cantidad 1 o pedimos según config.
        // Como es papelería, mejor pedir cantidad por si es hule/listón,
        // pero podemos optimizar si es pieza única.
        await _pedirCantidadYAgregar(p);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código no encontrado'), backgroundColor: Colors.orange),
        );
        _barcodeCtrl.clear();
        _barcodeFocusNode.requestFocus();
      }
    } catch (e) {
      debugPrint('Error scanner: $e');
    }
  }

  Future<void> _buscarProducto() async {
    final Producto? prodSeleccionado = await Navigator.push<Producto?>(
      context,
      MaterialPageRoute(
        builder: (_) => const InventarioScreen(modoSeleccion: true),
      ),
    );

    if (prodSeleccionado != null && mounted) {
      await _pedirCantidadYAgregar(prodSeleccionado);
    }
  }

  Future<void> _escanearParaVender() async {
    final String? codigo = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (codigo != null && codigo.isNotEmpty && mounted) {
      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final p = await _firebaseService.buscarVariantePorSKU(codigo);
        if (mounted) Navigator.pop(context); // cerrar loading

        if (p == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Producto no encontrado.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (mounted) {
          await _pedirCantidadYAgregar(p);
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // cerrar loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al buscar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ── Registrar Venta ───────────────────────────────────────────────────────

  Future<void> _confirmarVenta() async {
    if (_carrito.isEmpty) return;

    setState(() => _procesando = true);

    try {
      final turno = await _firebaseService.getTurnoActivo();

      // Validar caja abierta solo para pagos en efectivo
      if (_metodoPago == MetodoPago.efectivo && turno == null) {
        setState(() => _procesando = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Abre la caja antes de registrar ventas en efectivo.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Validar cliente si es crédito
      if (_metodoPago == MetodoPago.credito && _clienteSeleccionado == null) {
        setState(() => _procesando = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selecciona un cliente para ventas a crédito.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // --- VALIDACIÓN DE STOCK NEGATIVO (BUG FIX QA) ---
      List<String> productosEnNegativo = [];
      for (var item in _carrito) {
        final prod = await _firebaseService.getProducto(item.productoId);
        if (prod != null && item.cantidad > prod.cantidad) {
          productosEnNegativo.add(prod.nombre);
        }
      }

      if (productosEnNegativo.isNotEmpty) {
        if (!mounted) return;
        final continuar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Advertencia de Inventario'),
            content: Text(
              'El inventario de los siguientes productos quedará en negativo:\n\n'
              '${productosEnNegativo.join(', ')}\n\n'
              '¿Deseas continuar con la venta?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continuar'),
              ),
            ],
          ),
        );

        if (continuar != true) {
          setState(() => _procesando = false);
          return;
        }
      }
      // --- FIN VALIDACIÓN ---

      final nuevaVenta = Venta(
        id: '',
        fecha: DateTime.now(),
        items: List.from(_carrito),
        costoEnvio: double.tryParse(_costoEnvioCtrl.text.trim()) ?? 0.0,
        envioPagadoPorVendedor: _envioPagadoPorVendedor,
        metodoPago: _metodoPago,
        clienteId: _metodoPago == MetodoPago.credito ? _clienteSeleccionado?.id : null,
        tipoDescuento: _tipoDescuento,
        valorDescuento: double.tryParse(_valorDescuentoCtrl.text) ?? 0.0,
      );

      await _firebaseService.registrarVenta(nuevaVenta, turnoCajaId: turno?.id);

      final soldItems = List<VentaItem>.from(_carrito);
      
      setState(() {
        _carrito.clear();
        _clienteSeleccionado = null;
        _metodoPago = MetodoPago.efectivo;
        _procesando = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Venta completada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );

        // Imprimir Ticket automáticamente
        try {
          final negocio = await _firebaseService.getDatosNegocio();
          await ImpresionService.imprimirTicketVenta(nuevaVenta, negocio);
        } catch (e) {
          debugPrint('Error al imprimir ticket: $e');
        }

        // Devolvemos el carrito a la pantalla anterior para actualización optimista
        Navigator.pop(context, soldItems);
      }
    } catch (e) {
      setState(() => _procesando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar la venta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _intentarSalir() async {
    if (_carrito.isEmpty || _procesando) return true;

    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar Venta?'),
        content: const Text('Tienes productos en el carrito. Si sales, se perderá el carrito actual.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Quedarme'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    return salir ?? false;
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userData = AuthService().currentUserData;
    final bool esDueno = userData?.rol == AuthService.rolDueno;
    final bool puedeVerHistorial = esDueno || (userData?.permisos.puedeVerHistorialVentas ?? true);

    // PopScope maneja el botón back físico y el del AppBar (en Android 14+)
    return PopScope(
      canPop: _carrito.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final mustLeave = await _intentarSalir();
        if (mustLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: colorScheme.primary),
                child: const Text(
                  'Inventarios Universal',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.point_of_sale),
                title: const Text('Punto de Venta'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Inventario'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const InventarioScreen()));
                },
              ),
              if (puedeVerHistorial)
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Historial de Ventas'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HistorialVentasScreen()));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.people_outlined),
                title: const Text('Clientes y Créditos'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientesScreen()));
                },
              ),
              if (esDueno) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.bar_chart),
                  title: const Text('Estadísticas y Ganancias'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EstadisticasScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: const Text('Gestionar Categorías'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const GestionCategoriasScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.people_alt_outlined),
                  title: const Text('Mi Equipo'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MiEquipoScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.manage_search_outlined),
                  title: const Text('Bitácora de Movimientos'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BitacoraScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Configuración del Negocio'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfiguracionNegocioScreen()));
                  },
                ),
              ],
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  await AuthService().logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthGate()),
                      (route) => false,
                    );
                  }
                },
              ),
            ],
          ),
        ),
        appBar: AppBar(
          title: const Text('Punto de Venta'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Escanear producto',
              onPressed: _escanearParaVender,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Buscar en catálogo',
              onPressed: _buscarProducto,
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // Input para escáner láser
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _barcodeCtrl,
                    focusNode: _barcodeFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Escanear producto o ingresar código...',
                      prefixIcon: const Icon(Icons.qr_code_scanner),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () { _barcodeCtrl.clear(); _barcodeFocusNode.requestFocus(); },
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    ),
                    onSubmitted: _procesarCodigoEscaneado,
                  ),
                ),
                // Lista del carrito
                Expanded(
                  child: _carrito.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text('Carrito Vacío',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey.shade600)),
                              const SizedBox(height: 8),
                              Text('Escanea o busca un producto para agregar',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _carrito.length,
                          separatorBuilder: (ctx, idx) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _carrito[index];
                            return ListTile(
                              title: Text(item.nombre),
                              subtitle: Text('${item.cantidad.formatoInventario} x \$${item.precioUnitario.toStringAsFixed(2)}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '\$${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                    onPressed: () => _editarCantidadItem(index),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => setState(() => _carrito.removeAt(index)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                // Panel de resumen (Footer)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text(
                              '\$${_totalVenta.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _costoEnvioCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                decoration: const InputDecoration(labelText: 'Envío (\$)', isDense: true, border: OutlineInputBorder()),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Paga el envío:', style: TextStyle(fontSize: 12)),
                                  Row(
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Vend.', style: TextStyle(fontSize: 10)),
                                        selected: _envioPagadoPorVendedor,
                                        onSelected: (v) => setState(() => _envioPagadoPorVendedor = true),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 8),
                                      ChoiceChip(
                                        label: const Text('Clien.', style: TextStyle(fontSize: 10)),
                                        selected: !_envioPagadoPorVendedor,
                                        onSelected: (v) => setState(() => _envioPagadoPorVendedor = false),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // ── Descuento Global ──
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Descuento Caja:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  Row(
                                    children: [
                                      ChoiceChip(
                                        label: const Text('Ning.', style: TextStyle(fontSize: 10)),
                                        selected: _tipoDescuento == TipoDescuento.ninguno,
                                        onSelected: (v) {
                                          setState(() {
                                            _tipoDescuento = TipoDescuento.ninguno;
                                            _valorDescuentoCtrl.text = '0';
                                            _descuentoAutorizado = false;
                                          });
                                        },
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 4),
                                      ChoiceChip(
                                        label: const Text('\$', style: TextStyle(fontSize: 10)),
                                        selected: _tipoDescuento == TipoDescuento.fijo,
                                        onSelected: (v) => _intentarCambiarTipoDescuento(TipoDescuento.fijo),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      const SizedBox(width: 4),
                                      ChoiceChip(
                                        label: const Text('%', style: TextStyle(fontSize: 10)),
                                        selected: _tipoDescuento == TipoDescuento.porcentaje,
                                        onSelected: (v) => _intentarCambiarTipoDescuento(TipoDescuento.porcentaje),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _tipoDescuento == TipoDescuento.ninguno
                                ? const SizedBox()
                                : TextField(
                                    controller: _valorDescuentoCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: _tipoDescuento == TipoDescuento.fijo ? 'Caja (\$)' : 'Caja (%)',
                                      isDense: true,
                                      prefixIcon: const Icon(Icons.discount, size: 16),
                                      border: const OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Selector de método de pago
                        _buildSelectorMetodoPago(),
                        const SizedBox(height: 12),
                        // Selector de cliente (solo si es crédito)
                        if (_metodoPago == MetodoPago.credito)
                          _buildSelectorCliente(),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: (_carrito.isEmpty || _procesando) ? null : _confirmarVenta,
                            icon: _procesando
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.check_circle_outline),
                            label: Text(_procesando ? 'Procesando...' : 'Confirmar Venta', style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Selector de Método de Pago ────────────────────────────────────────────

  Widget _buildSelectorMetodoPago() {
    final metodos = [
      (MetodoPago.efectivo, 'Efectivo', Icons.payments_outlined),
      (MetodoPago.tarjeta, 'Tarjeta', Icons.credit_card),
      (MetodoPago.transferencia, 'Transferencia', Icons.swap_horiz),
      (MetodoPago.credito, 'Crédito', Icons.person_outline),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Método de pago',
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: metodos.map((m) {
              final (metodo, label, icon) = m;
              final sel = _metodoPago == metodo;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(icon, size: 16),
                  label: Text(label),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    _metodoPago = metodo;
                    if (metodo != MetodoPago.credito) _clienteSeleccionado = null;
                  }),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Selector de Cliente (solo crédito) ────────────────────────────────────

  Widget _buildSelectorCliente() {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final c = await Navigator.push<Cliente>(
          context,
          MaterialPageRoute(
              builder: (_) => const ClientesScreen(modoSeleccion: true)),
        );
        if (c != null) setState(() => _clienteSeleccionado = c);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
              color: _clienteSeleccionado != null
                  ? cs.primary
                  : cs.outline.withAlpha(80)),
          borderRadius: BorderRadius.circular(12),
          color: _clienteSeleccionado != null
              ? cs.primaryContainer.withAlpha(60)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              _clienteSeleccionado != null
                  ? Icons.person
                  : Icons.person_add_alt_1_outlined,
              color: _clienteSeleccionado != null ? cs.primary : cs.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _clienteSeleccionado == null
                  ? Text('Seleccionar cliente *',
                      style: TextStyle(color: cs.outline))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_clienteSeleccionado!.nombre,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: cs.primary)),
                        Text(
                          'Deuda: \$${_clienteSeleccionado!.saldoDeudor.toStringAsFixed(2)} | '
                          'Límite: ${_clienteSeleccionado!.limiteCreditoTexto}',
                          style: TextStyle(fontSize: 12, color: cs.primary),
                        ),
                      ],
                    ),
            ),
            if (_clienteSeleccionado != null)
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _clienteSeleccionado = null),
              ),
          ],
        ),
      ),
    );
  }
}
