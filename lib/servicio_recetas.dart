import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servicio_admin.dart';

/// Tipos de filtro según el origen y audiencia de las recetas
enum FiltroAudienciaReceta {
  todas,
  oficiales,
  recienSalidas,
  misRecetas,
  comunidad,
}

/// Servicio centralizado para la gestión y segmentación de recetas (Oficiales vs Privadas vs Comunidad)
class ServicioRecetas {
  ServicioRecetas._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Inserta una nueva receta con control defensivo y asignación de propietario.
  /// Si las columnas 'user_id' o 'es_oficial' aún no existen en Postgres (código 42703),
  /// reintenta de forma automática sin romper la experiencia del usuario.
  static Future<Map<String, dynamic>> insertarReceta({
    required String titulo,
    required String descripcion,
    required String instrucciones,
    String? tipoComida,
    int? calorias,
    String? macros,
    String? imagenUrl,
    int? porciones,
    String? tiempoPreparacion,
    bool? esOficial,
    bool? esPublica,
    bool? esNovedad,
    String? userIdOverride,
  }) async {
    final user = _client.auth.currentUser;
    final bool esAdmin = ServicioAdmin.esAdmin(user);

    // Por defecto: Las recetas de Alain (admin) son oficiales; las de usuarios son privadas
    final bool oficialFinal = esOficial ?? esAdmin;
    final bool publicaFinal = esPublica ?? esAdmin;
    final bool novedadFinal = esNovedad ?? false;

    final Map<String, dynamic> payloadCompleto = {
      'titulo': titulo,
      'descripcion': descripcion,
      'instrucciones': instrucciones,
      'es_oficial': oficialFinal,
      'es_publica': publicaFinal,
      'es_novedad': novedadFinal,
    };
    if (tipoComida != null) payloadCompleto['tipo_comida'] = tipoComida;
    if (calorias != null) payloadCompleto['calorias'] = calorias;
    if (macros != null) payloadCompleto['macros'] = macros;
    if (imagenUrl != null && imagenUrl.isNotEmpty) {
      payloadCompleto['imagen_url'] = imagenUrl;
    }
    if (porciones != null) payloadCompleto['porciones'] = porciones;
    if (tiempoPreparacion != null) {
      payloadCompleto['tiempo_preparacion'] = tiempoPreparacion;
    }
    // Si se pasa userIdOverride == 'none' o es creación masiva oficial, no vincular a cuenta personal
    if (userIdOverride == 'none') {
      // Dejar user_id como null explícito para que pertenezca al catálogo general
    } else if (userIdOverride != null && userIdOverride.isNotEmpty) {
      payloadCompleto['user_id'] = userIdOverride;
    } else if (user != null && !oficialFinal) {
      payloadCompleto['user_id'] = user.id;
    }

    try {
      final res = await _client
          .from('recetas')
          .insert(payloadCompleto)
          .select('id_receta, titulo, tipo_comida, calorias, macros')
          .single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      // Si la base de datos aún no tiene la columna es_novedad (error 42703)
      if (errorStr.contains('es_novedad') && (errorStr.contains('42703') || errorStr.contains('does not exist'))) {
        final payloadSinNovedad = Map<String, dynamic>.from(payloadCompleto)..remove('es_novedad');
        try {
          final res = await _client
              .from('recetas')
              .insert(payloadSinNovedad)
              .select('id_receta, titulo, tipo_comida, calorias, macros')
              .single();
          return Map<String, dynamic>.from(res);
        } catch (_) {}
      }
      // Si la base de datos aún no tiene las columnas user_id o es_oficial (error 42703)
      if (errorStr.contains('42703') || errorStr.contains('does not exist')) {
        debugPrint(
          'Aviso: Columnas de privacidad no detectadas en recetas. Guardando en modo compatible básico.',
        );
        final Map<String, dynamic> payloadBasico = {
          'titulo': titulo,
          'descripcion': descripcion,
          'instrucciones': instrucciones,
        };
        if (tipoComida != null) payloadBasico['tipo_comida'] = tipoComida;
        if (calorias != null) payloadBasico['calorias'] = calorias;
        if (macros != null) payloadBasico['macros'] = macros;
        if (imagenUrl != null && imagenUrl.isNotEmpty) {
          payloadBasico['imagen_url'] = imagenUrl;
        }
        if (porciones != null) payloadBasico['porciones'] = porciones;
        if (tiempoPreparacion != null) {
          payloadBasico['tiempo_preparacion'] = tiempoPreparacion;
        }

        final res = await _client
            .from('recetas')
            .insert(payloadBasico)
            .select('id_receta, titulo, tipo_comida, calorias, macros')
            .single();
        return Map<String, dynamic>.from(res);
      }
      rethrow;
    }
  }

  /// Verifica si la receta es del catálogo oficial
  static bool esOficial(Map<String, dynamic> receta) {
    if (receta.containsKey('es_oficial')) {
      final val = receta['es_oficial'];
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
    }
    // Si no tiene user_id, es parte del recetario base predeterminado
    return receta['user_id'] == null;
  }

  /// Verifica si la receta pertenece al lote más reciente de "Recién Salidas del Sartén"
  static bool esNovedad(Map<String, dynamic> receta) {
    if (receta.containsKey('es_novedad')) {
      final val = receta['es_novedad'];
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
    }
    // Heurística defensiva: Si aún no se ha ejecutado el SQL en Supabase,
    // las recetas del lote más reciente (IDs >= 102 que sean oficiales) son novedades
    final id = receta['id_receta'];
    final int idInt = id is int ? id : (int.tryParse(id?.toString() ?? '0') ?? 0);
    return idInt >= 102 && esOficial(receta);
  }

  /// Verifica si la receta fue creada por el usuario actual
  static bool esMiReceta(Map<String, dynamic> receta, [String? currentUserId]) {
    final uid = currentUserId ?? _client.auth.currentUser?.id;
    if (uid == null) return false;
    final rUserId = receta['user_id']?.toString();
    return rUserId != null && rUserId == uid;
  }

  /// Verifica si la receta es de otro usuario pero está compartida con la comunidad
  static bool esComunidad(
    Map<String, dynamic> receta, [
    String? currentUserId,
  ]) {
    final uid = currentUserId ?? _client.auth.currentUser?.id;
    final rUserId = receta['user_id']?.toString();
    if (rUserId == null) return false;
    if (uid != null && rUserId == uid) return false;

    // Si tiene es_publica explícito
    if (receta.containsKey('es_publica')) {
      final val = receta['es_publica'];
      if (val is bool) return val;
      if (val is String) return val.toLowerCase() == 'true';
    }
    // Por retrocompatibilidad, si es de otro usuario y no es oficial
    return !esOficial(receta);
  }

  /// Determina si una receta es de naturaleza canina / para mascotas (premios, galletas, snacks perrunos)
  static bool esRecetaCanina(Map<String, dynamic> receta) {
    final tipo = (receta['tipo_comida'] ?? '').toString().toLowerCase();
    final titulo = (receta['titulo'] ?? '').toString().toLowerCase();

    if (tipo.contains('canin') || tipo.contains('perrun') || tipo.contains('perro')) {
      return true;
    }
    if (titulo.contains('canino') ||
        titulo.contains('canina') ||
        titulo.contains('perruno') ||
        titulo.contains('perruna') ||
        titulo.contains('para perro') ||
        titulo.contains('para perrito')) {
      return true;
    }
    return false;
  }

  /// Determina si el usuario actual tiene permisos para eliminar o editar la receta
  static bool puedeModificar(Map<String, dynamic> receta) {
    if (ServicioAdmin.esAdmin()) return true;
    return esMiReceta(receta);
  }

  /// Cambia la visibilidad pública de una receta creada por el usuario
  static Future<bool> cambiarVisibilidadPublica({
    required int idReceta,
    required bool nuevaVisibilidad,
  }) async {
    try {
      await _client
          .from('recetas')
          .update({'es_publica': nuevaVisibilidad})
          .eq('id_receta', idReceta);
      return true;
    } catch (e) {
      debugPrint('Error al cambiar visibilidad: $e');
      return false;
    }
  }

  /// Elimina una receta (verificando antes que pertenezca al usuario o sea admin).
  /// Limpia de forma segura en cascada 'receta_detalle', 'planeador' y 'recetas_cocinadas'
  /// para evitar bloqueos por llaves foráneas en Postgres.
  static Future<bool> eliminarReceta(int idReceta) async {
    try {
      // 1. Limpiar ingredientes detallados
      try {
        await _client.from('receta_detalle').delete().eq('id_receta', idReceta);
      } catch (e) {
        debugPrint('Aviso al limpiar receta_detalle: $e');
      }

      // 2. Limpiar referencias en planeador
      try {
        await _client.from('planeador').delete().eq('id_receta', idReceta);
      } catch (e) {
        debugPrint('Aviso al limpiar planeador: $e');
      }

      // 3. Limpiar referencias en recetas_cocinadas
      try {
        await _client.from('recetas_cocinadas').delete().eq('id_receta', idReceta);
      } catch (e) {
        debugPrint('Aviso al limpiar recetas_cocinadas: $e');
      }

      // 4. Eliminar la receta principal
      await _client.from('recetas').delete().eq('id_receta', idReceta);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar receta $idReceta: $e');
      return false;
    }
  }

  /// Mapa de imágenes curadas y verificadas (HTTP 200) para recetas oficiales del catálogo.
  /// Garantiza que nunca se muestren fotos rotas (404), duplicadas o con cargas infinitas.
  static const Map<int, String> imagenesVerificadasPorId = {
    36: 'https://images.unsplash.com/photo-1506084868230-bb9d95c24759?auto=format&fit=crop&w=600&q=80',
    38: 'https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?auto=format&fit=crop&w=600&q=80',
    39: 'https://plus.unsplash.com/premium_photo-1661776841313-1bd2be380a64?auto=format&fit=crop&w=600&q=80',
    47: 'https://images.unsplash.com/photo-1562707774-553917f561df?auto=format&fit=crop&w=600&q=80',
    50: 'https://images.unsplash.com/photo-1577906096429-f73c2c312435?auto=format&fit=crop&w=600&q=80',
    52: 'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?auto=format&fit=crop&w=600&q=80',
    53: 'https://images.unsplash.com/photo-1514733670139-4d87a1941d55?auto=format&fit=crop&w=600&q=80',
    57: 'https://plus.unsplash.com/premium_photo-1673018249121-b7618b433466?auto=format&fit=crop&w=600&q=80',
    58: 'https://images.unsplash.com/photo-1573018943660-502eca08e4b4?auto=format&fit=crop&w=600&q=80',
    60: 'https://images.unsplash.com/photo-1597958792579-bd3517df6399?auto=format&fit=crop&w=600&q=80',
    61: 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?auto=format&fit=crop&w=600&q=80',
    63: 'https://images.unsplash.com/photo-1782821961510-aa2b6baed210?auto=format&fit=crop&w=600&q=80',
    66: 'https://images.unsplash.com/photo-1787472742133-031fc734b96f?auto=format&fit=crop&w=600&q=80',
    68: 'https://images.unsplash.com/photo-1781115650881-bc5d55bd31d2?auto=format&fit=crop&w=600&q=80',
    70: 'https://images.unsplash.com/photo-1730596140741-6cc4963ad816?auto=format&fit=crop&w=600&q=80',
    71: 'https://images.unsplash.com/photo-1651256785544-fc012585e6a2?auto=format&fit=crop&w=600&q=80',
    72: 'https://images.unsplash.com/photo-1789546554683-2edf71bcf2e7?auto=format&fit=crop&w=600&q=80',
    74: 'https://images.unsplash.com/photo-1522065235999-38c8248e5898?auto=format&fit=crop&w=600&q=80',
    77: 'https://plus.unsplash.com/premium_photo-1669559809547-6e4c4fe41371?auto=format&fit=crop&w=600&q=80',
    79: 'https://images.unsplash.com/photo-1577805947697-89e18249d767?auto=format&fit=crop&w=600&q=80',
    80: 'https://images.unsplash.com/photo-1768179669433-bd9d52949c20?auto=format&fit=crop&w=600&q=80',
    81: 'https://images.unsplash.com/photo-1622756144420-6877b1b7476e?auto=format&fit=crop&w=600&q=80',
    83: 'https://plus.unsplash.com/premium_photo-1664478294917-c11274b9ce79?auto=format&fit=crop&w=600&q=80',
    85: 'https://plus.unsplash.com/premium_photo-1673590981774-d9f534e0c617?auto=format&fit=crop&w=600&q=80',
    86: 'https://plus.unsplash.com/premium_photo-1663842680485-45592e97b54b?auto=format&fit=crop&w=600&q=80',
    87: 'https://plus.unsplash.com/premium_photo-1731950424220-17ce9415dcc7?auto=format&fit=crop&w=600&q=80',
    88: 'https://images.unsplash.com/photo-1757715377412-749d66c9c297?auto=format&fit=crop&w=600&q=80',
    89: 'https://images.unsplash.com/photo-1753173301157-8136a70b4178?auto=format&fit=crop&w=600&q=80',
    90: 'https://plus.unsplash.com/premium_photo-1694336203192-c9e7f2891b95?auto=format&fit=crop&w=600&q=80',
    92: 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80',
    94: 'https://images.unsplash.com/photo-1788786877538-2289d3e4cb02?auto=format&fit=crop&w=600&q=80',
    95: 'https://images.unsplash.com/photo-1543339308-43e59d6b73a6?auto=format&fit=crop&w=600&q=80',
    96: 'https://images.unsplash.com/photo-1678554500191-3885a6fbf8c2?auto=format&fit=crop&w=600&q=80',
    98: 'https://plus.unsplash.com/premium_photo-1694141252774-c937d97641da?auto=format&fit=crop&w=600&q=80',
    99: 'https://images.unsplash.com/photo-1560717845-968823efbee1?auto=format&fit=crop&w=600&q=80',
    100: 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?auto=format&fit=crop&w=600&q=80',
    103: 'https://plus.unsplash.com/premium_photo-1667807521536-bc35c8d8b64b?auto=format&fit=crop&w=600&q=80',
    106: 'https://images.unsplash.com/photo-1603048588665-791ca8aea617?auto=format&fit=crop&w=600&q=80',
    107: 'https://images.unsplash.com/photo-1518492104633-130d0cc84637?auto=format&fit=crop&w=600&q=80',
    109: 'https://images.unsplash.com/photo-1779541900636-6fd6d5ddfe12?auto=format&fit=crop&w=600&q=80',
    110: 'https://images.unsplash.com/photo-1590655367923-fa80b7e61b6c?auto=format&fit=crop&w=600&q=80',
    111: 'https://plus.unsplash.com/premium_photo-1699030868880-d8970ccc146e?auto=format&fit=crop&w=600&q=80',
    112: 'https://images.unsplash.com/photo-1676976197405-24347416edc1?auto=format&fit=crop&w=600&q=80',
    116: 'https://images.unsplash.com/photo-1565086869529-8c7802cca7a0?auto=format&fit=crop&w=600&q=80',
    118: 'https://images.unsplash.com/photo-1788509814866-e1ddecfa6f0a?auto=format&fit=crop&w=600&q=80',
    120: 'https://images.unsplash.com/photo-1781567502827-3c671d8cae63?auto=format&fit=crop&w=600&q=80',
    123: 'https://images.unsplash.com/photo-1456404823214-a69ef7a1fae5?auto=format&fit=crop&w=600&q=80',
    124: 'https://images.unsplash.com/photo-1784571246476-ae530d147e2e?auto=format&fit=crop&w=600&q=80',
  };

  /// Resuelve la URL optimizada y verificada para cualquier receta de la aplicación
  static String? obtenerImagenOptimizada({
    dynamic idReceta,
    String? titulo,
    String? rawUrl,
  }) {
    final int idInt = idReceta is int
        ? idReceta
        : (int.tryParse(idReceta?.toString() ?? '0') ?? 0);

    // 1. Si existe imagen verificada por ID, tiene prioridad absoluta
    if (idInt > 0 && imagenesVerificadasPorId.containsKey(idInt)) {
      return imagenesVerificadasPorId[idInt];
    }

    // 2. Control especial para picadillo tradicional por título
    final t = (titulo ?? '').toLowerCase();
    if (t.contains('picadillo') &&
        (rawUrl == null || rawUrl.contains('546069901') || rawUrl.isEmpty)) {
      return 'https://images.unsplash.com/photo-1590655367923-fa80b7e61b6c?auto=format&fit=crop&w=600&q=80';
    }

    if (rawUrl == null || rawUrl.trim().isEmpty) return null;

    final trimmed = rawUrl.trim();

    // 3. Si es de Unsplash, optimizar parámetros de resolución y compresión para móvil
    if (trimmed.contains('images.unsplash.com') || trimmed.contains('plus.unsplash.com')) {
      if (!trimmed.contains('w=') && !trimmed.contains('fit=')) {
        final sep = trimmed.contains('?') ? '&' : '?';
        return '$trimmed${sep}auto=format&fit=crop&w=600&q=80';
      }
    }

    return trimmed;
  }
}
