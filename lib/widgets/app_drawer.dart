import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/inventario_screen.dart';
import '../screens/ventas_screen.dart';
import '../screens/historial_ventas_screen.dart';
import '../screens/clientes_screen.dart';
import '../screens/estadisticas_screen.dart';
import '../screens/gestion_categorias_screen.dart';
import '../screens/mi_equipo_screen.dart';
import '../screens/bitacora_screen.dart';
import '../screens/configuracion_negocio_screen.dart';
import '../screens/auth_gate.dart';
import '../screens/caja_screen.dart';
import '../screens/gestion_proveedores_screen.dart';
import '../screens/registro_compra_screen.dart';
import '../screens/ajuste_inventario_screen.dart';
import '../models/negocio.dart';
import '../controllers/configuracion_controller.dart';

class AppDrawer extends StatefulWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _authService = AuthService();
  late final ConfiguracionController _configController;

  @override
  void initState() {
    super.initState();
    _configController = ConfiguracionController.instance;
    _configController.addListener(_rebuild);
    if (_configController.negocio == null) {
      _configController.cargarConfiguracion();
    }
  }

  @override
  void dispose() {
    _configController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _navigateTo(Widget screen, String routeName) {
    Navigator.pop(context); // Close drawer
    if (widget.currentRoute == routeName) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = _authService.currentUserData;
    final String userRol = userData?.rol?.toLowerCase() ?? '';
    final bool esDueno = userRol == 'dueño' || userRol == 'dueno' || userRol == 'admin';
    final bool puedeVerHistorial =
        esDueno || (userData?.permisos.puedeVerHistorialVentas ?? true);
    final bool puedeVerEstadisticas =
        esDueno || (userData?.permisos.puedeVerEstadisticas ?? false);

    final colorScheme = Theme.of(context).colorScheme;
    final negocio = _configController.negocio;
    final usaCaja = _configController.usaCajaRegistradora;

    return Drawer(
      child: Column(
        children: [
          _buildHeader(colorScheme, userData, negocio),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'Inventario',
                  routeName: 'inventario',
                  screen: const InventarioScreen(),
                ),
                _buildMenuItem(
                  icon: Icons.auto_fix_high_outlined,
                  title: 'Mermas y Ajustes',
                  routeName: '/ajuste_inventario',
                  screen: const AjusteInventarioScreen(),
                ),
                _buildMenuItem(
                  icon: Icons.point_of_sale,
                  title: 'Punto de Venta',
                  routeName: 'ventas',
                  screen: const VentasScreen(),
                ),
                if (usaCaja)
                  _buildMenuItem(
                    icon: Icons.point_of_sale_outlined,
                    title: 'Caja y Turnos',
                    routeName: 'caja',
                    screen: const CajaScreen(),
                  ),
                if (puedeVerHistorial)
                  _buildMenuItem(
                    icon: Icons.history,
                    title: 'Historial de Ventas',
                    routeName: 'historial',
                    screen: const HistorialVentasScreen(),
                  ),
                _buildMenuItem(
                  icon: Icons.people_outlined,
                  title: 'Clientes y Créditos',
                  routeName: 'clientes',
                  screen: const ClientesScreen(),
                ),

                if (esDueno || puedeVerEstadisticas) ...[
                  const Divider(),
                  _buildMenuItem(
                    icon: Icons.bar_chart,
                    title: 'Estadísticas y Ganancias',
                    routeName: 'estadisticas',
                    screen: const EstadisticasScreen(),
                  ),
                ],

                if (esDueno) ...[
                  const Divider(),
                  _buildMenuItem(
                    icon: Icons.local_shipping_outlined,
                    title: 'Proveedores',
                    routeName: '/proveedores',
                    screen: const GestionProveedoresScreen(),
                  ),
                  _buildMenuItem(
                    icon: Icons.add_business_outlined,
                    title: 'Registrar Compra',
                    routeName: '/registro_compra',
                    screen: const RegistroCompraScreen(),
                  ),
                  _buildMenuItem(
                    icon: Icons.category_outlined,
                    title: 'Gestionar Categorías',
                    routeName: 'categorias',
                    screen: const GestionCategoriasScreen(),
                  ),
                  _buildMenuItem(
                    icon: Icons.people_alt_outlined,
                    title: 'Mi Equipo',
                    routeName: 'equipo',
                    screen: const MiEquipoScreen(),
                  ),
                  _buildMenuItem(
                    icon: Icons.manage_search_outlined,
                    title: 'Bitácora de Movimientos',
                    routeName: 'bitacora',
                    screen: const BitacoraScreen(),
                  ),
                  _buildMenuItem(
                    icon: Icons.settings_outlined,
                    title: 'Configuración del Negocio',
                    routeName: 'configuracion',
                    screen: const ConfiguracionNegocioScreen(),
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onTap: () async {
              await _authService.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, UserData? userData, Negocio? negocio) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white,
            child: ClipOval(
              child: negocio?.logoUrl != null && negocio!.logoUrl!.isNotEmpty
                ? Image.network(
                    negocio.logoUrl!,
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                        Icon(Icons.storefront, size: 35, color: colorScheme.primary),
                  )
                : Icon(Icons.storefront, size: 35, color: colorScheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            negocio?.nombre ??
                userData?.negocioNombre ??
                'Inventarios Universal',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            userData?.nombre ?? '',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              (userData?.rol ?? '').toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String routeName,
    required Widget screen,
  }) {
    final isSelected = widget.currentRoute == routeName;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => _navigateTo(screen, routeName),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
