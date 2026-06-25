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

/// Paleta de colores centralizada para todo el sistema.
/// Azul slate premium + grises fríos + superficie blanca.
class AppColors {
  AppColors._();

  // Primario: Azul cobalto rico — confianza y modernidad
  static const Color primary       = Color(0xFF2563EB); // blue-600
  static const Color primaryLight  = Color(0xFF60A5FA); // blue-400
  static const Color primaryDark   = Color(0xFF1E3A8A); // blue-900

  // Secundario / acento
  static const Color secondary     = Color(0xFF475569); // slate-600
  static const Color secondaryLight= Color(0xFF94A3B8); // slate-400

  // Fondo y superficie
  static const Color background    = Color(0xFFF1F5F9); // slate-100 — gris muy suave
  static const Color surface       = Color(0xFFFFFFFF); // blanco puro para cards
  static const Color surfaceVariant= Color(0xFFE8EEF6); // azul-gris muy claro

  // Estados
  static const Color error         = Color(0xFFDC2626); // red-600
  static const Color warning       = Color(0xFFF59E0B); // amber-500
  static const Color success       = Color(0xFF16A34A); // green-600

  // Texto
  static const Color onPrimary     = Color(0xFFFFFFFF);
  static const Color textPrimary   = Color(0xFF0F172A); // slate-900
  static const Color textSecondary = Color(0xFF64748B); // slate-500
  static const Color outline       = Color(0xFFCBD5E1); // slate-300
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
    final cs = ColorScheme.light(
      primary:              AppColors.primary,
      onPrimary:            AppColors.onPrimary,
      primaryContainer:     const Color(0xFFDBEAFE), // blue-100
      onPrimaryContainer:   AppColors.primaryDark,
      secondary:            AppColors.secondary,
      onSecondary:          Colors.white,
      secondaryContainer:   const Color(0xFFDEEBFF), // blue-50 tinted
      onSecondaryContainer: AppColors.primaryDark,
      surface:              AppColors.surface,
      onSurface:            AppColors.textPrimary,
      surfaceContainerLowest: const Color(0xFFF8FAFC),
      surfaceContainerLow:  const Color(0xFFF1F5F9),
      surfaceContainer:     const Color(0xFFE8EEF6),
      surfaceContainerHigh: const Color(0xFFDDE4EF),
      surfaceContainerHighest: AppColors.surfaceVariant,
      outlineVariant:       const Color(0xFFDDE4EF),
      outline:              AppColors.outline,
      error:                AppColors.error,
      onError:              Colors.white,
    );

    return ThemeData(
      useMaterial3:   true,
      colorScheme:    cs,
      scaffoldBackgroundColor: AppColors.background,
      textTheme:      baseTextTheme,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor:  AppColors.surface,
        foregroundColor:  AppColors.textPrimary,
        elevation:        0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        shadowColor:      AppColors.outline.withAlpha(128),
        centerTitle:      false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color:     AppColors.surface,
        elevation: 0,
        shadowColor: const Color(0x1A2563EB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDDE4EF), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
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

      // ── ElevatedButton ────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize:    const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
          elevation: 0,
        ),
      ),

      // ── OutlinedButton ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize:    const Size(double.infinity, 52),
          side:           const BorderSide(color: AppColors.outline, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
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
