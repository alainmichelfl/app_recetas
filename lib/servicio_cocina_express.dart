import 'package:flutter/material.dart';

/// Tipos de filtros y colecciones rápidas para usuarios con poco tiempo
enum FiltroExpress {
  todos,
  express20,
  faciles5,
  ceroTrastes,
  sinFuego,
  batchReady,
}

extension FiltroExpressExtension on FiltroExpress {
  String get id {
    switch (this) {
      case FiltroExpress.todos:
        return 'todos';
      case FiltroExpress.express20:
        return 'express20';
      case FiltroExpress.faciles5:
        return 'faciles5';
      case FiltroExpress.ceroTrastes:
        return 'ceroTrastes';
      case FiltroExpress.sinFuego:
        return 'sinFuego';
      case FiltroExpress.batchReady:
        return 'batchReady';
    }
  }

  String get etiqueta {
    switch (this) {
      case FiltroExpress.todos:
        return 'Todas';
      case FiltroExpress.express20:
        return 'Express (≤ 20 min)';
      case FiltroExpress.faciles5:
        return 'Fáciles (≤ 5 ing)';
      case FiltroExpress.ceroTrastes:
        return 'Cero Trastes (1 Sartén)';
      case FiltroExpress.sinFuego:
        return 'Sin Estufa (5-10 min)';
      case FiltroExpress.batchReady:
        return 'Ensamble Batch (4 min)';
    }
  }

  String get emoji {
    switch (this) {
      case FiltroExpress.todos:
        return '🍽️';
      case FiltroExpress.express20:
        return '⚡';
      case FiltroExpress.faciles5:
        return '✨';
      case FiltroExpress.ceroTrastes:
        return '🍳';
      case FiltroExpress.sinFuego:
        return '🥗';
      case FiltroExpress.batchReady:
        return '🍱';
    }
  }

  String get descripcionCorta {
    switch (this) {
      case FiltroExpress.todos:
        return 'Todas las recetas disponibles';
      case FiltroExpress.express20:
        return 'Platillos completos listos en 20 minutos o menos';
      case FiltroExpress.faciles5:
        return 'Recetas minimalistas de 5 ingredientes o menos';
      case FiltroExpress.ceroTrastes:
        return 'Todo en una sola sartén, freidora de aire o refractario';
      case FiltroExpress.sinFuego:
        return 'Bowls, wraps y ensaladas sin prender la estufa';
      case FiltroExpress.batchReady:
        return 'Cenas calientes armadas con las bases preparadas del domingo';
    }
  }

  Color get color {
    switch (this) {
      case FiltroExpress.todos:
        return Colors.grey.shade800;
      case FiltroExpress.express20:
        return const Color(0xFFE65100); // Naranja vibrante
      case FiltroExpress.faciles5:
        return const Color(0xFF6A1B9A); // Morado amatista
      case FiltroExpress.ceroTrastes:
        return const Color(0xFF00695C); // Verde azulado
      case FiltroExpress.sinFuego:
        return const Color(0xFF2E7D32); // Verde fresco
      case FiltroExpress.batchReady:
        return const Color(0xFF1565C0); // Azul real
    }
  }

  Color get fondoColor {
    switch (this) {
      case FiltroExpress.todos:
        return Colors.grey.shade100;
      case FiltroExpress.express20:
        return const Color(0xFFFFF3E0);
      case FiltroExpress.faciles5:
        return const Color(0xFFF3E5F5);
      case FiltroExpress.ceroTrastes:
        return const Color(0xFFE0F2F1);
      case FiltroExpress.sinFuego:
        return const Color(0xFFE8F5E9);
      case FiltroExpress.batchReady:
        return const Color(0xFFE3F2FD);
    }
  }

  IconData get icono {
    switch (this) {
      case FiltroExpress.todos:
        return Icons.restaurant_menu;
      case FiltroExpress.express20:
        return Icons.bolt_rounded;
      case FiltroExpress.faciles5:
        return Icons.auto_awesome;
      case FiltroExpress.ceroTrastes:
        return Icons.skateboarding; // o skillet
      case FiltroExpress.sinFuego:
        return Icons.eco;
      case FiltroExpress.batchReady:
        return Icons.inventory_2;
    }
  }
}

/// Representa el desglose entre tiempo activo (picar/saltear) y tiempo pasivo (desatendido en horno o hervido)
class DesgloseTiempoCocina {
  final int totalMinutos;
  final int activoMinutos;
  final int pasivoMinutos;
  final bool esEstimado;

  const DesgloseTiempoCocina({
    required this.totalMinutos,
    required this.activoMinutos,
    required this.pasivoMinutos,
    this.esEstimado = true,
  });

  String get etiquetaResumen {
    if (totalMinutos <= 0) return 'Tiempo rápido';
    if (pasivoMinutos <= 0) return '⚡ $totalMinutos min (todo activo)';
    return '⏱️ $totalMinutos min (Activo: $activoMinutos min | Desatendido: $pasivoMinutos min)';
  }

  String get insigniaCorta {
    if (totalMinutos <= 0) return 'Rápido';
    return '$totalMinutos min';
  }
}

/// Servicio que centraliza la lógica de recetas express, conteo de ingredientes y cero trastes
class ServicioCocinaExpress {
  /// Extrae el total de minutos de una receta analizando campos explícitos o texto
  static int extraerMinutosTotales(Map<String, dynamic> receta) {
    // 1. Campo tiempo_preparacion en Supabase
    final rawTiempo = receta['tiempo_preparacion']?.toString() ?? '';
    if (rawTiempo.isNotEmpty && rawTiempo != 'No especificado') {
      final minutosCampo = _extraerMinutosDeTexto(rawTiempo);
      if (minutosCampo > 0) return minutosCampo;
    }

    // 2. Analizar bloque de texto en descripcion o instrucciones
    final textoCompleto =
        "${receta['descripcion'] ?? ''} ${receta['instrucciones'] ?? ''}";

    // Buscar "TIEMPO: X min", "TIEMPO TOTAL: 25 min", "DURACIÓN: 15 min" en su propia línea
    final regTiempoLinea = RegExp(
      r'(?:^|\n)\s*(?:⏱️\s*)?(?:tiempo(?:\s+total|\s+estimado|\s+de\s+preparaci[oó]n)?|duraci[oó]n)\s*:\s*([^\n\r]+)',
      caseSensitive: false,
    );
    final match = regTiempoLinea.firstMatch(textoCompleto);
    if (match != null) {
      final val = _extraerMinutosDeTexto(match.group(1) ?? '');
      if (val > 0) return val;
    }

    // 3. Si no hay encabezado explícito de TIEMPO, sumar los tiempos parciales de los pasos (ej. 3 min salteado + 15 min cocción = 18 min)
    final minutosSumados = _sumarMinutosDePasos(textoCompleto);
    if (minutosSumados > 0) return minutosSumados;

    // 4. Fallback heurístico según el tipo de comida o palabras clave
    final titulo = (receta['titulo'] ?? '').toString().toLowerCase();
    if (titulo.contains('express') ||
        titulo.contains('rápido') ||
        titulo.contains('wrap') ||
        titulo.contains('tosta') ||
        titulo.contains('smoothie') ||
        titulo.contains('licuado')) {
      return 12;
    }
    if (titulo.contains('ensalada') ||
        titulo.contains('sandwich') ||
        titulo.contains('sándwich') ||
        titulo.contains('quesadilla') ||
        titulo.contains('huevos') ||
        titulo.contains('omelette')) {
      return 15;
    }

    return 25; // Promedio estándar
  }

  static int _sumarMinutosDePasos(String texto) {
    final regMinutos = RegExp(r'(\d+)\s*(?:minutos?|mins?)\b', caseSensitive: false);
    final matches = regMinutos.allMatches(texto);
    int suma = 0;
    for (final m in matches) {
      final n = int.tryParse(m.group(1) ?? '') ?? 0;
      if (n > 0 && n <= 120) {
        suma += n;
      }
    }
    return suma;
  }

  static int _extraerMinutosDeTexto(String texto) {
    // Busca patrones como "15 min", "20 minutos", "1 hora", "45 mins"
    final regMinutos = RegExp(r'(\d+)\s*(?:minutos?|mins?|m\b)', caseSensitive: false);
    final matchMin = regMinutos.firstMatch(texto);
    if (matchMin != null) {
      return int.tryParse(matchMin.group(1) ?? '') ?? 0;
    }

    final regHoras = RegExp(r'(\d+)\s*(?:horas?|hrs?|h\b)', caseSensitive: false);
    final matchHoras = regHoras.firstMatch(texto);
    if (matchHoras != null) {
      final horas = int.tryParse(matchHoras.group(1) ?? '') ?? 0;
      return horas * 60;
    }

    return 0;
  }

  /// Calcula el desglose entre tiempo activo (manos en la masa) y tiempo pasivo (desatendido)
  static DesgloseTiempoCocina calcularDesglose(Map<String, dynamic> receta) {
    final total = extraerMinutosTotales(receta);
    final texto =
        "${receta['titulo'] ?? ''} ${receta['descripcion'] ?? ''} ${receta['instrucciones'] ?? ''}"
            .toLowerCase();

    // Detección explícita si la receta lo incluye en su texto
    final regActivo = RegExp(r'activo\s*:\s*(\d+)', caseSensitive: false);
    final regPasivo = RegExp(r'(?:pasivo|cocci[oó]n|desatendido)\s*:\s*(\d+)', caseSensitive: false);

    final mAct = regActivo.firstMatch(texto);
    final mPas = regPasivo.firstMatch(texto);

    if (mAct != null && mPas != null) {
      final act = int.tryParse(mAct.group(1) ?? '') ?? (total ~/ 2);
      final pas = int.tryParse(mPas.group(1) ?? '') ?? (total - act);
      return DesgloseTiempoCocina(
        totalMinutos: act + pas,
        activoMinutos: act,
        pasivoMinutos: pas,
        esEstimado: false,
      );
    }

    // Heurística gastronómica según la técnica culinaria
    final bool esHorno = texto.contains('hornear') ||
        texto.contains('horno') ||
        texto.contains('hornea') ||
        texto.contains('180°c') ||
        texto.contains('200°c');
    final bool esLento = texto.contains('hervir a fuego lento') ||
        texto.contains('cocinar por 40') ||
        texto.contains('cocinar por 30') ||
        texto.contains('marinar');
    final bool esAirFryer = texto.contains('air fryer') ||
        texto.contains('freidora de aire');
    final bool esFrio = esSinFuego(receta);

    // Total seguro contra negativos o cero
    final totalEfectivo = total > 0 ? total : (esFrio ? 5 : 15);

    if (esFrio || totalEfectivo <= 3) {
      // Todo es activo (picar/ensamblar) y cero tiempo pasivo
      return DesgloseTiempoCocina(
        totalMinutos: totalEfectivo,
        activoMinutos: totalEfectivo,
        pasivoMinutos: 0,
      );
    }

    if (esHorno || esLento) {
      // Mucho tiempo desatendido
      final minActivo = totalEfectivo >= 5 ? 5 : 1;
      final activo = (totalEfectivo * 0.3).round().clamp(minActivo, totalEfectivo);
      final pasivo = (totalEfectivo - activo).clamp(0, totalEfectivo);
      return DesgloseTiempoCocina(
        totalMinutos: totalEfectivo,
        activoMinutos: activo,
        pasivoMinutos: pasivo,
      );
    }

    if (esAirFryer) {
      final minActivo = totalEfectivo >= 4 ? 4 : 1;
      final activo = (totalEfectivo * 0.35).round().clamp(minActivo, totalEfectivo);
      final pasivo = (totalEfectivo - activo).clamp(0, totalEfectivo);
      return DesgloseTiempoCocina(
        totalMinutos: totalEfectivo,
        activoMinutos: activo,
        pasivoMinutos: pasivo,
      );
    }

    // Salteados, estufa rápida, sartenes
    final minActivo = totalEfectivo >= 5 ? 5 : 1;
    final activo = (totalEfectivo * 0.65).round().clamp(minActivo, totalEfectivo);
    final pasivo = (totalEfectivo - activo).clamp(0, totalEfectivo);
    return DesgloseTiempoCocina(
      totalMinutos: totalEfectivo,
      activoMinutos: activo,
      pasivoMinutos: pasivo,
    );
  }

  /// Cuenta la cantidad de ingredientes listados en una receta
  static int contarIngredientes(Map<String, dynamic> receta) {
    // Si viene la lista estructurada
    if (receta['ingredientes'] is List) {
      final lista = receta['ingredientes'] as List;
      if (lista.isNotEmpty) return lista.length;
    }

    final texto = "${receta['descripcion'] ?? ''} ${receta['instrucciones'] ?? ''}";

    // Extraer bloque entre "INGREDIENTES" e "INSTRUCCIONES"
    final regBloque = RegExp(
      r'ingredientes\s*:?(.*?)(?:instrucciones|preparaci[oó]n|elaboraci[oó]n|\n\n\n|$)',
      caseSensitive: false,
      dotAll: true,
    );

    final match = regBloque.firstMatch(texto);
    if (match != null) {
      final bloque = match.group(1) ?? '';
      // Contar líneas que inician con viñetas o guiones
      final lineas = bloque
          .split('\n')
          .map((l) => l.trim())
          .where((l) =>
              l.startsWith('-') ||
              l.startsWith('•') ||
              l.startsWith('*') ||
              RegExp(r'^\d+\.').hasMatch(l))
          .toList();
      if (lineas.isNotEmpty) return lineas.length;
    }

    // Fallback: contar líneas con guión en todo el texto
    final lineasGuion = texto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('-') || l.startsWith('•'))
        .toList();
    if (lineasGuion.isNotEmpty) return lineasGuion.length;

    return 6; // Promedio estándar
  }

  /// Evalúa si la receta califica como "Express (≤ 20 minutos)"
  static bool esExpress20(Map<String, dynamic> receta) {
    final minutos = extraerMinutosTotales(receta);
    return minutos > 0 && minutos <= 20;
  }

  /// Evalúa si la receta califica como "Fácil (≤ 5 ingredientes)"
  static bool esFacil5(Map<String, dynamic> receta) {
    final cuenta = contarIngredientes(receta);
    return cuenta > 0 && cuenta <= 5;
  }

  /// Evalúa si la receta es de "Una Sola Sartén / Cero Trastes (One-Pot & Air Fryer)"
  static bool esCeroTrastes(Map<String, dynamic> receta) {
    final texto =
        "${receta['titulo'] ?? ''} ${receta['descripcion'] ?? ''} ${receta['instrucciones'] ?? ''}"
            .toLowerCase();

    return texto.contains('una sola sartén') ||
        texto.contains('un solo sartén') ||
        texto.contains('one-pot') ||
        texto.contains('one pot') ||
        texto.contains('one pan') ||
        texto.contains('one-pan') ||
        texto.contains('skillet') ||
        texto.contains('sartén único') ||
        texto.contains('sarten unico') ||
        texto.contains('air fryer') ||
        texto.contains('freidora de aire') ||
        texto.contains('una charola') ||
        texto.contains('en la misma sartén') ||
        texto.contains('en el mismo sartén') ||
        texto.contains('en una sola cacerola');
  }

  /// Evalúa si la receta es de "Sin Estufa / Ensamble Frío (5-10 min)"
  static bool esSinFuego(Map<String, dynamic> receta) {
    final texto =
        "${receta['titulo'] ?? ''} ${receta['descripcion'] ?? ''} ${receta['instrucciones'] ?? ''}"
            .toLowerCase();

    return texto.contains('sin fuego') ||
        texto.contains('sin cocción') ||
        texto.contains('sin estufa') ||
        texto.contains('ensalada') ||
        texto.contains('tosta') ||
        texto.contains('tostas') ||
        texto.contains('wrap') ||
        texto.contains('wraps') ||
        texto.contains('ceviche') ||
        texto.contains('bowl frío') ||
        texto.contains('smoothie') ||
        texto.contains('licuado') ||
        texto.contains('sandwich') ||
        texto.contains('sándwich') ||
        texto.contains('tártara') ||
        texto.contains('tartar');
  }

  /// Evalúa si la receta es "Ensamble con Batch Cooking" (aprovecha bases cocidas del domingo)
  static bool esBatchReady(Map<String, dynamic> receta) {
    final texto =
        "${receta['titulo'] ?? ''} ${receta['descripcion'] ?? ''} ${receta['instrucciones'] ?? ''}"
            .toLowerCase();

    return texto.contains('batch cooking') ||
        texto.contains('arroz cocido') ||
        texto.contains('quinoa cocida') ||
        texto.contains('pollo deshebrado') ||
        texto.contains('verduras asadas previas') ||
        texto.contains('legumbres cocidas') ||
        texto.contains('frijoles cocidos') ||
        texto.contains('base pre-cocida') ||
        texto.contains('precocid') ||
        texto.contains('ensamble rápido') ||
        texto.contains('preparada con anticipación');
  }

  /// Comprueba si una receta cumple con el filtro express seleccionado
  static bool cumpleFiltroExpress(
    Map<String, dynamic> receta,
    FiltroExpress filtro,
  ) {
    switch (filtro) {
      case FiltroExpress.todos:
        return true;
      case FiltroExpress.express20:
        return esExpress20(receta);
      case FiltroExpress.faciles5:
        return esFacil5(receta);
      case FiltroExpress.ceroTrastes:
        return esCeroTrastes(receta);
      case FiltroExpress.sinFuego:
        return esSinFuego(receta);
      case FiltroExpress.batchReady:
        return esBatchReady(receta);
    }
  }

  /// Instrucciones de prompt para inyectar en Gemini cuando se activa el "Modo Express" en Chef IA
  static String construirInstruccionesPromptExpress({
    bool modoCeroTrastes = false,
    bool modoSinFuego = false,
    int tiempoMaximoMinutos = 15,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('''
    - MODO EXTREMO DE TIEMPO: COCINA EXPRESS (MÁXIMO $tiempoMaximoMinutos MINUTOS).
    El usuario NO tiene tiempo para cocinar hoy. Sigue estrictamente estas reglas:
    1. TIEMPO TOTAL: Debe estar lista en máximo $tiempoMaximoMinutos minutos de reloj.
    2. DESGLOSE DE TIEMPO OBLIGATORIO: En la descripción o cabecera incluye explícitamente:
       "Tiempo activo: X min | Cocción: Y min" (la suma no debe superar $tiempoMaximoMinutos min).
    3. MINIMALISMO DE INGREDIENTES: Usa máximo 5 o 6 ingredientes principales disponibles. Cero preparaciones largas.
    4. TÉCNICAS RÁPIDAS: Salteado rápido a fuego vivo, plancha, quesadilla/torta gourmet o ensamble en frío.
    ''');

    if (modoCeroTrastes) {
      buffer.writeln('''
    5. REGLA CERO TRASTES (ONE-PAN): Toda la cocción DEBE realizarse en una sola sartén o freidora de aire. Prohibido usar múltiples ollas.
    ''');
    }

    if (modoSinFuego) {
      buffer.writeln('''
    6. REGLA SIN FUEGO / SIN ESTUFA: La receta debe prepararse sin encender estufa ni horno (ensalada sustanciosa, wrap, tosta, bowl frío o ceviche express).
    ''');
    }

    return buffer.toString();
  }
}
