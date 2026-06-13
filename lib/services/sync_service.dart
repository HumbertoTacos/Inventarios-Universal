import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/venta.dart';
import 'firebase_service.dart';
import 'network_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  StreamSubscription? _networkSub;
  bool _isSyncing = false;

  void init() {
    _networkSub = NetworkService().onOfflineChange.listen((isOffline) {
      if (!isOffline) {
        _procesarColaOffline();
      }
    });
  }

  Future<void> _procesarColaOffline() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final firebaseService = FirebaseService();
      final negocioId = firebaseService.getNegocioIdOrNull();
      if (negocioId == null) return;

      final outboxRef = FirebaseFirestore.instance.collection('negocios').doc(negocioId).collection('cola_offline');
      
      // Buscar operaciones pendientes
      final pendientes = await outboxRef.where('estado', isEqualTo: 'pendiente').get();

      for (var doc in pendientes.docs) {
        final data = doc.data();
        
        if (data['tipoOperacion'] == 'registrarVenta') {
          final venta = Venta.fromMap(data['payload'] as Map<String, dynamic>, data['payload']['id']);
          
          // Ejecutamos la venta pasando isSyncing = true para que no vuelva al buzón
          await firebaseService.registrarVenta(venta, isSyncing: true);
          
          // Marcamos como procesado
          await doc.reference.update({
            'estado': 'procesado', 
            'fechaProcesado': DateTime.now().toIso8601String()
          });
        }
      }
    } catch (e) {
      debugPrint('Error sincronizando cola offline: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _networkSub?.cancel();
  }
}
