import 'package:flutter/material.dart';
import '../models/negocio.dart';
import '../services/firebase_service.dart';

class ConfiguracionController extends ChangeNotifier {
  ConfiguracionController._internal();
  static final ConfiguracionController instance = ConfiguracionController._internal();

  final FirebaseService _firebaseService = FirebaseService();
  Negocio? _negocio;
  bool _isLoading = false;

  Negocio? get negocio => _negocio;
  bool get isLoading => _isLoading;
  bool get usaCajaRegistradora => _negocio?.usaCajaRegistradora ?? false;

  Future<void> cargarConfiguracion() async {
    _isLoading = true;
    notifyListeners();
    try {
      _negocio = await _firebaseService.getDatosNegocio();
    } catch (e) {
      debugPrint('Error al cargar configuración: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Implementación de Actualización Optimista para el toggle de Caja Registradora
  Future<void> toggleUsaCajaRegistradora(bool newValue) async {
    if (_negocio == null) return;

    // 1. Guardar un respaldo
    final bool respaldoUsaCaja = _negocio!.usaCajaRegistradora;

    // 2. Actualización Inmediata (Optimista)
    // Modificamos el estado local ANTES de la llamada a Firebase
    _negocio = _negocio!.copyWith(usaCajaRegistradora: newValue);
    notifyListeners(); // Esto actualiza el sidebar y la pantalla de config en 0ms

    try {
      // 3. Llamada Asíncrona
      await _firebaseService.actualizarDatosNegocio(_negocio!);
    } catch (e) {
      // 4. Rollback (Manejo de Errores)
      _negocio = _negocio!.copyWith(usaCajaRegistradora: respaldoUsaCaja);
      notifyListeners();
      
      // Lanzamos la excepción para que la vista pueda mostrar un SnackBar
      throw Exception('No se pudo actualizar la configuración. Revisa tu conexión.');
    }
  }

  /// Guarda la configuración completa y actualiza la UI de forma optimista
  Future<void> guardarConfiguracionCompleta(Negocio nuevoNegocio) async {
    // 1. Respaldar estado actual
    final Negocio? respaldo = _negocio;

    // 2. Actualización Optimista Local
    _negocio = nuevoNegocio;
    notifyListeners();

    try {
      // 3. Persistencia en Firebase
      await _firebaseService.actualizarDatosNegocio(nuevoNegocio);
    } catch (e) {
      // 4. Rollback si falla
      _negocio = respaldo;
      notifyListeners();
      rethrow;
    }
  }
}
