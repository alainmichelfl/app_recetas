import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import 'config_api.dart';

/// Item de compra al mayoreo o club inteligente para Batch Cooking (Prioridad 27)
class ItemMayoreoBatchCooking {
  final String nombreIngrediente;
  final String categoria;
  final String presentacionMenudeo;
  final String presentacionMayoreo;
  final String tiendaRecomendada;
  final double ahorroPorcentual;
  final String tipConservacion;

  const ItemMayoreoBatchCooking({
    required this.nombreIngrediente,
    required this.categoria,
    required this.presentacionMenudeo,
    required this.presentacionMayoreo,
    required this.tiendaRecomendada,
    required this.ahorroPorcentual,
    required this.tipConservacion,
  });
}

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

  // =========================================================================
  // 🥫 COMPRA AL MAYOREO INTELIGENTE PARA BATCH COOKING (PRIORIDAD 27)
  // =========================================================================

  /// Consolida los ingredientes de la semana en presentaciones de Club / Mayoreo
  static List<ItemMayoreoBatchCooking> generarListaMayoreo(GuiaBatchCookingSemanal guia) {
    final List<ItemMayoreoBatchCooking> items = [];

    // 1. Carnes y Aves
    items.add(const ItemMayoreoBatchCooking(
      nombreIngrediente: 'Pechuga de Pollo sin hueso ni piel',
      categoria: 'Carnes & Aves',
      presentacionMenudeo: 'Charola súper 800 g (~2 platillos)',
      presentacionMayoreo: 'Charola Familiar Club 2.5 kg - 3 kg',
      tiendaRecomendada: 'Costco / Sam\'s Club / Pollería Mayoreo',
      ahorroPorcentual: 28.0,
      tipConservacion: 'Porcionar en bolsas herméticas (2 pechugas c/u); congela lo de jueves y viernes.',
    ));

    items.add(const ItemMayoreoBatchCooking(
      nombreIngrediente: 'Carne Molida de Res (90/10)',
      categoria: 'Carnes & Aves',
      presentacionMenudeo: 'Bandejita 500 g (\$180/kg súper)',
      presentacionMayoreo: 'Paquete Club 1.8 kg - 2.2 kg (\$135/kg)',
      tiendaRecomendada: 'Costco / Sam\'s Club',
      ahorroPorcentual: 25.0,
      tipConservacion: 'Guisar toda la carne el domingo (ej. picadillo o boloñesa) y congelar en 2 tuppers.',
    ));

    // 2. Proteína Económica / Desayunos
    items.add(const ItemMayoreoBatchCooking(
      nombreIngrediente: 'Huevo Blanco o Rojo Fresco',
      categoria: 'Lácteos & Huevos',
      presentacionMenudeo: 'Domo súper de 12 piezas (\$48 MXN)',
      presentacionMayoreo: 'Cartera de 30 piezas (\$82 MXN)',
      tiendaRecomendada: 'Central de Abasto / Cremería de Mayoreo',
      ahorroPorcentual: 32.0,
      tipConservacion: 'Mantener en lugar fresco o refri sin lavar. Dura 3 semanas en perfecto estado.',
    ));

    // 3. Granos & Abarrotes
    items.add(const ItemMayoreoBatchCooking(
      nombreIngrediente: 'Arroz Integral o Blanco / Frijol',
      categoria: 'Granos & Alacena',
      presentacionMenudeo: 'Bolsitas de 900 g súper (\$38/kg)',
      presentacionMayoreo: 'Bolsa Club / Costalito 2.5 kg - 5 kg (\$24/kg)',
      tiendaRecomendada: 'Central de Abasto / Sam\'s Club',
      ahorroPorcentual: 36.0,
      tipConservacion: 'Guardar en frascos herméticos de vidrio con 1 hoja de laurel seca para evitar humedad.',
    ));

    items.add(const ItemMayoreoBatchCooking(
      nombreIngrediente: 'Avena en Hojuelas & Frutos Secos',
      categoria: 'Granos & Alacena',
      presentacionMenudeo: 'Bolsita de 400 g súper (\$45 MXN)',
      presentacionMayoreo: 'Bolsa Club 1.5 kg - 2 kg (\$95 MXN)',
      tiendaRecomendada: 'Costco / Central de Abasto',
      ahorroPorcentual: 40.0,
      tipConservacion: 'Almacenar en alacena oscura. Ideal para preparar 5 frascos de overnight oats el domingo.',
    ));

    // 4. Verduras & Salsas Base
    items.add(const ItemMayoreoBatchCooking(
      nombreIngrediente: 'Jitomate Saladet & Cebolla Blanca',
      categoria: 'Frutas & Verduras',
      presentacionMenudeo: 'Charolitas emplayadas 1 kg (\$44/kg súper)',
      presentacionMayoreo: 'Red o reja de 3 kg a 5 kg (\$20/kg)',
      tiendaRecomendada: 'Central de Abasto / Mercado sobre ruedas',
      ahorroPorcentual: 45.0,
      tipConservacion: 'Cocer y licuar el domingo para tener 2 litros de recaudo/salsa madre listos en refri.',
    ));

    items.add(const ItemMayoreoBatchCooking(
      nombreIngrediente: 'Aceite de Oliva Extra Virgen',
      categoria: 'Granos & Alacena',
      presentacionMenudeo: 'Botella de 500 ml (\$150 MXN)',
      presentacionMayoreo: 'Botella Doble / Galón 2 Litros (\$320 MXN)',
      tiendaRecomendada: 'Costco / Sam\'s Club',
      ahorroPorcentual: 30.0,
      tipConservacion: 'Guardar lejos del calor de la estufa para conservar antioxidantes.',
    ));

    return items;
  }

  /// Formatea la lista de compra al mayoreo en texto para WhatsApp o portapapeles
  static String formatearListaMayoreoParaCompartir(List<ItemMayoreoBatchCooking> items) {
    final buffer = StringBuffer();
    buffer.writeln('🥫 *LISTA DE COMPRA AL MAYOREO & CLUB (BATCH COOKING)* 🛒✨');
    buffer.writeln('App: *Jitomate y Cebolla* (www.jitomateycebolla.com)');
    buffer.writeln('Ahorro estimado: *~32% vs comprar al menudeo en el súper*');
    buffer.writeln('────────────────────────');

    String catActual = '';
    for (var item in items) {
      if (item.categoria != catActual) {
        catActual = item.categoria;
        buffer.writeln('\n📦 *${catActual.toUpperCase()}*');
      }
      buffer.writeln('• *${item.nombreIngrediente}*');
      buffer.writeln('  ▫️ Mayoreo: ${item.presentacionMayoreo}');
      buffer.writeln('  ▫️ Dónde: ${item.tiendaRecomendada} (Ahorro: ~${item.ahorroPorcentual.toInt()}%)');
      buffer.writeln('  💡 _Tip: ${item.tipConservacion}_');
    }

    buffer.writeln('\n────────────────────────');
    buffer.writeln('💪 _"Comprar en bloque para tu Batch Cooking ahorra horas en la cocina y miles de pesos al mes."_');
    return buffer.toString();
  }
}
