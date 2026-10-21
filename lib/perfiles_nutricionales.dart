import 'package:flutter/material.dart';

/// Representa un sello de calidad nutricional y semáforo dietético calculado automáticamente
class SelloNutricional {
  final String etiqueta;
  final String emoji;
  final Color colorTexto;
  final Color colorFondo;
  final String descripcionCorta;

  const SelloNutricional({
    required this.etiqueta,
    required this.emoji,
    required this.colorTexto,
    required this.colorFondo,
    required this.descripcionCorta,
  });
}

/// Fuente única de verdad para objetivos calóricos y estilos de dieta.
/// Lo usan Preferencias, Planeador, Salud y Chef IA.
class PerfilesNutricionales {
  PerfilesNutricionales._();

  // ───────────── OBJETIVOS (calorías y macros) ─────────────
  static const String deficit = 'Déficit (Baja)';
  static const String mantenimiento = 'Mantenimiento';
  static const String volumen = 'Volumen (Alta)';

  static const List<String> objetivos = [deficit, mantenimiento, volumen];

  static const Map<String, Map<String, int>> macrosPorObjetivo = {
    deficit: {'calorias': 1500, 'proteinas': 130, 'carbs': 140, 'grasas': 45},
    mantenimiento: {
      'calorias': 2000,
      'proteinas': 140,
      'carbs': 230,
      'grasas': 65,
    },
    volumen: {'calorias': 2500, 'proteinas': 180, 'carbs': 300, 'grasas': 75},
  };

  /// Macros usados cuando el estilo de dieta es Keto (sobrescribe el objetivo).
  static const Map<String, int> macrosKeto = {
    'calorias': 1700,
    'proteinas': 110,
    'carbs': 30,
    'grasas': 130,
  };

  static const Map<String, String> descripcionObjetivo = {
    deficit: 'Platillos ligeros (~1,500 kcal/día) para déficit calórico.',
    mantenimiento: 'Balance estándar de nutrientes y energía (~2,000 kcal/día).',
    volumen: 'Alto aporte proteico y calórico (~2,500 kcal/día).',
  };

  // ───────────── ESTILOS DE DIETA (se pueden combinar) ─────────────
  static const String libre = 'Libre';
  static const String bajaEnGrasa = 'Baja en grasa';
  static const String keto = 'Keto';
  static const String vegetariana = 'Vegetariana';
  static const String vegana = 'Vegana';
  static const String pescetariana = 'Pescetariana';
  static const String altaProteina = 'Alta en proteína';
  static const String sinGluten = 'Sin gluten';
  static const String sinLactosa = 'Sin lactosa';
  static const String mediterranea = 'Mediterránea';
  static const String diabetes = 'Apto para diabetes';

  static const List<String> estilos = [
    libre,
    bajaEnGrasa,
    keto,
    vegetariana,
    vegana,
    pescetariana,
    altaProteina,
    sinGluten,
    sinLactosa,
    mediterranea,
    diabetes,
  ];

  /// Instrucción que se agrega al prompt del Chef IA por cada estilo.
  static const Map<String, String> instruccionIA = {
    bajaEnGrasa:
        'Dieta BAJA EN GRASA / LIBRE DE GRASA (Low-Fat): Prohibido usar manteca, tocino, empanizados, frituras por inmersión, mantequilla y lácteos enteros. Prioriza cocción al vapor, al horno, hervido, pochado o en freidora de aire. Usa proteínas magras (pechuga de pollo/pavo, pescados blancos, claras de huevo, legumbres). Máximo 5-7g de grasa por porción (~20g total al día).',
    keto: 'Dieta KETO: muy bajo en carbohidratos (máx. 30 g al día), alto en grasas saludables.',
    vegetariana: 'Dieta VEGETARIANA: sin carne, aves ni pescado (permite huevo y lácteos).',
    vegana: 'Dieta VEGANA: sin ningún producto de origen animal (sin carne, pescado, huevo, lácteos ni miel).',
    pescetariana: 'Dieta PESCETARIANA: sin carne ni aves; permite pescado, mariscos, huevo y lácteos.',
    altaProteina: 'Dieta ALTA EN PROTEÍNA: prioriza fuentes magras de proteína en cada platillo.',
    sinGluten: 'SIN GLUTEN (celiaquía/intolerancia): prohibido trigo, cebada, centeno, avena no certificada, pan, pasta de trigo y harina de trigo.',
    sinLactosa: 'SIN LACTOSA (intolerancia): prohibido leche, queso, crema, mantequilla y yogur con lactosa; usa alternativas sin lactosa.',
    mediterranea: 'Dieta MEDITERRÁNEA: aceite de oliva, pescado, legumbres, verduras y granos enteros; poca carne roja.',
    diabetes: 'APTO PARA DIABETES: bajo índice glucémico, sin azúcares añadidos ni harinas refinadas, carbohidratos complejos y fibra, porciones controladas.',
  };

  /// Palabras que delatan ingredientes a evitar (filtro simple para recetas
  /// ya guardadas en el Planeador, que se buscan por título y descripción).
  static const Map<String, List<String>> palabrasExcluidas = {
    bajaEnGrasa: [
      'manteca',
      'tocino',
      'chicharron',
      'chicharrón',
      'frito',
      'empanizado',
      'capeado',
      'crema entera',
      'carnitas',
      'chorizo',
      'panceta',
      'mayonesa',
    ],
    vegetariana: [
      'pollo', 'carne', 'res', 'cerdo', 'tocino', 'jamón', 'jamon', 'atún',
      'atun', 'pescado', 'camarón', 'camaron', 'salmón', 'salmon', 'pavo',
      'chorizo', 'bistec', 'costilla',
    ],
    vegana: [
      'pollo', 'carne', 'res', 'cerdo', 'tocino', 'jamón', 'jamon', 'atún',
      'atun', 'pescado', 'camarón', 'camaron', 'salmón', 'salmon', 'pavo',
      'chorizo', 'bistec', 'costilla', 'huevo', 'queso', 'leche', 'crema',
      'mantequilla', 'yogur', 'miel',
    ],
    pescetariana: [
      'pollo', 'carne', 'res', 'cerdo', 'tocino', 'jamón', 'jamon', 'pavo',
      'chorizo', 'bistec', 'costilla',
    ],
    sinGluten: ['pan', 'pasta', 'harina', 'trigo', 'tortilla de harina', 'galleta'],
    sinLactosa: ['queso', 'leche', 'crema', 'mantequilla', 'yogur', 'yogurt'],
  };

  // ───────────── Utilidades ─────────────
  /// Texto guardable en la BD (ej. "Keto,Sin lactosa").
  static String serializar(Iterable<String> seleccion) =>
      normalizar(seleccion).join(',');

  static List<String> deserializar(String? texto) {
    if (texto == null || texto.trim().isEmpty) return [libre];
    return normalizar(texto.split(','));
  }

  /// Quita valores desconocidos; soporta alias como "Libre de grasa"; "Libre" es exclusivo.
  static List<String> normalizar(Iterable<String> seleccion) {
    final limpios = seleccion
        .map((e) => e.trim())
        .map((e) {
          final l = e.toLowerCase();
          if (l == 'libre de grasa' || l == 'baja en grasa' || l == 'sin grasa') {
            return bajaEnGrasa;
          }
          return e;
        })
        .where((e) => estilos.contains(e) && e != libre)
        .toSet()
        .toList();
    return limpios.isEmpty ? [libre] : limpios;
  }

  /// Macros finales según objetivo + estilos (Keto manda sobre el objetivo; Baja en grasa ajusta grasas al mínimo).
  static Map<String, int> macrosPara(String objetivo, List<String> estilosSel) {
    if (estilosSel.contains(keto)) return macrosKeto;
    final base = Map<String, int>.from(
      macrosPorObjetivo[objetivo] ?? macrosPorObjetivo[mantenimiento]!,
    );
    if (estilosSel.contains(bajaEnGrasa)) {
      final grasasBase = base['grasas'] ?? 65;
      const int grasasBajas = 20;
      if (grasasBase > grasasBajas) {
        final reduccionKcal = (grasasBase - grasasBajas) * 9;
        base['grasas'] = grasasBajas;
        final carbsExtra = (reduccionKcal * 0.75 / 4).round();
        final protExtra = (reduccionKcal * 0.25 / 4).round();
        base['carbs'] = (base['carbs'] ?? 200) + carbsExtra;
        base['proteinas'] = (base['proteinas'] ?? 140) + protExtra;
      }
    }
    return base;
  }

  /// Texto de estilos y objetivo para el prompt del Chef IA.
  static String instruccionesPrompt(List<String> estilosSel) {
    final lineas = estilosSel
        .map((e) => instruccionIA[e])
        .whereType<String>()
        .map((t) => '- $t')
        .toList();
    return lineas.join('\n');
  }

  static String _sinAcentos(String s) {
    const de = 'áàäâéèëêíìïîóòöôúùüûñ';
    const a = 'aaaaeeeeiiiioooouuuun';
    var r = s.toLowerCase();
    for (var i = 0; i < de.length; i++) {
      r = r.replaceAll(de[i], a[i]);
    }
    return r;
  }

  /// Convierte el texto libre de alergias en términos ("mariscos, cacahuate y
  /// picante" -> [mariscos, cacahuate, picante]).
  static List<String> terminosAlergias(String alergias) {
    return alergias
        .split(RegExp(r'[,;\n]| y '))
        .map((e) => _sinAcentos(e.trim()))
        .where((e) => e.length >= 3)
        .toList();
  }

  static bool _contienePalabra(String textoNormalizado, String palabra) {
    final p = _sinAcentos(palabra);
    // Acepta plural simple (huevo/huevos, camaron/camarones)
    return RegExp(
      '(?<![a-z])${RegExp.escape(p)}(s|es)?(?![a-z])',
    ).hasMatch(textoNormalizado);
  }

  /// ¿La receta (título + descripción) choca con los estilos o las alergias?
  static bool recetaCompatible(
    String texto,
    List<String> estilosSel, {
    String alergias = '',
  }) {
    final t = ' ${_sinAcentos(texto)} ';
    for (final estilo in estilosSel) {
      final prohibidas = palabrasExcluidas[estilo];
      if (prohibidas == null) continue;
      for (final p in prohibidas) {
        if (_contienePalabra(t, p)) return false;
      }
    }
    for (final termino in terminosAlergias(alergias)) {
      if (_contienePalabra(t, termino)) return false;
    }
    return true;
  }

  /// Calcula dinámicamente los sellos nutricionales y semáforo dietético de una receta
  static List<SelloNutricional> calcularSellosNutricionales({
    required int calorias,
    required int proteinas,
    required int carbs,
    required int grasas,
    String? titulo,
  }) {
    final List<SelloNutricional> sellos = [];

    // 1. Alto en Proteína (> 25g)
    if (proteinas >= 25) {
      sellos.add(const SelloNutricional(
        etiqueta: 'Alto en Proteína',
        emoji: '🥩',
        colorTexto: Color(0xFFC62828),
        colorFondo: Color(0xFFFFEBEE),
        descripcionCorta: 'Aporta más de 25g de proteína magra',
      ));
    }

    // 2. Keto / Low-Carb (carbs <= 12g)
    if (carbs > 0 && carbs <= 12) {
      sellos.add(const SelloNutricional(
        etiqueta: 'Keto / Low-Carb',
        emoji: '🥑',
        colorTexto: Color(0xFF2E7D32),
        colorFondo: Color(0xFFE8F5E9),
        descripcionCorta: 'Máximo 12g de carbohidratos netos',
      ));
    }

    // 3. Bajo en Calorías (<= 350 kcal)
    if (calorias > 0 && calorias <= 350) {
      sellos.add(const SelloNutricional(
        etiqueta: 'Ligero / Déficit',
        emoji: '🥗',
        colorTexto: Color(0xFF00695C),
        colorFondo: Color(0xFFE0F2F1),
        descripcionCorta: 'Menos de 350 kcal por porción',
      ));
    }

    // 4. Bajo en Grasa (<= 10g)
    if (grasas > 0 && grasas <= 10) {
      sellos.add(const SelloNutricional(
        etiqueta: 'Bajo en Grasa',
        emoji: '⚡',
        colorTexto: Color(0xFFE65100),
        colorFondo: Color(0xFFFFF3E0),
        descripcionCorta: 'Menos de 10g de grasa por porción',
      ));
    }

    // 5. Apto Diabéticos (carbs <= 20g y bajo impacto calórico)
    if (carbs > 0 && carbs <= 20 && calorias <= 450) {
      sellos.add(const SelloNutricional(
        etiqueta: 'Apto Diabéticos',
        emoji: '🩺',
        colorTexto: Color(0xFF1565C0),
        colorFondo: Color(0xFFE3F2FD),
        descripcionCorta: 'Índice glucémico controlado y bajo impacto de glucosa',
      ));
    }

    return sellos;
  }
}
