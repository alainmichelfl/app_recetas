import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Modelo de datos para una receta cocinada / preparada
class RegistroCocina {
  final int idReceta;
  final String titulo;
  final DateTime fecha;
  final int veces;
  final int? idPlaneador;
  final String origen;

  RegistroCocina({
    required this.idReceta,
    required this.titulo,
    required this.fecha,
    this.veces = 1,
    this.idPlaneador,
    this.origen = 'detalle',
  });

  Map<String, dynamic> toMap() => {
        'id_receta': idReceta,
        'titulo': titulo,
        'fecha': fecha.toIso8601String(),
        'veces': veces,
        'id_planeador': idPlaneador,
        'origen': origen,
      };

  factory RegistroCocina.fromMap(Map<String, dynamic> map) {
    return RegistroCocina(
      idReceta: int.tryParse(map['id_receta']?.toString() ?? '0') ?? 0,
      titulo: map['titulo']?.toString() ?? '',
      fecha: DateTime.tryParse(map['fecha']?.toString() ?? '') ??
          DateTime.now(),
      veces: int.tryParse(map['veces']?.toString() ?? '1') ?? 1,
      idPlaneador: map['id_planeador'] != null
          ? int.tryParse(map['id_planeador'].toString())
          : null,
      origen: map['origen']?.toString() ?? 'detalle',
    );
  }
}

/// Servicio que gestiona el historial de recetas que el usuario ya cocinó.
/// Funciona de forma 100% offline y resiliente usando SharedPreferences, y
/// sincroniza en segundo plano con Supabase si la tabla `recetas_cocinadas` existe.
class ServicioHistorialCocina {
  static const String _prefKey = 'historial_recetas_cocinadas_v1';
  static Map<String, RegistroCocina>? _cache;

  /// Clave interna para el mapa (prioriza id_receta si > 0, si no usa título limpio)
  static String _clave(int idReceta, String titulo) {
    if (idReceta > 0) return 'id_$idReceta';
    return 'title_${titulo.trim().toLowerCase()}';
  }

  /// Carga inicial desde SharedPreferences
  static Future<Map<String, RegistroCocina>> _cargar() async {
    if (_cache != null) return _cache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_prefKey);
      if (str != null && str.isNotEmpty) {
        final Map<String, dynamic> raw = jsonDecode(str);
        _cache = raw.map(
          (k, v) => MapEntry(k, RegistroCocina.fromMap(v as Map<String, dynamic>)),
        );
        return _cache!;
      }
    } catch (e) {
      debugPrint('⚠️ Error al leer historial de cocina local: $e');
    }
    _cache = {};
    return _cache!;
  }

  /// Guarda el estado actual en SharedPreferences
  static Future<void> _guardar() async {
    if (_cache == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = _cache!.map((k, v) => MapEntry(k, v.toMap()));
      await prefs.setString(_prefKey, jsonEncode(raw));
    } catch (e) {
      debugPrint('⚠️ Error al guardar historial local: $e');
    }
  }

  /// Registra una receta como cocinada/preparada.
  /// Incrementa el contador de veces cocinada y actualiza la fecha a hoy.
  static Future<RegistroCocina> marcarComoCocinada({
    required int idReceta,
    required String titulo,
    int? idPlaneador,
    String origen = 'detalle',
  }) async {
    final mapa = await _cargar();
    final key = _clave(idReceta, titulo);

    final anterior = mapa[key];
    final nuevo = RegistroCocina(
      idReceta: idReceta,
      titulo: titulo.trim(),
      fecha: DateTime.now(),
      veces: (anterior?.veces ?? 0) + 1,
      idPlaneador: idPlaneador ?? anterior?.idPlaneador,
      origen: origen,
    );

    mapa[key] = nuevo;
    await _guardar();

    // Intentar sincronización con Supabase en segundo plano sin bloquear
    _sincronizarConSupabase(nuevo).catchError((e) {
      debugPrint('ℹ️ Supabase recetas_cocinadas sync omitido/offline: $e');
    });

    return nuevo;
  }

  /// Elimina una receta del historial si el usuario lo solicita
  static Future<void> desmarcarCocinada({
    required int idReceta,
    String? titulo,
  }) async {
    final mapa = await _cargar();
    final key = _clave(idReceta, titulo ?? '');
    mapa.remove(key);
    if (titulo != null && titulo.isNotEmpty) {
      mapa.remove(_clave(0, titulo));
    }
    await _guardar();
  }

  /// Revisa si una receta ya fue cocinada
  static Future<bool> fueCocinada(int idReceta, {String? titulo}) async {
    final mapa = await _cargar();
    if (idReceta > 0 && mapa.containsKey('id_$idReceta')) return true;
    if (titulo != null && titulo.trim().isNotEmpty) {
      final keyTitle = 'title_${titulo.trim().toLowerCase()}';
      if (mapa.containsKey(keyTitle)) return true;
      // Búsqueda aproximada por título en los registros existentes
      return mapa.values.any(
        (r) => r.titulo.toLowerCase().trim() == titulo.toLowerCase().trim(),
      );
    }
    return false;
  }

  /// Obtiene el registro de cocinado para una receta
  static Future<RegistroCocina?> obtenerRegistro(
    int idReceta, {
    String? titulo,
  }) async {
    final mapa = await _cargar();
    if (idReceta > 0 && mapa.containsKey('id_$idReceta')) {
      return mapa['id_$idReceta'];
    }
    if (titulo != null && titulo.trim().isNotEmpty) {
      final keyTitle = 'title_${titulo.trim().toLowerCase()}';
      if (mapa.containsKey(keyTitle)) return mapa[keyTitle];
      for (var r in mapa.values) {
        if (r.titulo.toLowerCase().trim() == titulo.toLowerCase().trim()) {
          return r;
        }
      }
    }
    return null;
  }

  /// Devuelve el conjunto de todos los IDs de recetas cocinadas
  static Future<Set<int>> obtenerIdsCocinadas() async {
    final mapa = await _cargar();
    return mapa.values
        .map((r) => r.idReceta)
        .where((id) => id > 0)
        .toSet();
  }

  /// Devuelve el conjunto de títulos de recetas cocinadas (en minúsculas)
  static Future<Set<String>> obtenerTitulosCocinadas() async {
    final mapa = await _cargar();
    return mapa.values
        .map((r) => r.titulo.toLowerCase().trim())
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  /// Devuelve todos los registros ordenados del más reciente al más antiguo
  static Future<List<RegistroCocina>> obtenerTodos() async {
    final mapa = await _cargar();
    final lista = mapa.values.toList();
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  /// Sincroniza con Supabase en segundo plano
  static Future<void> _sincronizarConSupabase(RegistroCocina registro) async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      final Map<String, dynamic> payload = {
        'titulo': registro.titulo,
        'fecha_cocinada': registro.fecha.toIso8601String(),
        'origen': registro.origen,
      };

      if (registro.idReceta > 0) {
        payload['id_receta'] = registro.idReceta;
      }
      if (registro.idPlaneador != null) {
        payload['id_planeador'] = registro.idPlaneador;
      }
      if (user != null) {
        payload['user_id'] = user.id;
      }

      await client.from('recetas_cocinadas').insert(payload);
    } catch (e) {
      // Ignorar si la tabla no está creada en Supabase o no hay conexión
      debugPrint('ℹ️ Supabase sync no disponible: $e');
    }
  }
}
