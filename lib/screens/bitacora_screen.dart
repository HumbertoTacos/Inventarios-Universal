import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../models/bitacora_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../widgets/app_drawer.dart';

class BitacoraScreen extends StatefulWidget {
  const BitacoraScreen({super.key});

  @override
  State<BitacoraScreen> createState() => _BitacoraScreenState();
}

class _BitacoraScreenState extends State<BitacoraScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  DateTimeRange? _rangoSeleccionado;
  
  // Referencia a la colección para el query directo
  final CollectionReference _bitacoraRef = FirebaseFirestore.instance.collection('bitacora');

  Future<void> _seleccionarRangoFechas() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _rangoSeleccionado,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _rangoSeleccionado = picked);
    }
  }

  Future<void> _exportarBitacora(List<BitacoraLog> logs) async {
    if (logs.isEmpty) return;

    try {
      // 1. Preparar datos
      List<List<dynamic>> rows = [];
      rows.add(['Fecha', 'Módulo', 'Usuario', 'Descripción']); // Cabecera

      for (var log in logs) {
        rows.add([
          DateFormat('yyyy-MM-dd HH:mm').format(log.fecha),
          log.modulo,
          log.nombreUsuario,
          log.descripcion,
        ]);
      }

      // 2. Convertir a CSV
      String csvData = const ListToCsvConverter().convert(rows);

      // 3. Guardar temporalmente
      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final path = '${directory.path}/bitacora_$dateStr.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      // 4. Compartir/Abrir
      await Share.shareXFiles([XFile(path)], text: 'Bitácora de Movimientos');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final negocioId = AuthService().currentNegocioId;
    Query query = _bitacoraRef
        .where('negocioId', isEqualTo: negocioId)
        .orderBy('fecha', descending: true)
        .limit(50);

    if (_rangoSeleccionado != null) {
      // Ajustamos el fin para incluir todo el último día (23:59:59)
      final inicio = DateTime(_rangoSeleccionado!.start.year, _rangoSeleccionado!.start.month, _rangoSeleccionado!.start.day);
      final fin = DateTime(_rangoSeleccionado!.end.year, _rangoSeleccionado!.end.month, _rangoSeleccionado!.end.day, 23, 59, 59);
      
      query = query
          .where('fecha', isGreaterThanOrEqualTo: inicio.toIso8601String())
          .where('fecha', isLessThanOrEqualTo: fin.toIso8601String());
    }

    return Scaffold(
      drawer: const AppDrawer(currentRoute: 'bitacora'),
      appBar: AppBar(
        title: const Text('Bitácora de Movimientos'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: query.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
              return IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: () {
                  final logs = snapshot.data!.docs.map((doc) => BitacoraLog.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
                  _exportarBitacora(logs);
                },
                tooltip: 'Exportar a CSV',
              );
            }
          ),
          if (_rangoSeleccionado != null)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => setState(() => _rangoSeleccionado = null),
              tooltip: 'Limpiar filtro',
            ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _seleccionarRangoFechas,
            tooltip: 'Filtrar por fecha',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data!.docs.map((doc) {
            return BitacoraLog.fromMap(doc.data() as Map<String, dynamic>, doc.id);
          }).toList();

          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.manage_search, size: 64, color: colorScheme.outline.withAlpha(100)),
                  const SizedBox(height: 16),
                  const Text('No se encontraron movimientos', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: logs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: _getIconForModulo(log.modulo),
                title: Text(log.descripcion, style: const TextStyle(fontSize: 14)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    children: [
                      Text(log.nombreUsuario, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 12)),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd/MM HH:mm').format(log.fecha), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(log.modulo, style: TextStyle(fontSize: 10, color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _getIconForModulo(String modulo) {
    IconData iconData;
    Color color;

    switch (modulo) {
      case 'VENTAS':
        iconData = Icons.point_of_sale;
        color = Colors.green;
        break;
      case 'INVENTARIO':
        iconData = Icons.inventory_2_outlined;
        color = Colors.orange;
        break;
      case 'CAJA':
        iconData = Icons.payments_outlined;
        color = Colors.blue;
        break;
      case 'CREDITOS':
        iconData = Icons.person_outline;
        color = Colors.purple;
        break;
      default:
        iconData = Icons.history;
        color = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: color.withAlpha(30),
      radius: 18,
      child: Icon(iconData, size: 18, color: color),
    );
  }
}
