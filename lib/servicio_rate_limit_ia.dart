import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resultado de la verificación de cuota y seguridad de IA
class ResultadoRateLimit {
  final bool permitido;
  final String motivo;
  final bool esCooldown;
  final int consultasRestantes;

  const ResultadoRateLimit({
    required this.permitido,
    this.motivo = '',
    this.esCooldown = false,
    this.consultasRestantes = 0,
  });

  @override
  String toString() =>
      'ResultadoRateLimit(permitido: $permitido, motivo: "$motivo", restante: $consultasRestantes)';
}

/// 🛡️ Prioridad R1: Controlador de Cuotas y Blindaje Anti-Abusos para Inteligencia Artificial.
/// Evita sobrecostos, llamadas infinitas y ataques de fuerza bruta en los motores de Chef IA y Sommelier.
class ServicioRateLimitIA {
  /// Límite máximo de consultas de IA permitidas por hora para el usuario (Free / Beta).
  static const int limitePorHora = 25;

  /// Tiempo mínimo de enfriamiento obligatorio entre clics consecutivos (evita doble clic accidental).
  static const Duration cooldownMinimo = Duration(seconds: 3);

  static DateTime? _ultimoLlamado;

  /// Clave de persistencia para marcas de tiempo en SharedPreferences
  static const String claveHistorial = 'rate_limit_ia_timestamps_v1';

  /// Evalúa si el usuario tiene permitido realizar una consulta con IA en este instante.
  static Future<ResultadoRateLimit> verificarPermiso({
    SharedPreferences? prefsOverride,
    DateTime? tiempoActualOverride,
  }) async {
    final ahora = tiempoActualOverride ?? DateTime.now();

    // 1. Verificación de Cooldown Inmediato (Previene clics dobles / bucles de UI)
    if (_ultimoLlamado != null) {
      final diferencia = ahora.difference(_ultimoLlamado!);
      if (diferencia < cooldownMinimo) {
        final segundosFaltantes = (cooldownMinimo.inMilliseconds - diferencia.inMilliseconds) / 1000.0;
        final segundosFormateados = segundosFaltantes > 0 ? segundosFaltantes.toStringAsFixed(1) : '1';
        return ResultadoRateLimit(
          permitido: false,
          motivo: 'El Chef IA está preparando tu solicitud. Espera $segundosFormateados s antes de consultar nuevamente.',
          esCooldown: true,
          consultasRestantes: 0,
        );
      }
    }

    // 2. Verificación de Cuota Horaria Móvil (Últimos 60 minutos)
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final listaTiempos = prefs.getStringList(claveHistorial) ?? [];

    final unaHoraAtras = ahora.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    final llamadasEnVentana = listaTiempos
        .map((t) => int.tryParse(t) ?? 0)
        .where((timestamp) => timestamp > unaHoraAtras)
        .toList();

    if (llamadasEnVentana.length >= limitePorHora) {
      return ResultadoRateLimit(
        permitido: false,
        motivo:
            'Has alcanzado la cuota de seguridad de $limitePorHora consultas de IA por hora. Tu límite se renovará automáticamente.',
        esCooldown: false,
        consultasRestantes: 0,
      );
    }

    final restantes = limitePorHora - llamadasEnVentana.length;
    return ResultadoRateLimit(
      permitido: true,
      consultasRestantes: restantes,
    );
  }

  /// Registra una llamada IA exitosa tanto en memoria (cooldown) como en almacenamiento persistente.
  static Future<void> registrarLlamadoExitoso({
    SharedPreferences? prefsOverride,
    DateTime? tiempoOverride,
  }) async {
    final ahora = tiempoOverride ?? DateTime.now();
    _ultimoLlamado = ahora;

    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final listaTiempos = prefs.getStringList(claveHistorial) ?? [];

    final unaHoraAtras = ahora.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    final tiemposLimpios = listaTiempos
        .map((t) => int.tryParse(t) ?? 0)
        .where((t) => t > unaHoraAtras)
        .map((t) => t.toString())
        .toList();

    tiemposLimpios.add(ahora.millisecondsSinceEpoch.toString());
    await prefs.setStringList(claveHistorial, tiemposLimpios);
  }

  /// Consulta cuántas llamadas se han realizado en la última hora móvil.
  static Future<int> consultarLlamadasUltimaHora({SharedPreferences? prefsOverride}) async {
    final ahora = DateTime.now();
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final listaTiempos = prefs.getStringList(claveHistorial) ?? [];

    final unaHoraAtras = ahora.subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
    return listaTiempos
        .map((t) => int.tryParse(t) ?? 0)
        .where((t) => t > unaHoraAtras)
        .length;
  }

  /// Reinicia el estado en memoria para tests unitarios.
  @visibleForTesting
  static void resetearParaPruebas() {
    _ultimoLlamado = null;
  }
}
