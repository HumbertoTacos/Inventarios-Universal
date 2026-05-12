import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/producto.dart';
import '../models/venta.dart';
import '../models/cliente.dart';
import '../services/firebase_service.dart';
import '../models/turno_caja.dart';
import 'inventario_screen.dart';
import 'barcode_scanner_screen.dart';
import 'clientes_screen.dart';
import '../services/auth_service.dart';
import '../utils/formatters.dart';
import '../services/impresion_service.dart';
import '../models/negocio.dart';
import 'caja_screen.dart';
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';
import '../widgets/premium_widgets.dart';
import '../controllers/configuracion_controller.dart';

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

  // ── Omni-Box: Escáner láser + Búsqueda por nombre unificados ──────────────
  final _barcodeFocusNode = FocusNode();
  final _barcodeCtrl = TextEditingController();
  Timer? _debounceTimer;
  List<Producto> _resultadosBusqueda = [];
  List<Producto> _productosGlobales = [];
  bool _mostrandoBusqueda = false;

  // [FinOps] Suscripción al Bounded Stream del catálogo (máx 50 productos)
  StreamSubscription<List<Producto>>? _catalogoSub;

  final _costoEnvioCtrl = TextEditingController(text: '0');
  bool _envioPagadoPorVendedor = true;

  // Crédito / Método de pago
  MetodoPago _metodoPago = MetodoPago.efectivo;
  Cliente? _clienteSeleccionado;

  // Descuentos Globales
  TipoDescuento _tipoDescuento = TipoDescuento.ninguno;
  final _valorDescuentoCtrl = TextEditingController(text: '0');
  bool _descuentoAutorizado = false;

  // ── Configuración del negocio ─────────────────────────────────────────────
  Negocio? _negocio;

  @override
  void initState() {
    super.initState();
    ConfiguracionController.instance.addListener(_onConfigChanged);
    _cargarNegocio();
    // [FinOps] Bounded Stream: máximo 50 productos, actualizaciones en tiempo real
    _catalogoSub = _firebaseService
        .getProductosStreamLimitado(limite: 50)
        .listen((productos) {
      if (mounted) {
        setState(() => _productosGlobales = productos);
        for (var p in productos) {
          _cacheProductos[p.id] = p;
        }
      }
    });
  }

  void _onConfigChanged() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }


  Future<void> _cargarNegocio() async {
    // [FinOps] Usar el caché del ConfiguracionController — 0 lecturas si ya está cargado
    final cached = ConfiguracionController.instance.negocio;
    if (cached != null) {
      if (mounted) setState(() => _negocio = cached);
      return;
    }
    try {
      final n = await _firebaseService.getDatosNegocio();
      if (mounted) setState(() => _negocio = n);
    } catch (_) {}
  }

  @override
  void dispose() {
    _catalogoSub?.cancel(); // [FinOps] Cancelar stream al salir de la pantalla
    ConfiguracionController.instance.removeListener(_onConfigChanged);
    _debounceTimer?.cancel();
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
    if (!mounted) return;

    double? cantidad;

    if (producto.permiteDecimales) {
      final TextEditingController ctrl = TextEditingController(text: '1');
      cantidad = await showDialog<double>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('¿Qué cantidad deseas agregar?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Producto: ${producto.nombre}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Stock disponible: ${producto.cantidad.formatoInventario}'),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Cantidad',
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
                  if (c > producto.cantidad) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Stock insuficiente: solo hay ${producto.cantidad.formatoInventario} disponibles'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
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
    } else {
      // Comportamiento estándar: agrega 1 unidad automáticamente
      if (producto.cantidad < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto agotado'), backgroundColor: Colors.red),
        );
        return;
      }
      cantidad = 1.0;
    }

    if (cantidad != null && cantidad > 0) {
      setState(() {
        _cacheProductos[producto.id] = producto;
        final existingIndex = _carrito.indexWhere((i) => i.productoId == producto.id);
        if (existingIndex >= 0) {
          final oldItem = _carrito[existingIndex];
          final nuevaCant = oldItem.cantidad + cantidad!;
          
          double precioFinal = _calcularPrecioUnitario(producto, nuevaCant);

          _carrito[existingIndex] = VentaItem(
            productoId: oldItem.productoId,
            nombre: oldItem.nombre,
            costoUnitario: oldItem.costoUnitario,
            precioUnitario: precioFinal,
            cantidad: nuevaCant,
          );
        } else {
          double precioFinal = _calcularPrecioUnitario(producto, cantidad!);

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
              if (val > producto.cantidad) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text('Stock insuficiente: solo hay ${producto.cantidad.formatoInventario}'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
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
    // [FinOps] Lee el PIN desde el caché en memoria — 0 lecturas a Firestore
    final negocio = _negocio ?? ConfiguracionController.instance.negocio;
    if (negocio == null) return false;
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

  // ── Lógica Omni-Box ───────────────────────────────────────────────────────

  /// Llamado por onChanged: aplica debounce y busca por nombre si hay letras.
  void _onOmniBoxChanged(String value) {
    _debounceTimer?.cancel();

    if (value.trim().isEmpty) {
      setState(() {
        _resultadosBusqueda = [];
        _mostrandoBusqueda = false;
      });
      return;
    }

    // Si el texto solo contiene dígitos, no activamos la búsqueda por nombre
    // (es un código de barras siendo escaneado — esperamos el onSubmitted)
    final soloDigitos = RegExp(r'^\d+$').hasMatch(value.trim());
    if (soloDigitos) return;

    // Hay letras: debounce de 500ms → buscar por nombre
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final query = value.trim().toLowerCase();

      // 1. Filtro local instantáneo sobre el caché
      final locales = _cacheProductos.values
          .where((p) => p.nombre.toLowerCase().contains(query))
          .toList();

      // 2. Si hay pocos resultados locales, buscar en Firestore
      List<Producto> remotos = [];
      if (locales.length < 5) {
        remotos = await _firebaseService.buscarProductosPorNombre(query);
      }

      // Fusionar evitando duplicados
      final ids = locales.map((p) => p.id).toSet();
      for (final r in remotos) {
        if (!ids.contains(r.id)) {
          locales.add(r);
          // Actualizar caché
          _cacheProductos[r.id] = r;
        }
      }

      if (mounted) {
        setState(() {
          _resultadosBusqueda = locales.take(10).toList();
          _mostrandoBusqueda = locales.isNotEmpty;
        });
      }
    });
  }

  /// Llamado por onSubmitted: lógica del escáner láser (ignora el debounce).
  Future<void> _onOmniBoxSubmitted(String code) async {
    _debounceTimer?.cancel(); // Cancelar cualquier búsqueda por nombre pendiente
    setState(() {
      _resultadosBusqueda = [];
      _mostrandoBusqueda = false;
    });

    if (code.trim().isEmpty) return;

    try {
      final p = await _firebaseService.buscarVariantePorSKU(code.trim());
      if (p != null) {
        await _pedirCantidadYAgregar(p);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Código no encontrado'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      debugPrint('Error Omni-Box scanner: $e');
    } finally {
      _barcodeCtrl.clear();
      _barcodeFocusNode.requestFocus();
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

  /// Lanza la pantalla de c\u00e1mara para escanear; al regresar procesa el c\u00f3digo.
  Future<void> _escanearParaVender() async {
    final String? codigo = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (codigo != null && codigo.isNotEmpty && mounted) {
      await _onOmniBoxSubmitted(codigo);
    }
  }

  // ── Registrar Venta ───────────────────────────────────────────────────────

  Future<void> _confirmarVenta({double pagoCliente = 0}) async {
    if (_carrito.isEmpty) return;

    setState(() => _procesando = true);

    try {
      final config = ConfiguracionController.instance;
      final usaCaja = config.negocio?.usaCajaRegistradora ?? _negocio?.usaCajaRegistradora ?? true;

      TurnoCaja? turno;
      if (usaCaja) {
        turno = await _firebaseService.getTurnoActivo();
      }

      if (usaCaja && _metodoPago == MetodoPago.efectivo && turno == null) {
        setState(() => _procesando = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Abre la caja antes de registrar ventas en efectivo.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'ABRIR CAJA',
                textColor: Colors.white,
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CajaScreen())),
              ),
            ),
          );
        }
        return;
      }

      if (_metodoPago == MetodoPago.credito && _clienteSeleccionado == null) {
        setState(() => _procesando = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecciona un cliente para ventas a crédito.'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      // Validación de stock
      List<String> productosEnNegativo = [];
      final idsCarrito = _carrito.map((i) => i.productoId).toSet().toList();
      final listaProdsFresh = await _firebaseService.getProductosPorLote(idsCarrito);
      final mapFresh = {for (var p in listaProdsFresh) p.id: p};

      for (var item in _carrito) {
        final prod = mapFresh[item.productoId];
        if (prod != null && item.cantidad > prod.cantidad) {
          productosEnNegativo.add(prod.nombre);
        }
      }

      if (productosEnNegativo.isNotEmpty) {
        setState(() => _procesando = false);
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Stock Insuficiente'),
            content: Text('Los siguientes productos no tienen stock suficiente: ${productosEnNegativo.join(', ')}'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
          ),
        );
        return;
      }

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

      // Registro en Firebase
      await _firebaseService.registrarVenta(nuevaVenta, turnoCajaId: turno?.id);

      // Guardamos datos para el ticket antes de limpiar
      final ventaFinal = nuevaVenta;
      // [FinOps] Reutilizar el negocio ya cargado en _negocio — 0 lecturas extra
      final negocioFinal = _negocio ?? await _firebaseService.getDatosNegocio();

      setState(() {
        _carrito.clear();
        _clienteSeleccionado = null;
        _metodoPago = MetodoPago.efectivo;
        _procesando = false;
        _barcodeCtrl.clear();
      });

      if (mounted) {
        // Mostrar Diálogo de Éxito y Cambio
        await _mostrarDialogoExito(
          venta: ventaFinal, 
          negocio: negocioFinal, 
          pago: pagoCliente,
          turno: turno,
        );
      }
    } catch (e) {
      setState(() => _procesando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar la venta: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _mostrarDialogoExito({
    required Venta venta, 
    required Negocio negocio, 
    required double pago,
    TurnoCaja? turno,
  }) async {
    final double cambio = (pago - venta.total).clamp(0.0, double.infinity);
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text('¡Venta Exitosa!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pago > 0) ...[
              const Text('Cambio a devolver:', style: TextStyle(fontSize: 16)),
              Text(
                '\$${cambio.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 20),
            ],
            const Text('¿Deseas imprimir el ticket de venta?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await ImpresionService.imprimirTicketVenta(
                venta: venta,
                negocio: negocio,
                pagoCliente: pago,
                turno: turno,
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('Imprimir Ticket'),
          ),
        ],
      ),
    );
  }

  Future<void> _prepararConfirmacion() async {
    if (_metodoPago == MetodoPago.efectivo) {
      final double? pago = await _mostrarDialogoCobroEfectivo();
      if (pago != null) {
        await _confirmarVenta(pagoCliente: pago);
      }
    } else {
      await _confirmarVenta(pagoCliente: _totalVenta);
    }
  }

  Future<double?> _mostrarDialogoCobroEfectivo() async {
    final ctrl = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cobro en Efectivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total a cobrar: \$${_totalVenta.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Monto Recibido',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (val) {
                final monto = double.tryParse(val) ?? 0.0;
                if (monto >= _totalVenta) Navigator.pop(ctx, monto);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final monto = double.tryParse(ctrl.text) ?? 0.0;
              if (monto < _totalVenta) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('El monto recibido es menor al total.'), backgroundColor: Colors.orange),
                );
                return;
              }
              Navigator.pop(ctx, monto);
            },
            child: const Text('Confirmar Cobro'),
          ),
        ],
      ),
    );
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
    final userData = AuthService().currentUserData;
    final bool esDueno = userData?.rol == AuthService.rolDueno;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f12): () => _confirmarVenta(),
        const SingleActivator(LogicalKeyboardKey.f10): () => _buscarProducto(),
        const SingleActivator(LogicalKeyboardKey.f8): () => setState(() => _metodoPago = MetodoPago.efectivo),
        const SingleActivator(LogicalKeyboardKey.f7): () => setState(() => _metodoPago = MetodoPago.tarjeta),
      },
      child: PopScope(
        canPop: _carrito.isEmpty,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final mustLeave = await _intentarSalir();
          if (mustLeave && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: ResponsiveScaffold(
          currentRoute: 'ventas',
          title: 'Punto de Venta',
          actions: [
            if (ConfiguracionController.instance.usaCajaRegistradora)
              FutureBuilder(
                future: _firebaseService.getTurnoActivo(),
                builder: (context, snapshot) {
                  final bool estaAbierta = snapshot.hasData && snapshot.data != null;
                  return Badge(
                    backgroundColor: estaAbierta ? Colors.green : Colors.red,
                    label: Text(estaAbierta ? 'ON' : 'OFF', style: const TextStyle(fontSize: 8)),
                    child: IconButton(
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      tooltip: 'Caja y Turnos',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CajaScreen())),
                    ),
                  );
                }
              ),
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Escanear producto',
              onPressed: _escanearParaVender,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Catálogo (F10)',
              onPressed: _buscarProducto,
            ),
          ],
          body: ResponsiveLayout(
            mobileBody: _buildMobileLayout(),
            tabletBody: _buildDesktopLayout(),
            desktopBody: _buildDesktopLayout(),
          ),
        ),
      ),
    );
  }

  // ── Layouts Responsivos ──────────────────────────────────────────────────

  Widget _buildMobileLayout() {
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          children: [
            _buildOmniBox(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_mostrandoBusqueda) _buildResultadosBusqueda(),
                    const SizedBox(height: 8),
                    _buildCarritoList(shrinkWrap: true, physics: const NeverScrollableScrollPhysics()),
                    if (isKeyboardOpen) 
                      _buildMiniFooter()
                    else 
                      _buildFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panel Izquierdo (Catálogo y Búsqueda)
        Expanded(
          flex: 6,
          child: Column(
            children: [
              _buildOmniBox(),
              if (_mostrandoBusqueda) _buildResultadosBusqueda(),
              Expanded(child: _buildDesktopGrid()),
            ],
          ),
        ),
        // Panel Derecho (Ticket de Venta)
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 12, 12, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(-2, 0))],
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Ticket Actual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(child: _buildCarritoList()),
                _buildFooter(isDesktop: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopGrid() {
    final items = _mostrandoBusqueda ? _resultadosBusqueda : _productosGlobales;
    if (items.isEmpty) {
      return const PremiumEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Catálogo Vacío',
        subtitle: 'No se encontraron productos disponibles.',
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length > 50 && !_mostrandoBusqueda ? 50 : items.length, // Limit if not searching to keep UI fast
      itemBuilder: (context, index) {
        final prod = items[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () async {
               _barcodeCtrl.clear();
               setState(() {
                 _resultadosBusqueda = [];
                 _mostrandoBusqueda = false;
               });
               await _pedirCantidadYAgregar(prod);
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Center(
                      child: Text(prod.nombre[0].toUpperCase(), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSecondaryContainer)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prod.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('\$${prod.precio.toStringAsFixed(2)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                      Text('Stock: ${prod.cantidad.formatoInventario}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOmniBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: TextField(
        controller: _barcodeCtrl,
        focusNode: _barcodeFocusNode,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Escanea un código o busca por nombre...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _barcodeCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _barcodeCtrl.clear();
                    setState(() {
                      _resultadosBusqueda = [];
                      _mostrandoBusqueda = false;
                    });
                    _barcodeFocusNode.requestFocus();
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        onChanged: _onOmniBoxChanged,
        onSubmitted: _onOmniBoxSubmitted,
      ),
    );
  }

  Widget _buildResultadosBusqueda() {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
      child: Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 14, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 6),
                Text(
                  '${_resultadosBusqueda.length} resultado(s)',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              itemCount: _resultadosBusqueda.length,
            itemBuilder: (context, i) {
              final prod = _resultadosBusqueda[i];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: Text(prod.nombre[0].toUpperCase(),
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondaryContainer)),
                ),
                title: Text(prod.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text('\$${prod.precio.toStringAsFixed(2)} · Stock: ${prod.cantidad.formatoInventario}',
                    style: const TextStyle(fontSize: 11)),
                trailing: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                onTap: () async {
                  _barcodeCtrl.clear();
                  setState(() {
                    _resultadosBusqueda = [];
                    _mostrandoBusqueda = false;
                  });
                  await _pedirCantidadYAgregar(prod);
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

  Widget _buildCarritoList({bool shrinkWrap = false, ScrollPhysics? physics}) {
    return _carrito.isEmpty
        ? const PremiumEmptyState(
            icon: Icons.shopping_basket_outlined,
            title: 'Carrito Vacío',
            subtitle: 'Escanea o busca un producto para agregar al inventario.',
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _carrito.length,
            shrinkWrap: shrinkWrap,
            physics: physics,
            itemBuilder: (context, index) {
              final item = _carrito[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: PremiumCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${item.cantidad.formatoInventario} x \$${item.precioUnitario.toStringAsFixed(2)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '\$${item.subtotal.toStringAsFixed(2)}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                  ),
                ),
              );
            },
          );
  }

  Widget _buildFooter({bool isDesktop = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDesktop ? Colors.transparent : Theme.of(context).colorScheme.surface,
        boxShadow: isDesktop ? null : const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:', style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.w600)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    '\$${_subtotalVenta.toStringAsFixed(2)}',
                    key: ValueKey<double>(_subtotalVenta),
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 0.5)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    '\$${_totalVenta.toStringAsFixed(2)}',
                    key: ValueKey<double>(_totalVenta),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ],
            ),
            // ── Sección de envíos (solo si el negocio la usa) ──
            if (ConfiguracionController.instance.negocio?.manejaEnvios ?? _negocio?.manejaEnvios ?? false) ...[
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
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            ChoiceChip(
                              label: const Text('Vendedor', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              selected: _envioPagadoPorVendedor,
                              onSelected: (v) => setState(() => _envioPagadoPorVendedor = true),
                              visualDensity: VisualDensity.compact,
                            ),
                            ChoiceChip(
                              label: const Text('Cliente', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
            ],
            const SizedBox(height: 12),
            // ── Descuento Global ─────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Descuento:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          ChoiceChip(
                            label: const Text('Ninguno', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: _tipoDescuento == TipoDescuento.ninguno,
                            onSelected: (_) {
                              setState(() {
                                _tipoDescuento = TipoDescuento.ninguno;
                                _valorDescuentoCtrl.text = '0';
                                _descuentoAutorizado = false;
                              });
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                          ChoiceChip(
                            label: const Text('Monto \$', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: _tipoDescuento == TipoDescuento.fijo,
                            onSelected: (_) => _intentarCambiarTipoDescuento(TipoDescuento.fijo),
                            visualDensity: VisualDensity.compact,
                          ),
                          ChoiceChip(
                            label: const Text('Porcen. %', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            selected: _tipoDescuento == TipoDescuento.porcentaje,
                            onSelected: (_) => _intentarCambiarTipoDescuento(TipoDescuento.porcentaje),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Visibility(
                    visible: _tipoDescuento != TipoDescuento.ninguno,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: TextField(
                      controller: _valorDescuentoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _tipoDescuento == TipoDescuento.fijo ? 'Descuento (\$)' : 'Descuento (%)',
                        isDense: true,
                        prefixIcon: const Icon(Icons.discount_outlined, size: 16),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
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
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: (_carrito.isEmpty || _procesando) ? null : _prepararConfirmacion,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _procesando
                        ? const SizedBox(key: ValueKey('loading'), width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, key: ValueKey('check')),
                  ),
                  label: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _procesando ? 'Procesando...' : 'Cobrar (F12) - \$${_totalVenta.toStringAsFixed(2)}',
                      key: ValueKey<bool>(_procesando),
                      style: const TextStyle(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Selector de Método de Pago ────────────────────────────────────────────

  Widget _buildSelectorMetodoPago() {
    final metodos = [
      (MetodoPago.efectivo, 'Efectivo (F8)', Icons.payments_outlined),
      (MetodoPago.tarjeta, 'Tarjeta (F7)', Icons.credit_card),
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
                  label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  Widget _buildMiniFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline.withAlpha(50))),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TOTAL:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.grey)),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '\$${_totalVenta.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
