import 'package:flutter/material.dart';
import '../models/turno_caja.dart';
import '../services/firebase_service.dart';

class CajaScreen extends StatefulWidget {
  const CajaScreen({Key? key}) : super(key: key);

  @override
  _CajaScreenState createState() => _CajaScreenState();
}

class _CajaScreenState extends State<CajaScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  TurnoCaja? _turnoActivo;
  bool _isLoading = true;

  final TextEditingController _fondoInicialController = TextEditingController();
  final TextEditingController _efectivoContadoController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarTurnoActivo();
  }

  Future<void> _cargarTurnoActivo() async {
    setState(() => _isLoading = true);
    try {
      final turno = await _firebaseService.getTurnoActivo();
      setState(() => _turnoActivo = turno);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar caja: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _abrirCaja() async {
    final fondoInicial = double.tryParse(_fondoInicialController.text) ?? 0.0;
    
    final nuevoTurno = TurnoCaja(
      id: '',
      fechaApertura: DateTime.now(),
      fondoInicial: fondoInicial,
    );

    setState(() => _isLoading = true);
    try {
      await _firebaseService.abrirTurnoCaja(nuevoTurno);
      await _cargarTurnoActivo();
      _fondoInicialController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caja abierta exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cerrarCaja() async {
    if (_turnoActivo == null) return;

    final efectivoContado = double.tryParse(_efectivoContadoController.text) ?? 0.0;

    setState(() => _isLoading = true);
    try {
      await _firebaseService.cerrarTurnoCaja(_turnoActivo!.id, efectivoContado);
      await _cargarTurnoActivo();
      _efectivoContadoController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caja cerrada (Arqueo completado)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arqueo de Caja'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _turnoActivo == null ? _buildAbrirCaja() : _buildCerrarCaja(),
      ),
    );
  }

  Widget _buildAbrirCaja() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
        const SizedBox(height: 20),
        const Text(
          'La caja está cerrada',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _fondoInicialController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto de Fondo Inicial (\$)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _abrirCaja,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
          child: const Text('ABRIR CAJA', style: TextStyle(fontSize: 18)),
        )
      ],
    );
  }

  Widget _buildCerrarCaja() {
    final turno = _turnoActivo!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_open, size: 60, color: Colors.green),
          const SizedBox(height: 10),
          const Text(
            'Caja Abierta',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const Divider(height: 40),
          
          _buildInfoRow('Fondo Inicial:', turno.fondoInicial),
          _buildInfoRow('Ventas en Efectivo:', turno.ventasEfectivo),
          const Divider(),
          _buildInfoRow(
            'Total Esperado en Caja:', 
            turno.totalEsperadoEfectivo,
            isBold: true
          ),
          
          const SizedBox(height: 40),
          const Text(
            'ARQUEO / CORTE',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _efectivoContadoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Efectivo físico contado en caja (\$)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _cerrarCaja,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.all(16)
            ),
            child: const Text('CERRAR CAJA', style: TextStyle(fontSize: 18, color: Colors.white)),
          ),
          
          const SizedBox(height: 20),
          const Text(
            '* Nota: Al presionar Cerrar Caja, se registrará el sobrante/faltante con base al efectivo ingresado.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center,
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
