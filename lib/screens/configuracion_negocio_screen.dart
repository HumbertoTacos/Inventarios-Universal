import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/negocio.dart';
import '../services/firebase_service.dart';
import '../widgets/responsive_scaffold.dart';
import '../utils/responsive_layout.dart';
import '../controllers/configuracion_controller.dart';

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
  final _pinCtrl = TextEditingController();
  
  String? _logoUrl;
  Uint8List? _previewBytes;
  
  bool _isLoading = true;
  bool _isSaving = false;

  bool _usaCajaRegistradora = false;
  bool _manejaEnvios = false;

  late final ConfiguracionController _configController;

  @override
  void initState() {
    super.initState();
    _configController = ConfiguracionController.instance;
    _configController.addListener(_syncFromController);
    _cargarDatos();
  }

  @override
  void dispose() {
    _configController.removeListener(_syncFromController);
    super.dispose();
  }

  void _syncFromController() {
    if (_configController.negocio != null && mounted) {
      setState(() {
        _usaCajaRegistradora = _configController.usaCajaRegistradora;
      });
    }
  }

  Future<void> _cargarDatos() async {
    if (_configController.negocio == null) {
      await _configController.cargarConfiguracion();
    }
    
    final negocio = _configController.negocio;
    if (negocio != null && mounted) {
      setState(() {
        _nombreCtrl.text = negocio.nombre;
        _rfcCtrl.text = negocio.rfc ?? '';
        _telCtrl.text = negocio.telefono ?? '';
        _dirCtrl.text = negocio.direccion ?? '';
        _pinCtrl.text = negocio.pinAutorizacion ?? '';
        _logoUrl = negocio.logoUrl;
        _usaCajaRegistradora = negocio.usaCajaRegistradora;
        _manejaEnvios = negocio.manejaEnvios;
        _isLoading = false;
      });
    }
  }

  Future<void> _seleccionarImagen() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) {
          setState(() {
            _previewBytes = bytes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    
    setState(() => _isSaving = true);
    try {
      String? finalLogoUrl = _logoUrl;
      
      if (_previewBytes != null) {
        finalLogoUrl = await _firebaseService.subirLogoNegocio(_previewBytes!);
      }

      final n = Negocio(
        id: '', 
        nombre: _nombreCtrl.text.trim(),
        rfc: _rfcCtrl.text.trim(),
        telefono: _telCtrl.text.trim(),
        direccion: _dirCtrl.text.trim(),
        pinAutorizacion: _pinCtrl.text.trim(),
        logoUrl: finalLogoUrl,
        usaCajaRegistradora: _usaCajaRegistradora,
        manejaEnvios: _manejaEnvios,
      );

      await _configController.guardarConfiguracionCompleta(n);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada correctamente'), backgroundColor: Colors.green),
        );
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
    return ResponsiveScaffold(
      currentRoute: 'configuracion',
      title: 'Configuración del Negocio',
      body: ResponsiveLayout(
        mobileBody: _buildBody(isDesktop: false),
        tabletBody: _buildBody(isDesktop: true),
        desktopBody: _buildBody(isDesktop: true),
      ),
    );
  }

  Widget _buildBody({bool isDesktop = false}) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogoSection(),
              const SizedBox(height: 24),
              _buildFormSection(),
              const SizedBox(height: 24),
              _buildComportamientoSection(),
              const SizedBox(height: 40),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: _previewBytes != null 
              ? MemoryImage(_previewBytes!) 
              : (_logoUrl != null ? NetworkImage(_logoUrl!) as ImageProvider : null),
            child: (_previewBytes == null && _logoUrl == null) 
              ? const Icon(Icons.store, size: 60, color: Colors.grey) 
              : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                onPressed: _seleccionarImagen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Datos Generales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _textField(_nombreCtrl, 'Nombre del Negocio', Icons.storefront, mandatory: true),
            const SizedBox(height: 12),
            _textField(_rfcCtrl, 'RFC (Opcional)', Icons.badge_outlined),
            const SizedBox(height: 12),
            _textField(_telCtrl, 'Teléfono de contacto', Icons.phone, inputType: TextInputType.phone),
            const SizedBox(height: 12),
            _textField(_dirCtrl, 'Dirección', Icons.location_on_outlined, maxLines: 2),
            const SizedBox(height: 12),
            _textField(_pinCtrl, 'PIN de Autorización (4-6 dígitos)', Icons.lock_outline, 
              inputType: TextInputType.number, 
              isPassword: true,
              hint: 'Se pedirá para cancelaciones o descuentos'),
          ],
        ),
      ),
    );
  }

  Widget _buildComportamientoSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Funciones del Sistema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Uso de Caja Registradora'),
              subtitle: const Text('Activa el control de turnos, ingresos y egresos de efectivo.'),
              value: _usaCajaRegistradora,
              onChanged: (val) => setState(() => _usaCajaRegistradora = val),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Manejo de Envíos / Domicilios'),
              subtitle: const Text('Agrega campos para dirección y repartidor en las ventas.'),
              value: _manejaEnvios,
              onChanged: (val) => setState(() => _manejaEnvios = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _guardar,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        child: _isSaving 
          ? const CircularProgressIndicator(color: Colors.white) 
          : const Text('GUARDAR CONFIGURACIÓN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String label, IconData icon, {
    bool mandatory = false, 
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
    bool isPassword = false,
    String? hint,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      maxLines: maxLines,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: mandatory ? const Text('* ', style: TextStyle(color: Colors.red)) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
