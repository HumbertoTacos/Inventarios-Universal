import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/venta.dart';
import '../models/turno_caja.dart';
import '../models/movimiento_inventario.dart';
import '../models/dashboard_data.dart';
import '../models/cliente.dart';
import '../models/abono.dart';
import '../models/negocio.dart';
import '../models/bitacora_log.dart';

import 'auth_service.dart';

/// Resultado paginado que incluye la lista de productos y el cursor para la siguiente página.
class ProductosPaginadosResult {
  final List<Producto> productos;
  final DocumentSnapshot? lastDoc;
  ProductosPaginadosResult({required this.productos, this.lastDoc});
}

class FirebaseService {

  String get _negocioId {
    final id = AuthService().currentNegocioId;
    if (id.isEmpty) throw Exception("No hay negocio seleccionado");
    return id;
  }

  CollectionReference get _productosRef =>
      FirebaseFirestore.instance.collection('negocios').doc(_negocioId).collection('productos');

  CollectionReference get _categoriasRef =>
      FirebaseFirestore.instance.collection('negocios').doc(_negocioId).collection('categorias');

  CollectionReference get _ventasRef =>
      FirebaseFirestore.instance.collection('negocios').doc(_negocioId).collection('ventas');

  CollectionReference get _turnosCajaRef =>
      FirebaseFirestore.instance.collection('negocios').doc(_negocioId).collection('turnos_caja');

  CollectionReference get _kardexRef =>
      FirebaseFirestore.instance.collection('negocios').doc(_negocioId).collection('kardex');

  CollectionReference get _clientesRef =>
      FirebaseFirestore.instance.collection('negocios').doc(_negocioId).collection('clientes');

  CollectionReference get _abonosRef =>
      FirebaseFirestore.instance.collection('negocios').doc(_negocioId).collection('abonos');

  DocumentReference get _negocioDataRef =>
      FirebaseFirestore.instance.collection('negocios').doc(_negocioId);

  Reference get _storageRef =>
      FirebaseStorage.instance.ref().child('negocios').child(_negocioId);

  String get _currentUserId => AuthService().currentUser?.uid ?? 'unknown';

  // ── Productos (Optimizados) ───────────────────────────────────────────────

  /// Obtiene de manera Paginada los Productos.
  /// - Primera página (startAfter == null): siempre va al servidor
  ///   para reflejar cambios de stock recientes (ventas, ajustes).
  /// - Páginas siguientes: caché primero para reducir lecturas.
  Future<ProductosPaginadosResult> getProductosPaginados({int limite = 20, DocumentSnapshot? startAfter}) async {
    Query query = _productosRef
        .where('activo', isEqualTo: true)
        .where('esBase', isEqualTo: true)
        .orderBy('nombre')
        .limit(limite);
        
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // Primera carga → forzar servidor (stock siempre fresco)
    if (startAfter == null) {
      final snap = await query.get(const GetOptions(source: Source.server));
      return ProductosPaginadosResult(
        productos: snap.docs.map((d) => Producto.fromMap(d.data() as Map<String, dynamic>, d.id)).toList(),
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    }

    // Páginas siguientes → caché primero para ahorrar lecturas
    try {
      final snapshot = await query.get(const GetOptions(source: Source.cache));
      if (snapshot.docs.isNotEmpty) {
        return ProductosPaginadosResult(
          productos: snapshot.docs.map((d) => Producto.fromMap(d.data() as Map<String, dynamic>, d.id)).toList(),
          lastDoc: snapshot.docs.last,
        );
      }
    } catch (_) {}
    
    final onlineSnapshot = await query.get(const GetOptions(source: Source.serverAndCache));
    return ProductosPaginadosResult(
      productos: onlineSnapshot.docs.map((doc) => Producto.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList(),
      lastDoc: onlineSnapshot.docs.isNotEmpty ? onlineSnapshot.docs.last : null,
    );
  }


  /// Busca variante plana por código de barras de manera eficiente limitando la respuesta a 1
  Future<Producto?> buscarVariantePorSKU(String codigo) async {
    final query = _productosRef
        .where('activo', isEqualTo: true)
        .where('codigoBarras', isEqualTo: codigo)
        .limit(1);
    
    try {
      final cacheSnap = await query.get(const GetOptions(source: Source.cache));
      if (cacheSnap.docs.isNotEmpty) {
        return Producto.fromMap(cacheSnap.docs.first.data() as Map<String, dynamic>, cacheSnap.docs.first.id);
      }
    } catch (_) {}
    
    final serverSnap = await query.get(const GetOptions(source: Source.serverAndCache));
    if (serverSnap.docs.isNotEmpty) {
      return Producto.fromMap(serverSnap.docs.first.data() as Map<String, dynamic>, serverSnap.docs.first.id);
    }
    return null;
  }

  Future<void> agregarProducto(Producto producto) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(_productosRef.doc(), producto.toMap());
      _inyectarLogBatch(batch, 'INVENTARIO', 'Agregó nuevo producto: ${producto.nombre}');
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al agregar producto: ${e.message}');
    }
  }

  Future<void> actualizarProducto(Producto producto) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_productosRef.doc(producto.id), producto.toMap());
      _inyectarLogBatch(batch, 'INVENTARIO', 'Editó datos del producto: ${producto.nombre}');
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al actualizar producto: ${e.message}');
    }
  }

  Future<void> eliminarProducto(String id) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_productosRef.doc(id), {'activo': false});
      _inyectarLogBatch(batch, 'INVENTARIO', 'Eliminó (desactivó) producto ID: $id');
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al eliminar producto: ${e.message}');
    }
  }

  /// [FinOps] Optimización N+1: Obtiene múltiples productos en una sola consulta por lotes.
  Future<List<Producto>> getProductosPorLote(List<String> ids) async {
    if (ids.isEmpty) return [];
    // Dividimos en lotes de 30 (límite de Firestore para whereIn)
    List<Producto> results = [];
    for (var i = 0; i < ids.length; i += 30) {
      final end = (i + 30) > ids.length ? ids.length : i + 30;
      final chunk = ids.sublist(i, end);
      final snap = await _productosRef.where(FieldPath.documentId, whereIn: chunk).get();
      results.addAll(snap.docs.map((d) => Producto.fromMap(d.data() as Map<String, dynamic>, d.id)));
    }
    return results;
  }

  Future<Producto?> getProducto(String id) async {
    final doc = await _productosRef.doc(id).get();
    if (!doc.exists) return null;
    return Producto.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Método para reabastecer inventario recalculando el Costo Promedio Ponderado y registrando Kardex
  Future<void> reabastecerProducto(String productoId, double cantidadNueva, double costoCompraNuevo) async {
    final docRef = _productosRef.doc(productoId);
    
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception("El producto no existe");
        }
        
        final data = snapshot.data() as Map<String, dynamic>;
        
        final stockViejo = (data['cantidad'] as num?)?.toDouble() ?? 0.0;
        final costoViejo = (data['costo_promedio'] as num? ?? data['costo'] as num?)?.toDouble() ?? 0.0;
        
        final valorViejo = stockViejo * costoViejo;
        final valorNuevo = cantidadNueva * costoCompraNuevo;
        final nuevoStock = stockViejo + cantidadNueva;
        
        double nuevoCostoPromedio = costoViejo;
        if (nuevoStock > 0) {
          nuevoCostoPromedio = (valorViejo + valorNuevo) / nuevoStock;
        }

        // Ejecutar actualización de stock
        transaction.update(docRef, {
          'cantidad': nuevoStock,
          'costo_promedio': nuevoCostoPromedio,
        });

        // Escribir Kardex atómicamente
        final kardexDoc = _kardexRef.doc();
        final movimiento = MovimientoInventario(
          id: kardexDoc.id,
          productoId: productoId,
          tipoMovimiento: TipoMovimiento.entrada,
          cantidadAlterada: cantidadNueva,
          stockResultante: nuevoStock,
          motivo: 'Reabastecimiento/Compra',
          fecha: DateTime.now(),
          usuarioId: _currentUserId,
        );
        transaction.set(kardexDoc, movimiento.toMap());
        
        _inyectarLogTransaccional(transaction, 'INVENTARIO', 'Reabasteció ${cantidadNueva} unidades de producto ID: $productoId');
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al reabastecer producto: ${e.message}');
    }
  }

  /// Realiza un ajuste manual del inventario registrando el Kardex.
  Future<void> ajustarInventario(String productoId, double cantidad, String motivo) async {
    final docRef = _productosRef.doc(productoId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("El producto no existe");

        final currentStock = (snapshot.get('cantidad') as num).toDouble();
        final nuevoStock = currentStock + cantidad;

        transaction.update(docRef, {'cantidad': nuevoStock});

        final kardexDoc = _kardexRef.doc();
        final mov = MovimientoInventario(
          id: kardexDoc.id,
          productoId: productoId,
          tipoMovimiento: TipoMovimiento.ajuste,
          cantidadAlterada: cantidad,
          stockResultante: nuevoStock,
          motivo: motivo,
          fecha: DateTime.now(),
          usuarioId: _currentUserId,
        );
        transaction.set(kardexDoc, mov.toMap());
        
        _inyectarLogTransaccional(transaction, 'INVENTARIO', 'AJUSTE MANUAL: Ajustó inventario de producto ID: $productoId ($cantidad). Motivo: $motivo');
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al ajustar inventario: ${e.message}');
    }
  }

  // ── Categorías ────────────────────────────────────────────────────────────

  /// Stream en tiempo real de todas las categorías, ordenadas por `orden`.
  Stream<List<Categoria>> getCategorias() {
    return _categoriasRef
        .orderBy('orden')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return Categoria.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList());
  }

  /// Agrega una nueva categoría.
  Future<void> agregarCategoria(Categoria categoria) async {
    try {
      await _categoriasRef.add(categoria.toMap());
    } on FirebaseException catch (e) {
      throw Exception('Error al agregar categoría: ${e.message}');
    }
  }

  /// Devuelve cuántos productos usan la categoría con ese [nombreCategoria].
  Future<int> contarProductosPorCategoria(String nombreCategoria) async {
    final snapshot = await _productosRef
        .where('categoria', isEqualTo: nombreCategoria)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// Elimina una categoría por su [id]. Verificar antes que no tenga productos.
  Future<void> eliminarCategoria(String id) async {
    try {
      await _categoriasRef.doc(id).delete();
    } on FirebaseException catch (e) {
      throw Exception('Error al eliminar categoría: ${e.message}');
    }
  }

  /// Siembra las categorías iniciales SOLO si la colección está vacía.
  Future<void> sembrarCategorias() async {
    final snapshot = await _categoriasRef.limit(1).get();
    if (snapshot.docs.isNotEmpty) return; // Ya hay datos, no sembrar

    List<AtributoCategoria> atributosTamanoColor(List<String> tamanos) {
      return [
        AtributoCategoria(
            nombre: 'Tamaño', esListaFija: true, opciones: tamanos),
        AtributoCategoria(nombre: 'Color', esListaFija: false),
      ];
    }

    final categorias = [
      Categoria(id: '', nombre: 'Sábanas', atributos: atributosTamanoColor(['Individual', 'Matrimonial', 'Queen', 'King']), orden: 1),
      Categoria(id: '', nombre: 'Cortinas', atributos: atributosTamanoColor(['Unitalla']), orden: 2),
      Categoria(id: '', nombre: 'Fundas de almohada', atributos: atributosTamanoColor(['Matrimonial', 'King']), orden: 3),
      Categoria(id: '', nombre: 'Cobertores Lisos', atributos: atributosTamanoColor(['Individual', 'Matrimonial', 'Queen', 'King']), orden: 4),
      Categoria(id: '', nombre: 'Cobertores Diseños', atributos: [
        AtributoCategoria(nombre: 'Tamaño', esListaFija: true, opciones: ['Individual', 'Matrimonial', 'Queen', 'King']),
        AtributoCategoria(nombre: 'Diseño', esListaFija: false),
      ], orden: 5),
      Categoria(id: '', nombre: 'Colchas', atributos: atributosTamanoColor(['Matrimonial', 'Queen', 'King']), orden: 6),
      Categoria(id: '', nombre: 'Cubre sillas', atributos: atributosTamanoColor(['Unitalla']), orden: 7),
      Categoria(id: '', nombre: 'Cubre sillones', atributos: atributosTamanoColor(['Unitalla']), orden: 8),
      Categoria(id: '', nombre: 'Almohada viajera', atributos: atributosTamanoColor(['Unitalla']), orden: 9),
    ];

    final batch = FirebaseFirestore.instance.batch();
    for (final cat in categorias) {
      batch.set(_categoriasRef.doc(), cat.toMap());
    }
    await batch.commit();
  }

  // ── Bitácora (Audit Trail) ───────────────────────────────────────────────

  final CollectionReference _bitacoraRef = FirebaseFirestore.instance.collection('bitacora');

  /// Genera un Map para el log de bitácora (Helper Interno para Atomicidad)
  Map<String, dynamic> _generarLogMap(String modulo, String descripcion) {
    final user = AuthService().currentUserData;
    return {
      'fecha': DateTime.now().toIso8601String(),
      'usuarioId': _currentUserId,
      'nombreUsuario': user?.nombre ?? 'Desconocido',
      'negocioId': _negocioId,
      'modulo': modulo,
      'descripcion': descripcion,
    };
  }

  /// Inyecta un log dentro de una transacción de Firestore (Atomicidad 100%)
  void _inyectarLogTransaccional(Transaction transaction, String modulo, String descripcion) {
    transaction.set(_bitacoraRef.doc(), _generarLogMap(modulo, descripcion));
  }

  /// Inyecta un log dentro de un WriteBatch (Atomicidad 100%)
  void _inyectarLogBatch(WriteBatch batch, String modulo, String descripcion) {
    batch.set(_bitacoraRef.doc(), _generarLogMap(modulo, descripcion));
  }

  // ── Arqueo de Caja (Turnos) ───────────────────────────────────────────────

  /// Crea un nuevo turno de caja abierto
  Future<void> abrirTurnoCaja(TurnoCaja turno) async {
    try {
      final docTurno = _turnosCajaRef.doc();
      final turnoGuardar = TurnoCaja(
        id: docTurno.id,
        fechaApertura: turno.fechaApertura,
        fondoInicial: turno.fondoInicial,
        estado: EstadoTurno.abierto,
      );
      final batch = FirebaseFirestore.instance.batch();
      batch.set(docTurno, turnoGuardar.toMap());
      _inyectarLogBatch(batch, 'CAJA', 'Abrió caja con un fondo inicial de \$${turno.fondoInicial.toStringAsFixed(2)}');
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al abrir caja: ${e.message}');
    }
  }

  /// Cierra un turno de caja existente, actualizando efectivo físico y fecha
  Future<void> cerrarTurnoCaja(String turnoId, double efectivoContado) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_turnosCajaRef.doc(turnoId), {
        'estado': EstadoTurno.cerrado.name,
        'fechaCierre': DateTime.now().toIso8601String(),
        'efectivoContado': efectivoContado,
      });
      _inyectarLogBatch(batch, 'CAJA', 'Cerró caja. Efectivo en mostrador: \$${efectivoContado.toStringAsFixed(2)}');
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al cerrar caja: ${e.message}');
    }
  }

  /// Obtiene el turno de caja abierto actual (si hay alguno)
  Future<TurnoCaja?> getTurnoActivo() async {
    final snapshot = await _turnosCajaRef
        .where('estado', isEqualTo: EstadoTurno.abierto.name)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return TurnoCaja.fromMap(
        snapshot.docs.first.data() as Map<String, dynamic>,
        snapshot.docs.first.id);
  }

  /// Registra un gasto o retiro de efectivo del turno actual
  Future<void> registrarRetiroCaja(String turnoId, double monto, String concepto) async {
    try {
      final docRef = _turnosCajaRef.doc(turnoId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Turno no encontrado');
        
        final data = snapshot.data() as Map<String, dynamic>;
        final retirosActuales = (data['retirosEfectivo'] as num?)?.toDouble() ?? 0.0;
        final historial = (data['historialRetiros'] as List<dynamic>?)?.toList() ?? [];
        
        historial.add({
          'monto': monto,
          'concepto': concepto,
          'hora': DateTime.now().toIso8601String(),
        });

        transaction.update(docRef, {
          'retirosEfectivo': retirosActuales + monto,
          'historialRetiros': historial,
        });
        
        _inyectarLogTransaccional(transaction, 'CAJA', 'Retiró \$${monto.toStringAsFixed(2)} de caja. Concepto: $concepto');
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al registrar retiro: ${e.message}');
    }
  }

  // ── Ventas ────────────────────────────────────────────────────────────────

  Future<void> registrarVenta(Venta venta, {String? turnoCajaId}) async {
    // Validación de crédito
    if (venta.metodoPago == MetodoPago.credito) {
      if (venta.clienteId == null || venta.clienteId!.isEmpty) {
        throw Exception('Debes seleccionar un cliente para ventas a crédito.');
      }
    }

    // Si la venta es en efectivo, exigimos que nos pasen el ID del turno actual
    if (venta.metodoPago == MetodoPago.efectivo && turnoCajaId == null) {
      throw Exception('Se requiere una caja abierta para registrar ventas en efectivo.');
    }

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Lecturas obligatorias antes de escrituras
        DocumentSnapshot? docTurnoSnapshot;
        if (turnoCajaId != null) {
          docTurnoSnapshot = await transaction.get(_turnosCajaRef.doc(turnoCajaId));
          if (!docTurnoSnapshot.exists) throw Exception('El turno de caja no existe.');
          if (docTurnoSnapshot.get('estado') != EstadoTurno.abierto.name) {
            throw Exception('El turno de caja ya está cerrado.');
          }
        }

        // 1b. Si es crédito, leer y validar el cliente
        DocumentSnapshot? docClienteSnapshot;
        if (venta.metodoPago == MetodoPago.credito && venta.clienteId != null) {
          docClienteSnapshot = await transaction.get(_clientesRef.doc(venta.clienteId!));
          if (!docClienteSnapshot.exists) throw Exception('El cliente no existe.');
          final clienteData = docClienteSnapshot.data() as Map<String, dynamic>;
          final limiteCredito = (clienteData['limiteCredito'] as num?)?.toDouble() ?? 0.0;
          final saldoActual = (clienteData['saldoDeudor'] as num?)?.toDouble() ?? 0.0;

          if (limiteCredito <= 0) {
            throw Exception('Este cliente tiene el crédito bloqueado (límite = \$0).');
          }
          if (saldoActual + venta.total > limiteCredito) {
            final disponible = limiteCredito - saldoActual;
            throw Exception(
              'Límite de crédito insuficiente. '
              'Disponible: \$${disponible.toStringAsFixed(2)}, '
              'Requerido: \$${venta.total.toStringAsFixed(2)}.',
            );
          }
        }

        // Leer productos para validar stock
        Map<String, DocumentSnapshot> productosSnaps = {};
        for (final item in venta.items) {
          final docSnap = await transaction.get(_productosRef.doc(item.productoId));
          if (!docSnap.exists) throw Exception('El producto ${item.nombre} ya no existe.');
          productosSnaps[item.productoId] = docSnap;
        }

        // 2. Escrituras
        // a) Guardar la venta
        final docVenta = _ventasRef.doc();
        final ventaParaGuardar = Venta(
          id: docVenta.id,
          fecha: venta.fecha,
          items: venta.items,
          costoEnvio: venta.costoEnvio,
          envioPagadoPorVendedor: venta.envioPagadoPorVendedor,
          estado: venta.estado,
          metodoPago: venta.metodoPago,
          tipoDescuento: venta.tipoDescuento,
          valorDescuento: venta.valorDescuento,
          clienteId: venta.clienteId,
        );
        transaction.set(docVenta, ventaParaGuardar.toMap());

        // b) Descontar inventario y registrar Kardex de Salida
        for (final item in venta.items) {
          final ref = _productosRef.doc(item.productoId);
          final currentStock = (productosSnaps[item.productoId]!.get('cantidad') as num).toInt();
          final newStock = currentStock - item.cantidad;
          
          transaction.update(ref, {'cantidad': newStock});

          final kardexDoc = _kardexRef.doc();
          final mov = MovimientoInventario(
            id: kardexDoc.id,
            productoId: item.productoId,
            tipoMovimiento: TipoMovimiento.salida,
            cantidadAlterada: -item.cantidad,
            stockResultante: newStock,
            motivo: 'Venta realizada (POS)',
            fecha: DateTime.now(),
            usuarioId: _currentUserId,
          );
          transaction.set(kardexDoc, mov.toMap());
        }

        // c) Si es crédito, actualizar saldo del cliente
        if (venta.metodoPago == MetodoPago.credito &&
            venta.clienteId != null &&
            docClienteSnapshot != null) {
          final refCliente = _clientesRef.doc(venta.clienteId!);
          final saldoActual = (docClienteSnapshot.data() as Map<String, dynamic>)['saldoDeudor'] ?? 0.0;
          transaction.update(refCliente, {
            'saldoDeudor': saldoActual + ventaParaGuardar.total,
          });
        }

        // d) Actualizar turno de caja según método de pago
        if (turnoCajaId != null && docTurnoSnapshot != null) {
          final refTurno = _turnosCajaRef.doc(turnoCajaId);
          String campoActualizar;
          switch (venta.metodoPago) {
            case MetodoPago.efectivo:
              campoActualizar = 'ventasEfectivo';
              break;
            case MetodoPago.tarjeta:
              campoActualizar = 'ventasTarjeta';
              break;
            case MetodoPago.transferencia:
              campoActualizar = 'ventasTransferencia';
              break;
            case MetodoPago.credito:
              campoActualizar = 'ventasCredito';
              break;
          }
          final valorActual = (docTurnoSnapshot.data() as Map<String, dynamic>)[campoActualizar] ?? 0.0;
          transaction.update(refTurno, {
            campoActualizar: valorActual + ventaParaGuardar.total,
          });
        }
        
        _inyectarLogTransaccional(transaction, 'VENTAS', 'Registró venta exitosa por \$${venta.total.toStringAsFixed(2)} (${venta.metodoPago.name})');
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al registrar venta (Firebase): ${e.message}');
    } catch (e) {
      throw Exception('Error en transacción de venta: $e');
    }
  }

  Future<void> cancelarVenta(Venta venta) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docVenta = _ventasRef.doc(venta.id);
        
        // 1. Lecturas (Productos para obtener su stock actual y evitar fallos del Kardex)
        Map<String, DocumentSnapshot> productosSnaps = {};
        for (final item in venta.items) {
          final docSnap = await transaction.get(_productosRef.doc(item.productoId));
          if (!docSnap.exists) throw Exception("Producto ${item.nombre} no existe");
          productosSnaps[item.productoId] = docSnap;
        }

        // 2. Escrituras
        // a) Cambiar estado
        transaction.update(docVenta, {'estado': 'cancelada'});

        // b) Devolver productos al inventario y Kardex
        for (final item in venta.items) {
          final ref = _productosRef.doc(item.productoId);
          final currentStock = (productosSnaps[item.productoId]!.get('cantidad') as num).toInt();
          final newStock = currentStock + item.cantidad;
          
          transaction.update(ref, {'cantidad': newStock});

          final kardexDoc = _kardexRef.doc();
          final mov = MovimientoInventario(
            id: kardexDoc.id,
            productoId: item.productoId,
            tipoMovimiento: TipoMovimiento.entrada,
            cantidadAlterada: item.cantidad,
            stockResultante: newStock,
            motivo: 'Cancelación de Venta',
            fecha: DateTime.now(),
            usuarioId: _currentUserId,
          );
          transaction.set(kardexDoc, mov.toMap());
        }

        // 3. Reversión financiera (Bug Fix QA)
        if (venta.metodoPago == MetodoPago.efectivo) {
          // Buscamos el turno abierto de forma atómica si es posible, 
          // o usamos una lectura previa si no. Aquí buscaremos el activo.
          final turnosQuery = await _turnosCajaRef
              .where('estado', isEqualTo: EstadoTurno.abierto.name)
              .limit(1)
              .get();
          
          if (turnosQuery.docs.isNotEmpty) {
            final turnoDoc = turnosQuery.docs.first;
            final ventasEfectivoActual = (turnoDoc.get('ventasEfectivo') as num?)?.toDouble() ?? 0.0;
            transaction.update(turnoDoc.reference, {
              'ventasEfectivo': ventasEfectivoActual - venta.total,
            });
          }
        } else if (venta.metodoPago == MetodoPago.credito && venta.clienteId != null) {
          final refCliente = _clientesRef.doc(venta.clienteId!);
          final snapCliente = await transaction.get(refCliente);
          if (snapCliente.exists) {
            final saldoActual = (snapCliente.get('saldoDeudor') as num?)?.toDouble() ?? 0.0;
            transaction.update(refCliente, {
              'saldoDeudor': (saldoActual - venta.total).clamp(0.0, double.infinity),
            });
          }
        }
        
        _inyectarLogTransaccional(transaction, 'VENTAS', 'CANCELACION: Canceló la venta #${venta.id} por \$${venta.total.toStringAsFixed(2)}');
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al cancelar venta: ${e.message}');
    }
  }

  Future<void> devolverVenta({
    required Venta venta,
    required double costoEnvioDevolucion,
    required bool volverAVender,
  }) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docVenta = _ventasRef.doc(venta.id);

        Map<String, DocumentSnapshot> productosSnaps = {};
        if (volverAVender) {
          for (final item in venta.items) {
            final docSnap = await transaction.get(_productosRef.doc(item.productoId));
            if (!docSnap.exists) throw Exception("Producto ${item.nombre} no existe");
            productosSnaps[item.productoId] = docSnap;
          }
        }

        transaction.update(docVenta, {
          'estado': 'devuelta',
          'costoEnvioDevolucion': costoEnvioDevolucion,
          'devueltoAlInventario': volverAVender,
        });

        if (volverAVender) {
          for (final item in venta.items) {
            final ref = _productosRef.doc(item.productoId);
            final currentStock = (productosSnaps[item.productoId]!.get('cantidad') as num).toInt();
            final newStock = currentStock + item.cantidad;
            
            transaction.update(ref, {'cantidad': newStock});

            final kardexDoc = _kardexRef.doc();
            final mov = MovimientoInventario(
              id: kardexDoc.id,
              productoId: item.productoId,
              tipoMovimiento: TipoMovimiento.entrada,
              cantidadAlterada: item.cantidad,
              stockResultante: newStock,
              motivo: 'Devolución de Venta',
              fecha: DateTime.now(),
              usuarioId: _currentUserId,
            );
            transaction.set(kardexDoc, mov.toMap());
          }
        }

        // 3. Reversión financiera (Bug Fix QA)
        if (venta.metodoPago == MetodoPago.efectivo) {
          final turnosQuery = await _turnosCajaRef
              .where('estado', isEqualTo: EstadoTurno.abierto.name)
              .limit(1)
              .get();
          
          if (turnosQuery.docs.isNotEmpty) {
            final turnoDoc = turnosQuery.docs.first;
            final ventasEfectivoActual = (turnoDoc.get('ventasEfectivo') as num?)?.toDouble() ?? 0.0;
            transaction.update(turnoDoc.reference, {
              'ventasEfectivo': ventasEfectivoActual - venta.total,
            });
          }
        } else if (venta.metodoPago == MetodoPago.credito && venta.clienteId != null) {
          final refCliente = _clientesRef.doc(venta.clienteId!);
          final snapCliente = await transaction.get(refCliente);
          if (snapCliente.exists) {
            final saldoActual = (snapCliente.get('saldoDeudor') as num?)?.toDouble() ?? 0.0;
            transaction.update(refCliente, {
              'saldoDeudor': (saldoActual - venta.total).clamp(0.0, double.infinity),
            });
          }
        }
        
        final modo = volverAVender ? 'Devolución al inventario' : 'Reembolso sin retorno de stock';
        _inyectarLogTransaccional(transaction, 'VENTAS', 'DEVOLUCION: $modo de la venta #${venta.id} por \$${venta.total.toStringAsFixed(2)}');
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al registrar devolución: ${e.message}');
    }
  }

  // ── Estadísticas y Ganancias ──────────────────────────────────────────────

  /// Obtiene historial paginado de ventas
  Future<List<Venta>> getVentasPaginadas({int limite = 20, DocumentSnapshot? startAfter}) async {
    Query query = _ventasRef
        .orderBy('fecha', descending: true)
        .limit(limite);
        
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    
    final snapshot = await query.get(const GetOptions(source: Source.serverAndCache));
    return snapshot.docs.map((doc) => Venta.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  /// Obtiene ventas en un rango de fechas
  Stream<List<Venta>> getVentasPorRango(DateTime inicio, DateTime fin) {
    return _ventasRef
        .where('fecha', isGreaterThanOrEqualTo: inicio.toIso8601String())
        .where('fecha', isLessThanOrEqualTo: fin.toIso8601String())
        .orderBy('fecha', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return Venta.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList());
  }

  /// Calcula el capital total congelado en el inventario
  Future<double> getCapitalEnInventario() async {
    final snapshot = await _productosRef.get();
    double totalCapital = 0.0;
    
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final stock = (data['cantidad'] as num?)?.toInt() ?? 0;
      final costoPromedio = (data['costo_promedio'] as num? ?? data['costo'] as num?)?.toDouble() ?? 0.0;
      
      if (stock > 0) {
        totalCapital += (stock * costoPromedio);
      }
    }
    
    return totalCapital;
  }

  /// Retorna datos analíticos para el Dashboard, filtrando por los últimos [dias] días.
  /// Optimizado: solo lee ventas dentro del rango de fechas, no toda la colección.
  Future<DashboardData> getDashboardData({int dias = 7}) async {
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, ahora.day)
        .subtract(Duration(days: dias - 1));
    final inicioStr = inicio.toIso8601String();

    // [FinOps] Optimización: Obtenemos agregaciones globales del servidor en una sola lectura
    final aggQuery = _ventasRef
        .where('estado', isEqualTo: 'completada')
        .where('fecha', isGreaterThanOrEqualTo: inicioStr)
        .orderBy('fecha');
    
    final aggregateSnapshot = await aggQuery.aggregate(sum('total'), count()).get();
    final double serverTotalIngresos = (aggregateSnapshot.getSum('total') ?? 0).toDouble();
    final int serverTotalVentas = aggregateSnapshot.count ?? 0;

    final snapshot = await _ventasRef
        .where('fecha', isGreaterThanOrEqualTo: inicioStr)
        .orderBy('fecha', descending: false)
        .get(const GetOptions(source: Source.serverAndCache));

    final ventas = snapshot.docs
        .map((d) => Venta.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();

    final fmt = DateFormat('MM/dd');
    final ingresosPorDia = <String, double>{};
    final costosPorDia = <String, double>{};
    final contadores = <String, double>{};
    final nombres = <String, String>{};
    final ingresosProd = <String, double>{};

    double ingresosTotales = 0;
    double costosTotales = 0;
    int totalVentas = 0;

    for (final v in ventas) {
      if (v.estado == 'cancelada') continue;

      final key = fmt.format(v.fecha);
      ingresosPorDia[key] ??= 0;
      costosPorDia[key] ??= 0;

      if (v.estado == 'completada') {
        totalVentas++;
        for (final item in v.items) {
          final ing = item.precioUnitario * item.cantidad;
          final cos = item.costoUnitario * item.cantidad;
          ingresosPorDia[key] = ingresosPorDia[key]! + ing;
          costosPorDia[key] = costosPorDia[key]! + cos;
          ingresosTotales += ing;
          costosTotales += cos;
          contadores[item.productoId] = (contadores[item.productoId] ?? 0) + item.cantidad;
          nombres[item.productoId] = item.nombre;
          ingresosProd[item.productoId] = (ingresosProd[item.productoId] ?? 0) + ing;
        }
        if (v.costoEnvio > 0) {
          if (v.envioPagadoPorVendedor) {
            costosPorDia[key] = costosPorDia[key]! + v.costoEnvio;
            costosTotales += v.costoEnvio;
          } else {
            ingresosPorDia[key] = ingresosPorDia[key]! + v.costoEnvio;
            ingresosTotales += v.costoEnvio;
          }
        }
      } else if (v.estado == 'devuelta') {
        if (!v.devueltoAlInventario) {
          for (final item in v.items) {
            final cos = item.costoUnitario * item.cantidad;
            costosPorDia[key] = costosPorDia[key]! + cos;
            costosTotales += cos;
          }
        }
        if (v.costoEnvioDevolucion > 0) {
          costosPorDia[key] = costosPorDia[key]! + v.costoEnvioDevolucion;
          costosTotales += v.costoEnvioDevolucion;
        }
      }
    }

    final ganancia = ingresosTotales - costosTotales;
    final margen = ingresosTotales > 0 ? (ganancia / ingresosTotales) * 100 : 0.0;

    final top = (contadores.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(5)
        .map((e) => TopProducto(
              productoId: e.key,
              nombre: nombres[e.key] ?? 'Desconocido',
              cantidadVendida: e.value,
              ingresoGenerado: ingresosProd[e.key] ?? 0,
            ))
        .toList();

    return DashboardData(
      ingresosPorDia: ingresosPorDia,
      costosPorDia: costosPorDia,
      ingresosTotales: ingresosTotales,
      costosTotales: costosTotales,
      gananciaBruta: ganancia,
      margenPorcentaje: margen,
      totalVentas: totalVentas,
      topProductos: top,
      diasConsultados: dias,
    );
  }

  /// Productos con stock por debajo del umbral de alerta.
  Future<List<Producto>> getProductosBajoStock({int umbral = 5}) async {
    final snap = await _productosRef
        .where('activo', isEqualTo: true)
        .where('esBase', isEqualTo: true)
        .where('cantidad', isLessThanOrEqualTo: umbral)
        .orderBy('cantidad')
        .get(const GetOptions(source: Source.serverAndCache));
    return snap.docs
        .map((d) => Producto.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  // ── Clientes ──────────────────────────────────────────────────────────────

  Future<String> agregarCliente(Cliente cliente) async {
    final doc = await _clientesRef.add(cliente.toMap()
      ..['fechaRegistro'] = DateTime.now().toIso8601String());
    return doc.id;
  }

  Future<void> actualizarCliente(Cliente cliente) async {
    await _clientesRef.doc(cliente.id).update(cliente.toMap());
  }

  Future<void> eliminarCliente(String clienteId) async {
    await _clientesRef.doc(clienteId).delete();
  }

  /// Stream paginado de clientes ordenados por nombre.
  Stream<List<Cliente>> getClientesStream() {
    return _clientesRef
        .orderBy('nombre')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Cliente.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Busca clientes cuyo nombre empiece con [query] (prefix search).
  Future<List<Cliente>> buscarClientes(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim();
    final snap = await _clientesRef
        .where('nombre', isGreaterThanOrEqualTo: q)
        .where('nombre', isLessThan: '$q\uf8ff')
        .limit(10)
        .get();
    return snap.docs
        .map((d) => Cliente.fromMap(d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  Future<Cliente?> getCliente(String clienteId) async {
    final doc = await _clientesRef.doc(clienteId).get();
    if (!doc.exists) return null;
    return Cliente.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  // ── Abonos ────────────────────────────────────────────────────────────────

  /// Registra un abono de forma atómica:
  /// 1. Guarda el abono en la subcolección `abonos`.
  /// 2. Resta el monto del saldoDeudor del cliente.
  /// 3. Si el abono es en efectivo, suma al turno de caja activo.
  Future<void> registrarAbono(Abono abono) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // ── Lecturas ────────────────────────────────────────────────────
        final docCliente = await transaction.get(_clientesRef.doc(abono.clienteId));
        if (!docCliente.exists) throw Exception('Cliente no encontrado.');
        final saldoActual = (docCliente.data() as Map<String, dynamic>)['saldoDeudor'] as num? ?? 0.0;
        if (abono.monto > saldoActual) {
          throw Exception(
            'El abono (\$${abono.monto.toStringAsFixed(2)}) supera la deuda actual (\$${saldoActual.toStringAsFixed(2)}).',
          );
        }

        // Si el abono es en efectivo, buscamos el turno activo
        DocumentSnapshot? docTurno;
        if (abono.metodoPago == MetodoPago.efectivo) {
          final turnoSnap = await _turnosCajaRef
              .where('estado', isEqualTo: EstadoTurno.abierto.name)
              .limit(1)
              .get();
          if (turnoSnap.docs.isNotEmpty) {
            docTurno = await transaction.get(_turnosCajaRef.doc(turnoSnap.docs.first.id));
          }
        }

        // ── Escrituras ──────────────────────────────────────────────────
        // a) Guardar el abono
        final docAbono = _abonosRef.doc();
        transaction.set(docAbono, {
          ...abono.toMap(),
        });

        // b) Restar saldo del cliente
        transaction.update(_clientesRef.doc(abono.clienteId), {
          'saldoDeudor': (saldoActual - abono.monto).clamp(0.0, double.infinity),
        });

        // c) Sumar al turno de caja si el abono es en efectivo
        if (docTurno != null) {
          final ventasEfActual = (docTurno.data() as Map<String, dynamic>)['ventasEfectivo'] as num? ?? 0.0;
          transaction.update(docTurno.reference, {
            'ventasEfectivo': ventasEfActual + abono.monto,
          });
        }

        _inyectarLogTransaccional(transaction, 'CREDITOS', 'Registró abono de \$${abono.monto.toStringAsFixed(2)} para el cliente ID: ${abono.clienteId}');
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al registrar abono: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// Historial de abonos de un cliente en tiempo real.
  Stream<List<Abono>> getAbonosPorCliente(String clienteId) {
    return _abonosRef
        .where('clienteId', isEqualTo: clienteId)
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => Abono.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  // ── Datos del Negocio ────────────────────────────────────────────────────

  Future<Negocio> getDatosNegocio() async {
    final doc = await _negocioDataRef.get();
    if (doc.exists) {
      return Negocio.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return Negocio(id: _negocioId, nombre: 'Mi Negocio');
  }

  Future<void> actualizarDatosNegocio(Negocio negocio) async {
    await _negocioDataRef.set(negocio.toMap(), SetOptions(merge: true));
  }

  Future<String> subirLogoNegocio(Uint8List imageBytes) async {
    final ref = _storageRef.child('logo.jpg');
    final uploadTask = await ref.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
    return await uploadTask.ref.getDownloadURL();
  }
}
