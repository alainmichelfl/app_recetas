import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'perfiles_nutricionales.dart';
import 'tipos_cocina.dart';

class PreferenciasUsuario {
  /// Meta calórica: Déficit (Baja) | Mantenimiento | Volumen (Alta)
  final String objetivo;

  /// Estilos de dieta combinables (Keto, Vegana, Sin gluten, Apto para diabetes...)
  final List<String> estilos;

  /// Tipos de cocina preferidos (Mexicana, Japonesa, Thai, Italiana, etc.)
  final List<String> tiposCocina;

  final String alergias;
  final String superFavorito;
  final int porciones;
  final double presupuestoSemanal;
  final bool notificaciones;

  const PreferenciasUsuario({
    this.objetivo = PerfilesNutricionales.mantenimiento,
    this.estilos = const [PerfilesNutricionales.libre],
    this.tiposCocina = const [TiposCocina.todas],
    this.alergias = '',
    this.superFavorito = 'Walmart',
    this.porciones = 2,
    this.presupuestoSemanal = 1500.0,
    this.notificaciones = true,
  });

  factory PreferenciasUsuario.fromMap(
    Map<String, dynamic> map, {
    List<String>? fallbackTiposCocina,
  }) {
    final objetivo = map['objetivo']?.toString() ?? '';
    final rawTipos = map['tipos_cocina']?.toString();
    final tipos = rawTipos != null && rawTipos.isNotEmpty
        ? TiposCocina.deserializar(rawTipos)
        : (fallbackTiposCocina ?? [TiposCocina.todas]);

    return PreferenciasUsuario(
      objetivo: PerfilesNutricionales.objetivos.contains(objetivo)
          ? objetivo
          : PerfilesNutricionales.mantenimiento,
      estilos: PerfilesNutricionales.deserializar(
        map['estilos_dieta']?.toString(),
      ),
      tiposCocina: TiposCocina.normalizar(tipos),
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
      'tipos_cocina': TiposCocina.serializar(tiposCocina),
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
  static const String _keyTiposCocinaLocal = 'pref_tipos_cocina_local_v1';

  // Cache en memoria para acceso rápido
  static PreferenciasUsuario? _cache;

  static PreferenciasUsuario? get cache => _cache;

  /// Obtiene las preferencias del usuario en sesión, o las predeterminadas si falla
  static Future<PreferenciasUsuario> obtenerPreferencias() async {
    List<String>? tiposCocinaLocales;
    try {
      final sp = await SharedPreferences.getInstance();
      final guardado = sp.getString(_keyTiposCocinaLocal);
      if (guardado != null && guardado.isNotEmpty) {
        tiposCocinaLocales = TiposCocina.deserializar(guardado);
      }
    } catch (e) {
      debugPrint('Error al leer preferencias locales: $e');
    }

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
            fallbackTiposCocina: tiposCocinaLocales,
          );
          return _cache!;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error al consultar preferencias en Supabase: $e');
    }

    _cache ??= PreferenciasUsuario(
      tiposCocina: tiposCocinaLocales ?? const [TiposCocina.todas],
    );
    return _cache!;
  }

  /// Guarda o actualiza las preferencias del usuario en sesión.
  /// Lanza una excepción si no hay sesión o si Supabase rechaza el guardado.
  static Future<void> guardarPreferencias(PreferenciasUsuario prefs) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Inicia sesión para guardar tus preferencias.');
    }

    // 1. Guardar localmente en SharedPreferences para disponibilidad instantánea
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        _keyTiposCocinaLocal,
        TiposCocina.serializar(prefs.tiposCocina),
      );
    } catch (e) {
      debugPrint('Error al persistir preferencias en local: $e');
    }

    // 2. Persistir en Supabase de forma resiliente
    final datos = prefs.toMap();
    datos['user_id'] = user.id;

    try {
      await _supabase
          .from('preferencias_usuario')
          .upsert(datos, onConflict: 'user_id');
    } catch (e) {
      // Si la columna tipos_cocina no existe aún en la tabla de Supabase, reintentar sin romper
      if (e.toString().contains('tipos_cocina') ||
          e.toString().contains('column') ||
          e.toString().contains('schema')) {
        debugPrint(
          'Aviso: tipos_cocina no existe aún como columna en Supabase; guardando resto de campos.',
        );
        datos.remove('tipos_cocina');
        await _supabase
            .from('preferencias_usuario')
            .upsert(datos, onConflict: 'user_id');
      } else {
        rethrow;
      }
    }

    _cache = prefs;
  }
}
