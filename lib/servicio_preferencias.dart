import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'perfiles_nutricionales.dart';

class PreferenciasUsuario {
  /// Meta calórica: Déficit (Baja) | Mantenimiento | Volumen (Alta)
  final String objetivo;

  /// Estilos de dieta combinables (Keto, Vegana, Sin gluten, Apto para diabetes...)
  final List<String> estilos;
  final String alergias;
  final String superFavorito;
  final int porciones;
  final double presupuestoSemanal;
  final bool notificaciones;

  const PreferenciasUsuario({
    this.objetivo = PerfilesNutricionales.mantenimiento,
    this.estilos = const [PerfilesNutricionales.libre],
    this.alergias = '',
    this.superFavorito = 'Walmart',
    this.porciones = 2,
    this.presupuestoSemanal = 1500.0,
    this.notificaciones = true,
  });

  factory PreferenciasUsuario.fromMap(Map<String, dynamic> map) {
    final objetivo = map['objetivo']?.toString() ?? '';
    return PreferenciasUsuario(
      objetivo: PerfilesNutricionales.objetivos.contains(objetivo)
          ? objetivo
          : PerfilesNutricionales.mantenimiento,
      estilos: PerfilesNutricionales.deserializar(
        map['estilos_dieta']?.toString(),
      ),
      alergias: map['alergias']?.toString() ?? '',
      superFavorito: map['super_favorito']?.toString() ?? 'Walmart',
      porciones: int.tryParse(map['porciones']?.toString() ?? '2') ?? 2,
      presupuestoSemanal:
          double.tryParse(map['presupuesto_semanal']?.toString() ?? '1500') ??
              1500.0,
      notificaciones: map['notificaciones'] is bool
          ? map['notificaciones'] as bool
          : (map['notificaciones']?.toString().toLowerCase() == 'true'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'objetivo': objetivo,
      'estilos_dieta': PerfilesNutricionales.serializar(estilos),
      'alergias': alergias,
      'super_favorito': superFavorito,
      'porciones': porciones,
      'presupuesto_semanal': presupuestoSemanal,
      'notificaciones': notificaciones,
      'actualizado_en': DateTime.now().toIso8601String(),
    };
  }
}

class ServicioPreferencias {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Cache en memoria para acceso rápido
  static PreferenciasUsuario? _cache;

  static PreferenciasUsuario? get cache => _cache;

  /// Obtiene las preferencias del usuario en sesión, o las predeterminadas si falla
  static Future<PreferenciasUsuario> obtenerPreferencias() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final List<dynamic> respuesta = await _supabase
            .from('preferencias_usuario')
            .select()
            .eq('user_id', user.id)
            .limit(1);

        if (respuesta.isNotEmpty) {
          _cache = PreferenciasUsuario.fromMap(
            Map<String, dynamic>.from(respuesta.first as Map),
          );
          return _cache!;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error al consultar preferencias en Supabase: $e');
    }

    _cache ??= const PreferenciasUsuario();
    return _cache!;
  }

  /// Guarda o actualiza las preferencias del usuario en sesión.
  /// Lanza una excepción si no hay sesión o si Supabase rechaza el guardado.
  static Future<void> guardarPreferencias(PreferenciasUsuario prefs) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Inicia sesión para guardar tus preferencias.');
    }

    final datos = prefs.toMap();
    datos['user_id'] = user.id;

    await _supabase
        .from('preferencias_usuario')
        .upsert(datos, onConflict: 'user_id');

    _cache = prefs;
  }
}
