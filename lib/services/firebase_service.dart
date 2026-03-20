import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/producto.dart';
import '../models/categoria.dart';

class FirebaseService {
  final CollectionReference _productosRef =
      FirebaseFirestore.instance.collection('productos');

  final CollectionReference _categoriasRef =
      FirebaseFirestore.instance.collection('categorias');

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

  /// Siembra las categorías iniciales SOLO si la colección está vacía.
  Future<void> sembrarCategorias() async {
    final snapshot = await _categoriasRef.limit(1).get();
    if (snapshot.docs.isNotEmpty) return; // Ya hay datos, no sembrar

    final categorias = [
      Categoria(id: '', nombre: 'Sábanas', tipoAtributo: 'color',
          tamanos: ['Individual', 'Matrimonial', 'Queen', 'King'], orden: 1),
      Categoria(id: '', nombre: 'Cortinas', tipoAtributo: 'color',
          tamanos: ['Unitalla'], orden: 2),
      Categoria(id: '', nombre: 'Fundas de almohada', tipoAtributo: 'color',
          tamanos: ['Matrimonial', 'King'], orden: 3),
      Categoria(id: '', nombre: 'Cobertores Lisos', tipoAtributo: 'color',
          tamanos: ['Individual', 'Matrimonial', 'Queen', 'King'], orden: 4),
      Categoria(id: '', nombre: 'Cobertores Diseños', tipoAtributo: 'diseño',
          tamanos: ['Individual', 'Matrimonial', 'Queen', 'King'], orden: 5),
      Categoria(id: '', nombre: 'Colchas', tipoAtributo: 'color',
          tamanos: ['Matrimonial', 'Queen', 'King'], orden: 6),
      Categoria(id: '', nombre: 'Cubre sillas', tipoAtributo: 'color',
          tamanos: ['Unitalla'], orden: 7),
      Categoria(id: '', nombre: 'Cubre sillones', tipoAtributo: 'color',
          tamanos: ['Unitalla'], orden: 8),
      Categoria(id: '', nombre: 'Almohada viajera', tipoAtributo: 'color',
          tamanos: ['Unitalla'], orden: 9),
    ];

    final batch = FirebaseFirestore.instance.batch();
    for (final cat in categorias) {
      batch.set(_categoriasRef.doc(), cat.toMap());
    }
    await batch.commit();
  }
}
