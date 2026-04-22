import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PermisosEmpleado {
  final bool puedeAjustarStock;
  final bool puedeEditarProductos;
  final bool puedeEliminarProductos;
  final bool puedeVerEstadisticas;
  final bool puedeVerHistorialVentas;
  final bool puedeAbrirCerrarCaja;

  const PermisosEmpleado({
    this.puedeAjustarStock = true,
    this.puedeEditarProductos = false,
    this.puedeEliminarProductos = false,
    this.puedeVerEstadisticas = false,
    this.puedeVerHistorialVentas = true,
    this.puedeAbrirCerrarCaja = true,
  });

  /// El dueño siempre tiene todos los permisos en true.
  const PermisosEmpleado.dueno()
      : puedeAjustarStock = true,
        puedeEditarProductos = true,
        puedeEliminarProductos = true,
        puedeVerEstadisticas = true,
        puedeVerHistorialVentas = true,
        puedeAbrirCerrarCaja = true;

  factory PermisosEmpleado.fromMap(Map<String, dynamic> map) {
    return PermisosEmpleado(
      puedeAjustarStock: map['puedeAjustarStock'] as bool? ?? true,
      puedeEditarProductos: map['puedeEditarProductos'] as bool? ?? false,
      puedeEliminarProductos: map['puedeEliminarProductos'] as bool? ?? false,
      puedeVerEstadisticas: map['puedeVerEstadisticas'] as bool? ?? false,
      puedeVerHistorialVentas: map['puedeVerHistorialVentas'] as bool? ?? true,
      puedeAbrirCerrarCaja: map['puedeAbrirCerrarCaja'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'puedeAjustarStock': puedeAjustarStock,
    'puedeEditarProductos': puedeEditarProductos,
    'puedeEliminarProductos': puedeEliminarProductos,
    'puedeVerEstadisticas': puedeVerEstadisticas,
    'puedeVerHistorialVentas': puedeVerHistorialVentas,
    'puedeAbrirCerrarCaja': puedeAbrirCerrarCaja,
  };
}

class UserData {
  final String uid;
  final String nombre;
  final String email;
  final String negocioNombre;
  final String negocioId;
  final String estatus;
  final String rol;
  final PermisosEmpleado permisos;

  UserData({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.negocioNombre,
    required this.negocioId,
    required this.estatus,
    required this.rol,
    required this.permisos,
  });
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  // Constantes de roles para evitar errores de tipeo o codificación
  static const String rolDueno = 'dueño';
  static const String rolEmpleado = 'empleado';
  static const String rolAdmin = 'admin';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserData? currentUserData;

  String get currentNegocioId => currentUserData?.negocioId ?? '';

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> reloadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        // Normalización: quitamos espacios y pasamos a minúsculas para evitar errores de tipeo
        final rawRol = data['rol'] as String? ?? rolEmpleado;
        final rol = rawRol.trim().toLowerCase();

        final permisosMap = data['permisos'] as Map<String, dynamic>?;
        
        // El dueño siempre tiene todos los permisos en su negocio
        final permisos = (rol == rolDueno)
            ? const PermisosEmpleado.dueno()
            : permisosMap != null
                ? PermisosEmpleado.fromMap(permisosMap)
                : const PermisosEmpleado();

        currentUserData = UserData(
          uid: user.uid,
          nombre: data['nombre'] ?? '',
          email: data['email'] ?? '',
          negocioNombre: data['negocioNombre'] ?? '',
          negocioId: data['negocioId'] ?? '',
          estatus: data['estatus'] ?? 'pendiente',
          rol: rol, // Guardamos el rol normalizado
          permisos: permisos,
        );
      } else {
        currentUserData = null;
      }
    } else {
      currentUserData = null;
    }
  }

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await reloadUserData();
  }

  String _generarCodigo() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  /// Fase 1: Crea el usuario en Auth y guarda los datos en una colección temporal
  Future<void> registerAuthOnly({
    required String nombre,
    required String email,
    required String password,
    String? negocioNombre,
    String? codigoInvitacion,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email, 
      password: password
    );
    final user = userCredential.user!;

    // Guardar datos en colección temporal para no ensuciar la base de datos principal
    await _firestore.collection('pre_registro').doc(user.uid).set({
      'nombre': nombre,
      'email': email,
      'negocioNombre': negocioNombre,
      'codigoInvitacion': codigoInvitacion,
      'fechaRegistro': FieldValue.serverTimestamp(),
    });

    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Fase 2: Mueve los datos de la colección temporal a las colecciones reales
  Future<void> completarRegistroDesdeTemporal() async {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) return;

    final doc = await _firestore.collection('pre_registro').doc(user.uid).get();
    if (!doc.exists) return; // Ya se completó o no existe

    final data = doc.data()!;
    final String nombre = data['nombre'] ?? '';
    final String email = data['email'] ?? '';
    final String? negocioNombre = data['negocioNombre'];
    final String? codigoInvitacion = data['codigoInvitacion'];

    if (codigoInvitacion != null && codigoInvitacion.isNotEmpty) {
      final query = await _firestore.collection('negocios').where('codigoInvitacion', isEqualTo: codigoInvitacion).limit(1).get();
      if (query.docs.isEmpty) throw Exception('El código de invitación ya no es válido');
      
      final negocioDoc = query.docs.first;
      await _firestore.collection('usuarios').doc(user.uid).set({
        'nombre': nombre,
        'email': email,
        'negocioNombre': negocioDoc['nombre'],
        'negocioId': negocioDoc.id,
        'estatus': 'aprobado',
        'rol': rolEmpleado,
      });
    } else if (negocioNombre != null && negocioNombre.isNotEmpty) {
      final negocioRef = _firestore.collection('negocios').doc();
      await negocioRef.set({
        'nombre': negocioNombre,
        'creadoPor': user.uid,
        'codigoInvitacion': _generarCodigo(),
      });

      await _firestore.collection('usuarios').doc(user.uid).set({
        'nombre': nombre,
        'email': email,
        'negocioNombre': negocioNombre,
        'negocioId': negocioRef.id,
        'estatus': 'pendiente',
        'rol': rolDueno,
      });
    }

    // Limpieza
    await _firestore.collection('pre_registro').doc(user.uid).delete();
    await reloadUserData();
  }

  Future<void> loginWithGoogle() async {
    UserCredential? credential;
    try {
      if (kIsWeb) {
        // Usamos Redirect en lugar de Popup para evitar bloqueos de seguridad COOP de los navegadores
        await _auth.signInWithRedirect(GoogleAuthProvider());
        // En Web, el flujo se detiene aquí porque la página se recarga
        return; 
      } else {
        credential = await _auth.signInWithProvider(GoogleAuthProvider());
      }
      
      if (credential.user != null) {
        await reloadUserData();
      }
    } catch (e) {
      throw Exception('Error en Google Sign-In: $e');
    }
  }

  Future<void> completarRegistroGoogle({
    String? negocioNombre,
    String? codigoInvitacion,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No hay usuario autenticado');

    if (codigoInvitacion != null && codigoInvitacion.isNotEmpty) {
      final query = await _firestore.collection('negocios').where('codigoInvitacion', isEqualTo: codigoInvitacion).limit(1).get();
      if (query.docs.isEmpty) throw Exception('El código de invitación no existe o ya expiró');
      
      final negocioDoc = query.docs.first;
      await _firestore.collection('usuarios').doc(user.uid).set({
        'nombre': user.displayName ?? 'Usuario Google',
        'email': user.email ?? '',
        'negocioNombre': negocioDoc['nombre'],
        'negocioId': negocioDoc.id,
        'estatus': 'aprobado',
        'rol': 'empleado',
      });
    } else if (negocioNombre != null && negocioNombre.isNotEmpty) {
      final negocioRef = _firestore.collection('negocios').doc();
      await negocioRef.set({
        'nombre': negocioNombre,
        'creadoPor': user.uid,
        'codigoInvitacion': _generarCodigo(),
      });

      await _firestore.collection('usuarios').doc(user.uid).set({
        'nombre': user.displayName ?? 'Usuario Google',
        'email': user.email ?? '',
        'negocioNombre': negocioNombre,
        'negocioId': negocioRef.id,
        'estatus': 'pendiente',
        'rol': 'dueño',
      });
    } else {
      throw Exception('Falta el nombre del negocio o un código de invitación');
    }

    await reloadUserData();
  }

  Future<String> obtenerCodigoInvitacionActual() async {
    final negocioId = currentNegocioId;
    if (negocioId.isEmpty) return '';
    final doc = await _firestore.collection('negocios').doc(negocioId).get();
    return doc.data()?['codigoInvitacion'] ?? '';
  }

  Future<String> regenerarCodigoInvitacion() async {
    final negocioId = currentNegocioId;
    if (negocioId.isEmpty) throw Exception('No hay negocio activo');
    final nuevoCodigo = _generarCodigo();
    await _firestore.collection('negocios').doc(negocioId).update({
      'codigoInvitacion': nuevoCodigo
    });
    return nuevoCodigo;
  }

  Future<void> despedirEmpleado(String empleadoUid) async {
    await _firestore.collection('usuarios').doc(empleadoUid).update({
      'estatus': 'despedido'
    });
  }

  /// Actualiza los permisos de un empleado en Firestore.
  Future<void> actualizarPermisosEmpleado(String empleadoUid, PermisosEmpleado permisos) async {
    await _firestore.collection('usuarios').doc(empleadoUid).update({
      'permisos': permisos.toMap(),
    });
    // Si estamos editando los permisos del usuario actual, recargamos
    if (_auth.currentUser?.uid == empleadoUid) {
      await reloadUserData();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    currentUserData = null;
  }
}
