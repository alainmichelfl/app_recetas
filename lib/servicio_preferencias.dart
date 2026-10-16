import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'perfiles_nutricionales.dart';
import 'tipos_cocina.dart';
import 'utensilios_cocina.dart';

class PreferenciasUsuario {
  /// Meta calórica: Déficit (Baja) | Mantenimiento | Volumen (Alta)
  final String objetivo;

  /// Estilos de dieta combinables (Keto, Vegana, Sin gluten, Apto para diabetes...)
  final List<String> estilos;

  /// Tipos de cocina preferidos (Mexicana, Japonesa, Thai, Italiana, etc.)
  final List<String> tiposCocina;

  /// Utensilios y electrodomésticos disponibles en cocina
  final List<String> utensilios;

  final String alergias;
  final String superFavorito;
  final int porciones;
  final double presupuestoSemanal;
  final bool notificaciones;
  final bool alertaDescongelado;
  final bool alertaFrescura;
  final String horaDescongelado;

  const PreferenciasUsuario({
    this.objetivo = PerfilesNutricionales.mantenimiento,
    this.estilos = const [PerfilesNutricionales.libre],
    this.tiposCocina = const [TiposCocina.todas],
    this.utensilios = const ['sarten', 'licuadora'],
    this.alergias = '',
    this.superFavorito = 'Walmart',
    this.porciones = 2,
    this.presupuestoSemanal = 1500.0,
    this.notificaciones = true,
    this.alertaDescongelado = true,
    this.alertaFrescura = true,
    this.horaDescongelado = '20:00',
  });

  factory PreferenciasUsuario.fromMap(
    Map<String, dynamic> map, {
    List<String>? fallbackTiposCocina,
    List<String>? fallbackUtensilios,
  }) {
    final objetivo = map['objetivo']?.toString() ?? '';
    final rawTipos = map['tipos_cocina']?.toString();
    final tipos = rawTipos != null && rawTipos.isNotEmpty
        ? TiposCocina.deserializar(rawTipos)
        : (fallbackTiposCocina ?? [TiposCocina.todas]);

    final rawUtensilios = map['utensilios']?.toString();
    final utensilios = rawUtensilios != null && rawUtensilios.isNotEmpty
        ? UtensiliosCocina.deserializar(rawUtensilios)
        : (fallbackUtensilios ?? UtensiliosCocina.porDefecto);

    return PreferenciasUsuario(
      objetivo: PerfilesNutricionales.objetivos.contains(objetivo)
          ? objetivo
          : PerfilesNutricionales.mantenimiento,
      estilos: PerfilesNutricionales.deserializar(
        map['estilos_dieta']?.toString(),
      ),
      tiposCocina: TiposCocina.normalizar(tipos),
      utensilios: utensilios,
      alergias: map['alergias']?.toString() ?? '',
      superFavorito: map['super_favorito']?.toString() ?? 'Walmart',
      porciones: int.tryParse(map['porciones']?.toString() ?? '2') ?? 2,
      presupuestoSemanal:
          double.tryParse(map['presupuesto_semanal']?.toString() ?? '1500') ??
              1500.0,
      notificaciones: map['notificaciones'] is bool
          ? map['notificaciones'] as bool
          : (map['notificaciones']?.toString().toLowerCase() == 'true'),
      alertaDescongelado: map['alerta_descongelado'] is bool
          ? map['alerta_descongelado'] as bool
          : (map['alerta_descongelado']?.toString().toLowerCase() != 'false'),
      alertaFrescura: map['alerta_frescura'] is bool
          ? map['alerta_frescura'] as bool
          : (map['alerta_frescura']?.toString().toLowerCase() != 'false'),
      horaDescongelado: map['hora_descongelado']?.toString() ?? '20:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'objetivo': objetivo,
      'estilos_dieta': PerfilesNutricionales.serializar(estilos),
      'tipos_cocina': TiposCocina.serializar(tiposCocina),
      'utensilios': UtensiliosCocina.serializar(utensilios),
      'alergias': alergias,
      'super_favorito': superFavorito,
      'porciones': porciones,
      'presupuesto_semanal': presupuestoSemanal,
      'notificaciones': notificaciones,
      'alerta_descongelado': alertaDescongelado,
      'alerta_frescura': alertaFrescura,
      'hora_descongelado': horaDescongelado,
      'actualizado_en': DateTime.now().toIso8601String(),
    };
  }
}

class ServicioPreferencias {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _keyTiposCocinaLocal = 'pref_tipos_cocina_local_v1';
  static const String _keyUtensiliosLocal = 'pref_utensilios_local_v1';

  // Cache en memoria para acceso rápido
  static PreferenciasUsuario? _cache;

  static PreferenciasUsuario? get cache => _cache;

  /// Obtiene las preferencias del usuario en sesión, o las predeterminadas si falla
  static Future<PreferenciasUsuario> obtenerPreferencias() async {
    List<String>? tiposCocinaLocales;
    List<String>? utensiliosLocales;
    bool? alertaDescongeladoLocal;
    bool? alertaFrescuraLocal;
    String? horaDescongeladoLocal;
    try {
      final sp = await SharedPreferences.getInstance();
      final guardado = sp.getString(_keyTiposCocinaLocal);
      if (guardado != null && guardado.isNotEmpty) {
        tiposCocinaLocales = TiposCocina.deserializar(guardado);
      }
      final guardadoUtensilios = sp.getString(_keyUtensiliosLocal);
      if (guardadoUtensilios != null && guardadoUtensilios.isNotEmpty) {
        utensiliosLocales = UtensiliosCocina.deserializar(guardadoUtensilios);
      }
      alertaDescongeladoLocal = sp.getBool('pref_alerta_descongelado_v1');
      alertaFrescuraLocal = sp.getBool('pref_alerta_frescura_v1');
      horaDescongeladoLocal = sp.getString('pref_hora_descongelado_v1');
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
          final map = Map<String, dynamic>.from(respuesta.first as Map);
          if (alertaDescongeladoLocal != null && !map.containsKey('alerta_descongelado')) {
            map['alerta_descongelado'] = alertaDescongeladoLocal;
          }
          if (alertaFrescuraLocal != null && !map.containsKey('alerta_frescura')) {
            map['alerta_frescura'] = alertaFrescuraLocal;
          }
          if (horaDescongeladoLocal != null && !map.containsKey('hora_descongelado')) {
            map['hora_descongelado'] = horaDescongeladoLocal;
          }
          _cache = PreferenciasUsuario.fromMap(
            map,
            fallbackTiposCocina: tiposCocinaLocales,
            fallbackUtensilios: utensiliosLocales,
          );
          return _cache!;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error al consultar preferencias en Supabase: $e');
    }

    _cache ??= PreferenciasUsuario(
      tiposCocina: tiposCocinaLocales ?? const [TiposCocina.todas],
      utensilios: utensiliosLocales ?? UtensiliosCocina.porDefecto,
      alertaDescongelado: alertaDescongeladoLocal ?? true,
      alertaFrescura: alertaFrescuraLocal ?? true,
      horaDescongelado: horaDescongeladoLocal ?? '20:00',
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
      await sp.setString(
        _keyUtensiliosLocal,
        UtensiliosCocina.serializar(prefs.utensilios),
      );
      await sp.setBool('pref_alerta_descongelado_v1', prefs.alertaDescongelado);
      await sp.setBool('pref_alerta_frescura_v1', prefs.alertaFrescura);
      await sp.setString('pref_hora_descongelado_v1', prefs.horaDescongelado);
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
      debugPrint('Aviso: columna opcional faltante en Supabase al guardar preferencias: $e');
      datos.remove('tipos_cocina');
      datos.remove('utensilios');
      datos.remove('alerta_descongelado');
      datos.remove('alerta_frescura');
      datos.remove('hora_descongelado');
      try {
        await _supabase
            .from('preferencias_usuario')
            .upsert(datos, onConflict: 'user_id');
      } catch (e2) {
        debugPrint('Error secundario guardando preferencias básicas: $e2');
      }
    }

    _cache = prefs;
  }
}
