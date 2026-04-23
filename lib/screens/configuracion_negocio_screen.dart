import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/negocio.dart';
import '../services/firebase_service.dart';

class ConfiguracionNegocioScreen extends StatefulWidget {
  const ConfiguracionNegocioScreen({super.key});

  @override
  State<ConfiguracionNegocioScreen> createState() => _ConfiguracionNegocioScreenState();
}

class _ConfiguracionNegocioScreenState extends State<ConfiguracionNegocioScreen> {
  final _firebaseService = FirebaseService();
  
  final _nombreCtrl = TextEditingController();
  final _rfcCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  
  String? _logoUrl;
  Uint8List? _previewBytes;
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final negocio = await _firebaseService.getDatosNegocio();
      setState(() {
        _nombreCtrl.text = negocio.nombre;
        _rfcCtrl.text = negocio.rfc ?? '';
        _telCtrl.text = negocio.telefono ?? '';
        _dirCtrl.text = negocio.direccion ?? '';
        _logoUrl = negocio.logoUrl;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  Future<void> _seleccionarImagen() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _previewBytes = bytes;
      });
    }
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    
    setState(() => _isSaving = true);
    try {
      String? finalLogoUrl = _logoUrl;
      
      // Si seleccionó una nueva imagen, subirla a Storage
      if (_previewBytes != null) {
        finalLogoUrl = await _firebaseService.subirLogoNegocio(_previewBytes!);
      }

      final negocio = await _firebaseService.getDatosNegocio();
      final actualizado = negocio.copyWith(
        nombre: _nombreCtrl.text.trim(),
        rfc: _rfcCtrl.text.trim().isNotEmpty ? _rfcCtrl.text.trim() : null,
        telefono: _telCtrl.text.trim().isNotEmpty ? _telCtrl.text.trim() : null,
        direccion: _dirCtrl.text.trim().isNotEmpty ? _dirCtrl.text.trim() : null,
        logoUrl: finalLogoUrl,
      );
      
      await _firebaseService.actualizarDatosNegocio(actualizado);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identidad del Negocio')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Información Visual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _seleccionarImagen,
                    child: Container(
                      width: 150, height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _previewBytes != null
                          ? Image.memory(_previewBytes!, fit: BoxFit.contain)
                          : (_logoUrl != null
                              ? Image.network(_logoUrl!, fit: BoxFit.contain)
                              : const Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.blue)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _seleccionarImagen,
                    child: Text(_logoUrl == null && _previewBytes == null ? 'Subir Logotipo' : 'Cambiar Logotipo'),
                  ),
                ),
                const Divider(height: 48),
                const Text('Datos Fiscales y de Contacto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                _buildField('Nombre Comercial *', _nombreCtrl, Icons.business),
                _buildField('RFC / Identificación Fiscal', _rfcCtrl, Icons.description_outlined),
                _buildField('Teléfono de Contacto', _telCtrl, Icons.phone_android),
                _buildField('Dirección Física', _dirCtrl, Icons.location_on_outlined, maxLines: 2),
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton.icon(
                    icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.save_outlined),
                    onPressed: _isSaving ? null : _guardar,
                    label: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Guardar y Actualizar Localmente', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }
}
