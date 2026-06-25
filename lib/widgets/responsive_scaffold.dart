import 'package:flutter/material.dart';
import '../utils/responsive_layout.dart';
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
import '../screens/cuentas_por_pagar_screen.dart';
import '../screens/sugerencias_compra_screen.dart';
import '../screens/actualizacion_precios_screen.dart';
import '../screens/ajuste_inventario_screen.dart';
import '../screens/configuracion_impresora_screen.dart';
import '../controllers/configuracion_controller.dart';

// Notificador global para el estado del sidebar - Esto garantiza persistencia total
final ValueNotifier<bool> g_sidebarNotifier = ValueNotifier<bool>(true);

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
      mobileBody: _MobileShell(
        currentRoute: currentRoute,
        title: title,
        actions: actions,
        appBarBottom: appBarBottom,
        floatingActionButton: floatingActionButton,
        hideDrawer: hideDrawer,
        body: body,
      ),
      tabletBody: _DesktopShell(
        currentRoute: currentRoute,
        title: title,
        actions: actions,
        appBarBottom: appBarBottom,
        floatingActionButton: floatingActionButton,
        hideDrawer: hideDrawer,
        body: body,
      ),
      desktopBody: _DesktopShell(
        currentRoute: currentRoute,
        title: title,
        actions: actions,
        appBarBottom: appBarBottom,
        floatingActionButton: floatingActionButton,
        hideDrawer: hideDrawer,
        body: body,
      ),
    );
  }
}

// ─── Desktop Shell ────────────────────────────────────────────────────────────

class _DesktopShell extends StatelessWidget {
  final String currentRoute;
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBarBottom;
  final bool hideDrawer;

  const _DesktopShell({
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
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: g_sidebarNotifier,
      builder: (context, isExtended, child) {
        return Scaffold(
          backgroundColor: colorScheme.surfaceContainerLowest,
          body: Row(
            children: [
              if (!hideDrawer)
                AppNavigationRail(
                  currentRoute: currentRoute,
                  extended: isExtended,
                  onToggle: () {
                    g_sidebarNotifier.value = !g_sidebarNotifier.value;
                  },
                ),
              Expanded(
                child: Column(
                  children: [
                    // ── Desktop Header ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (actions != null) ...actions!,
                        ],
                      ),
                    ),
                    if (appBarBottom != null) appBarBottom!,
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: floatingActionButton,
        );
      },
    );
  }
}

// ─── Navigation Rail (Sidebar) ────────────────────────────────────────────────

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
  bool _loadingUserData = false;

  @override
  void initState() {
    super.initState();
    _configController = ConfiguracionController.instance;
    _configController.addListener(_rebuild);
    if (_configController.negocio == null) {
      _configController.cargarConfiguracion();
    }
    _checkUserData();
  }

  void _checkUserData() {
    if (_authService.currentUserData == null && !_loadingUserData) {
      _loadingUserData = true;
      _authService.reloadUserData().then((_) {
        if (mounted) setState(() => _loadingUserData = false);
      });
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
    final bool usaCaja = _configController.usaCajaRegistradora;
    final negocio = _configController.negocio;
    final colorScheme = Theme.of(context).colorScheme;

    final List<_RailItem> items = _getAvailableMenuItems(userData, usaCaja);

    int selectedIndex = items.indexWhere((item) => item.route == widget.currentRoute);
    if (selectedIndex == -1) selectedIndex = 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: widget.extended ? 228 : 72,
      child: _buildSidebarContent(
        context, colorScheme, userData, items, selectedIndex, widget.onToggle, negocio),
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
    // Sidebar background — very slightly tinted
    const sidebarBg = Color(0xFF1A2D45);
    const sidebarBgLight = Color(0xFF213552);
    const textOnSidebar = Colors.white;
    const textOnSidebarMuted = Color(0xFF8BACC4);
    const sidebarAccent = Color(0xFF4A9EE8);
    const sidebarActiveItem = Color(0xFF2E5B88);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sidebarBg, sidebarBgLight],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              widget.extended ? 16 : 8,
              MediaQuery.of(context).padding.top + 16,
              widget.extended ? 8 : 8,
              16,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              border: const Border(
                bottom: BorderSide(color: Color(0x22FFFFFF), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle button row
                Row(
                  mainAxisAlignment: widget.extended
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.center,
                  children: [
                    if (widget.extended)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Text(
                          'MENÚ',
                          style: TextStyle(
                            color: textOnSidebarMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: onToggle,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              widget.extended ? Icons.menu_open_rounded : Icons.menu_rounded,
                              key: ValueKey(widget.extended),
                              color: textOnSidebarMuted,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Logo + info
                Center(
                  child: Container(
                    width: widget.extended ? 56 : 44,
                    height: widget.extended ? 56 : 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: sidebarAccent.withValues(alpha: 0.35),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: negocio?.logoUrl != null && negocio!.logoUrl!.isNotEmpty
                          ? Image.network(
                              negocio.logoUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.storefront_rounded,
                                size: widget.extended ? 28 : 22,
                                color: const Color(0xFF2E5B88),
                              ),
                            )
                          : Icon(
                              Icons.storefront_rounded,
                              size: widget.extended ? 28 : 22,
                              color: const Color(0xFF2E5B88),
                            ),
                    ),
                  ),
                ),
                if (widget.extended) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          negocio?.nombre ?? userData?.negocioNombre ?? 'Mi Negocio',
                          style: const TextStyle(
                            color: textOnSidebar,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userData?.nombre ?? '',
                          style: const TextStyle(
                            color: textOnSidebarMuted,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: sidebarAccent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sidebarAccent.withValues(alpha: 0.35), width: 1),
                          ),
                          child: Text(
                            (userData?.rol ?? '').toUpperCase(),
                            style: const TextStyle(
                              color: sidebarAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Navigation List ───────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildSectionHeader('Operaciones', textOnSidebarMuted),
                _buildNavItemFromRoute(items, 'ventas', sidebarAccent, sidebarActiveItem),
                if (_configController.usaCajaRegistradora)
                  _buildNavItemFromRoute(items, 'caja', sidebarAccent, sidebarActiveItem),
                _buildNavItemFromRoute(items, 'historial', sidebarAccent, sidebarActiveItem),
                _buildNavItemFromRoute(items, 'clientes', sidebarAccent, sidebarActiveItem),

                _buildDivider(),

                _buildSectionHeader('Inventario', textOnSidebarMuted),
                _buildNavItemFromRoute(items, 'inventario', sidebarAccent, sidebarActiveItem),
                _buildNavItemFromRoute(items, 'actualizacion_precios', sidebarAccent, sidebarActiveItem),
                _buildNavItemFromRoute(items, 'ajuste_inventario', sidebarAccent, sidebarActiveItem),
                _buildNavItemFromRoute(items, 'categorias', sidebarAccent, sidebarActiveItem),

                _buildDivider(),

                _buildSectionHeader('Compras', textOnSidebarMuted),
                _buildNavItemFromRoute(items, 'proveedores', sidebarAccent, sidebarActiveItem),
                _buildNavItemFromRoute(items, 'registro_compra', sidebarAccent, sidebarActiveItem),
                _buildNavItemFromRoute(items, 'sugerencias_compra', sidebarAccent, sidebarActiveItem),
                _buildNavItemFromRoute(items, 'cuentas_por_pagar', sidebarAccent, sidebarActiveItem),

                _buildDivider(),

                _buildSectionHeader('Administración', textOnSidebarMuted),
                _buildNavItemFromRoute(items, 'estadisticas', sidebarAccent, sidebarActiveItem),
                _buildNavItemFromRoute(items, 'equipo', sidebarAccent, sidebarActiveItem),
                _buildNavItemFromRoute(items, 'bitacora', sidebarAccent, sidebarActiveItem),
                _buildNavItemFromRoute(items, 'configuracion', sidebarAccent, sidebarActiveItem),
                _buildNavItemFromRoute(items, 'impresora', sidebarAccent, sidebarActiveItem),
              ],
            ),
          ),

          // ── Logout ────────────────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x22FFFFFF), width: 1)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildLogoutTile(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.extended ? 16 : 12,
        vertical: 6,
      ),
      child: Container(
        height: 1,
        color: const Color(0x18FFFFFF),
      ),
    );
  }

  Widget _buildNavItemFromRoute(
    List<_RailItem> items,
    String route,
    Color accentColor,
    Color activeItemColor,
  ) {
    final i = items.indexWhere((it) => it.route == route);
    if (i == -1) return const SizedBox.shrink();
    final item = items[i];
    final isSelected = widget.currentRoute == route;
    return _buildNavItem(item, isSelected, accentColor, activeItemColor);
  }

  Widget _buildSectionHeader(String title, Color mutedColor) {
    if (!widget.extended) return const SizedBox(height: 4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: mutedColor,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    _RailItem item,
    bool isSelected,
    Color accentColor,
    Color activeItemColor,
  ) {
    const textOnSidebar = Colors.white;
    const textOnSidebarMuted = Color(0xFF8BACC4);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: accentColor.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _navigateTo(item.screen, item.route),
            hoverColor: Colors.white.withValues(alpha: 0.05),
            splashColor: accentColor.withValues(alpha: 0.1),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.extended ? 12 : 0,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment: widget.extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  // Active indicator line on left
                  if (widget.extended && isSelected)
                    Container(
                      width: 3,
                      height: 20,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )
                  else if (widget.extended)
                    const SizedBox(width: 13),

                  Icon(
                    item.icon,
                    color: isSelected ? accentColor : textOnSidebarMuted,
                    size: 20,
                  ),
                  if (widget.extended) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          color: isSelected ? textOnSidebar : textOnSidebarMuted,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 13.5,
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
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    const Color logoutColor = Color(0xFFFF6B6B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: logoutColor.withValues(alpha: 0.08),
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
                if (widget.extended) const SizedBox(width: 13),
                const Icon(Icons.logout_rounded, color: logoutColor, size: 20),
                if (widget.extended) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Cerrar Sesión',
                      style: TextStyle(
                        color: logoutColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
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
}

// ─── Rail Item ────────────────────────────────────────────────────────────────

class _RailItem {
  final String route;
  final String title;
  final IconData icon;
  final Widget screen;
  final String? section;

  _RailItem(this.route, this.title, this.icon, this.screen, {this.section});
}

List<_RailItem> _getAvailableMenuItems(UserData? userData, bool usaCaja) {
  debugPrint('DEBUG: _getAvailableMenuItems - userData: $userData, rol: ${userData?.rol}');
  final String userRol = userData?.rol?.toLowerCase() ?? '';
  final bool esDueno = userRol == 'dueño' || userRol == 'dueno' || userRol == 'admin';
  final bool puedeVerHistorial = esDueno || (userData?.permisos.puedeVerHistorialVentas ?? true);
  final bool puedeVerEstadisticas = esDueno || (userData?.permisos.puedeVerEstadisticas ?? false);
  debugPrint('DEBUG: _getAvailableMenuItems - esDueno: $esDueno, puedeVerEstadisticas: $puedeVerEstadisticas');

  return [
    _RailItem('ventas', 'Punto de Venta', Icons.point_of_sale_rounded, const VentasScreen(), section: 'Operaciones'),
    if (usaCaja) _RailItem('caja', 'Caja y Turnos', Icons.point_of_sale_outlined, const CajaScreen(), section: 'Operaciones'),
    if (puedeVerHistorial) _RailItem('historial', 'Historial de Ventas', Icons.receipt_long_rounded, const HistorialVentasScreen(), section: 'Operaciones'),
    _RailItem('clientes', 'Clientes y Créditos', Icons.people_alt_rounded, const ClientesScreen(), section: 'Operaciones'),

    _RailItem('inventario', 'Catálogo de Productos', Icons.inventory_2_rounded, const InventarioScreen(), section: 'Inventario'),
    _RailItem('actualizacion_precios', 'Actualización de Precios', Icons.price_change_rounded, const ActualizacionPreciosScreen(), section: 'Inventario'),
    _RailItem('ajuste_inventario', 'Mermas y Ajustes', Icons.auto_fix_high_rounded, const AjusteInventarioScreen(), section: 'Inventario'),
    if (esDueno) _RailItem('categorias', 'Gestionar Categorías', Icons.category_rounded, const GestionCategoriasScreen(), section: 'Inventario'),

    if (esDueno) ...[
      _RailItem('proveedores', 'Proveedores', Icons.local_shipping_rounded, const GestionProveedoresScreen(), section: 'Compras y Proveedores'),
      _RailItem('registro_compra', 'Registrar Entrada (Compra)', Icons.add_business_rounded, const RegistroCompraScreen(), section: 'Compras y Proveedores'),
      _RailItem('sugerencias_compra', 'Sugerencias de Compra', Icons.auto_graph_rounded, const SugerenciasCompraScreen(), section: 'Compras y Proveedores'),
      _RailItem('cuentas_por_pagar', 'Cuentas por Pagar', Icons.money_off_csred_rounded, const CuentasPorPagarScreen(), section: 'Compras y Proveedores'),
    ],

    if (esDueno || puedeVerEstadisticas) _RailItem('estadisticas', 'Estadísticas y Ganancias', Icons.bar_chart_rounded, const EstadisticasScreen(), section: 'Administración'),

    if (esDueno) ...[
      _RailItem('equipo', 'Mi Equipo', Icons.groups_rounded, const MiEquipoScreen(), section: 'Administración'),
      _RailItem('bitacora', 'Bitácora de Movimientos', Icons.manage_search_rounded, const BitacoraScreen(), section: 'Administración'),
      _RailItem('configuracion', 'Configuración del Negocio', Icons.settings_rounded, const ConfiguracionNegocioScreen(), section: 'Administración'),
      _RailItem('impresora', 'Impresora Bluetooth', Icons.print_rounded, const ConfiguracionImpresoraScreen(), section: 'Administración'),
    ]
  ];
}

// ─── Mobile Shell ─────────────────────────────────────────────────────────────

class _MobileShell extends StatefulWidget {
  final String currentRoute;
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final PreferredSizeWidget? appBarBottom;
  final bool hideDrawer;

  const _MobileShell({
    required this.currentRoute,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.appBarBottom,
    this.hideDrawer = false,
  });

  @override
  State<_MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<_MobileShell> {
  final _authService = AuthService();
  late final ConfiguracionController _configController;
  bool _loadingUserData = false;

  @override
  void initState() {
    super.initState();
    _configController = ConfiguracionController.instance;
    _configController.addListener(_rebuild);
    if (_configController.negocio == null) {
      _configController.cargarConfiguracion();
    }
    _checkUserData();
  }

  void _checkUserData() {
    if (_authService.currentUserData == null && !_loadingUserData) {
      _loadingUserData = true;
      _authService.reloadUserData().then((_) {
        if (mounted) setState(() => _loadingUserData = false);
      });
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

  void _navigateTo(Widget screen, String routeName, {bool slideRight = true, bool useSlide = false}) {
    if (widget.currentRoute == routeName) return;
    if (!useSlide) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => screen,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionDuration: const Duration(milliseconds: 250),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final begin = Offset(slideRight ? 1.0 : -1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  void _handleSwipeNext() {
    if (widget.currentRoute == 'ventas') {
      _navigateTo(const InventarioScreen(), 'inventario', slideRight: true, useSlide: true);
    } else if (widget.currentRoute == 'inventario') {
      _navigateTo(const ClientesScreen(), 'clientes', slideRight: true, useSlide: true);
    }
  }

  void _handleSwipePrev() {
    if (widget.currentRoute == 'clientes') {
      _navigateTo(const InventarioScreen(), 'inventario', slideRight: false, useSlide: true);
    } else if (widget.currentRoute == 'inventario') {
      _navigateTo(const VentasScreen(), 'ventas', slideRight: false, useSlide: true);
    } else if (widget.currentRoute != 'ventas') {
      _navigateTo(const ClientesScreen(), 'clientes', slideRight: false, useSlide: true);
    }
  }

  List<Widget> _buildMoreMenuChildren(BuildContext context, List<_RailItem> items, String currentRoute) {
    final colorScheme = Theme.of(context).colorScheme;
    final List<Widget> children = [];
    String? currentSection;

    for (final item in items) {
      if (item.section != currentSection) {
        currentSection = item.section;
        if (currentSection != null) {
          children.add(
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
              child: Text(
                currentSection.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          );
        }
      }

      final isSelected = currentRoute == item.route;

      children.add(
        Material(
          color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.12)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            title: Text(
              item.title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            trailing: isSelected
                ? Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
            onTap: () {
              Navigator.pop(context);
              _navigateTo(item.screen, item.route);
            },
          ),
        ),
      );
    }

    children.add(const Divider(height: 32, indent: 16, endIndent: 16));
    children.add(
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
        ),
        title: const Text(
          'Cerrar Sesión',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 14),
        ),
        onTap: () async {
          Navigator.pop(context);
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
    );
    children.add(const SizedBox(height: 24));

    return children;
  }

  void _showMoreMenu(BuildContext context, List<_RailItem> allItems) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return Column(
              children: [
                // Pill handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'MÁS OPCIONES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: _buildMoreMenuChildren(context, allItems, widget.currentRoute),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = _authService.currentUserData;
    final usaCaja = _configController.usaCajaRegistradora;
    final allItems = _getAvailableMenuItems(userData, usaCaja);
    final colorScheme = Theme.of(context).colorScheme;

    int currentIndex = 0;
    if (widget.currentRoute == 'ventas') currentIndex = 0;
    else if (widget.currentRoute == 'inventario') currentIndex = 1;
    else if (widget.currentRoute == 'clientes') currentIndex = 2;
    else currentIndex = 3;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.primary.withValues(alpha: 0.05),
        shadowColor: Colors.black.withValues(alpha: 0.08),
        automaticallyImplyLeading: false,
        title: Text(
          widget.title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: colorScheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        actions: widget.actions,
        bottom: widget.appBarBottom,
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -300) {
            _handleSwipeNext();
          } else if (details.primaryVelocity! > 300) {
            _handleSwipePrev();
          }
        },
        behavior: HitTestBehavior.translucent,
        child: widget.body,
      ),
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: widget.hideDrawer
          ? null
          : Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: currentIndex,
                elevation: 0,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                indicatorColor: colorScheme.primary.withValues(alpha: 0.12),
                onDestinationSelected: (index) {
                  if (index == 0) _navigateTo(const VentasScreen(), 'ventas');
                  else if (index == 1) _navigateTo(const InventarioScreen(), 'inventario');
                  else if (index == 2) _navigateTo(const ClientesScreen(), 'clientes');
                  else if (index == 3) _showMoreMenu(context, allItems);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.point_of_sale_outlined),
                    selectedIcon: Icon(Icons.point_of_sale_rounded),
                    label: 'Ventas',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2_rounded),
                    label: 'Inventario',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_alt_outlined),
                    selectedIcon: Icon(Icons.people_alt_rounded),
                    label: 'Clientes',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.grid_view_outlined),
                    selectedIcon: Icon(Icons.grid_view_rounded),
                    label: 'Más',
                  ),
                ],
              ),
            ),
    );
  }
}
