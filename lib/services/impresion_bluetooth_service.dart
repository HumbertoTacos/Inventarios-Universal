import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/venta.dart';
import '../models/turno_caja.dart';
import '../models/negocio.dart';
import 'auth_service.dart';

class ImpresionBluetoothService {
  static final ImpresionBluetoothService _instance = ImpresionBluetoothService._internal();
  factory ImpresionBluetoothService() => _instance;
  ImpresionBluetoothService._internal();

  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  static const String _printerMacKey = 'printer_mac_address';

  Future<List<BluetoothDevice>> getDevices() async {
    if (kIsWeb) return [];
    return await bluetooth.getBondedDevices();
  }

  Future<bool> conectar(BluetoothDevice device) async {
    if (kIsWeb) return false;
    try {
      final isConnected = await bluetooth.isConnected ?? false;
      if (isConnected) {
        await bluetooth.disconnect();
      }
      await bluetooth.connect(device);
      
      final prefs = await SharedPreferences.getInstance();
      if (device.address != null) {
        await prefs.setString(_printerMacKey, device.address!);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> autoconectar() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final macAddress = prefs.getString(_printerMacKey);
    if (macAddress != null) {
      final isConnected = await bluetooth.isConnected ?? false;
      if (!isConnected) {
        final devices = await getDevices();
        for (var device in devices) {
          if (device.address == macAddress) {
            await bluetooth.connect(device);
            break;
          }
        }
      }
    }
  }

  Future<void> imprimirTicketVenta(Venta venta, Negocio datosNegocio) async {
    if (kIsWeb) return; // Bluetooth no disponible en web
    final isConnected = await bluetooth.isConnected ?? false;
    if (!isConnected) {
      await autoconectar();
      final isConnectedNow = await bluetooth.isConnected ?? false;
      if (!isConnectedNow) return; // Si sigue desconectado, ignora.
    }

    final String negocioNombre = datosNegocio.nombre.isNotEmpty ? datosNegocio.nombre : 'Mi Negocio';
    final empleado = AuthService().empleadoActivo;
    final String cajeroNombre = empleado != null ? empleado.nombre : 'Admin';
    final String fechaStr = DateFormat('dd/MM/yyyy HH:mm').format(venta.fecha);
    final String folio = venta.id.length > 6 ? venta.id.substring(0, 6).toUpperCase() : venta.id.toUpperCase();

    // Iniciar impresión
    bluetooth.printCustom(negocioNombre, 3, 1); // Size 3, Align Center
    bluetooth.printNewLine();
    
    bluetooth.printCustom('Fecha: $fechaStr', 1, 0); // Size 1, Align Left
    bluetooth.printCustom('Cajero: $cajeroNombre', 1, 0);
    bluetooth.printCustom('Folio: $folio', 1, 0);
    bluetooth.printNewLine();

    bluetooth.printCustom('--------------------------------', 1, 1);
    
    for (var item in venta.items) {
      String lineName = '\${item.cantidad}x \${item.nombre}';
      if (lineName.length > 20) lineName = lineName.substring(0, 20); // Truncar si es muy largo
      String lineTotal = '\$${item.subtotal.toStringAsFixed(2)}';
      bluetooth.printLeftRight(lineName, lineTotal, 1);
    }

    bluetooth.printCustom('--------------------------------', 1, 1);
    bluetooth.printNewLine();
    
    bluetooth.printLeftRight('SUBTOTAL', '\$${venta.subtotal.toStringAsFixed(2)}', 1);
    if (venta.valorDescuento > 0) {
      bluetooth.printLeftRight('DESCUENTO', '-\$${venta.descuentoAplicado.toStringAsFixed(2)}', 1);
    }
    
    bluetooth.printCustom('TOTAL: \$${venta.total.toStringAsFixed(2)}', 2, 1); // Size 2, Align Center
    
    bluetooth.printNewLine();
    bluetooth.printCustom('¡Gracias por su compra!', 1, 1);
    
    // Avanzar papel para cortar
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
  }

  Future<void> imprimirCorteZ(TurnoCaja turno, Negocio datosNegocio) async {
    if (kIsWeb) return; // Bluetooth no disponible en web
    final isConnected = await bluetooth.isConnected ?? false;
    if (!isConnected) {
      await autoconectar();
      final isConnectedNow = await bluetooth.isConnected ?? false;
      if (!isConnectedNow) return;
    }

    final String negocioNombre = datosNegocio.nombre.isNotEmpty ? datosNegocio.nombre : 'Mi Negocio';
    final String fechaApertura = DateFormat('dd/MM/yyyy HH:mm').format(turno.fechaApertura);
    final String fechaCierre = turno.fechaCierre != null 
        ? DateFormat('dd/MM/yyyy HH:mm').format(turno.fechaCierre!) 
        : DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    bluetooth.printCustom(negocioNombre, 3, 1);
    bluetooth.printCustom('CORTE DE CAJA (Z)', 2, 1);
    bluetooth.printNewLine();

    bluetooth.printCustom('Cajero ID: ${turno.usuarioId}', 1, 0);
    bluetooth.printCustom('Apertura: $fechaApertura', 1, 0);
    bluetooth.printCustom('Cierre: $fechaCierre', 1, 0);
    bluetooth.printNewLine();

    bluetooth.printCustom('--------------------------------', 1, 1);
    
    bluetooth.printLeftRight('Fondo Inicial:', '\$${turno.fondoInicial.toStringAsFixed(2)}', 1);
    bluetooth.printLeftRight('Ventas Efectivo:', '\$${turno.ventasEfectivo.toStringAsFixed(2)}', 1);
    bluetooth.printLeftRight('Ventas Tarjeta:', '\$${turno.ventasTarjeta.toStringAsFixed(2)}', 1);
    bluetooth.printLeftRight('Ingresos:', '\$${turno.entradasEfectivo.toStringAsFixed(2)}', 1);
    bluetooth.printLeftRight('Egresos:', '\$${turno.egresosEfectivo.toStringAsFixed(2)}', 1);
    
    bluetooth.printCustom('--------------------------------', 1, 1);
    
    final efectivoEsperado = turno.fondoInicial + turno.ventasEfectivo + turno.entradasEfectivo - turno.egresosEfectivo;
    bluetooth.printLeftRight('EFECTIVO ESPERADO:', '\$${efectivoEsperado.toStringAsFixed(2)}', 1);
    
    if (turno.efectivoContado != null) {
      bluetooth.printLeftRight('EFECTIVO FISICO:', '\$${turno.efectivoContado!.toStringAsFixed(2)}', 1);
      bluetooth.printLeftRight('DIFERENCIA:', '\$${turno.diferenciaEfectivo.toStringAsFixed(2)}', 1);
    }
    
    bluetooth.printNewLine();
    bluetooth.printCustom('--------------------------------', 1, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
  }
}
