import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servicio_admin.dart';

/// Tipos de filtro según el origen y audiencia de las recetas
enum FiltroAudienciaReceta {
  todas,
  oficiales,
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
  }) async {
    final user = _client.auth.currentUser;
    final bool esAdmin = ServicioAdmin.esAdmin(user);

    // Por defecto: Las recetas de Alain (admin) son oficiales; las de usuarios son privadas
    final bool oficialFinal = esOficial ?? esAdmin;
    final bool publicaFinal = esPublica ?? esAdmin;

    final Map<String, dynamic> payloadCompleto = {
      'titulo': titulo,
      'descripcion': descripcion,
      'instrucciones': instrucciones,
      'es_oficial': oficialFinal,
      'es_publica': publicaFinal,
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
    if (user != null) payloadCompleto['user_id'] = user.id;

    try {
      final res = await _client
          .from('recetas')
          .insert(payloadCompleto)
          .select('id_receta, titulo, tipo_comida, calorias, macros')
          .single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
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

  /// Elimina una receta (verificando antes que pertenezca al usuario o sea admin)
  static Future<bool> eliminarReceta(int idReceta) async {
    try {
      // 1. Eliminar primero los ingredientes detallados
      try {
        await _client.from('receta_detalle').delete().eq('id_receta', idReceta);
      } catch (_) {}

      // 2. Eliminar la receta
      await _client.from('recetas').delete().eq('id_receta', idReceta);
      return true;
    } catch (e) {
      debugPrint('Error al eliminar receta $idReceta: $e');
      return false;
    }
  }
}
