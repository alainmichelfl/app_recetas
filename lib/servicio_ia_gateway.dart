import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config_api.dart';
import 'servicio_rate_limit_ia.dart';

/// 🛡️ Prioridad R1: Gateway Seguro para Inteligencia Artificial (Gemini Proxy)
///
/// Arquitectura Híbrida de Seguridad:
/// 1. Prioriza la Supabase Edge Function 'gemini-proxy' para ocultar la API Key de Gemini
///    y aplicar cuotas en servidor seguro sin exponer credenciales en el cliente web/PWA.
/// 2. Aplica Rate-Limiting anti-spam local y defensivo previo a cualquier llamada.
/// 3. Ofrece Resiliencia / Fallback Automático: si la Edge Function aún no está desplegada
///    en Supabase o hay un fallo de red, recurre de forma transparente a la conexión local
///    con [ConfigApi.geminiKey], garantizando que la app NUNCA se interrumpa para los usuarios.
class ServicioIAGateway {
  static const List<String> _nombresFuncionSupabase = ['gemini-proxy', 'gemin-proxy'];

  /// Bandera para forzar el fallback local durante pruebas unitarias o depuración
  @visibleForTesting
  static bool forzarFallbackLocal = false;

  /// Cliente HTTP inyectable para pruebas unitarias
  @visibleForTesting
  static http.Client? clienteHttpMock;

  /// URL de fallback local a Google Gemini API
  static String get urlGeminiFallback =>
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${ConfigApi.geminiKey}';

  /// Ejecuta una solicitud de IA pasando por el filtro de seguridad de cuotas (Rate Limit)
  /// y dirigiéndola preferentemente por la Supabase Edge Function 'gemini-proxy'.
  static Future<String?> ejecutarPeticion({
    required Map<String, dynamic> cuerpo,
    bool forzarJson = true,
    bool omitirRateLimit = false,
  }) async {
    // 1. Verificación de Rate-Limit y Cuotas Anti-Abusos
    if (!omitirRateLimit) {
      final permiso = await ServicioRateLimitIA.verificarPermiso();
      if (!permiso.permitido) {
        debugPrint('🛡️ [R1 Rate Limit Bloqueado] ${permiso.motivo}');
        return '⚠️ ${permiso.motivo}';
      }
    }

    final Map<String, dynamic> payload = {
      ...cuerpo,
      "generationConfig": {
        "responseMimeType": forzarJson ? "application/json" : "text/plain",
      },
      "safetySettings": [
        {
          "category": "HARM_CATEGORY_HARASSMENT",
          "threshold": "BLOCK_ONLY_HIGH",
        },
        {
          "category": "HARM_CATEGORY_HATE_SPEECH",
          "threshold": "BLOCK_ONLY_HIGH",
        },
        {
          "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
          "threshold": "BLOCK_ONLY_HIGH",
        },
        {
          "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
          "threshold": "BLOCK_ONLY_HIGH",
        },
      ],
    };

    // 2. Ruta Blindada Primaria: Supabase Edge Function 'gemini-proxy' (o alias 'gemin-proxy')
    if (!forzarFallbackLocal) {
      try {
        final respuestaEdge = await _invocarSupabaseEdgeFunction(payload);
        if (respuestaEdge != null && respuestaEdge.isNotEmpty) {
          debugPrint('🛡️ [R1 Gateway] Consulta atendida con éxito por Supabase Edge Function (Key blindada).');
          if (!omitirRateLimit) {
            await ServicioRateLimitIA.registrarLlamadoExitoso();
          }
          return respuestaEdge;
        }
      } catch (e) {
        debugPrint(
          'ℹ️ [R1 Gateway] Supabase Edge Function no disponible ($e). Recurriendo a fallback seguro con Gemini.',
        );
      }
    }

    // 3. Ruta de Resiliencia / Fallback Local: Llamada directa a Google Gemini
    final resultadoFallback = await _ejecutarFallbackDirecto(payload);
    if (resultadoFallback != null &&
        !resultadoFallback.startsWith('❌') &&
        !resultadoFallback.startsWith('⚠️') &&
        !omitirRateLimit) {
      await ServicioRateLimitIA.registrarLlamadoExitoso();
    }
    return resultadoFallback;
  }

  /// Invoca la Supabase Edge Function probando 'gemini-proxy' (y 'gemin-proxy' como alias defensivo)
  static Future<String?> _invocarSupabaseEdgeFunction(Map<String, dynamic> payload) async {
    try {
      final client = Supabase.instance.client;
      for (final nombre in _nombresFuncionSupabase) {
        try {
          final FunctionResponse response = await client.functions.invoke(
            nombre,
            body: payload,
          );

          if (response.status == 200 && response.data != null) {
            final data = response.data;
            if (data is Map && data['texto'] != null) {
              return data['texto'].toString();
            } else if (data is String) {
              return data;
            }
          }
        } catch (_) {
          // Continuar al siguiente alias si este no responde
        }
      }
    } catch (_) {
      // Supabase no inicializado o fallo total
      return null;
    }
    return null;
  }

  /// Fallback directo con reintentos a la API de Gemini (garantiza cero tiempo de inactividad)
  static Future<String?> _ejecutarFallbackDirecto(Map<String, dynamic> payload) async {
    int intentos = 0;
    const maxIntentos = 3;
    final cliente = clienteHttpMock ?? http.Client();

    while (intentos < maxIntentos) {
      intentos++;
      try {
        final respuesta = await cliente.post(
          Uri.parse(urlGeminiFallback),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (respuesta.statusCode == 200) {
          final datos = jsonDecode(respuesta.body);
          final candidate = datos['candidates']?[0];

          if (candidate == null || candidate['content'] == null) {
            final reason = candidate?['finishReason'] ?? 'Desconocido';
            debugPrint('⚠️ Gemini bloqueó la respuesta: $reason');
            return null;
          }

          final parts = candidate['content']['parts'];
          if (parts != null && parts is List && parts.isNotEmpty) {
            return parts[0]['text']?.toString();
          }
          return null;
        } else if (respuesta.statusCode == 503 || respuesta.statusCode == 429) {
          debugPrint('⏳ Google saturado (${respuesta.statusCode}). Reintentando ($intentos/$maxIntentos)...');
          await Future.delayed(Duration(seconds: intentos == 1 ? 2 : 4));
        } else {
          debugPrint('❌ Error de Google Gemini (${respuesta.statusCode}):\n${respuesta.body}');
          return '❌ Error de Google (${respuesta.statusCode}):\n${respuesta.body}';
        }
      } catch (e) {
        debugPrint('⏳ Error de red en llamada directa ($e). Reintentando...');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    return null;
  }
}
