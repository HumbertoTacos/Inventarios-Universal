import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../services/impresion_bluetooth_service.dart';

class ConfiguracionImpresoraScreen extends StatefulWidget {
  const ConfiguracionImpresoraScreen({Key? key}) : super(key: key);

  @override
  State<ConfiguracionImpresoraScreen> createState() => _ConfiguracionImpresoraScreenState();
}

class _ConfiguracionImpresoraScreenState extends State<ConfiguracionImpresoraScreen> {
  final ImpresionBluetoothService _impresionService = ImpresionBluetoothService();
  List<BluetoothDevice> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    try {
      final devices = await _impresionService.getDevices();
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar dispositivos: \$e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _conectar(BluetoothDevice device) async {
    setState(() => _isLoading = true);
    final exito = await _impresionService.conectar(device);
    setState(() => _isLoading = false);

    if (mounted) {
      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\${device.name} conectada'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al conectar con \${device.name}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _probarImpresion() async {
    final isConnected = await _impresionService.bluetooth.isConnected ?? false;
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay impresora conectada'), backgroundColor: Colors.orange),
      );
      return;
    }

    _impresionService.bluetooth.printCustom('TICKET DE PRUEBA', 3, 1);
    _impresionService.bluetooth.printNewLine();
    _impresionService.bluetooth.printLeftRight('Prueba de texto', 'OK', 1);
    _impresionService.bluetooth.printNewLine();
    _impresionService.bluetooth.printCustom('¡Conexión Exitosa!', 1, 1);
    _impresionService.bluetooth.printNewLine();
    _impresionService.bluetooth.printNewLine();
    _impresionService.bluetooth.printNewLine();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Impresora'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDevices,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Selecciona tu impresora térmica (Asegúrate de haberla emparejado por Bluetooth en los ajustes de tu dispositivo):',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        leading: const Icon(Icons.print),
                        title: Text(device.name ?? 'Dispositivo Desconocido'),
                        subtitle: Text(device.address ?? ''),
                        onTap: () => _conectar(device),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Imprimir Ticket de Prueba'),
                    onPressed: _probarImpresion,
                  ),
                ),
              ],
            ),
    );
  }
}
