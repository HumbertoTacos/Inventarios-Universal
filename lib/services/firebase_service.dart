import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/venta.dart';
import '../models/turno_caja.dart';
import '../models/movimiento_caja.dart';
import '../models/movimiento_inventario.dart';
import '../models/dashboard_data.dart';
import '../models/cliente.dart';
import '../models/abono.dart';
import '../models/negocio.dart';
import '../models/bitacora_log.dart';
import '../models/proveedor.dart';
import '../models/compra.dart';
import '../models/cuenta_por_pagar.dart';
import '../models/movimiento_kardex.dart';

import 'auth_service.dart';
import 'network_service.dart';

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

  String? getNegocioIdOrNull() {
    final id = AuthService().currentNegocioId;
    return id.isEmpty ? null : id;
  }

  CollectionReference get _productosRef => FirebaseFirestore.instance
      .collection('negocios')
      .doc(_negocioId)
      .collection('productos');

  CollectionReference get _categoriasRef => FirebaseFirestore.instance
      .collection('negocios')
      .doc(_negocioId)
      .collection('categorias');

  CollectionReference get _ventasRef => FirebaseFirestore.instance
      .collection('negocios')
      .doc(_negocioId)
      .collection('ventas');

  CollectionReference get _turnosCajaRef => FirebaseFirestore.instance
      .collection('negocios')
      .doc(_negocioId)
      .collection('turnos_caja');

  CollectionReference get _kardexRef => FirebaseFirestore.instance
      .collection('negocios')
      .doc(_negocioId)
      .collection('kardex');

  CollectionReference get _comprasRef => FirebaseFirestore.instance
      .collection('negocios')
      .doc(_negocioId)
      .collection('compras');

  CollectionReference get _cuentasPorPagarRef => FirebaseFirestore.instance
      .collection('negocios')
      .doc(_negocioId)
      .collection('cuentas_por_pagar');

  CollectionReference get _clientesRef => FirebaseFirestore.instance
      .collection('negocios')
      .doc(_negocioId)
      .collection('clientes');

  CollectionReference get _abonosRef => FirebaseFirestore.instance
      .collection('negocios')
      .doc(_negocioId)
      .collection('abonos');

  CollectionReference get _proveedoresRef => FirebaseFirestore.instance
      .collection('negocios')
      .doc(_negocioId)
      .collection('proveedores');

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
  Future<ProductosPaginadosResult> getProductosPaginados({
    int limite = 20,
    DocumentSnapshot? startAfter,
    String? categoriaId,
    String? proveedorId,
  }) async {
    Query query = _productosRef
        .where('activo', isEqualTo: true)
        .where('esBase', isEqualTo: true);

    if (categoriaId != null && categoriaId.isNotEmpty) {
      query = query.where('categoriaId', isEqualTo: categoriaId);
    }
    if (proveedorId != null && proveedorId.isNotEmpty) {
      query = query.where('proveedorId', isEqualTo: proveedorId);
    }

    query = query.orderBy('nombre').limit(limite);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    // Primera carga → forzar servidor (stock siempre fresco)
    if (startAfter == null) {
      final snap = await query.get(const GetOptions(source: Source.server));
      return ProductosPaginadosResult(
        productos: snap.docs
            .map(
              (d) => Producto.fromMap(d.data() as Map<String, dynamic>, d.id),
            )
            .toList(),
        lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null,
      );
    }

    // Páginas siguientes → caché primero para ahorrar lecturas
    try {
      final snapshot = await query.get(const GetOptions(source: Source.cache));
      if (snapshot.docs.isNotEmpty) {
        return ProductosPaginadosResult(
          productos: snapshot.docs
              .map(
                (d) => Producto.fromMap(d.data() as Map<String, dynamic>, d.id),
              )
              .toList(),
          lastDoc: snapshot.docs.last,
        );
      }
    } catch (_) {}

    final onlineSnapshot = await query.get(
      const GetOptions(source: Source.serverAndCache),
    );
    return ProductosPaginadosResult(
      productos: onlineSnapshot.docs
          .map(
            (doc) =>
                Producto.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList(),
      lastDoc: onlineSnapshot.docs.isNotEmpty ? onlineSnapshot.docs.last : null,
    );
  }

  Stream<List<Producto>> getProductos() {
    return _productosRef
        .where('activo', isEqualTo: true)
        .where('esBase', isEqualTo: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => Producto.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// [FinOps] Stream limitado de productos — Bounded Stream para evitar sobrecostos.
  /// Usa `.limit()` obligatorio. El filtrado avanzado se realiza localmente en la UI.
  /// - [limite]: Número máximo de documentos a escuchar (default 50).
  /// - [categoriaId]: Filtra por categoría en el servidor si se proporciona.
  Stream<List<Producto>> getProductosStreamLimitado({
    int limite = 50,
    String? categoriaId,
  }) {
    Query query = _productosRef
        .where('activo', isEqualTo: true)
        .where('esBase', isEqualTo: true)
        .orderBy('nombre')
        .limit(limite); // ← Regla crítica FinOps: SIEMPRE presente

    if (categoriaId != null && categoriaId.isNotEmpty) {
      query = query.where('categoriaId', isEqualTo: categoriaId);
    }

    return query.snapshots().map(
      (snap) => snap.docs
          .map(
            (doc) =>
                Producto.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList(),
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
        return Producto.fromMap(
          cacheSnap.docs.first.data() as Map<String, dynamic>,
          cacheSnap.docs.first.id,
        );
      }
    } catch (_) {}

    final serverSnap = await query.get(
      const GetOptions(source: Source.serverAndCache),
    );
    if (serverSnap.docs.isNotEmpty) {
      return Producto.fromMap(
        serverSnap.docs.first.data() as Map<String, dynamic>,
        serverSnap.docs.first.id,
      );
    }
    return null;
  }

  Future<void> agregarProducto(Producto producto) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(_productosRef.doc(), producto.toMap());
      _inyectarLogBatch(
        batch,
        'INVENTARIO',
        'Agregó nuevo producto: ${producto.nombre}',
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al agregar producto: ${e.message}');
    }
  }

  Future<void> actualizarProducto(Producto producto) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_productosRef.doc(producto.id), producto.toMap());
      _inyectarLogBatch(
        batch,
        'INVENTARIO',
        'Editó datos del producto: ${producto.nombre}',
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al actualizar producto: ${e.message}');
    }
  }

  Future<void> eliminarProducto(String id) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_productosRef.doc(id), {'activo': false});
      _inyectarLogBatch(
        batch,
        'INVENTARIO',
        'Eliminó (desactivó) producto ID: $id',
      );
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
      final snap = await _productosRef
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(
        snap.docs.map(
          (d) => Producto.fromMap(d.data() as Map<String, dynamic>, d.id),
        ),
      );
    }
    return results;
  }

  Future<Producto?> getProducto(String id) async {
    final doc = await _productosRef.doc(id).get();
    if (!doc.exists) return null;
    return Producto.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Método para reabastecer inventario recalculando el Costo Promedio Ponderado y registrando Kardex
  Future<void> reabastecerProducto(
    String productoId,
    double cantidadNueva,
    double costoCompraNuevo,
  ) async {
    final docRef = _productosRef.doc(productoId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception("El producto no existe");
        }

        final data = snapshot.data() as Map<String, dynamic>;

        final stockViejo = (data['cantidad'] as num?)?.toDouble() ?? 0.0;
        final costoViejo =
            (data['costo_promedio'] as num? ?? data['costo'] as num?)
                ?.toDouble() ??
            0.0;

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

        _inyectarLogTransaccional(
          transaction,
          'INVENTARIO',
          'Reabasteció ${cantidadNueva} unidades de producto ID: $productoId',
        );
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al reabastecer producto: ${e.message}');
    }
  }

  /// Realiza un ajuste manual del inventario registrando el Kardex.
  Future<void> ajustarInventario(
    String productoId,
    double cantidad,
    String motivo,
  ) async {
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

        _inyectarLogTransaccional(
          transaction,
          'INVENTARIO',
          'AJUSTE MANUAL: Ajustó inventario de producto ID: $productoId ($cantidad). Motivo: $motivo',
        );
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
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            return Categoria.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList(),
        );
  }

  /// Agrega una nueva categoría.
  Future<void> agregarCategoria(Categoria categoria) async {
    try {
      await _categoriasRef.add(categoria.toMap());
    } on FirebaseException catch (e) {
      throw Exception('Error al agregar categoría: ${e.message}');
    }
  }

  /// Actualiza una categoría existente y sus productos asociados si el nombre cambió.
  Future<void> actualizarCategoria(
    Categoria categoria, {
    String? nombreAnterior,
  }) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Actualizar el documento de la categoría
      batch.update(_categoriasRef.doc(categoria.id), categoria.toMap());

      // 2. Si el nombre cambió, actualizar todos los productos que usaban el nombre viejo
      if (nombreAnterior != null && nombreAnterior != categoria.nombre) {
        final productosSnap = await _productosRef
            .where('categoria', isEqualTo: nombreAnterior)
            .get();
        for (var doc in productosSnap.docs) {
          batch.update(doc.reference, {'categoria': categoria.nombre});
        }
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al actualizar categoría: ${e.message}');
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
          nombre: 'Tamaño',
          esListaFija: true,
          opciones: tamanos,
        ),
        AtributoCategoria(nombre: 'Color', esListaFija: false),
      ];
    }

    final categorias = [
      Categoria(
        id: '',
        nombre: 'Sábanas',
        atributos: atributosTamanoColor([
          'Individual',
          'Matrimonial',
          'Queen',
          'King',
        ]),
        orden: 1,
      ),
      Categoria(
        id: '',
        nombre: 'Cortinas',
        atributos: atributosTamanoColor(['Unitalla']),
        orden: 2,
      ),
      Categoria(
        id: '',
        nombre: 'Fundas de almohada',
        atributos: atributosTamanoColor(['Matrimonial', 'King']),
        orden: 3,
      ),
      Categoria(
        id: '',
        nombre: 'Cobertores Lisos',
        atributos: atributosTamanoColor([
          'Individual',
          'Matrimonial',
          'Queen',
          'King',
        ]),
        orden: 4,
      ),
      Categoria(
        id: '',
        nombre: 'Cobertores Diseños',
        atributos: [
          AtributoCategoria(
            nombre: 'Tamaño',
            esListaFija: true,
            opciones: ['Individual', 'Matrimonial', 'Queen', 'King'],
          ),
          AtributoCategoria(nombre: 'Diseño', esListaFija: false),
        ],
        orden: 5,
      ),
      Categoria(
        id: '',
        nombre: 'Colchas',
        atributos: atributosTamanoColor(['Matrimonial', 'Queen', 'King']),
        orden: 6,
      ),
      Categoria(
        id: '',
        nombre: 'Cubre sillas',
        atributos: atributosTamanoColor(['Unitalla']),
        orden: 7,
      ),
      Categoria(
        id: '',
        nombre: 'Cubre sillones',
        atributos: atributosTamanoColor(['Unitalla']),
        orden: 8,
      ),
      Categoria(
        id: '',
        nombre: 'Almohada viajera',
        atributos: atributosTamanoColor(['Unitalla']),
        orden: 9,
      ),
    ];

    final batch = FirebaseFirestore.instance.batch();
    for (final cat in categorias) {
      batch.set(_categoriasRef.doc(), cat.toMap());
    }
    await batch.commit();
  }

  // ── Bitácora (Audit Trail) ───────────────────────────────────────────────

  CollectionReference get _bitacoraRef => FirebaseFirestore.instance
      .collection('negocios')
      .doc(_negocioId)
      .collection('bitacora');

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
  void _inyectarLogTransaccional(
    Transaction transaction,
    String modulo,
    String descripcion,
  ) {
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
        usuarioId: _currentUserId,
        fechaApertura: turno.fechaApertura,
        fondoInicial: turno.fondoInicial,
        estado: EstadoTurno.abierto,
      );
      final batch = FirebaseFirestore.instance.batch();
      batch.set(docTurno, turnoGuardar.toMap());
      _inyectarLogBatch(
        batch,
        'CAJA',
        'Abrió caja con un fondo inicial de \$${turno.fondoInicial.toStringAsFixed(2)}',
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al abrir caja: ${e.message}');
    }
  }

  /// Cierra un turno de caja existente, actualizando efectivo físico, calculando diferencia y fecha
  Future<void> cerrarTurnoCaja(String turnoId, double efectivoContado) async {
    try {
      final docRef = _turnosCajaRef.doc(turnoId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Turno no encontrado');

        final data = snapshot.data() as Map<String, dynamic>;

        final fondoInicial = (data['fondoInicial'] as num?)?.toDouble() ?? 0.0;
        final ventasEfectivo =
            (data['ventasEfectivo'] as num?)?.toDouble() ?? 0.0;
        final entradasEfectivo =
            (data['entradasEfectivo'] as num?)?.toDouble() ?? 0.0;
        final egresosEfectivo =
            (data['egresosEfectivo'] as num?)?.toDouble() ??
            (data['retirosEfectivo'] as num?)?.toDouble() ??
            0.0;

        final esperado =
            (fondoInicial + ventasEfectivo + entradasEfectivo) -
            egresosEfectivo;
        final diferencia = efectivoContado - esperado;

        transaction.update(docRef, {
          'estado': EstadoTurno.cerrado.name,
          'fechaCierre': DateTime.now().toIso8601String(),
          'efectivoContado': efectivoContado,
          'diferencia': diferencia,
        });

        _inyectarLogTransaccional(
          transaction,
          'CAJA',
          'Cerró caja. Efectivo contado: \$${efectivoContado.toStringAsFixed(2)}, Diferencia: \$${diferencia.toStringAsFixed(2)}',
        );
      });
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
      snapshot.docs.first.id,
    );
  }

  /// Helper privado para obtener el turno activo del usuario actual (si existe)
  Future<DocumentSnapshot?> _obtenerTurnoActivoDoc() async {
    final snapshot = await _turnosCajaRef
        .where('estado', isEqualTo: EstadoTurno.abierto.name)
        .where('usuarioId', isEqualTo: _currentUserId)
        .limit(1)
        .get();
    return snapshot.docs.isEmpty ? null : snapshot.docs.first;
  }

  /// Registra un movimiento de caja (ingreso o egreso) en el turno actual
  Future<void> registrarMovimientoCaja(MovimientoCaja mov) async {
    try {
      final docTurno = _turnosCajaRef.doc(mov.turnoId);
      final docMov = docTurno
          .collection('movimientos')
          .doc(mov.id.isEmpty ? null : mov.id);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docTurno);
        if (!snapshot.exists) throw Exception('Turno no encontrado');

        final data = snapshot.data() as Map<String, dynamic>;

        // 1. Registrar el movimiento en la subcolección
        final movToSave = MovimientoCaja(
          id: docMov.id,
          turnoId: mov.turnoId,
          tipo: mov.tipo,
          monto: mov.monto,
          concepto: mov.concepto,
          fecha: mov.fecha,
        );
        transaction.set(docMov, movToSave.toMap());

        // 2. Actualizar totales del turno
        if (mov.tipo == 'ingreso') {
          final entradasActuales =
              (data['entradasEfectivo'] as num?)?.toDouble() ?? 0.0;
          transaction.update(docTurno, {
            'entradasEfectivo': entradasActuales + mov.monto,
          });
          _inyectarLogTransaccional(
            transaction,
            'CAJA',
            'Ingresó \$${mov.monto.toStringAsFixed(2)} a caja. Concepto: ${mov.concepto}',
          );
        } else {
          final egresosActuales =
              (data['egresosEfectivo'] as num?)?.toDouble() ??
              (data['retirosEfectivo'] as num?)?.toDouble() ??
              0.0;
          // Mantenemos historialRetiros por compatibilidad visual si hace falta
          final historial =
              (data['historialRetiros'] as List<dynamic>?)?.toList() ?? [];
          historial.add({
            'monto': mov.monto,
            'concepto': mov.concepto,
            'hora': DateTime.now().toIso8601String(),
          });

          transaction.update(docTurno, {
            'egresosEfectivo': egresosActuales + mov.monto,
            'historialRetiros': historial,
          });
          _inyectarLogTransaccional(
            transaction,
            'CAJA',
            'Retiró \$${mov.monto.toStringAsFixed(2)} de caja. Concepto: ${mov.concepto}',
          );
        }
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al registrar movimiento: ${e.message}');
    }
  }

  // ── Ventas ────────────────────────────────────────────────────────────────

  Future<void> registrarVenta(Venta venta, {String? turnoCajaId, bool isSyncing = false}) async {
    // ── INTERCEPTOR OFFLINE ──
    if (!isSyncing && NetworkService().isOffline) {
      final outboxRef = FirebaseFirestore.instance
          .collection('negocios')
          .doc(_negocioId)
          .collection('cola_offline')
          .doc();
      
      await outboxRef.set({
        'id': outboxRef.id,
        'tipoOperacion': 'registrarVenta',
        'payload': venta.toMap(),
        'estado': 'pendiente',
        'fechaCreacion': DateTime.now().toIso8601String(),
      });
      return; // Retornamos éxito inmediato a la UI
    }

    // Validación de crédito
    if (venta.metodoPago == MetodoPago.credito) {
      if (venta.clienteId == null || venta.clienteId!.isEmpty) {
        throw Exception('Debes seleccionar un cliente para ventas a crédito.');
      }
    }

    // El chequeo de caja abierta se movió dentro de la transacción
    // para validar si el negocio realmente la usa (FinOps/UX).

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Lecturas obligatorias antes de escrituras
        // a) Datos del negocio (para validar si usa caja)
        final snapNegocio = await transaction.get(_negocioDataRef);
        final usaCaja = snapNegocio.exists
            ? (snapNegocio.get('usaCajaRegistradora') ?? true)
            : true;

        // b) Obtener turno de caja (opcional/flexible)

        DocumentSnapshot? docTurnoSnapshot;
        if (turnoCajaId != null) {
          docTurnoSnapshot = await transaction.get(
            _turnosCajaRef.doc(turnoCajaId),
          );
        } else if (usaCaja) {
          // Búsqueda flexible: si el negocio usa caja pero no se pasó ID, buscamos el turno activo del usuario
          final activeQuery = await _turnosCajaRef
              .where('estado', isEqualTo: EstadoTurno.abierto.name)
              .where('usuarioId', isEqualTo: _currentUserId)
              .limit(1)
              .get();
          if (activeQuery.docs.isNotEmpty) {
            docTurnoSnapshot = await transaction.get(
              activeQuery.docs.first.reference,
            );
          }
        }

        // 1b. Si es crédito, leer y validar el cliente
        DocumentSnapshot? docClienteSnapshot;
        if (venta.metodoPago == MetodoPago.credito && venta.clienteId != null) {
          docClienteSnapshot = await transaction.get(
            _clientesRef.doc(venta.clienteId!),
          );
          if (!docClienteSnapshot.exists)
            throw Exception('El cliente no existe.');
          final clienteData = docClienteSnapshot.data() as Map<String, dynamic>;
          final limiteCredito =
              (clienteData['limiteCredito'] as num?)?.toDouble() ?? 0.0;
          final saldoActual =
              (clienteData['saldoDeudor'] as num?)?.toDouble() ?? 0.0;

          if (limiteCredito <= 0) {
            throw Exception(
              'Este cliente tiene el crédito bloqueado (límite = \$0).',
            );
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
          final docSnap = await transaction.get(
            _productosRef.doc(item.productoId),
          );
          if (!docSnap.exists)
            throw Exception('El producto ${item.nombre} ya no existe.');
          productosSnaps[item.productoId] = docSnap;
        }

        // 2. Escrituras
        // a) Guardar la venta
        final docVenta = _ventasRef.doc();

        // Inyectar costoActual de cada producto en los items de la venta
        final itemsConCostoActual = venta.items.map((item) {
          final snap = productosSnaps[item.productoId]!;
          final data = snap.data() as Map<String, dynamic>;
          final costoReal =
              (data['costoActual'] as num?)?.toDouble() ??
              (data['costoPromedio'] as num?)?.toDouble() ??
              0.0;

          return VentaItem(
            productoId: item.productoId,
            nombre: item.nombre,
            costoUnitario: costoReal,
            precioUnitario: item.precioUnitario,
            cantidad: item.cantidad,
            proveedorId: data['proveedorId'],
            proveedorNombre: data['proveedorNombre'],
          );
        }).toList();

        final ventaParaGuardar = Venta(
          id: docVenta.id,
          fecha: venta.fecha,
          items: itemsConCostoActual,
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
          final currentStock =
              (productosSnaps[item.productoId]!.get('cantidad') as num).toInt();
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
          final saldoActual =
              (docClienteSnapshot.data()
                  as Map<String, dynamic>)['saldoDeudor'] ??
              0.0;
          transaction.update(refCliente, {
            'saldoDeudor': saldoActual + ventaParaGuardar.total,
          });
        }

        // d) Actualizar turno de caja según método de pago (INTEGRACIÓN FLEXIBLE)
        if (venta.estado != 'pendiente' &&
            docTurnoSnapshot != null &&
            docTurnoSnapshot.exists) {
          final refTurno = docTurnoSnapshot.reference;

          if (venta.metodoPago == MetodoPago.efectivo) {
            // 1. Actualizar total de ventas en efectivo
            final valorActual =
                (docTurnoSnapshot.data()
                        as Map<String, dynamic>)['ventasEfectivo']
                    as num? ??
                0.0;
            transaction.update(refTurno, {
              'ventasEfectivo': valorActual + ventaParaGuardar.total,
            });

            // 2. Registrar el movimiento detallado
            final docMov = refTurno.collection('movimientos').doc();
            transaction.set(docMov, {
              'turnoId': docTurnoSnapshot.id,
              'tipo': 'ingreso',
              'monto': ventaParaGuardar.total,
              'concepto':
                  'Venta POS #${docVenta.id.substring(0, 5).toUpperCase()}',
              'fecha': DateTime.now().toIso8601String(),
            });
          } else {
            // Para otros métodos de pago, solo actualizamos el total estadístico del turno
            String campoActualizar;
            switch (venta.metodoPago) {
              case MetodoPago.tarjeta:
                campoActualizar = 'ventasTarjeta';
                break;
              case MetodoPago.transferencia:
                campoActualizar = 'ventasTransferencia';
                break;
              case MetodoPago.credito:
                campoActualizar = 'ventasCredito';
                break;
              default:
                campoActualizar = 'ventasEfectivo';
            }
            final valorActual =
                (docTurnoSnapshot.data()
                        as Map<String, dynamic>)[campoActualizar]
                    as num? ??
                0.0;
            transaction.update(refTurno, {
              campoActualizar: valorActual + ventaParaGuardar.total,
            });
          }
        }

        _inyectarLogTransaccional(
          transaction,
          'VENTAS',
          'Registró venta exitosa por \$${venta.total.toStringAsFixed(2)} (${venta.metodoPago.name})',
        );
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al registrar venta (Firebase): ${e.message}');
    } catch (e) {
      throw Exception('Error en transacción de venta: $e');
    }
  }

  // ── Cobrar Venta Pendiente (Parked Sales) ─────────────────────────────────

  Future<void> cobrarVentaPendiente(
    String ventaId,
    MetodoPago metodo,
    double total,
    String? turnoCajaId,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docVentaRef = _ventasRef.doc(ventaId);
        final snapVenta = await transaction.get(docVentaRef);
        if (!snapVenta.exists) throw Exception('La venta no existe.');

        // Actualizamos venta a completada
        transaction.update(docVentaRef, {
          'estado': 'completada',
          'metodoPago': metodo.name,
        });

        // 1. Lecturas obligatorias
        final snapNegocio = await transaction.get(_negocioDataRef);
        final usaCaja = snapNegocio.exists
            ? (snapNegocio.get('usaCajaRegistradora') ?? true)
            : true;

        DocumentSnapshot? docTurnoSnapshot;
        if (turnoCajaId != null) {
          docTurnoSnapshot = await transaction.get(
            _turnosCajaRef.doc(turnoCajaId),
          );
        } else if (usaCaja) {
          final activeQuery = await _turnosCajaRef
              .where('estado', isEqualTo: EstadoTurno.abierto.name)
              .where('usuarioId', isEqualTo: _currentUserId)
              .limit(1)
              .get();
          if (activeQuery.docs.isNotEmpty) {
            docTurnoSnapshot = await transaction.get(
              activeQuery.docs.first.reference,
            );
          }
        }

        // 2. Escrituras en caja
        if (docTurnoSnapshot != null && docTurnoSnapshot.exists) {
          final refTurno = docTurnoSnapshot.reference;

          if (metodo == MetodoPago.efectivo) {
            final valorActual =
                (docTurnoSnapshot.data()
                        as Map<String, dynamic>)['ventasEfectivo']
                    as num? ??
                0.0;
            transaction.update(refTurno, {
              'ventasEfectivo': valorActual + total,
            });

            final docMov = refTurno.collection('movimientos').doc();
            transaction.set(docMov, {
              'turnoId': docTurnoSnapshot.id,
              'tipo': 'ingreso',
              'monto': total,
              'concepto':
                  'Cobro Venta #${docVentaRef.id.substring(0, 5).toUpperCase()}',
              'fecha': DateTime.now().toIso8601String(),
            });
          } else {
            String campoActualizar;
            switch (metodo) {
              case MetodoPago.tarjeta:
                campoActualizar = 'ventasTarjeta';
                break;
              case MetodoPago.transferencia:
                campoActualizar = 'ventasTransferencia';
                break;
              case MetodoPago.credito:
                campoActualizar = 'ventasCredito';
                break;
              default:
                campoActualizar = 'ventasEfectivo';
            }
            final valorActual =
                (docTurnoSnapshot.data()
                        as Map<String, dynamic>)[campoActualizar]
                    as num? ??
                0.0;
            transaction.update(refTurno, {
              campoActualizar: valorActual + total,
            });
          }
        }

        final descripcionLog =
            'Cobro de venta pausada #${docVentaRef.id.substring(0, 5).toUpperCase()} por \$${total.toStringAsFixed(2)}';
        _inyectarLogTransaccional(
          transaction,
          'VENTA_RECUPERADA',
          descripcionLog,
        );
      });
    } catch (e) {
      throw Exception('Error al cobrar venta pendiente: $e');
    }
  }

  /// [FinOps] Obtiene las ventas en espera (pendientes) del día actual
  Stream<List<Venta>> getVentasPendientesStream() {
    return _ventasRef
        .where('estado', isEqualTo: 'pendiente')
        .limit(50)
        .snapshots()
        .map((snap) {
          final todas = snap.docs
              .map((d) => Venta.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();
          final hoy = DateTime.now();
          return todas
              .where(
                (v) =>
                    v.fecha.year == hoy.year &&
                    v.fecha.month == hoy.month &&
                    v.fecha.day == hoy.day,
              )
              .toList()
            ..sort((a, b) => b.fecha.compareTo(a.fecha));
        });
  }

  Future<void> reabrirVentaPendiente(Venta venta) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // ── 1. FASE DE LECTURAS (Todos los get deben ir estrictamente primero) ──

        // 1a. Leer la venta explícitamente (Obligatorio para que Firebase valide la regla de "estado == pendiente")
        final ventaRef = _ventasRef.doc(venta.id);
        final snapVenta = await transaction.get(ventaRef);

        if (!snapVenta.exists) {
          throw Exception(
            'La venta ya no existe o fue cobrada en otro dispositivo.',
          );
        }

        // 1b. Leer todos los productos involucrados
        Map<String, DocumentSnapshot> productosSnaps = {};
        for (final item in venta.items) {
          final prodRef = _productosRef.doc(item.productoId);
          productosSnaps[item.productoId] = await transaction.get(prodRef);
        }

        // ── 2. FASE DE ESCRITURAS (Updates, Sets y Deletes van al final) ──

        // 2a. Restaurar el stock y registrar el movimiento en Kardex
        for (final item in venta.items) {
          final snapProd = productosSnaps[item.productoId]!;
          if (snapProd.exists) {
            final currentStock =
                (snapProd.get('cantidad') as num?)?.toDouble() ?? 0.0;

            transaction.update(snapProd.reference, {
              'cantidad': currentStock + item.cantidad,
            });

            final kardexDoc = _kardexRef.doc();
            final mov = MovimientoInventario(
              id: kardexDoc.id,
              productoId: item.productoId,
              tipoMovimiento: TipoMovimiento.entrada,
              cantidadAlterada: item.cantidad,
              stockResultante: currentStock + item.cantidad,
              motivo:
                  'Reapertura de Venta en Espera #${venta.id.substring(0, 5).toUpperCase()}',
              fecha: DateTime.now(),
              usuarioId: _currentUserId,
            );
            transaction.set(kardexDoc, mov.toMap());
          }
        }

        // 2b. Eliminar la venta pausada y guardar bitácora
        transaction.delete(ventaRef);
        _inyectarLogTransaccional(
          transaction,
          'VENTAS',
          'Se reabrió la venta en espera #${venta.id.substring(0, 5).toUpperCase()}',
        );
      });
    } catch (e) {
      debugPrint('Error en reabrirVentaPendiente: $e');
      throw Exception('Error al reabrir venta pendiente: $e');
    }
  }

  Future<void> cancelarVenta(Venta venta) async {
    try {
      // ── Pre-validaciones (fuera de la transacción para poder hacer queries) ──

      // Paso 1: Verificar configuración del negocio
      final negocioSnap = await _negocioDataRef.get();
      final negocioData = negocioSnap.data() as Map<String, dynamic>?;
      final bool usaCaja =
          (negocioData?['usaCajaRegistradora'] as bool?) ?? false;

      // Paso 1b: Si usa caja, buscar el turno activo del usuario ACTUAL
      DocumentSnapshot? turnoActualSnap;
      if (usaCaja) {
        final turnosQuery = await _turnosCajaRef
            .where('estado', isEqualTo: EstadoTurno.abierto.name)
            .where('usuarioId', isEqualTo: _currentUserId)
            .limit(1)
            .get();

        if (turnosQuery.docs.isEmpty) {
          throw Exception(
            'Debes abrir tu caja registradora para poder realizar una devolución de efectivo.',
          );
        }
        turnoActualSnap = turnosQuery.docs.first;
      }

      // ── Transacción Atómica ───────────────────────────────────────────────
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docVenta = _ventasRef.doc(venta.id);

        // Paso 2a: Leer stock actual de todos los productos (ANTES de escrituras)
        final Map<String, DocumentSnapshot> productosSnaps = {};
        for (final item in venta.items) {
          final docSnap = await transaction.get(
            _productosRef.doc(item.productoId),
          );
          if (!docSnap.exists)
            throw Exception(
              'Producto "${item.nombre}" no existe en el inventario.',
            );
          productosSnaps[item.productoId] = docSnap;
        }

        // Leer el turno dentro de la transacción para estado consistente
        DocumentSnapshot? turnoTransSnap;
        if (turnoActualSnap != null) {
          turnoTransSnap = await transaction.get(turnoActualSnap.reference);
        }

        // ── Paso 2: Restauración Base (siempre se ejecuta) ─────────────────

        // a) Marcar venta como cancelada
        transaction.update(docVenta, {'estado': 'cancelada'});

        // b) Devolver productos al inventario + registrar en Kardex
        for (final item in venta.items) {
          final ref = _productosRef.doc(item.productoId);
          final currentStock =
              (productosSnaps[item.productoId]!.get('cantidad') as num)
                  .toDouble();
          final newStock = currentStock + item.cantidad;

          transaction.update(ref, {'cantidad': newStock});

          final kardexDoc = _kardexRef.doc();
          final movInv = MovimientoInventario(
            id: kardexDoc.id,
            productoId: item.productoId,
            tipoMovimiento: TipoMovimiento.entrada,
            cantidadAlterada: item.cantidad,
            stockResultante: newStock,
            motivo:
                'Cancelación de Venta #${venta.id.length >= 8 ? venta.id.substring(0, 8).toUpperCase() : venta.id.toUpperCase()}',
            fecha: DateTime.now(),
            usuarioId: _currentUserId,
          );
          transaction.set(kardexDoc, movInv.toMap());
        }

        // c) Reversión de saldo de crédito si aplica
        if (venta.metodoPago == MetodoPago.credito && venta.clienteId != null) {
          final refCliente = _clientesRef.doc(venta.clienteId!);
          final snapCliente = await transaction.get(refCliente);
          if (snapCliente.exists) {
            final saldoActual =
                (snapCliente.get('saldoDeudor') as num?)?.toDouble() ?? 0.0;
            transaction.update(refCliente, {
              'saldoDeudor': (saldoActual - venta.total).clamp(
                0.0,
                double.infinity,
              ),
            });
          }
        }

        // ── Paso 3: Afectación de Caja (solo si aplica) ────────────────────
        if (turnoTransSnap != null && turnoActualSnap != null) {
          final turnoData = turnoTransSnap.data() as Map<String, dynamic>;
          final egresosActuales =
              (turnoData['egresosEfectivo'] as num?)?.toDouble() ?? 0.0;
          final historial =
              (turnoData['historialRetiros'] as List<dynamic>?)?.toList() ?? [];

          // a) Crear documento de MovimientoCaja como Egreso
          final docMovRef = turnoActualSnap.reference
              .collection('movimientos')
              .doc();
          transaction.set(docMovRef, {
            'turnoId': turnoActualSnap.id,
            'tipo': 'egreso',
            'monto': venta.total,
            'concepto':
                'Devolución por cancelación de Venta #${venta.id.length >= 8 ? venta.id.substring(0, 8).toUpperCase() : venta.id.toUpperCase()}',
            'fecha': DateTime.now().toIso8601String(),
          });

          // b) Actualizar egresosEfectivo del turno
          historial.add({
            'monto': venta.total,
            'concepto':
                'Devolución por cancelación de Venta #${venta.id.length >= 8 ? venta.id.substring(0, 8).toUpperCase() : venta.id.toUpperCase()}',
            'hora': DateTime.now().toIso8601String(),
          });
          transaction.update(turnoActualSnap.reference, {
            'egresosEfectivo': egresosActuales + venta.total,
            'historialRetiros': historial,
          });
        }

        // ── Bitácora ────────────────────────────────────────────────────────
        _inyectarLogTransaccional(
          transaction,
          'VENTAS',
          'CANCELACIÓN: Venta #${venta.id.length >= 8 ? venta.id.substring(0, 8).toUpperCase() : venta.id.toUpperCase()} por \$${venta.total.toStringAsFixed(2)}. '
              '${turnoActualSnap != null ? "Egreso registrado en caja." : "Sin afectación de caja."}',
        );
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al cancelar venta: ${e.message}');
    }
    // Las excepciones lanzadas manualmente (ej: sin turno abierto) se propagan tal cual
  }

  // ── Compras ───────────────────────────────────────────────────────────────

  Future<void> registrarCompra(
    Compra compra, {
    double? nuevoPrecioVenta,
  }) async {
    // 1. Buscar turno activo fuera de la transacción (opcional)
    final turnoDoc = await _obtenerTurnoActivoDoc();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Leer productos para actualizar stock y costo promedio
        Map<String, DocumentSnapshot> productosSnaps = {};
        for (final item in compra.items) {
          final docSnap = await transaction.get(
            _productosRef.doc(item.productoId),
          );
          if (!docSnap.exists)
            throw Exception('El producto ${item.nombre} no existe.');
          productosSnaps[item.productoId] = docSnap;
        }

        // 2. Procesar cada item de la compra
        for (final item in compra.items) {
          final snap = productosSnaps[item.productoId]!;
          final data = snap.data() as Map<String, dynamic>;

          final double stockActual =
              (data['cantidad'] as num?)?.toDouble() ?? 0.0;
          final double costoActual =
              (data['costoActual'] as num?)?.toDouble() ??
              (data['costoPromedio'] as num?)?.toDouble() ??
              0.0;

          // Cálculo de Costo Promedio Ponderado
          // Nuevo Costo = ((Stock Actual * Costo Actual) + (Cant. Comprada * Costo Compra)) / (Stock Actual + Cant. Comprada)
          double nuevoCosto = item.costoUnitario;
          if (stockActual + item.cantidad > 0) {
            nuevoCosto =
                ((stockActual * costoActual) +
                    (item.cantidad * item.costoUnitario)) /
                (stockActual + item.cantidad);
          }

          final double nuevoStock = stockActual + item.cantidad;

          // Actualizar producto con historial de compra
          final Map<String, dynamic> updateData = {
            'cantidad': nuevoStock,
            'costoActual': nuevoCosto,
            'costoPromedio': nuevoCosto,
            'ultimaCompraFecha': compra.fecha.toIso8601String(),
            'ultimoCostoCompra': item.costoUnitario,
          };

          if (nuevoPrecioVenta != null && nuevoPrecioVenta > 0) {
            updateData['precio'] = nuevoPrecioVenta;
            updateData['nombreLower'] = data['nombre']
                .toString()
                .toLowerCase(); // Aseguramos consistencia
          }

          transaction.update(snap.reference, updateData);

          // Registrar en Kardex
          final kardexDoc = _kardexRef.doc();
          final mov = MovimientoInventario(
            id: kardexDoc.id,
            productoId: item.productoId,
            tipoMovimiento: TipoMovimiento.entrada,
            cantidadAlterada: item.cantidad,
            stockResultante: nuevoStock,
            motivo: 'Compra a proveedor',
            fecha: DateTime.now(),
            usuarioId: _currentUserId,
          );
          transaction.set(kardexDoc, mov.toMap());
        }

        // 3. Guardar la compra
        final docCompra = _comprasRef.doc();
        transaction.set(docCompra, compra.toMap());

        // 4. Si es crédito, crear Cuenta por Pagar
        if (compra.esCredito) {
          final docCPP = _cuentasPorPagarRef.doc();
          final cpp = CuentaPorPagar(
            id: docCPP.id,
            proveedorId: compra.proveedorId,
            nombreProveedor: compra.proveedorNombre ?? 'Proveedor Desconocido',
            compraId: docCompra.id,
            montoTotal: compra.costoTotal,
            saldoPendiente: compra.costoTotal,
            fechaCompra: compra.fecha,
            fechaVencimiento: compra.fechaVencimiento,
            estado: 'pendiente',
          );
          transaction.set(docCPP, cpp.toMap());
        }

        // 5. Integración flexible con Caja (EGRESO por compra de contado)
        if (turnoDoc != null && !compra.esCredito) {
          final refTurno = _turnosCajaRef.doc(turnoDoc.id);
          final snapTurno = await transaction.get(refTurno);

          if (snapTurno.exists) {
            final egresosActuales =
                (snapTurno.data() as Map<String, dynamic>)['egresosEfectivo']
                    as num? ??
                0.0;

            // a) Actualizar total de egresos
            transaction.update(refTurno, {
              'egresosEfectivo': egresosActuales + compra.costoTotal,
            });

            // b) Registrar el movimiento detallado
            final docMov = refTurno.collection('movimientos').doc();
            transaction.set(docMov, {
              'turnoId': turnoDoc.id,
              'tipo': 'egreso',
              'monto': compra.costoTotal,
              'concepto': 'Compra: ${compra.proveedorNombre ?? "Proveedor"}',
              'fecha': DateTime.now().toIso8601String(),
            });
          }
        }

        _inyectarLogTransaccional(
          transaction,
          'COMPRAS',
          'Registró una compra por \$${compra.costoTotal.toStringAsFixed(2)}${compra.esCredito ? " (A CRÉDITO)" : ""}',
        );
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al registrar compra: ${e.message}');
    }
  }

  // ── Proveedores ───────────────────────────────────────────────────────────

  Stream<List<CuentaPorPagar>> getCuentasPorPagar() {
    return _cuentasPorPagarRef
        .orderBy('fechaCompra', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => CuentaPorPagar.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  /// Registra un abono a una cuenta por pagar de proveedor.
  /// Afecta de forma atómica el saldo de la deuda y los egresos de caja si hay un turno abierto.
  Future<void> registrarAbonoProveedor(
    String cuentaId,
    double montoAbono,
  ) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Leer Cuenta por Pagar
        final cppRef = _cuentasPorPagarRef.doc(cuentaId);
        final cppSnap = await transaction.get(cppRef);
        if (!cppSnap.exists) throw Exception('La cuenta por pagar no existe.');

        final cppData = cppSnap.data() as Map<String, dynamic>;
        final double saldoActual =
            (cppData['saldoPendiente'] as num?)?.toDouble() ?? 0.0;

        if (montoAbono <= 0) throw Exception('El monto debe ser mayor a cero.');
        if (montoAbono > saldoActual) {
          throw Exception(
            'El abono (\$${montoAbono.toStringAsFixed(2)}) supera el saldo pendiente (\$${saldoActual.toStringAsFixed(2)}).',
          );
        }

        final double nuevoSaldo = saldoActual - montoAbono;
        final String nuevoEstado = nuevoSaldo <= 0 ? 'pagada' : 'parcial';

        // 2. Actualizar Cuenta por Pagar
        transaction.update(cppRef, {
          'saldoPendiente': nuevoSaldo,
          'estado': nuevoEstado,
        });

        // 3. Integración con Caja (EGRESO por abono)
        // Buscamos si el usuario actual tiene un turno abierto
        final activeQuery = await _turnosCajaRef
            .where('estado', isEqualTo: EstadoTurno.abierto.name)
            .where('usuarioId', isEqualTo: _currentUserId)
            .limit(1)
            .get();

        if (activeQuery.docs.isNotEmpty) {
          final turnoSnap = await transaction.get(
            activeQuery.docs.first.reference,
          );
          if (turnoSnap.exists) {
            final refTurno = turnoSnap.reference;
            final double egresosActuales =
                ((turnoSnap.data() as Map<String, dynamic>)['egresosEfectivo']
                            as num? ??
                        0.0)
                    .toDouble();

            // a) Actualizar turno (Egresos)
            transaction.update(refTurno, {
              'egresosEfectivo': egresosActuales + montoAbono,
            });

            // b) Registrar movimiento detallado de caja
            final docMov = refTurno.collection('movimientos').doc();
            transaction.set(docMov, {
              'turnoId': turnoSnap.id,
              'tipo': 'egreso',
              'monto': montoAbono,
              'concepto': 'Abono a proveedor: ${cppData['nombreProveedor']}',
              'fecha': DateTime.now().toIso8601String(),
            });
          }
        }

        // 4. Registrar en Bitácora
        _inyectarLogTransaccional(
          transaction,
          'COMPRAS',
          'Abono a proveedor "${cppData['nombreProveedor']}" por \$${montoAbono.toStringAsFixed(2)}. Saldo restante: \$${nuevoSaldo.toStringAsFixed(2)}',
        );
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al registrar abono: ${e.message}');
    }
  }

  Stream<List<Proveedor>> getProveedores() {
    return _proveedoresRef
        .orderBy('nombre')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) =>
                    Proveedor.fromMap(d.data() as Map<String, dynamic>, d.id),
              )
              .toList(),
        );
  }

  Future<void> agregarProveedor(Proveedor proveedor) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final docRef = _proveedoresRef.doc();
      batch.set(docRef, proveedor.toMap());
      _inyectarLogBatch(
        batch,
        'PROVEEDORES',
        'Agregó al proveedor: ${proveedor.nombreComercial}',
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al agregar proveedor: ${e.message}');
    }
  }

  Future<void> actualizarProveedor(Proveedor proveedor) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_proveedoresRef.doc(proveedor.id), proveedor.toMap());
      _inyectarLogBatch(
        batch,
        'PROVEEDORES',
        'Actualizó al proveedor: ${proveedor.nombreComercial}',
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al actualizar proveedor: ${e.message}');
    }
  }

  Future<void> eliminarProveedor(String id, String nombre) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.delete(_proveedoresRef.doc(id));
      _inyectarLogBatch(batch, 'PROVEEDORES', 'Eliminó al proveedor: $nombre');
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al eliminar proveedor: ${e.message}');
    }
  }

  Future<void> devolverVenta({
    required Venta venta,
    required double costoEnvioDevolucion,
    required bool volverAVender,
  }) async {
    try {
      // ── Pre-validaciones (fuera de la transacción para poder hacer queries) ──

      // Paso 1: Verificar configuración del negocio
      final negocioSnap = await _negocioDataRef.get();
      final negocioData = negocioSnap.data() as Map<String, dynamic>?;
      final bool usaCaja =
          (negocioData?['usaCajaRegistradora'] as bool?) ?? false;

      // Paso 1b: Si usa caja, buscar el turno activo del usuario ACTUAL
      DocumentSnapshot? turnoActualSnap;
      if (usaCaja) {
        final turnosQuery = await _turnosCajaRef
            .where('estado', isEqualTo: EstadoTurno.abierto.name)
            .where('usuarioId', isEqualTo: _currentUserId)
            .limit(1)
            .get();

        if (turnosQuery.docs.isEmpty) {
          throw Exception(
            'Debes abrir tu caja registradora para poder realizar una devolución de efectivo.',
          );
        }
        turnoActualSnap = turnosQuery.docs.first;
      }

      // ── Transacción Atómica ───────────────────────────────────────────────
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docVenta = _ventasRef.doc(venta.id);

        // Paso 2a: Leer stock actual de todos los productos (ANTES de escrituras) si volverAVender
        final Map<String, DocumentSnapshot> productosSnaps = {};
        if (volverAVender) {
          for (final item in venta.items) {
            final docSnap = await transaction.get(
              _productosRef.doc(item.productoId),
            );
            if (!docSnap.exists)
              throw Exception(
                'Producto "${item.nombre}" no existe en el inventario.',
              );
            productosSnaps[item.productoId] = docSnap;
          }
        }

        // Leer el turno dentro de la transacción para estado consistente
        DocumentSnapshot? turnoTransSnap;
        if (turnoActualSnap != null) {
          turnoTransSnap = await transaction.get(turnoActualSnap.reference);
        }

        // ── Paso 2: Restauración Base (siempre se ejecuta) ─────────────────

        // a) Marcar venta como devuelta
        transaction.update(docVenta, {
          'estado': 'devuelta',
          'costoEnvioDevolucion': costoEnvioDevolucion,
          'devueltoAlInventario': volverAVender,
        });

        // b) Devolver productos al inventario + registrar en Kardex (solo si volverAVender)
        if (volverAVender) {
          for (final item in venta.items) {
            final ref = _productosRef.doc(item.productoId);
            final currentStock =
                (productosSnaps[item.productoId]!.get('cantidad') as num)
                    .toDouble();
            final newStock = currentStock + item.cantidad;

            transaction.update(ref, {'cantidad': newStock});

            final kardexDoc = _kardexRef.doc();
            final movInv = MovimientoInventario(
              id: kardexDoc.id,
              productoId: item.productoId,
              tipoMovimiento: TipoMovimiento.entrada,
              cantidadAlterada: item.cantidad,
              stockResultante: newStock,
              motivo:
                  'Devolución de Venta #${venta.id.length >= 8 ? venta.id.substring(0, 8).toUpperCase() : venta.id.toUpperCase()}',
              fecha: DateTime.now(),
              usuarioId: _currentUserId,
            );
            transaction.set(kardexDoc, movInv.toMap());
          }
        }

        // c) Reversión de saldo de crédito si aplica
        if (venta.metodoPago == MetodoPago.credito && venta.clienteId != null) {
          final refCliente = _clientesRef.doc(venta.clienteId!);
          final snapCliente = await transaction.get(refCliente);
          if (snapCliente.exists) {
            final saldoActual =
                (snapCliente.get('saldoDeudor') as num?)?.toDouble() ?? 0.0;
            transaction.update(refCliente, {
              'saldoDeudor': (saldoActual - venta.total).clamp(
                0.0,
                double.infinity,
              ),
            });
          }
        }

        // ── Paso 3: Afectación de Caja (solo si aplica) ────────────────────
        if (turnoTransSnap != null && turnoActualSnap != null) {
          final turnoData = turnoTransSnap.data() as Map<String, dynamic>;
          final egresosActuales =
              (turnoData['egresosEfectivo'] as num?)?.toDouble() ?? 0.0;
          final historial =
              (turnoData['historialRetiros'] as List<dynamic>?)?.toList() ?? [];

          final totalEgreso = venta.total + costoEnvioDevolucion;

          // a) Crear documento de MovimientoCaja como Egreso
          final docMovRef = turnoActualSnap.reference
              .collection('movimientos')
              .doc();
          transaction.set(docMovRef, {
            'turnoId': turnoActualSnap.id,
            'tipo': 'egreso',
            'monto': totalEgreso,
            'concepto':
                'Reembolso por Devolución de Venta #${venta.id.length >= 8 ? venta.id.substring(0, 8).toUpperCase() : venta.id.toUpperCase()}',
            'fecha': DateTime.now().toIso8601String(),
          });

          // b) Actualizar egresosEfectivo del turno
          historial.add({
            'monto': totalEgreso,
            'concepto':
                'Reembolso por Devolución de Venta #${venta.id.length >= 8 ? venta.id.substring(0, 8).toUpperCase() : venta.id.toUpperCase()}',
            'hora': DateTime.now().toIso8601String(),
          });
          transaction.update(turnoActualSnap.reference, {
            'egresosEfectivo': egresosActuales + totalEgreso,
            'historialRetiros': historial,
          });
        }

        // ── Bitácora ────────────────────────────────────────────────────────
        final modo = volverAVender
            ? 'Devolución al inventario'
            : 'Reembolso sin retorno de stock';
        _inyectarLogTransaccional(
          transaction,
          'VENTAS',
          'DEVOLUCIÓN: $modo de la venta #${venta.id.length >= 8 ? venta.id.substring(0, 8).toUpperCase() : venta.id.toUpperCase()} por \$${venta.total.toStringAsFixed(2)}. '
              '${turnoActualSnap != null ? "Egreso registrado en caja." : "Sin afectación de caja."}',
        );
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al registrar devolución: ${e.message}');
    }
  }

  // ── Estadísticas y Ganancias ──────────────────────────────────────────────

  /// Obtiene historial paginado de ventas
  Future<List<Venta>> getVentasPaginadas({
    int limite = 20,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _ventasRef.orderBy('fecha', descending: true).limit(limite);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get(
      const GetOptions(source: Source.serverAndCache),
    );
    return snapshot.docs
        .map((doc) => Venta.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  /// Obtiene ventas en un rango de fechas
  Stream<List<Venta>> getVentasPorRango(DateTime inicio, DateTime fin) {
    return _ventasRef
        .where('fecha', isGreaterThanOrEqualTo: inicio.toIso8601String())
        .where('fecha', isLessThanOrEqualTo: fin.toIso8601String())
        .orderBy('fecha', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            return Venta.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList(),
        );
  }

  /// [FinOps] Lazy Cache — evita el Full Collection Scan en cada llamada.
  /// - Caché válido 12 horas: costo = 1 lectura (doc del negocio).
  /// - Caché expirado: Full Scan + escribe el nuevo valor (amortizado en el tiempo).
  Future<double> getCapitalEnInventario() async {
    // Paso 1: Leer el documento del Negocio (1 lectura)
    final negocioDoc = await _negocioDataRef.get();
    if (negocioDoc.exists) {
      final data = negocioDoc.data() as Map<String, dynamic>;
      final cached = (data['capitalInventarioCache'] as num?)?.toDouble();
      final ultimaStr = data['ultimaActualizacionCapital'] as String?;
      final ultima = ultimaStr != null ? DateTime.tryParse(ultimaStr) : null;

      // Paso 2: Si el caché es fresco (< 12 horas), devolver sin leer productos
      if (cached != null && ultima != null) {
        final age = DateTime.now().difference(ultima);
        if (age.inHours < 12) {
          return cached; // ✅ 1 lectura total
        }
      }
    }

    // Paso 3: Caché expirado o ausente — Full Scan
    final snapshot = await _productosRef
        .where('activo', isEqualTo: true)
        .where('esBase', isEqualTo: true)
        .get();
    double totalCapital = 0.0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final stock = (data['cantidad'] as num?)?.toDouble() ?? 0.0;
      final costoPromedio =
          (data['costoPromedio'] as num? ??
                  data['costo_promedio'] as num? ??
                  data['costo'] as num?)
              ?.toDouble() ??
          0.0;
      if (stock > 0) totalCapital += stock * costoPromedio;
    }

    // Paso 4: Persistir el nuevo valor en caché (1 escritura merge)
    await _negocioDataRef.set({
      'capitalInventarioCache': totalCapital,
      'ultimaActualizacionCapital': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));

    return totalCapital;
  }

  /// Retorna datos analíticos para el Dashboard, filtrando por los últimos [dias] días.
  /// Optimizado: solo lee ventas dentro del rango de fechas, no toda la colección.
  Future<DashboardData> getDashboardData({int dias = 7}) async {
    final ahora = DateTime.now();
    final inicio = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
    ).subtract(Duration(days: dias - 1));
    final inicioStr = inicio.toIso8601String();

    // [FinOps] Optimización: Obtenemos agregaciones globales del servidor en una sola lectura
    final aggQuery = _ventasRef
        .where('estado', isEqualTo: 'completada')
        .where('fecha', isGreaterThanOrEqualTo: inicioStr)
        .orderBy('fecha');

    final aggregateSnapshot = await aggQuery
        .aggregate(sum('total'), count())
        .get();
    final double serverTotalIngresos = (aggregateSnapshot.getSum('total') ?? 0)
        .toDouble();
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
    final utilidadPorProveedor = <String, double>{};
    final nombresProveedores = <String, String>{};

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
          contadores[item.productoId] =
              (contadores[item.productoId] ?? 0) + item.cantidad;
          nombres[item.productoId] = item.nombre;
          ingresosProd[item.productoId] =
              (ingresosProd[item.productoId] ?? 0) + ing;

          // Rentabilidad por Proveedor
          if (item.proveedorId != null) {
            final util = ing - cos;
            utilidadPorProveedor[item.proveedorId!] =
                (utilidadPorProveedor[item.proveedorId!] ?? 0) + util;
            nombresProveedores[item.proveedorId!] =
                item.proveedorNombre ?? 'Proveedor Desconocido';
          }
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
    final margen = ingresosTotales > 0
        ? (ganancia / ingresosTotales) * 100
        : 0.0;

    final top =
        (contadores.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(5)
            .map(
              (e) => TopProducto(
                productoId: e.key,
                nombre: nombres[e.key] ?? 'Desconocido',
                cantidadVendida: e.value,
                ingresoGenerado: ingresosProd[e.key] ?? 0,
              ),
            )
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
      utilidadPorProveedor: utilidadPorProveedor,
      nombresProveedores: nombresProveedores,
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
    final doc = await _clientesRef.add(
      cliente.toMap()..['fechaRegistro'] = DateTime.now().toIso8601String(),
    );
    return doc.id;
  }

  Future<void> actualizarCliente(Cliente cliente) async {
    await _clientesRef.doc(cliente.id).update(cliente.toMap());
  }

  Future<void> eliminarCliente(String clienteId) async {
    await _clientesRef.doc(clienteId).delete();
  }

  /// [FinOps] Stream de clientes con límite de 100 — evita descargas completas.
  Stream<List<Cliente>> getClientesStream() {
    return _clientesRef
        .orderBy('nombre')
        .limit(100) // FinOps: máx 100 docs en tiempo real
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => Cliente.fromMap(d.data() as Map<String, dynamic>, d.id),
              )
              .toList(),
        );
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

  Future<Cliente?> getCliente(String id) async {
    try {
      final doc = await _clientesRef.doc(id).get();
      if (!doc.exists) return null;
      return Cliente.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      debugPrint('Error al obtener cliente: $e');
      return null;
    }
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
        final docCliente = await transaction.get(
          _clientesRef.doc(abono.clienteId),
        );
        if (!docCliente.exists) throw Exception('Cliente no encontrado.');
        final saldoActual =
            (docCliente.data() as Map<String, dynamic>)['saldoDeudor']
                as num? ??
            0.0;
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
            docTurno = await transaction.get(
              _turnosCajaRef.doc(turnoSnap.docs.first.id),
            );
          }
        }

        // ── Escrituras ──────────────────────────────────────────────────
        // a) Guardar el abono
        final docAbono = _abonosRef.doc();
        transaction.set(docAbono, {...abono.toMap()});

        // b) Restar saldo del cliente
        transaction.update(_clientesRef.doc(abono.clienteId), {
          'saldoDeudor': (saldoActual - abono.monto).clamp(
            0.0,
            double.infinity,
          ),
        });

        // c) Sumar al turno de caja si el abono es en efectivo
        if (docTurno != null) {
          final ventasEfActual =
              (docTurno.data() as Map<String, dynamic>)['ventasEfectivo']
                  as num? ??
              0.0;
          transaction.update(docTurno.reference, {
            'ventasEfectivo': ventasEfActual + abono.monto,
          });
        }

        _inyectarLogTransaccional(
          transaction,
          'CREDITOS',
          'Registró abono de \$${abono.monto.toStringAsFixed(2)} para el cliente ID: ${abono.clienteId}',
        );
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al registrar abono: ${e.message}');
    } catch (e) {
      rethrow;
    }
  }

  /// [FinOps] Historial de abonos de un cliente — limitado a los 50 más recientes.
  Stream<List<Abono>> getAbonosPorCliente(String clienteId) {
    return _abonosRef
        .where('clienteId', isEqualTo: clienteId)
        .orderBy('fecha', descending: true)
        .limit(50) // FinOps: máx 50 abonos en tiempo real
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => Abono.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList(),
        );
  }

  // ── Búsqueda por Nombre ──────────────────────────────────────────────────

  /// Busca productos activos cuyo nombre empieza con [query] (prefijo Firestore).
  /// Máximo 20 resultados para no sobrecargar la UI.
  Future<List<Producto>> buscarProductosPorNombre(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || q.length < 1) return [];

    // Técnica de rango: isGreaterThanOrEqualTo + isLessThanOrEqualTo con \uf8ff
    try {
      final snap = await _productosRef
          .where('activo', isEqualTo: true)
          // Quitamos .where('esBase', isEqualTo: true) para permitir buscar variantes
          .where('nombreLower', isGreaterThanOrEqualTo: q)
          .where('nombreLower', isLessThanOrEqualTo: '$q\uf8ff')
          .limit(20)
          .get(const GetOptions(source: Source.serverAndCache));

      return snap.docs
          .map((d) => Producto.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    } catch (e) {
      debugPrint('Error en buscarProductosPorNombre: $e');
      return [];
    }
  }

  // ── Importación Masiva CSV ────────────────────────────────────────────────

  /// Importa una lista de filas CSV como productos.
  /// Columnas esperadas: Nombre, Categoria, Precio, Costo, Cantidad, Unidad, CodigoBarras
  /// Crea categorías al vuelo si no existen. Usa WriteBatch (máx 500 por lote).
  Future<int> importarProductosCSV(List<Map<String, String>> filas) async {
    if (filas.isEmpty) return 0;

    // 1. Cargar mapa de categorías existentes (nombre → id)
    final catSnap = await _categoriasRef.orderBy('orden').get();
    final Map<String, String> catMap = {};
    for (final doc in catSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final nombre = data['nombre'] as String? ?? '';
      if (nombre.isNotEmpty) catMap[nombre.toLowerCase()] = doc.id;
    }

    // 2. Pre-calcular el orden máximo para nuevas categorías
    int ordenMax = catSnap.docs.length;

    // 3. Cargar proveedores existentes (nombre → {id, nombreComercial})
    final provSnap = await _proveedoresRef.get();
    final Map<String, Map<String, String>> provMap = {};
    for (final doc in provSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final nombre = data['nombreComercial'] as String? ?? '';
      if (nombre.isNotEmpty) {
        provMap[nombre.toLowerCase()] = {'id': doc.id, 'nombre': nombre};
      }
    }

    int importados = 0;
    const int tamLote = 400; // margen por debajo del límite 500 de Firestore

    for (int offset = 0; offset < filas.length; offset += tamLote) {
      final lote = filas.sublist(
        offset,
        (offset + tamLote) > filas.length ? filas.length : offset + tamLote,
      );

      final batch = FirebaseFirestore.instance.batch();

      for (final fila in lote) {
        final nombre = (fila['Nombre'] ?? '').trim();
        if (nombre.isEmpty) continue;

        // 2a. Resolver categoría
        final categoriaNombre = (fila['Categoria'] ?? 'General').trim();
        final categoriaKey = categoriaNombre.toLowerCase();

        if (!catMap.containsKey(categoriaKey)) {
          // Crear categoría al vuelo
          final newCatRef = _categoriasRef.doc();
          ordenMax++;
          batch.set(newCatRef, {
            'nombre': categoriaNombre,
            'orden': ordenMax,
            'atributos': [],
          });
          catMap[categoriaKey] = newCatRef.id;
        }

        // 2b. Construir el producto
        final precio = double.tryParse(fila['Precio'] ?? '0') ?? 0.0;

        // Aceptar tanto "Costo" como "Costo Base"
        final costoStr = fila['Costo Base'] ?? fila['Costo'] ?? '0';
        final costo = double.tryParse(costoStr) ?? 0.0;

        final cantidad = double.tryParse(fila['Cantidad'] ?? '0') ?? 0.0;
        final unidad = (fila['Unidad'] ?? 'pza').trim();
        final codigo = (fila['CodigoBarras'] ?? '').trim();
        final atributosStr = (fila['Atributos'] ?? '').trim();
        final proveedorNombreCSV = (fila['Proveedor'] ?? '').trim();

        // Búsqueda de proveedor
        String? proveedorId;
        String? proveedorNombreFinal;
        if (proveedorNombreCSV.isNotEmpty) {
          final pMatch = provMap[proveedorNombreCSV.toLowerCase()];
          if (pMatch != null) {
            proveedorId = pMatch['id'];
            proveedorNombreFinal = pMatch['nombre'];
          } else {
            // Requerimiento: Si no existe, marcar error
            throw Exception(
              'El proveedor "$proveedorNombreCSV" no existe en el sistema. Créalo primero o deja la columna vacía.',
            );
          }
        }

        // Parseo de atributos dinámicos (Clave:Valor, Clave:Valor)
        Map<String, dynamic> atributosMap = {};
        if (atributosStr.isNotEmpty) {
          final pares = atributosStr.split(',');
          for (var par in pares) {
            final partes = par.split(':');
            if (partes.length >= 2) {
              final clave = partes[0].trim();
              final valor = partes[1].trim();
              if (clave.isNotEmpty) atributosMap[clave] = valor;
            }
          }
        }

        final prodRef = _productosRef.doc();
        final nombreLower = nombre.toLowerCase();
        batch.set(prodRef, {
          'nombre': nombre,
          'nombreLower': nombreLower,
          'categoria': categoriaNombre,
          'precio': precio,
          'costoPromedio': costo, // Llave correcta para el modelo
          'costoActual': costo, // Inicializamos también el costo actual
          'cantidad': cantidad,
          'unidad': unidad,
          'codigoBarras': codigo.isNotEmpty ? codigo : null,
          'atributos': atributosMap,
          'proveedorId': proveedorId,
          'proveedorNombre': proveedorNombreFinal,
          'activo': true,
          'esBase': true,
          'enPromocion': false,
          'fechaCreacion': DateTime.now().toIso8601String(),
        });
        importados++;
      }

      await batch.commit();
    }

    return importados;
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
    final uploadTask = await ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  // ── Módulo de Mermas y Ajustes (Kardex) ───────────────────────────────────

  /// Registra un ajuste de inventario (merma, daño, etc.) de forma atómica.
  /// No afecta costos ni cajas, solo stock físico.
  Future<void> registrarAjusteInventario(MovimientoKardex movimiento) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final productDoc = await transaction.get(
          _productosRef.doc(movimiento.productoId),
        );

        if (!productDoc.exists) {
          throw Exception('El producto no existe.');
        }

        final productData = productDoc.data() as Map<String, dynamic>;
        final stockActual =
            (productData['cantidad'] as num?)?.toDouble() ?? 0.0;

        if (stockActual < movimiento.cantidad) {
          throw Exception(
            'Stock insuficiente para realizar el ajuste. Stock actual: $stockActual',
          );
        }

        final nuevoStock = stockActual - movimiento.cantidad;

        // 1. Actualizar stock del producto
        transaction.update(productDoc.reference, {'cantidad': nuevoStock});

        // 2. Registrar en Kardex
        final kardexDoc = _kardexRef.doc();
        transaction.set(kardexDoc, movimiento.toMap());

        // 3. Registrar en Bitácora
        final descripcionLog =
            'Ajuste de inventario: -${movimiento.cantidad} de ${movimiento.nombreProducto} por ${movimiento.tipoMovimiento.replaceAll('_', ' ')}';
        _inyectarLogTransaccional(transaction, 'INVENTARIO', descripcionLog);
      });
    } on FirebaseException catch (e) {
      throw Exception('Error en la transacción de ajuste: ${e.message}');
    }
  }

  // ── Empleados y Solicitudes ──────────────────────────────────────────────

  /// [FinOps] Stream de solicitudes de empleados con límite para evitar sobrecostos
  Stream<QuerySnapshot> getSolicitudesPendientesStream(String negocioId) {
    if (negocioId.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('negocios')
        .doc(negocioId)
        .collection('solicitudes')
        .where('estatus', isEqualTo: 'pendiente')
        .limit(50)
        .snapshots();
  }

  /// [FinOps] Stream de empleados activos con límite para evitar sobrecostos
  Stream<QuerySnapshot> getEmpleadosActivosStream(String negocioId) {
    if (negocioId.isEmpty) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('usuarios')
        .where('negocioId', isEqualTo: negocioId)
        .where('rol', isNotEqualTo: 'dueño')
        .limit(100)
        .snapshots();
  }
}
