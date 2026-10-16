import 'package:flutter/material.dart';
import 'servicio_ia.dart';

enum ModoElectrodomestico {
  tradicional,
  thermomix,
  airFryer,
}

extension ModoElectrodomesticoExt on ModoElectrodomestico {
  String get etiqueta {
    switch (this) {
      case ModoElectrodomestico.tradicional:
        return 'Tradicional';
      case ModoElectrodomestico.thermomix:
        return 'Thermomix (TM5/TM6/TM7) 🤖';
      case ModoElectrodomestico.airFryer:
        return 'Air Fryer 🍟';
    }
  }

  String get id {
    switch (this) {
      case ModoElectrodomestico.tradicional:
        return 'tradicional';
      case ModoElectrodomestico.thermomix:
        return 'thermomix';
      case ModoElectrodomestico.airFryer:
        return 'air_fryer';
    }
  }

  String get icono {
    switch (this) {
      case ModoElectrodomestico.tradicional:
        return '🍳';
      case ModoElectrodomestico.thermomix:
        return '🤖';
      case ModoElectrodomestico.airFryer:
        return '🍟';
    }
  }

  Color get colorPrimario {
    switch (this) {
      case ModoElectrodomestico.tradicional:
        return const Color(0xFFE53935);
      case ModoElectrodomestico.thermomix:
        return const Color(0xFF00897B); // Verde característico Thermomix
      case ModoElectrodomestico.airFryer:
        return const Color(0xFFF57C00); // Ámbar/naranja tostado
    }
  }

  String get subtitulo {
    switch (this) {
      case ModoElectrodomestico.tradicional:
        return 'Sartén, olla y fuego convencional';
      case ModoElectrodomestico.thermomix:
        return 'Control de temperatura, velocidad, giro inverso y accesorios';
      case ModoElectrodomestico.airFryer:
        return 'Cocción por convección de aire rápida y sin aceite';
    }
  }
}

/// Parámetros extraídos de un paso guiado para robot de cocina o freidora de aire
class ParametrosPasoRobot {
  final String? tiempo;
  final String? temperatura;
  final String? velocidad;
  final String? giro;
  final String? accesorio;
  final String textoLimpio;

  const ParametrosPasoRobot({
    this.tiempo,
    this.temperatura,
    this.velocidad,
    this.giro,
    this.accesorio,
    required this.textoLimpio,
  });

  bool get tieneParametros =>
      tiempo != null ||
      temperatura != null ||
      velocidad != null ||
      giro != null ||
      accesorio != null;
}

class ServicioCopilotoCocina {
  /// Extrae parámetros clave de un paso culinario ya sea con corchetes [5 seg | 120°C | Vel 1]
  /// o por detección contextual de palabras clave en el texto.
  static ParametrosPasoRobot parsearPaso(
    String pasoTexto, {
    ModoElectrodomestico modo = ModoElectrodomestico.tradicional,
  }) {
    String texto = pasoTexto.trim();
    String? tiempo;
    String? temperatura;
    String? velocidad;
    String? giro;
    String? accesorio;

    // 1. Detectar patrón de corchetes inicial: [Tiempo | Temp | Vel | ...]
    final matchCorchetes = RegExp(r'^\[(.*?)\]\s*(.*)$', dotAll: true).firstMatch(texto);
    if (matchCorchetes != null) {
      final contenidoCorchetes = matchCorchetes.group(1) ?? '';
      texto = matchCorchetes.group(2) ?? '';

      final segmentos = contenidoCorchetes.split('|').map((s) => s.trim()).toList();
      for (var seg in segmentos) {
        if (seg.isEmpty) continue;
        final segLower = seg.toLowerCase();

        // 1. Accesorios o acciones clave (revisar antes para no confundir 'agitar a los 5 min' con tiempo principal)
        if (segLower.contains('mariposa') ||
            segLower.contains('cestillo') ||
            segLower.contains('cubilete') ||
            segLower.contains('espátula') ||
            segLower.contains('canastilla') ||
            segLower.contains('agitar') ||
            segLower.contains('voltear') ||
            segLower.contains('precalentar')) {
          accesorio ??= seg;
        }
        // 2. Temperatura
        else if (segLower.contains('varoma') ||
            segLower.contains('sin temp') ||
            RegExp(r'\d+\s*°c?', caseSensitive: false).hasMatch(segLower)) {
          temperatura ??= seg;
        }
        // 3. Velocidad
        else if (segLower.contains('vel') ||
            segLower.contains('cuchara') ||
            segLower.contains('espiga') ||
            segLower.contains('turbo')) {
          velocidad ??= seg;
        }
        // 4. Giro inverso
        else if (segLower.contains('giro') ||
            segLower.contains('↺') ||
            segLower.contains('inverso')) {
          giro ??= seg;
        }
        // 5. Tiempo
        else if (RegExp(r'\d+\s*(?:seg|min|h|segundos|minutos|horas)', caseSensitive: false).hasMatch(segLower)) {
          tiempo ??= seg;
        }
      }
    }

    // 2. Si no se encontraron por corchetes, intentar extracción contextual si estamos en modo robot
    if (modo == ModoElectrodomestico.thermomix || modo == ModoElectrodomestico.airFryer) {
      if (temperatura == null) {
        final matchTemp = RegExp(
          r'(\d+\s*°C|varoma)',
          caseSensitive: false,
        ).firstMatch(texto);
        if (matchTemp != null) temperatura = matchTemp.group(1);
      }

      if (tiempo == null) {
        final matchTiempo = RegExp(
          r'(\d+\s*(?:seg|min|segundos|minutos))',
          caseSensitive: false,
        ).firstMatch(texto);
        if (matchTiempo != null) tiempo = matchTiempo.group(1);
      }

      if (modo == ModoElectrodomestico.thermomix) {
        if (velocidad == null) {
          final matchVel = RegExp(
            r'(vel(?:ocidad)?\s*(?:\d+(?:\.\d+)?|cuchara|espiga|turbo))',
            caseSensitive: false,
          ).firstMatch(texto);
          if (matchVel != null) velocidad = matchVel.group(1);
        }

        if (giro == null && (texto.toLowerCase().contains('giro inverso') || texto.contains('↺'))) {
          giro = 'Giro inverso ↺';
        }

        if (accesorio == null) {
          if (texto.toLowerCase().contains('mariposa')) {
            accesorio = 'Mariposa 🦋';
          } else if (texto.toLowerCase().contains('cestillo')) {
            accesorio = 'Cestillo 🧺';
          } else if (texto.toLowerCase().contains('varoma')) {
            accesorio = 'Varoma ♨️';
          }
        }
      }
    }

    return ParametrosPasoRobot(
      tiempo: tiempo,
      temperatura: temperatura,
      velocidad: velocidad,
      giro: giro,
      accesorio: accesorio,
      textoLimpio: texto.trim(),
    );
  }

  /// Adapta una receta existente a Thermomix o Air Fryer usando el motor de IA Gemini.
  static Future<String?> adaptarReceta({
    required String titulo,
    required String ingredientes,
    required String instrucciones,
    required ModoElectrodomestico modo,
  }) async {
    if (modo == ModoElectrodomestico.tradicional) {
      return instrucciones;
    }

    return await ServicioIA.adaptarRecetaAElectrodomestico(
      titulo: titulo,
      ingredientes: ingredientes,
      instrucciones: instrucciones,
      modo: modo.id,
    );
  }
}
