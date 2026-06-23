import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'registro_screen.dart';
import 'auth_gate.dart';
import 'recuperar_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading    = false;
  bool _obscurePass  = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final pass  = _passwordController.text;
    if (email.isEmpty || pass.isEmpty) {
      _msg('Por favor, ingresa tu correo y contraseña.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService().login(email, pass);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }
    } catch (e) {
      if (mounted) _msg('Credenciales incorrectas. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginGoogle() async {
    setState(() => _isLoading = true);
    try {
      await AuthService().loginWithGoogle();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }
    } catch (e) {
      if (mounted) _msg('Error con Google: $e');
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
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  // ── Layout Móvil (< 900px) ────────────────────────────────────────────────

  Widget _buildNarrowLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLogo(large: false),
              const SizedBox(height: 40),
              _buildFormCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Layout Web / Tablet (>= 900px) ────────────────────────────────────────

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Panel de branding (izquierda)
        Expanded(
          flex: 5,
          child: _buildBrandingPanel(),
        ),
        // Panel de formulario (derecha)
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _buildFormCard(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Panel de Branding ─────────────────────────────────────────────────────

  Widget _buildBrandingPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, const Color(0xFF6366F1)],
        ),
      ),
      child: Stack(
        children: [
          // Pattern decorativo (círculos sutiles)
          Positioned(
            top: -60, left: -60,
            child: _buildDecorCircle(240, Colors.white.withAlpha(10)),
          ),
          Positioned(
            bottom: -80, right: -80,
            child: _buildDecorCircle(300, Colors.white.withAlpha(8)),
          ),
          Positioned(
            top: 200, right: -40,
            child: _buildDecorCircle(180, Colors.white.withAlpha(12)),
          ),
          // Contenido
          Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(large: true, light: true),
                const SizedBox(height: 56),
                Text(
                  'Gestiona tu negocio\ncon inteligencia.',
                  style: GoogleFonts.outfit(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Control de inventario, punto de venta y análisis financiero en un solo lugar.',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Colors.white.withAlpha(180),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),
                ..._buildFeatureItems(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  List<Widget> _buildFeatureItems() {
    final features = [
      (Icons.inventory_2_outlined, 'Inventario en tiempo real'),
      (Icons.point_of_sale_outlined, 'Punto de venta integrado'),
      (Icons.bar_chart_outlined, 'Reportes y estadísticas'),
      (Icons.group_outlined, 'Gestión de equipo'),
    ];
    return features.map((f) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(f.$1, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 14),
          Text(
            f.$2,
            style: GoogleFonts.outfit(
              color: Colors.white.withAlpha(220),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    )).toList();
  }

  // ── Logo ──────────────────────────────────────────────────────────────────

  Widget _buildLogo({required bool large, bool light = false}) {
    final iconBg    = light ? Colors.white.withAlpha(30) : AppColors.primary.withAlpha(20);
    final iconColor = light ? Colors.white : AppColors.primary;
    final textColor = light ? Colors.white : AppColors.textPrimary;
    final subColor  = light ? Colors.white.withAlpha(180) : AppColors.textSecondary;

    return Row(
      mainAxisSize: large ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.all(large ? 14 : 11),
          decoration: BoxDecoration(
            color:        iconBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.inventory_2_rounded,
            color: iconColor,
            size:  large ? 28 : 22,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventarios',
              style: GoogleFonts.outfit(
                fontSize:   large ? 22 : 18,
                fontWeight: FontWeight.w700,
                color:      textColor,
              ),
            ),
            Text(
              'Universal',
              style: GoogleFonts.outfit(
                fontSize:   large ? 13 : 11,
                fontWeight: FontWeight.w500,
                color:      subColor,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Formulario ────────────────────────────────────────────────────────────

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color:  AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color:   Colors.black.withAlpha(10),
            blurRadius: 24,
            offset:  const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bienvenido de vuelta',
            style: GoogleFonts.outfit(
              fontSize:   24,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ingresa con tu cuenta para continuar',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color:    AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Email
          TextField(
            controller:  _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText:  'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),

          // Contraseña
          TextField(
            controller:  _passwordController,
            obscureText: _obscurePass,
            onSubmitted: (_) => _login(),
            decoration: InputDecoration(
              labelText:  'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RecuperarPasswordScreen()),
              ),
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: GoogleFonts.outfit(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Botón principal
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: CircularProgressIndicator(),
            ))
          else ...[
            FilledButton(
              onPressed: _login,
              child: const Text('Iniciar Sesión'),
            ),
            const SizedBox(height: 12),

            // Divider OR
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

            // Google
            OutlinedButton.icon(
              icon:  const Icon(Icons.g_mobiledata, size: 22, color: Color(0xFFDB4437)),
              label: const Text('Continuar con Google'),
              onPressed: _loginGoogle,
            ),
            const SizedBox(height: 20),

            // Registrarse
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegistroScreen()),
                ),
                child: Text.rich(
                  TextSpan(
                    text: '¿No tienes cuenta? ',
                    style: GoogleFonts.outfit(color: AppColors.textSecondary),
                    children: [
                      TextSpan(
                        text: 'Registra tu negocio',
                        style: GoogleFonts.outfit(
                          color:      AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
