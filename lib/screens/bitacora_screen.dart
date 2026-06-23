import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../models/bitacora_log.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../widgets/premium_widgets.dart';
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';

class BitacoraScreen extends StatefulWidget {
  const BitacoraScreen({super.key});

  @override
  State<BitacoraScreen> createState() => _BitacoraScreenState();
}

class _BitacoraScreenState extends State<BitacoraScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  DateTimeRange? _rangoSeleccionado;
  
  // Referencia a la colección para el query directo
  // Referencia a la colección anidada para FinOps y Seguridad
  CollectionReference get _bitacoraRef {
    final id = AuthService().currentNegocioId;
    return FirebaseFirestore.instance.collection('negocios').doc(id).collection('bitacora');
  }

  Future<void> _seleccionarRangoFechas() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _rangoSeleccionado,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      setState(() => _rangoSeleccionado = picked);
    }
  }

  Future<void> _exportarBitacora(List<BitacoraLog> logs) async {
    if (logs.isEmpty) return;

    try {
      List<List<dynamic>> rows = [];
      rows.add(['Fecha', 'Módulo', 'Usuario', 'Descripción']);

      for (var log in logs) {
        rows.add([
          DateFormat('yyyy-MM-dd HH:mm').format(log.fecha),
          log.modulo,
          log.nombreUsuario,
          log.descripcion,
        ]);
      }

      final csvData = const ListToCsvConverter().convert(rows);
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final fileName = 'bitacora_$dateStr';

      // BOM UTF-8 para que Excel abra con acentos
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csvData)]);

      // FileSaver: web → descarga navegador, Android → carpeta Descargas
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.csv,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: \$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final negocioId = AuthService().currentNegocioId;
    Query query = _bitacoraRef
        .where('negocioId', isEqualTo: negocioId)
        .orderBy('fecha', descending: true)
        .limit(50);

    if (_rangoSeleccionado != null) {
      final start = DateTime(_rangoSeleccionado!.start.year, _rangoSeleccionado!.start.month, _rangoSeleccionado!.start.day);
      final end = DateTime(_rangoSeleccionado!.end.year, _rangoSeleccionado!.end.month, _rangoSeleccionado!.end.day, 23, 59, 59);
      
      query = query
          .where('fecha', isGreaterThanOrEqualTo: start)
          .where('fecha', isLessThanOrEqualTo: end);
    }

    return ResponsiveScaffold(
      currentRoute: 'bitacora',
      title: 'Bitácora de Movimientos',
      actions: [
        if (_rangoSeleccionado != null)
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () => setState(() => _rangoSeleccionado = null),
            tooltip: 'Limpiar filtro',
          ),
        IconButton(
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: _seleccionarRangoFechas,
          tooltip: 'Filtrar por fecha',
        ),
      ],
      body: ResponsiveLayout(
        mobileBody: _buildBody(query, isDesktop: false),
        tabletBody: _buildBody(query, isDesktop: true),
        desktopBody: _buildBody(query, isDesktop: true),
      ),
    );
  }

  Widget _buildBody(Query query, {bool isDesktop = false}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 800),
        child: Column(
          children: [
            if (_rangoSeleccionado != null)
              _buildRangoActivo(),
            
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final logs = snapshot.data!.docs
                      .map((doc) => BitacoraLog.fromFirestore(doc))
                      .toList();

                  if (logs.isEmpty) {
                    return const PremiumEmptyState(
                      icon: Icons.history_toggle_off,
                      title: 'Sin movimientos',
                      subtitle: 'No se encontraron registros en este período.',
                    );
                  }

                  return Column(
                    children: [
                      _buildExportButton(logs),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: logs.length,
                          itemBuilder: (context, index) => PremiumCard(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: _buildLogTile(logs[index]),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangoActivo() {
    final fmt = DateFormat('dd MMM yyyy');
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.filter_list, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'Filtrando: ${fmt.format(_rangoSeleccionado!.start)} - ${fmt.format(_rangoSeleccionado!.end)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(List<BitacoraLog> logs) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton.icon(
        onPressed: () => _exportarBitacora(logs),
        icon: const Icon(Icons.download),
        label: const Text('Exportar a CSV'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 45),
        ),
      ),
    );
  }

  Widget _buildLogTile(BitacoraLog log) {
    final tt = Theme.of(context).textTheme;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        children: [
          Text(log.modulo.toUpperCase(), 
            style: tt.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold
            )
          ),
          const Spacer(),
          Text(fmt.format(log.fecha), style: tt.labelSmall?.copyWith(color: Colors.grey)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(log.descripcion, style: tt.bodyMedium),
          const SizedBox(height: 2),
          Text('Por: ${log.nombreUsuario}', style: tt.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
