import 'package:flutter/material.dart';
import '../utils/responsive_layout.dart';
import 'app_drawer.dart';
import '../services/auth_service.dart';
import '../models/negocio.dart';
import '../screens/auth_gate.dart';

import '../screens/inventario_screen.dart';
import '../screens/ventas_screen.dart';
import '../screens/historial_ventas_screen.dart';
import '../screens/clientes_screen.dart';
import '../screens/estadisticas_screen.dart';
import '../screens/gestion_categorias_screen.dart';
import '../screens/mi_equipo_screen.dart';
import '../screens/bitacora_screen.dart';
import '../screens/configuracion_negocio_screen.dart';
import '../screens/caja_screen.dart';
import '../screens/gestion_proveedores_screen.dart';
import '../screens/registro_compra_screen.dart';
import '../controllers/configuracion_controller.dart';

class ResponsiveScaffold extends StatelessWidget {
  final String currentRoute;
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBarBottom;
  final bool hideDrawer;

  const ResponsiveScaffold({
    super.key,
    required this.currentRoute,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.appBarBottom,
    this.hideDrawer = false,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileBody: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: actions,
          bottom: appBarBottom,
        ),
        drawer: hideDrawer ? null : AppDrawer(currentRoute: currentRoute),
        body: body,
        floatingActionButton: floatingActionButton,
      ),
      tabletBody: _DesktopShell(
        currentRoute: currentRoute,
        title: title,
        actions: actions,
        appBarBottom: appBarBottom,
        floatingActionButton: floatingActionButton,
        hideDrawer: hideDrawer,
        startExpanded: false,  // Tablet: empieza compacto
        body: body,
      ),
      desktopBody: _DesktopShell(
        currentRoute: currentRoute,
        title: title,
        actions: actions,
        appBarBottom: appBarBottom,
        floatingActionButton: floatingActionButton,
        hideDrawer: hideDrawer,
        startExpanded: true,  // Desktop: empieza expandido
        body: body,
      ),
    );
  }
}

/// Shell de escritorio con sidebar togglable.
class _DesktopShell extends StatefulWidget {
  final String currentRoute;
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBarBottom;
  final bool hideDrawer;
  final bool startExpanded;

  const _DesktopShell({
    required this.currentRoute,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.appBarBottom,
    this.hideDrawer = false,
    this.startExpanded = true,
  });

  @override
  State<_DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<_DesktopShell> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.startExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          if (!widget.hideDrawer)
            AppNavigationRail(
              currentRoute: widget.currentRoute,
              extended: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
          Expanded(
            child: Column(
              children: [
                // Custom Desktop Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  color: colorScheme.surface,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (widget.actions != null)
                        ...widget.actions!,
                    ],
                  ),
                ),
                if (widget.appBarBottom != null)
                  widget.appBarBottom!,
                Expanded(
                  child: widget.body,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}

class AppNavigationRail extends StatefulWidget {
  final String currentRoute;
  final bool extended;
  final VoidCallback? onToggle;

  const AppNavigationRail({
    super.key,
    required this.currentRoute,
    this.extended = false,
    this.onToggle,
  });

  @override
  State<AppNavigationRail> createState() => _AppNavigationRailState();
}

class _AppNavigationRailState extends State<AppNavigationRail> {
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
    if (widget.currentRoute == routeName) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionDuration: const Duration(milliseconds: 150),
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
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
    
    final negocio = _configController.negocio;
    final bool usaCaja = _configController.usaCajaRegistradora;

    final colorScheme = Theme.of(context).colorScheme;

    final List<_RailItem> items = [
      _RailItem('inventario', 'Inventario', Icons.inventory_2_outlined, const InventarioScreen()),
      _RailItem('ventas', 'Punto de Venta', Icons.point_of_sale, const VentasScreen()),
      if (usaCaja)
        _RailItem('caja', 'Caja y Turnos', Icons.point_of_sale_outlined, const CajaScreen()),
      if (puedeVerHistorial)
        _RailItem('historial', 'Historial', Icons.history, const HistorialVentasScreen()),
      _RailItem('clientes', 'Clientes', Icons.people_outlined, const ClientesScreen()),
      if (esDueno || puedeVerEstadisticas)
        _RailItem('estadisticas', 'Estadísticas', Icons.bar_chart, const EstadisticasScreen()),
      if (esDueno) ...[
        _RailItem('proveedores', 'Proveedores', Icons.local_shipping_outlined, const GestionProveedoresScreen()),
        _RailItem('registro_compra', 'Comprar', Icons.add_business_outlined, const RegistroCompraScreen()),
        _RailItem('categorias', 'Categorías', Icons.category_outlined, const GestionCategoriasScreen()),
        _RailItem('equipo', 'Mi Equipo', Icons.people_alt_outlined, const MiEquipoScreen()),
        _RailItem('bitacora', 'Bitácora', Icons.manage_search_outlined, const BitacoraScreen()),
        _RailItem('configuracion', 'Configuración', Icons.settings_outlined, const ConfiguracionNegocioScreen()),
      ]
    ];

    int selectedIndex = items.indexWhere((item) => item.route == widget.currentRoute);
    if (selectedIndex == -1) selectedIndex = 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: widget.extended ? 220 : 80,
      child: _buildSidebarContent(context, colorScheme, userData, items, selectedIndex, widget.onToggle, negocio),
    );
  }

  Widget _buildSidebarContent(
    BuildContext context,
    ColorScheme colorScheme,
    UserData? userData,
    List<_RailItem> items,
    int selectedIndex,
    VoidCallback? onToggle,
    Negocio? negocio,
  ) {
    return Container(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header con logo e info ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              widget.extended ? 16 : 8,
              MediaQuery.of(context).padding.top + 16,
              widget.extended ? 16 : 8,
              16,
            ),
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
                // Fila superior con botón Hamburguesa
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.extended)
                      const Text(
                        'MENÚ',
                        style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        widget.extended ? Icons.menu_open : Icons.menu,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: onToggle,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Logo
                Center(
                  child: CircleAvatar(
                    radius: widget.extended ? 30 : 22,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: negocio?.logoUrl != null && negocio!.logoUrl!.isNotEmpty
                        ? Image.network(
                            negocio.logoUrl!,
                            width: widget.extended ? 60 : 44,
                            height: widget.extended ? 60 : 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context2, e, st) =>
                                Icon(Icons.storefront, size: widget.extended ? 30 : 22, color: colorScheme.primary),
                          )
                        : Icon(Icons.storefront, size: widget.extended ? 30 : 22, color: colorScheme.primary),
                  ),
                ),
              ),
                if (widget.extended) ...[
                  const SizedBox(height: 10),
                  Text(
                    negocio?.nombre ?? userData?.negocioNombre ?? 'Mi Negocio',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userData?.nombre ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
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
              ],
            ),
          ),
          // ── Botón toggle hamburguesa ──────────────────────────────────────
          if (onToggle != null)
            InkWell(
              onTap: onToggle,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: colorScheme.primary.withValues(alpha: 0.15),
                child: Row(
                  mainAxisAlignment: widget.extended
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(right: widget.extended ? 12 : 0),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          widget.extended ? Icons.chevron_left : Icons.chevron_right,
                          key: ValueKey(widget.extended),
                          color: colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Lista de navegación ──────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                final isSelected = i == selectedIndex;
                return _buildNavItem(context, colorScheme, item, isSelected);
              },
            ),
          ),

          // ── Cerrar Sesión ────────────────────────────────────────────────
          const Divider(height: 1),
          _buildLogoutTile(context, colorScheme),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    ColorScheme colorScheme,
    _RailItem item,
    bool isSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isSelected ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateTo(item.screen, item.route),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.extended ? 12 : 0,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: widget.extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                if (widget.extended) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.extended ? 12 : 0,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: widget.extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout, color: Colors.red, size: 22),
                if (widget.extended) ...[
                  const SizedBox(width: 14),
                  const Text(
                    'Cerrar Sesión',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailItem {
  final String route;
  final String title;
  final IconData icon;
  final Widget screen;

  _RailItem(this.route, this.title, this.icon, this.screen);
}
