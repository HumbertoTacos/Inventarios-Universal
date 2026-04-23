import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'auth_gate.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _nombreController          = TextEditingController();
  final _emailController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _negocioController         = TextEditingController();
  final _codigoController          = TextEditingController();

  bool _isCreatingBusiness    = true;
  bool _isLoading             = false;
  bool _obscurePassword       = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _negocioController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final nombre  = _nombreController.text.trim();
    final email   = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm  = _confirmPasswordController.text;

    if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
      _msg('Por favor, llena todos los campos obligatorios.');
      return;
    }
    if (password != confirm) {
      _msg('Las contraseñas no coinciden.');
      return;
    }
    if (password.length < 6) {
      _msg('La contraseña debe tener al menos 6 caracteres.');
      return;
    }
    if (_isCreatingBusiness && _negocioController.text.trim().isEmpty) {
      _msg('Ingresa el nombre de tu negocio.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().registerAuthOnly(
        nombre:            nombre,
        email:             email,
        password:          password,
        negocioNombre:     _isCreatingBusiness ? _negocioController.text.trim() : null,
        codigoInvitacion:  !_isCreatingBusiness ? _codigoController.text.trim() : null,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) _msg('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().loginWithGoogle();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) _msg('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _msg(String m, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 32),
                // Form card
                _buildFormCard(),
                const SizedBox(height: 20),
                // Back to login
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text.rich(
                    TextSpan(
                      text: '¿Ya tienes cuenta? ',
                      style: GoogleFonts.outfit(color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: 'Inicia sesión',
                          style: GoogleFonts.outfit(
                            color:      AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          'Crea tu cuenta',
          style: GoogleFonts.outfit(
            fontSize:   26,
            fontWeight: FontWeight.w700,
            color:      AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Configura tu negocio en menos de un minuto',
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color:     Colors.black.withAlpha(10),
            blurRadius: 24,
            offset:    const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Sección 1: Datos Personales ───────────────────────────────────
          _buildSectionLabel('Información personal', Icons.person_outline),
          const SizedBox(height: 16),
          TextField(
            controller: _nombreController,
            decoration: const InputDecoration(
              labelText:  'Nombre completo',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller:  _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText:  'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller:  _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText:  'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller:  _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText:  'Confirmar contraseña',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),

          // ── Sección 2: Tipo de Cuenta ─────────────────────────────────────
          _buildSectionLabel('Tipo de cuenta', Icons.business_outlined),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildAccountTypeCard(
                  icon:     Icons.storefront_rounded,
                  title:    'Propietario',
                  subtitle: 'Crear negocio',
                  selected: _isCreatingBusiness,
                  onTap:    () => setState(() { _isCreatingBusiness = true; _codigoController.clear(); }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAccountTypeCard(
                  icon:     Icons.badge_rounded,
                  title:    'Empleado',
                  subtitle: 'Tengo un código',
                  selected: !_isCreatingBusiness,
                  onTap:    () => setState(() { _isCreatingBusiness = false; _negocioController.clear(); }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: _isCreatingBusiness
                ? TextField(
                    key:        const ValueKey('negocio'),
                    controller: _negocioController,
                    decoration: const InputDecoration(
                      labelText:  'Nombre de tu negocio',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                  )
                : TextField(
                    key:        const ValueKey('codigo'),
                    controller: _codigoController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText:  'Código de invitación',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                      helperText: 'Tu dueño te lo proporcionará',
                    ),
                  ),
          ),

          const SizedBox(height: 28),

          // ── Botones ───────────────────────────────────────────────────────
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: CircularProgressIndicator(),
            ))
          else ...[
            FilledButton(
              onPressed: _registrar,
              child: const Text('Crear cuenta'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('o', style: GoogleFonts.outfit(color: AppColors.textSecondary)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon:  const Icon(Icons.g_mobiledata, size: 22, color: Color(0xFFDB4437)),
              label: const Text('Registrarse con Google'),
              onPressed: _loginWithGoogle,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize:   13,
            fontWeight: FontWeight.w700,
            color:      AppColors.primary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTypeCard({
    required IconData icon,
    required String   title,
    required String   subtitle,
    required bool     selected,
    required VoidCallback onTap,
  }) {
    final bg     = selected ? AppColors.primary.withAlpha(15) : AppColors.surfaceVariant;
    final border = selected ? AppColors.primary : AppColors.outline;
    final iconC  = selected ? AppColors.primary : AppColors.textSecondary;
    final titleC = selected ? AppColors.primary : AppColors.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color:        bg,
          borderRadius: BorderRadius.circular(12),
          border:       Border.all(color: border, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconC, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                color:      titleC,
                fontSize:   13,
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
