import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pantalla_login.dart';
import 'pantalla_recetas.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xjfzlthgycczcjbifaty.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhqZnpsdGhneWNjemNqYmlmYXR5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAxNzgwNjMsImV4cCI6MjEwNTc1NDA2M30.NUDw9b9woZaKow-JGn-bPBpaMI9aTpmrgCjiQzpTVg4',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jitomate y Cebolla',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          primary: const Color(0xFFD32F2F),
          secondary: Colors.black87,
          surface: const Color(0xFFFAFAFA),
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
          backgroundColor: Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
          ),
        ),
      ),
      home: const ControladorSesion(),
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
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sesionActiva = Supabase.instance.client.auth.currentSession != null;

    if (sesionActiva) {
      return const PantallaRecetas();
    } else {
      return const PantallaLogin();
    }
  }
}
