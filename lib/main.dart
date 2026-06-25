import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/pin_lock_screen.dart';
import 'screens/ventas_screen.dart';
import 'services/network_service.dart';
import 'services/auth_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline cache: solo Android/Desktop — web usa IndexedDB automático
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  await NetworkService().init();

  runApp(const MiInventarioApp());
}

/// Paleta profesional: grises neutros + UN solo azul de acento, usado con moderación.
class AppColors {
  AppColors._();

  // Primario: azul corporativo discreto — aparece solo donde hay acción real
  static const Color primary       = Color(0xFF2563EB);
  static const Color primaryDark   = Color(0xFF1E40AF);

  // Texto: jerarquía con grises neutros
  static const Color textPrimary   = Color(0xFF111827); // casi negro, texto principal
  static const Color textSecondary = Color(0xFF6B7280); // gris medio, texto de apoyo
  static const Color textDisabled  = Color(0xFF9CA3AF); // gris claro, deshabilitado

  // Superficies: todo parte del blanco
  static const Color background    = Color(0xFFF9FAFB); // gris-blanco muy sutil
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceHover  = Color(0xFFF3F4F6); // fondo hover/activo

  // Bordes
  static const Color outline       = Color(0xFFE5E7EB); // borde estándar
  static const Color outlineStrong = Color(0xFFD1D5DB); // borde con más peso

  // Legado — mantener compatibilidad
  static const Color secondary     = Color(0xFF6B7280);
  static const Color secondaryLight= Color(0xFF9CA3AF);
  static const Color surfaceVariant= Color(0xFFF3F4F6);
  static const Color onPrimary     = Color(0xFFFFFFFF);

  // Estados
  static const Color error         = Color(0xFFDC2626);
  static const Color warning       = Color(0xFFF59E0B);
  static const Color success       = Color(0xFF16A34A);
}

class MiInventarioApp extends StatefulWidget {
  const MiInventarioApp({super.key});

  @override
  State<MiInventarioApp> createState() => _MiInventarioAppState();
}

class _MiInventarioAppState extends State<MiInventarioApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // paused = Android background, hidden = iOS/Desktop, inactive = web tab hidden
    final shouldLock = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (kIsWeb && state == AppLifecycleState.inactive);
    if (shouldLock) {
      if (AuthService().empleadoActivo != null) {
        AuthService().setEmpleadoActivo(null);
        navigatorKey.currentState?.pushReplacementNamed('/pin_lock');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.outfitTextTheme();

    return MaterialApp(
      title: 'Inventarios Universal',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(textTheme),
      routes: {
        '/': (context) => const AuthGate(),
        '/pin_lock': (context) => const PinLockScreen(),
        '/pos': (context) => const VentasScreen(),
      },
    );
  }

  ThemeData _buildTheme(TextTheme baseTextTheme) {
    const cs = ColorScheme.light(
      primary:              AppColors.primary,
      onPrimary:            AppColors.onPrimary,
      primaryContainer:     Color(0xFFEFF6FF),  // azul muy pálido
      onPrimaryContainer:   AppColors.primaryDark,
      secondary:            AppColors.secondary,
      onSecondary:          Colors.white,
      secondaryContainer:   Color(0xFFF3F4F6),
      onSecondaryContainer: AppColors.textPrimary,
      surface:              AppColors.surface,
      onSurface:            AppColors.textPrimary,
      surfaceContainerLowest: Color(0xFFFCFCFC),
      surfaceContainerLow:  Color(0xFFF9FAFB),
      surfaceContainer:     Color(0xFFF3F4F6),
      surfaceContainerHigh: Color(0xFFE5E7EB),
      surfaceContainerHighest: AppColors.surfaceVariant,
      outlineVariant:       AppColors.outline,
      outline:              AppColors.outlineStrong,
      error:                AppColors.error,
      onError:              Colors.white,
    );

    return ThemeData(
      useMaterial3:   true,
      colorScheme:    cs,
      scaffoldBackgroundColor: AppColors.background,
      textTheme:      baseTextTheme,

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor:  AppColors.surface,
        foregroundColor:  AppColors.textPrimary,
        elevation:        0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        shadowColor:      AppColors.outline.withAlpha(80),
        centerTitle:      false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color:     AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.outline, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled:      true,
        fillColor:   AppColors.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
        hintStyle:  GoogleFonts.outfit(color: AppColors.textSecondary),
        floatingLabelStyle: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w600),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      ),

      // ── Botones Rellenos ──────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize:     const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
          elevation: 0,
        ),
      ),

      // ── ElevatedButton ─────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize:    const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
          elevation: 0,
        ),
      ),

      // ── OutlinedButton ─────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize:    const Size(0, 40),
          side:           const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ),

      // ── TextButton ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500),
        ),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor:  AppColors.surfaceVariant,
        selectedColor:    AppColors.primary.withAlpha(50),
        checkmarkColor:   Colors.black,
        iconTheme:        const IconThemeData(color: Colors.black),
        side: const BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.black, fontWeight: FontWeight.w600),
        secondaryLabelStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.black, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.outline,
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior:    SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.outfit(color: Colors.white),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withAlpha(20),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12);
          }
          return GoogleFonts.outfit(color: AppColors.textSecondary, fontWeight: FontWeight.w500, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: AppColors.primary, size: 24);
          }
          return IconThemeData(color: AppColors.textSecondary, size: 22);
        }),
      ),
    );
  }
}
