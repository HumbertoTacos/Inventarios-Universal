import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = 'Solicitando permisos...';
    });

    // Solicitar permiso para instalar paquetes
    if (Platform.isAndroid) {
      if (await Permission.requestInstallPackages.isDenied) {
        await Permission.requestInstallPackages.request();
      }
    }

    setState(() {
      _statusMessage = 'Descargando actualización...';
    });

    try {
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/update_${widget.updateInfo.versionAString}.apk';

      final dio = Dio();
      await dio.download(
        widget.updateInfo.apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _progress = received / total;
            });
          }
        },
      );

      setState(() {
        _statusMessage = 'Descarga completada. Iniciando instalación...';
        _progress = 1.0;
      });

      final result = await OpenFilex.open(savePath);
      
      if (result.type != ResultType.done) {
        setState(() {
          _statusMessage = 'Error al instalar: ${result.message}';
          _isDownloading = false;
        });
      } else {
        // El instalador del sistema se encargará ahora
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error en la descarga: $e';
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.updateInfo.esObligatorio && !_isDownloading,
      child: AlertDialog(
        title: const Text('Nueva Versión Disponible', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('La versión ${widget.updateInfo.versionAString} está disponible. Te recomendamos instalarla para disfrutar de las últimas mejoras y correcciones.'),
            const SizedBox(height: 24),
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(_statusMessage, style: const TextStyle(fontSize: 13, color: Colors.grey))),
                  Text('${(_progress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ] else if (_statusMessage.isNotEmpty) ...[
              Text(_statusMessage, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ]
          ],
        ),
        actions: [
          if (!widget.updateInfo.esObligatorio && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Más tarde'),
            ),
          if (!_isDownloading)
            FilledButton.icon(
              icon: const Icon(Icons.download),
              onPressed: _startDownload,
              label: const Text('Actualizar Ahora'),
            ),
        ],
      ),
    );
  }
}
