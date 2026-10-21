import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pantalla_login.dart';
import 'pantalla_recetas.dart';
import 'pantalla_restablecer_password.dart';

/// Notificador global del modo de tema para toda la aplicación
final ValueNotifier<ThemeMode> themeModeNotifier =
    ValueNotifier<ThemeMode>(ThemeMode.light);

/// Alterna y persiste la preferencia de modo oscuro en almacenamiento local
Future<void> alternarModoOscuro(bool activo) async {
  themeModeNotifier.value = activo ? ThemeMode.dark : ThemeMode.light;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modo_oscuro_activo_v1', activo);
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xjfzlthgycczcjbifaty.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhqZnpsdGhneWNjemNqYmlmYXR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNzgwNjMsImV4cCI6MjEwNTc1NDA2M30.NUDw9b9woZaKow-JGn-bPBpaMI9aTpmrgCjiQzpTVg4',
  );

  try {
    final prefs = await SharedPreferences.getInstance();
    final bool modoOscuro = prefs.getBool('modo_oscuro_activo_v1') ?? false;
    themeModeNotifier.value = modoOscuro ? ThemeMode.dark : ThemeMode.light;
  } catch (_) {}

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Jitomate y Cebolla',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE53935),
              primary: const Color(0xFFD32F2F),
              secondary: Colors.black87,
              surface: const Color(0xFFFAFAFA),
              brightness: Brightness.light,
            ),
            textTheme: GoogleFonts.nunitoTextTheme(
              Theme.of(context).textTheme
                  .apply(bodyColor: Colors.black87, displayColor: Colors.black),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                elevation: 4,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 5,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Color(0xFF1E2022),
              foregroundColor: Colors.white,
              iconTheme: IconThemeData(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121416),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE53935),
              primary: const Color(0xFFE53935),
              secondary: Colors.white70,
              surface: const Color(0xFF1E2022),
              brightness: Brightness.dark,
            ),
            textTheme: GoogleFonts.nunitoTextTheme(
              ThemeData.dark().textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                elevation: 4,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1E2022),
              elevation: 4,
              shadowColor: Colors.black45,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFF2C3035), width: 1),
              ),
              clipBehavior: Clip.antiAlias,
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Color(0xFF16181A),
              foregroundColor: Colors.white,
              iconTheme: IconThemeData(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
            ),
          ),
          home: const ControladorSesion(),
        );
      },
    );
  }
}

// 🛡️ CADENERO DE SESIÓN (Abre directo en Mis Recetas si hay sesión)
class ControladorSesion extends StatefulWidget {
  const ControladorSesion({super.key});

  @override
  State<ControladorSesion> createState() => _ControladorSesionState();
}

class _ControladorSesionState extends State<ControladorSesion> {
  bool _enRecuperacionPassword = false;

  @override
  void initState() {
    super.initState();
    _detectarRecuperacionEnUrl();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          setState(() {
            _enRecuperacionPassword = true;
          });
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        if (mounted) {
          setState(() {
            _enRecuperacionPassword = false;
          });
        }
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  void _detectarRecuperacionEnUrl() {
    if (kIsWeb) {
      try {
        final fragment = Uri.base.fragment;
        final query = Uri.base.queryParameters;
        if (fragment.contains('type=recovery') || query['type'] == 'recovery') {
          _enRecuperacionPassword = true;
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enRecuperacionPassword) {
      return PantallaRestablecerPassword(
        onPasswordRestablecida: () {
          setState(() {
            _enRecuperacionPassword = false;
          });
        },
      );
    }

    final sesionActiva = Supabase.instance.client.auth.currentSession != null;

    if (sesionActiva) {
      return const PantallaRecetas();
    } else {
      return const PantallaLogin();
    }
  }
}
