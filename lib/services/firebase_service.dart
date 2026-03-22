import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/producto.dart';
import '../models/categoria.dart';
import '../models/venta.dart';

import 'auth_service.dart';

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

  // ── Productos ─────────────────────────────────────────────────────────────

  /// Stream en tiempo real de todos los productos.
  Stream<List<Producto>> getProductos() {
    return _productosRef
        .orderBy('nombre')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return Producto.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList());
  }

  /// Busca productos cuyo código de barras coincida exactamente.
  Future<List<Producto>> buscarPorCodigoBarras(String codigo) async {
    final snapshot =
        await _productosRef.where('codigoBarras', isEqualTo: codigo).get();
    return snapshot.docs.map((doc) {
      return Producto.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  Future<void> agregarProducto(Producto producto) async {
    try {
      await _productosRef.add(producto.toMap());
    } on FirebaseException catch (e) {
      throw Exception('Error al agregar producto: ${e.message}');
    }
  }

  Future<void> actualizarProducto(Producto producto) async {
    try {
      await _productosRef.doc(producto.id).update(producto.toMap());
    } on FirebaseException catch (e) {
      throw Exception('Error al actualizar producto: ${e.message}');
    }
  }

  Future<void> eliminarProducto(String id) async {
    try {
      await _productosRef.doc(id).delete();
    } on FirebaseException catch (e) {
      throw Exception('Error al eliminar producto: ${e.message}');
    }
  }

  /// Método para reabastecer inventario recalculando el Costo Promedio Ponderado
  Future<void> reabastecerProducto(String productoId, int cantidadNueva, double costoCompraNuevo) async {
    final docRef = _productosRef.doc(productoId);
    
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception("El producto no existe");
        }
        
        final data = snapshot.data() as Map<String, dynamic>;
        
        // Obtener valores actuales (con fallback para documentos viajos con 'costo')
        final stockViejo = (data['cantidad'] as num?)?.toInt() ?? 0;
        final costoViejo = (data['costo_promedio'] as num? ?? data['costo'] as num?)?.toDouble() ?? 0.0;
        
        // Lógica de Costo Promedio Ponderado
        final valorViejo = stockViejo * costoViejo;
        final valorNuevo = cantidadNueva * costoCompraNuevo;
        final nuevoStock = stockViejo + cantidadNueva;
        
        double nuevoCostoPromedio = costoViejo;
        if (nuevoStock > 0) {
          nuevoCostoPromedio = (valorViejo + valorNuevo) / nuevoStock;
        }

        // Ejecutar actualización
        transaction.update(docRef, {
          'cantidad': nuevoStock,
          'costo_promedio': nuevoCostoPromedio,
        });
      });
    } on FirebaseException catch (e) {
      throw Exception('Error al reabastecer producto: ${e.message}');
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

  // ── Ventas ────────────────────────────────────────────────────────────────

  Future<void> registrarVenta(Venta venta) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Guardar la venta (el ID se generará automáticamente si mandamos uno vacío, o usamos uno nuevo)
    final docVenta = _ventasRef.doc();
    
    // Asignar el ID autogenerado al modelo antes de guardar
    final ventaParaGuardar = Venta(
      id: docVenta.id,
      fecha: venta.fecha,
      items: venta.items,
      costoEnvio: venta.costoEnvio,
      envioPagadoPorVendedor: venta.envioPagadoPorVendedor,
    );
    
    batch.set(docVenta, ventaParaGuardar.toMap());

    // 2. Descontar inventario de todos los productos
    for (final item in venta.items) {
      final docProd = _productosRef.doc(item.productoId);
      // Usamos increment con valor negativo para restar atómicamente
      batch.update(docProd, {
        'cantidad': FieldValue.increment(-item.cantidad),
      });
    }

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al registrar venta: ${e.message}');
    }
  }

  Future<void> cancelarVenta(Venta venta) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Cambiar estado a 'cancelada'
    final docVenta = _ventasRef.doc(venta.id);
    batch.update(docVenta, {'estado': 'cancelada'});

    // 2. Devolver productos al inventario
    for (final item in venta.items) {
      final docProd = _productosRef.doc(item.productoId);
      batch.update(docProd, {
        'cantidad': FieldValue.increment(item.cantidad),
      });
    }

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al cancelar venta: ${e.message}');
    }
  }

  Future<void> devolverVenta({
    required Venta venta,
    required double costoEnvioDevolucion,
    required bool volverAVender,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Cambiar estado a 'devuelta' y registrar costos
    final docVenta = _ventasRef.doc(venta.id);
    batch.update(docVenta, {
      'estado': 'devuelta',
      'costoEnvioDevolucion': costoEnvioDevolucion,
      'devueltoAlInventario': volverAVender,
    });

    // 2. Devolver productos al inventario SI están aptos para volver a venderse
    if (volverAVender) {
      for (final item in venta.items) {
        final docProd = _productosRef.doc(item.productoId);
        batch.update(docProd, {
          'cantidad': FieldValue.increment(item.cantidad),
        });
      }
    }

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      throw Exception('Error al registrar devolución: ${e.message}');
    }
  }

  // ── Estadísticas y Ganancias ──────────────────────────────────────────────

  /// Obtiene el flujo en vivo de todas las ventas (ordenadas de más reciente a más antigua)
  Stream<List<Venta>> getVentasStream() {
    return _ventasRef
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              return Venta.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList());
  }

  /// Obtiene ventas en un rango de fechas
  Stream<List<Venta>> getVentasPorRango(DateTime inicio, DateTime fin) {
    return _ventasRef
        .where('fecha', isGreaterThanOrEqualTo: inicio.toIso8601String())
        .where('fecha', isLessThanOrEqualTo: fin.toIso8601String())
        .orderBy('fecha', descending: true)
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
}
