import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserData {
  final String uid;
  final String nombre;
  final String email;
  final String negocioNombre;
  final String negocioId;
  final String estatus;
  final String rol;

  UserData({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.negocioNombre,
    required this.negocioId,
    required this.estatus,
    required this.rol,
  });
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

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
        currentUserData = UserData(
          uid: user.uid,
          nombre: data['nombre'] ?? '',
          email: data['email'] ?? '',
          negocioNombre: data['negocioNombre'] ?? '',
          negocioId: data['negocioId'] ?? '',
          estatus: data['estatus'] ?? 'pendiente',
          rol: data['rol'] ?? 'usuario',
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

  Future<void> register({
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

    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
    
    if (codigoInvitacion != null && codigoInvitacion.isNotEmpty) {
      // Entra como empleado aprobado de inmediato
      final query = await _firestore.collection('negocios').where('codigoInvitacion', isEqualTo: codigoInvitacion).limit(1).get();
      if (query.docs.isEmpty) throw Exception('El código de invitación no existe o ya expiró');
      
      final negocioDoc = query.docs.first;
      await _firestore.collection('usuarios').doc(user.uid).set({
        'nombre': nombre,
        'email': email,
        'negocioNombre': negocioDoc['nombre'],
        'negocioId': negocioDoc.id,
        'estatus': 'aprobado',
        'rol': 'empleado',
      });
    } else if (negocioNombre != null && negocioNombre.isNotEmpty) {
      // Crea el negocio como dueño
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
        'rol': 'dueño',
      });
    } else {
      throw Exception('Falta el nombre del negocio o un código de invitación');
    }

    await reloadUserData();
  }

  Future<void> loginWithGoogle() async {
    UserCredential? credential;
    try {
      if (kIsWeb) {
        credential = await _auth.signInWithPopup(GoogleAuthProvider());
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

  Future<void> logout() async {
    await _auth.signOut();
    currentUserData = null;
  }
}
