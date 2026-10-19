import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'config_api.dart';

/// Etapa o bloque de 30 minutos del Batch Cooking Dominical
class EtapaBatchCooking {
  final int bloqueNumero;
  final String tiempoEstimado;
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final List<String> tareas;
  final List<String> tips;

  const EtapaBatchCooking({
    required this.bloqueNumero,
    required this.tiempoEstimado,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.tareas,
    required this.tips,
  });
}

/// Guía completa estructurada para preparar en bloque la comida de la semana
class GuiaBatchCookingSemanal {
  final int totalPlatillos;
  final List<String> platillosPlaneados;
  final Map<String, List<String>> categoriasIngredientes;
  final List<EtapaBatchCooking> etapas;
  final List<String> reglasConservacion;
  final DateTime fechaGeneracion;

  const GuiaBatchCookingSemanal({
    required this.totalPlatillos,
    required this.platillosPlaneados,
    required this.categoriasIngredientes,
    required this.etapas,
    required this.reglasConservacion,
    required this.fechaGeneracion,
  });

  /// Formatea la guía en texto listo para compartir por WhatsApp
  String formatearParaCompartir() {
    final buffer = StringBuffer();
    buffer.writeln('🍱 *GUÍA DE BATCH COOKING & PREP DAY (2 HORAS)* 👨‍🍳🔥');
    buffer.writeln('App: *Jitomate y Cebolla* (www.jitomateycebolla.com)');
    buffer.writeln('Platillos cubiertos: $totalPlatillos comidas de la semana');
    buffer.writeln('────────────────────────');
    if (platillosPlaneados.isNotEmpty) {
      buffer.writeln('📋 *Menú Agendado:*');
      for (var p in platillosPlaneados.take(6)) {
        buffer.writeln('  • $p');
      }
      if (platillosPlaneados.length > 6) {
        buffer.writeln('  • ... y ${platillosPlaneados.length - 6} más.');
      }
      buffer.writeln('────────────────────────');
    }

    for (var etapa in etapas) {
      buffer.writeln('⏰ *${etapa.tiempoEstimado} | ${etapa.titulo}*');
      for (var t in etapa.tareas) {
        buffer.writeln('  ☑️ $t');
      }
      if (etapa.tips.isNotEmpty) {
        buffer.writeln('  💡 _Tip: ${etapa.tips.first}_');
      }
      buffer.writeln('');
    }

    buffer.writeln('────────────────────────');
    buffer.writeln('❄️ *Reglas de Conservación:*');
    for (var r in reglasConservacion.take(3)) {
      buffer.writeln('  📌 $r');
    }
    buffer.writeln('────────────────────────');
    buffer.writeln('💪 _"Dedicar 2 horas el domingo te regala paz mental, dinero y salud de lunes a viernes."_');
    return buffer.toString();
  }
}

/// Servicio inteligente de Batch Cooking & Meal Prep
class ServicioBatchCooking {
  ServicioBatchCooking._();

  static const List<String> _palabrasBases = [
    'arroz', 'frijol', 'frijoles', 'lenteja', 'lentejas', 'pasta', 'quinoa',
    'papa', 'papas', 'camote', 'avena', 'garbanzo', 'garbanzos', 'tortilla',
  ];

  static const List<String> _palabrasVerduras = [
    'calabacita', 'calabaza', 'zanahoria', 'cebolla', 'jitomate', 'tomate',
    'pimiento', 'brocoli', 'brócoli', 'coliflor', 'champiñon', 'champiñones',
    'espinaca', 'lechuga', 'pepino', 'chayote', 'ejote', 'ejotes', 'apio',
  ];

  static const List<String> _palabrasProteinas = [
    'pollo', 'pechuga', 'carne', 'res', 'bistec', 'molida', 'atun', 'atún',
    'pescado', 'salmon', 'salmón', 'huevo', 'huevos', 'tofu', 'queso',
    'pavo', 'camaron', 'camarones', 'lomo', 'cerdo',
  ];

  static const List<String> _palabrasSalsas = [
    'salsa', 'aderezo', 'vinagreta', 'crema', 'pesto', 'guacamole',
    'mayonesa', 'chile', 'chiles', 'adobo', 'marinada',
  ];

  /// Genera una guía determinista optimizada a partir del plan semanal del usuario
  static GuiaBatchCookingSemanal generarGuiaDesdePlan(List<dynamic> planSemanal) {
    final List<String> titulos = [];
    final Set<String> bases = {};
    final Set<String> verduras = {};
    final Set<String> proteinas = {};
    final Set<String> salsas = {};

    for (var item in planSemanal) {
      final receta = item['recetas'] as Map<String, dynamic>? ?? {};
      final String titulo = (receta['titulo'] ?? '').toString().trim();
      final String desc = (receta['descripcion'] ?? '').toString().toLowerCase();
      final String textoCompleto = '$titulo $desc'.toLowerCase();

      if (titulo.isNotEmpty && !titulos.contains(titulo)) {
        titulos.add(titulo);
      }

      for (var p in _palabrasBases) {
        if (textoCompleto.contains(p)) bases.add(p);
      }
      for (var p in _palabrasVerduras) {
        if (textoCompleto.contains(p)) verduras.add(p);
      }
      for (var p in _palabrasProteinas) {
        if (textoCompleto.contains(p)) proteinas.add(p);
      }
      for (var p in _palabrasSalsas) {
        if (textoCompleto.contains(p)) salsas.add(p);
      }
    }

    final String basesTexto = bases.isNotEmpty ? bases.take(3).join(', ') : 'Arroz integral y frijoles de la olla';
    final String verdurasTexto = verduras.isNotEmpty ? verduras.take(4).join(', ') : 'Calabacitas, zanahoria, cebolla y pimientos';
    final String proteinasTexto = proteinas.isNotEmpty ? proteinas.take(3).join(', ') : 'Pechuga de pollo y carne magra';
    final String salsasTexto = salsas.isNotEmpty ? salsas.take(2).join(', ') : 'Salsa verde asada y vinagreta clásica';

    final etapas = [
      EtapaBatchCooking(
        bloqueNumero: 1,
        tiempoEstimado: 'Min 0 - 30',
        titulo: 'Horno, Granos & Bases Calientes 🔥',
        subtitulo: 'Aprovecha el calor simultáneo del horno y la estufa',
        icono: Icons.outdoor_grill_outlined,
        color: const Color(0xFFD84315), // Deep Orange
        tareas: [
          'Precalienta el horno a 200°C y prepara 2 charolas grandes con papel encerado o silicón.',
          'Pon a hervir el agua para tus bases ($basesTexto). Déjalas cociendo a fuego medio-bajo tapadas.',
          'Lava, seca y corta las verduras duras ($verdurasTexto) en cubos homogéneos.',
          'Coloca las verduras en la charola, rocía con aceite de oliva, sal, pimienta y ajo en polvo. ¡Al horno por 25 min!',
        ],
        tips: [
          'Cortar los vegetales del mismo tamaño garantiza que se doren parejos sin quemarse.',
          'Si cocinas legumbres secas, remojarlas desde la noche anterior reduce el tiempo de cocción a la mitad.',
        ],
      ),
      EtapaBatchCooking(
        bloqueNumero: 2,
        tiempoEstimado: 'Min 30 - 60',
        titulo: 'Proteínas & Marinados Express 🥩🍗',
        subtitulo: 'Cocina proteínas jugosas que soporten el recalentado',
        icono: Icons.kebab_dining_outlined,
        color: const Color(0xFFC2185B), // Ruby / Magenta
        tareas: [
          'Porciona tus proteínas principales ($proteinasTexto) en tiras, fajitas o filetes de grosor uniforme.',
          'Prepara un marinado rápido: limón, aceite de oliva, orégano, mostaza dijon y un toque de sal.',
          'Sella las proteínas en sartén antiadherente bien caliente de 3 a 4 minutos por lado.',
          'Retíralas a término 3/4 o justo al punto. Al recalentarlas durante la semana no quedarán resecas.',
        ],
        tips: [
          'Seca la carne o pollo con una toalla de papel antes de ponerla en el sartén para lograr un dorado perfecto.',
          'Deja reposar las proteínas 5 minutos en una tabla antes de rebanarlas para que los jugos se redistribuyan.',
        ],
      ),
      EtapaBatchCooking(
        bloqueNumero: 3,
        tiempoEstimado: 'Min 60 - 90',
        titulo: 'Salsas Base, Aderezos & Aliños 🥗🥣',
        subtitulo: 'El secreto del sabor fresco que no aburre en la semana',
        icono: Icons.blender_outlined,
        color: const Color(0xFF00897B), // Teal esmeralda
        tareas: [
          'Asa o hierve jitomates, cebolla y chiles para tu salsa comodín ($salsasTexto). Licúa con sal y ajo.',
          'Prepara un frasco de vinagreta madre (3 partes de aceite de oliva por 1 de vinagre/limón). Guarda emulsionada.',
          'Lava y desinfecta lechugas y hierbas frescas (cilantro, perejil). Sécalas al 100% con toallas de papel.',
          'Pica guarniciones crujientes en crudo (pepino, apio, rábanos) para acompañar tus platos al momento.',
        ],
        tips: [
          'Guarda las hojas verdes en un tupper con una servilleta absorbente en el fondo; durarán crujientes hasta 7 días.',
          'NUNCA mezcles el aderezo con la ensalada en el tupper. Adereza siempre 1 minuto antes de comer.',
        ],
      ),
      EtapaBatchCooking(
        bloqueNumero: 4,
        tiempoEstimado: 'Min 90 - 120',
        titulo: 'Porcionado, Enfriado & Etiquetado 🍱🏷️',
        subtitulo: 'Distribuye en recipientes herméticos y rotula los días',
        icono: Icons.inventory_2_outlined,
        color: const Color(0xFF1565C0), // Blue
        tareas: [
          'Deja que todos los alimentos cocinados pierdan el vapor caliente antes de taparlos (evita la condensación agria).',
          'Distribuye en tuppers herméticos de vidrio o plástico libre de BPA: Base + Proteína + Verdura asada.',
          'Regla de asignación: Lunes, Martes y Miércoles van directo al refrigerador (a 4°C o menos).',
          'Jueves y Viernes van etiquetados con fecha al congelador (-18°C) para mantener su frescura intacta.',
          'Limpieza rápida de tablas, sartenes y mesada con agua tibia y jabón. ¡Semana resuelta!',
        ],
        tips: [
          'Tapar comida aún hirviendo genera vapor que acidifica los alimentos y acelera su descomposición.',
          'Baja la porción del congelador al refrigerador la noche anterior para que se descongele despacio y conserve textura.',
        ],
      ),
    ];

    final reglas = [
      'Regla de los 3-4 días: Todo alimento cocinado en refrigeración debe consumirse en máximo 4 días.',
      'Cadena de frío: Mantén tu refrigerador entre 2°C y 4°C. Evita abrir la puerta innecesariamente.',
      'Recalentado único: Recalienta únicamente la porción que vas a comer a más de 74°C. No vuelvas a guardar sobras recalentadas.',
      'Humedad cero en ensaladas: El agua residual es el enemigo número uno de la lechuga y espinaca.',
    ];

    return GuiaBatchCookingSemanal(
      totalPlatillos: titulos.isNotEmpty ? titulos.length : 7,
      platillosPlaneados: titulos,
      categoriasIngredientes: {
        'Bases': bases.toList(),
        'Verduras': verduras.toList(),
        'Proteínas': proteinas.toList(),
        'Salsas': salsas.toList(),
      },
      etapas: etapas,
      reglasConservacion: reglas,
      fechaGeneracion: DateTime.now(),
    );
  }

  /// Genera una guía hiperpersonalizada con Gemini IA si el usuario desea asistencia en vivo
  static Future<GuiaBatchCookingSemanal> generarGuiaConIA({
    required List<dynamic> planSemanal,
    required String objetivo,
  }) async {
    final baseLocal = generarGuiaDesdePlan(planSemanal);

    try {
      final model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: ConfigApi.geminiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.6,
        ),
      );

      final platillosTexto = baseLocal.platillosPlaneados.isNotEmpty
          ? baseLocal.platillosPlaneados.join(', ')
          : 'Comidas caseras saludables';

      final prompt = '''
      Eres un Chef Ejecutivo experto en Batch Cooking y Meal Prep inteligente.
      El usuario va a cocinar durante 2 HORAS el domingo para cubrir estos platillos agendados:
      $platillosTexto
      Objetivo nutricional: $objetivo

      Diseña la guía exacta de 4 bloques de 30 minutos:
      - Bloque 1 (Min 0-30): Horno y granos/almidones base
      - Bloque 2 (Min 30-60): Proteínas y marinados
      - Bloque 3 (Min 60-90): Salsas, aliños y ensaladas en frío
      - Bloque 4 (Min 90-120): Porcionado, enfriamiento, empaque y etiquetado

      Responde ÚNICAMENTE con un JSON con esta estructura exacta:
      {
        "etapas": [
          {
            "bloqueNumero": 1,
            "tiempoEstimado": "Min 0 - 30",
            "titulo": "Título atractivo",
            "subtitulo": "Subtítulo explicativo",
            "tareas": ["Tarea 1", "Tarea 2", "Tarea 3", "Tarea 4"],
            "tips": ["Tip 1", "Tip 2"]
          },
          {
            "bloqueNumero": 2,
            "tiempoEstimado": "Min 30 - 60",
            "titulo": "Título atractivo",
            "subtitulo": "Subtítulo explicativo",
            "tareas": ["Tarea 1", "Tarea 2", "Tarea 3", "Tarea 4"],
            "tips": ["Tip 1"]
          },
          {
            "bloqueNumero": 3,
            "tiempoEstimado": "Min 60 - 90",
            "titulo": "Título atractivo",
            "subtitulo": "Subtítulo explicativo",
            "tareas": ["Tarea 1", "Tarea 2", "Tarea 3", "Tarea 4"],
            "tips": ["Tip 1"]
          },
          {
            "bloqueNumero": 4,
            "tiempoEstimado": "Min 90 - 120",
            "titulo": "Título atractivo",
            "subtitulo": "Subtítulo explicativo",
            "tareas": ["Tarea 1", "Tarea 2", "Tarea 3", "Tarea 4"],
            "tips": ["Tip 1"]
          }
        ],
        "reglasConservacion": [
          "Regla 1",
          "Regla 2",
          "Regla 3"
        ]
      }
      ''';

      final res = await model.generateContent([Content.text(prompt)]);
      final raw = (res.text ?? '').replaceAll('```json', '').replaceAll('```', '').trim();
      final data = jsonDecode(raw) as Map<String, dynamic>;

      final rawEtapas = (data['etapas'] as List? ?? []);
      if (rawEtapas.length == 4) {
        final List<EtapaBatchCooking> etapasIA = [];
        final colores = [
          const Color(0xFFD84315),
          const Color(0xFFC2185B),
          const Color(0xFF00897B),
          const Color(0xFF1565C0),
        ];
        final iconos = [
          Icons.outdoor_grill_outlined,
          Icons.kebab_dining_outlined,
          Icons.blender_outlined,
          Icons.inventory_2_outlined,
        ];

        for (int i = 0; i < 4; i++) {
          final e = rawEtapas[i] as Map<String, dynamic>;
          etapasIA.add(EtapaBatchCooking(
            bloqueNumero: i + 1,
            tiempoEstimado: e['tiempoEstimado']?.toString() ?? baseLocal.etapas[i].tiempoEstimado,
            titulo: e['titulo']?.toString() ?? baseLocal.etapas[i].titulo,
            subtitulo: e['subtitulo']?.toString() ?? baseLocal.etapas[i].subtitulo,
            icono: iconos[i],
            color: colores[i],
            tareas: (e['tareas'] as List? ?? []).map((t) => t.toString()).toList(),
            tips: (e['tips'] as List? ?? []).map((t) => t.toString()).toList(),
          ));
        }

        final rawReglas = (data['reglasConservacion'] as List? ?? [])
            .map((r) => r.toString())
            .toList();

        return GuiaBatchCookingSemanal(
          totalPlatillos: baseLocal.totalPlatillos,
          platillosPlaneados: baseLocal.platillosPlaneados,
          categoriasIngredientes: baseLocal.categoriasIngredientes,
          etapas: etapasIA,
          reglasConservacion: rawReglas.isNotEmpty ? rawReglas : baseLocal.reglasConservacion,
          fechaGeneracion: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('ℹ️ Generación IA de Batch Cooking tuvo fallback local: $e');
    }

    return baseLocal;
  }
}
