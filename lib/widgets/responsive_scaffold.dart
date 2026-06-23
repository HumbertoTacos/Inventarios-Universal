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
                    // Custom Desktop Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      color: colorScheme.surface,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (actions != null)
                            ...actions!,
                        ],
                      ),
                    ),
                    if (appBarBottom != null)
                      appBarBottom!,
                    Expanded(
                      child: body,
                    ),
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
        if (mounted) {
          setState(() {
            _loadingUserData = false;
          });
        }
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
                  mainAxisAlignment: widget.extended
                      ? MainAxisAlignment.spaceBetween
                      : MainAxisAlignment.center,
                  children: [
                    if (widget.extended)
                      const Expanded(
                        child: Text(
                          'MENÚ',
                          style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5),
                          overflow: TextOverflow.ellipsis,
                        ),
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
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // ── OPERACIONES ──
                _buildSectionHeader('Operaciones'),
                _buildNavItemFromRoute(items, 'ventas'),
                if (_configController.usaCajaRegistradora) _buildNavItemFromRoute(items, 'caja'),
                _buildNavItemFromRoute(items, 'historial'),
                _buildNavItemFromRoute(items, 'clientes'),

                const Divider(indent: 16, endIndent: 16, height: 24),

                // ── INVENTARIO ──
                _buildSectionHeader('Inventario'),
                _buildNavItemFromRoute(items, 'inventario'),
                _buildNavItemFromRoute(items, 'actualizacion_precios'),
                _buildNavItemFromRoute(items, 'ajuste_inventario'),
                _buildNavItemFromRoute(items, 'categorias'),

                const Divider(indent: 16, endIndent: 16, height: 24),

                // ── COMPRAS ──
                _buildSectionHeader('Compras'),
                _buildNavItemFromRoute(items, 'proveedores'),
                _buildNavItemFromRoute(items, 'registro_compra'),
                _buildNavItemFromRoute(items, 'sugerencias_compra'),
                _buildNavItemFromRoute(items, 'cuentas_por_pagar'),

                const Divider(indent: 16, endIndent: 16, height: 24),

                // ── ADMINISTRACIÓN ──
                _buildSectionHeader('Administración'),
                _buildNavItemFromRoute(items, 'estadisticas'),
                _buildNavItemFromRoute(items, 'equipo'),
                _buildNavItemFromRoute(items, 'bitacora'),
                _buildNavItemFromRoute(items, 'configuracion'),
                _buildNavItemFromRoute(items, 'impresora'),
              ],
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

  Widget _buildNavItemFromRoute(List<_RailItem> items, String route) {
    final i = items.indexWhere((it) => it.route == route);
    if (i == -1) return const SizedBox.shrink();
    final item = items[i];
    final isSelected = widget.currentRoute == route;
    return _buildNavItem(context, Theme.of(context).colorScheme, item, isSelected);
  }

  Widget _buildSectionHeader(String title) {
    if (!widget.extended) return const SizedBox(height: 8);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          letterSpacing: 1.1,
        ),
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
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
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
                  const Expanded(
                    child: Text(
                      'Cerrar Sesión',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
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
}

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
    _RailItem('ventas', 'Punto de Venta', Icons.point_of_sale, const VentasScreen(), section: 'Operaciones'),
    if (usaCaja) _RailItem('caja', 'Caja y Turnos', Icons.point_of_sale_outlined, const CajaScreen(), section: 'Operaciones'),
    if (puedeVerHistorial) _RailItem('historial', 'Historial de Ventas', Icons.history, const HistorialVentasScreen(), section: 'Operaciones'),
    _RailItem('clientes', 'Clientes y Créditos', Icons.people_outlined, const ClientesScreen(), section: 'Operaciones'),
    
    _RailItem('inventario', 'Catálogo de Productos', Icons.inventory_2_outlined, const InventarioScreen(), section: 'Inventario'),
    _RailItem('actualizacion_precios', 'Actualización de Precios', Icons.price_change_outlined, const ActualizacionPreciosScreen(), section: 'Inventario'),
    _RailItem('ajuste_inventario', 'Mermas y Ajustes', Icons.auto_fix_high_outlined, const AjusteInventarioScreen(), section: 'Inventario'),
    if (esDueno) _RailItem('categorias', 'Gestionar Categorías', Icons.category_outlined, const GestionCategoriasScreen(), section: 'Inventario'),
    
    if (esDueno) ...[
      _RailItem('proveedores', 'Proveedores', Icons.local_shipping_outlined, const GestionProveedoresScreen(), section: 'Compras y Proveedores'),
      _RailItem('registro_compra', 'Registrar Entrada (Compra)', Icons.add_business_outlined, const RegistroCompraScreen(), section: 'Compras y Proveedores'),
      _RailItem('sugerencias_compra', 'Sugerencias de Compra', Icons.auto_graph_outlined, const SugerenciasCompraScreen(), section: 'Compras y Proveedores'),
      _RailItem('cuentas_por_pagar', 'Cuentas por Pagar', Icons.money_off_csred_outlined, const CuentasPorPagarScreen(), section: 'Compras y Proveedores'),
    ],

    if (esDueno || puedeVerEstadisticas) _RailItem('estadisticas', 'Estadísticas y Ganancias', Icons.bar_chart, const EstadisticasScreen(), section: 'Administración'),
    
    if (esDueno) ...[
      _RailItem('equipo', 'Mi Equipo', Icons.people_alt_outlined, const MiEquipoScreen(), section: 'Administración'),
      _RailItem('bitacora', 'Bitácora de Movimientos', Icons.manage_search_outlined, const BitacoraScreen(), section: 'Administración'),
      _RailItem('configuracion', 'Configuración del Negocio', Icons.settings_outlined, const ConfiguracionNegocioScreen(), section: 'Administración'),
      _RailItem('impresora', 'Impresora Bluetooth', Icons.print_outlined, const ConfiguracionImpresoraScreen(), section: 'Administración'),
    ]
  ];
}

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
        if (mounted) {
          setState(() {
            _loadingUserData = false;
          });
        }
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
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
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
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                  letterSpacing: 1.2,
                ),
              ),
            ),
          );
        }
      }
      
      final isSelected = currentRoute == item.route;
      
      children.add(
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected 
                  ? colorScheme.primary.withValues(alpha: 0.1) 
                  : colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
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
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
            ),
          ),
          trailing: isSelected ? Icon(Icons.check, color: colorScheme.primary, size: 18) : null,
          onTap: () {
            Navigator.pop(context);
            _navigateTo(item.screen, item.route);
          },
        ),
      );
    }

    children.add(const Divider(height: 32));
    children.add(
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.logout, color: Colors.red, size: 20),
        ),
        title: const Text(
          'Cerrar Sesión',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                // Pill handler
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'MÁS OPCIONES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
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

    int currentIndex = 0; // Default a Ventas
    if (widget.currentRoute == 'ventas') currentIndex = 0;
    else if (widget.currentRoute == 'inventario') currentIndex = 1;
    else if (widget.currentRoute == 'clientes') currentIndex = 2;
    else currentIndex = 3; // 'Más' o cualquier otra ruta se mapea visualmente aquí

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.actions,
        bottom: widget.appBarBottom,
        automaticallyImplyLeading: false, // Quitar icono del Drawer
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
      bottomNavigationBar: widget.hideDrawer ? null : NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          if (index == 0) _navigateTo(const VentasScreen(), 'ventas');
          else if (index == 1) _navigateTo(const InventarioScreen(), 'inventario');
          else if (index == 2) _navigateTo(const ClientesScreen(), 'clientes');
          else if (index == 3) _showMoreMenu(context, allItems);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            selectedIcon: Icon(Icons.point_of_sale),
            label: 'Ventas',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}
