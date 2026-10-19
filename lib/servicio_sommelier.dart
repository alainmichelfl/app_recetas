import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config_api.dart';

/// Modelo que encapsula las tres vertientes del maridaje gastronómico:
/// Vino de autor, Cóctel / Destilado y Mocktail artesanal (sin alcohol).
class MaridajeReceta {
  final String vino;
  final String destilado;
  final String sinAlcohol;
  final String notasArmonia;
  final String temperaturaServicio;
  final String tipoCopa;
  final String categoriaPerfil;
  final List<String> ingredientesBebida;

  const MaridajeReceta({
    required this.vino,
    required this.destilado,
    required this.sinAlcohol,
    required this.notasArmonia,
    required this.temperaturaServicio,
    required this.tipoCopa,
    required this.categoriaPerfil,
    required this.ingredientesBebida,
  });

  Map<String, dynamic> toMap() => {
        'vino': vino,
        'destilado': destilado,
        'sinAlcohol': sinAlcohol,
        'notasArmonia': notasArmonia,
        'temperaturaServicio': temperaturaServicio,
        'tipoCopa': tipoCopa,
        'categoriaPerfil': categoriaPerfil,
        'ingredientesBebida': ingredientesBebida,
      };

  factory MaridajeReceta.fromMap(Map<String, dynamic> map) {
    return MaridajeReceta(
      vino: map['vino']?.toString() ?? '',
      destilado: map['destilado']?.toString() ?? '',
      sinAlcohol: map['sinAlcohol']?.toString() ?? '',
      notasArmonia: map['notasArmonia']?.toString() ?? '',
      temperaturaServicio: map['temperaturaServicio']?.toString() ?? 'Fresco',
      tipoCopa: map['tipoCopa']?.toString() ?? 'Copa estándar',
      categoriaPerfil: map['categoriaPerfil']?.toString() ?? 'General',
      ingredientesBebida: (map['ingredientesBebida'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  String resumenParaCompartir(String tituloReceta) {
    final sb = StringBuffer();
    sb.writeln('🍷 *Maridaje de Sommelier para: $tituloReceta*');
    sb.writeln('🍇 *Vino:* $vino');
    sb.writeln('🥃 *Destilado / Cóctel:* $destilado');
    sb.writeln('🍹 *Sin Alcohol:* $sinAlcohol');
    sb.writeln('🎯 *Armonía:* $notasArmonia');
    sb.writeln('❄️ *Temperatura:* $temperaturaServicio | 🥂 *Copa:* $tipoCopa');
    sb.writeln('\n_Jitomate y Cebolla · Cava & Sommelier Virtual_ 🍅🧅');
    return sb.toString();
  }
}

/// Servicio inteligente de Sommelier y Cava Virtual.
/// Combina un motor heurístico gastronómico instantáneo (funciona offline)
/// con la potencia de Gemini IA para recomendaciones de alta gama personalizadas.
class ServicioSommelier {
  ServicioSommelier._();

  static String _normalizarTexto(String s) {
    const de = 'áàäâéèëêíìïîóòöôúùüûñ';
    const a = 'aaaaeeeeiiiioooouuuun';
    var r = s.toLowerCase();
    for (var i = 0; i < de.length; i++) {
      r = r.replaceAll(de[i], a[i]);
    }
    return r;
  }

  /// Generador heurístico instantáneo según proteínas, ingredientes clave y perfil de sabor.
  static MaridajeReceta generarMaridajeHeuristico(
    String titulo, {
    List<String> ingredientes = const [],
    String descripcion = '',
  }) {
    final corpus = _normalizarTexto(
      '$titulo ${ingredientes.join(" ")} $descripcion',
    );

    // 1. Mariscos y pescados
    if (corpus.contains('camaron') ||
        corpus.contains('pescado') ||
        corpus.contains('atun') ||
        corpus.contains('salmon') ||
        corpus.contains('pulpo') ||
        corpus.contains('marisco') ||
        corpus.contains('ceviche') ||
        corpus.contains('tilapia') ||
        corpus.contains('huachinango') ||
        corpus.contains('robalo') ||
        corpus.contains('almeja') ||
        corpus.contains('ostion')) {
      return const MaridajeReceta(
        categoriaPerfil: 'Mariscos & Pesca Fresca',
        vino:
            'Sauvignon Blanc fresco (Valle de Guadalupe) o Albariño (Rías Baixas) con alta acidez cítrica y notas de pasto verde.',
        destilado:
            'Gin & Tonic botánico con cáscara de pepino y limón verde, o Mezcal Espadín joven con rodaja de naranja.',
        sinAlcohol:
            'Mocktail cítrico de agua mineral espumosa, pepino machacado, menta fresca y un toque de limón real.',
        notasArmonia:
            'La frescura y acidez cortante del maridaje limpian la delicada grasa marina, elevando el yodo y las notas salinas sin opacar el platillo.',
        temperaturaServicio: '7°C a 9°C (Bien frío)',
        tipoCopa: 'Copa de vino blanco tulipa o vaso Collins alto',
        ingredientesBebida: [
          'Vino Sauvignon Blanc o Albariño',
          'Agua mineral con gas',
          'Pepino fresco',
          'Menta',
          'Limón real',
        ],
      );
    }

    // 2. Carnes rojas y cortes
    if (corpus.contains('rib eye') ||
        corpus.contains('arrachera') ||
        corpus.contains('picanha') ||
        corpus.contains('picana') ||
        corpus.contains('corte') ||
        corpus.contains('carne de res') ||
        corpus.contains('bistec') ||
        corpus.contains('costilla de res') ||
        corpus.contains('estofado') ||
        corpus.contains('birria') ||
        corpus.contains('suadero') ||
        corpus.contains('asado')) {
      return const MaridajeReceta(
        categoriaPerfil: 'Cortes & Carnes Rojas',
        vino:
            'Cabernet Sauvignon con paso por roble o Malbec Reserva con taninos redondos, cuerpo estructurado y notas a frutos negros y vainilla.',
        destilado:
            'Whisky Bourbon en las rocas con twist de naranja o Old Fashioned con amargo de Angostura.',
        sinAlcohol:
            'Cold Brew espumoso con agua tónica, rodaja de naranja deshidratada y ramita de romero ligeramente flameada.',
        notasArmonia:
            'Los taninos nobles y la corpulencia de la bebida disuelven la grasa intramuscular de la carne, limpiando el paladar a cada bocado.',
        temperaturaServicio: '16°C a 18°C (Temperatura cava)',
        tipoCopa: 'Copa Burdeos de cáliz amplio o vaso Old Fashioned',
        ingredientesBebida: [
          'Vino Cabernet Sauvignon o Malbec',
          'Café Cold Brew concentrado',
          'Agua tónica',
          'Naranja',
          'Romero fresco',
        ],
      );
    }

    // 3. Pastas y cocina italiana
    if (corpus.contains('pasta') ||
        corpus.contains('espagueti') ||
        corpus.contains('spaghetti') ||
        corpus.contains('lasana') ||
        corpus.contains('lasagna') ||
        corpus.contains('pizza') ||
        corpus.contains('fettuccine') ||
        corpus.contains('alfredo') ||
        corpus.contains('carbonara') ||
        corpus.contains('ravioles') ||
        corpus.contains('pesto') ||
        corpus.contains('parmesano')) {
      final esSalsaBlanca =
          corpus.contains('alfredo') ||
          corpus.contains('crema') ||
          corpus.contains('pesto');
      return MaridajeReceta(
        categoriaPerfil: 'Pastas & Cocina Italiana',
        vino: esSalsaBlanca
            ? 'Chardonnay con sutil barrica o Pinot Grigio italiano fresco y untuoso.'
            : 'Chianti Classico (Sangiovese) con acidez vivaz que dialoga a la perfección con la salsa de tomate.',
        destilado:
            'Aperol Spritz con Prosecco y rodaja de naranja, o Negroni clásico con vermut dulce.',
        sinAlcohol:
            'Spritzer de agua con gas con jarabe ligero de albahaca fresca y rodaja de limón amarillo.',
        notasArmonia:
            'La acidez equilibrada complementa las notas de hierbas mediterráneas, ajo y quesos maduros sin saturar la boca.',
        temperaturaServicio: esSalsaBlanca ? '10°C a 12°C' : '15°C a 17°C',
        tipoCopa: 'Copa de vino universal o copa de balón para Spritz',
        ingredientesBebida: [
          'Vino Sangiovese Chianti o Pinot Grigio',
          'Agua con gas San Pellegrino',
          'Albahaca fresca',
          'Limón amarillo',
        ],
      );
    }

    // 4. Cerdo y Carnitas
    if (corpus.contains('cerdo') ||
        corpus.contains('lomo') ||
        corpus.contains('chuleta') ||
        corpus.contains('costilla de cerdo') ||
        corpus.contains('carnitas') ||
        corpus.contains('pastor') ||
        corpus.contains('cochinita') ||
        corpus.contains('chicharron')) {
      return const MaridajeReceta(
        categoriaPerfil: 'Cerdo & Sabores Glaseados',
        vino:
            'Tempranillo joven, Zinfandel jugoso o un Cava Brut espumoso que rompa la riqueza de la carne.',
        destilado:
            'Mezcal artesanal con sal de chapulín o Mojito clásico con ron añejo y mucha hierbabuena.',
        sinAlcohol:
            'Tepache artesanal ligero de piña macerada con canela en rama y clavo de olor, servido con abundante hielo.',
        notasArmonia:
            'Las notas especiadas y el punto burbujeante o frutal cortan la riqueza de la grasa del cerdo y potencian los adobos.',
        temperaturaServicio: '12°C a 14°C',
        tipoCopa: 'Vaso veladora mezcalero o copa flauta',
        ingredientesBebida: [
          'Vino Tempranillo o Cava Brut',
          'Piña fresca',
          'Canela en rama',
          'Hierbabuena fresca',
        ],
      );
    }

    // 5. Cocina mexicana tradicional y salsas picantes
    if (corpus.contains('mole') ||
        corpus.contains('chile') ||
        corpus.contains('chiles') ||
        corpus.contains('enchilada') ||
        corpus.contains('chilaquiles') ||
        corpus.contains('taco') ||
        corpus.contains('pipian') ||
        corpus.contains('pozole') ||
        corpus.contains('adobo') ||
        corpus.contains('salsa verde') ||
        corpus.contains('salsa roja')) {
      return const MaridajeReceta(
        categoriaPerfil: 'Cocina Mexicana & Especias',
        vino:
            'Syrah de corte frutal, Rosado seco con cuerpo (Garnacha) o un Chenin Blanc fresco (el azúcar residual equilibra el picante).',
        destilado:
            'Tequila Blanco o Reposado 100% de agave con sangrita casera de jitomate y naranja agria.',
        sinAlcohol:
            'Agua fresca de flor de jamaica infusionada con frutos rojos macerados y un toque de anís estrella.',
        notasArmonia:
            'Un maridaje con notas florales y acidez amortigua la capsaicina de los chiles sin opacar la complejidad del recetario tradicional.',
        temperaturaServicio: '12°C a 14°C',
        tipoCopa: 'Copa de vino estándar o caballito tequilero de boca ancha',
        ingredientesBebida: [
          'Vino Rosado de Garnacha o Chenin Blanc',
          'Flor de Jamaica',
          'Frutos rojos',
          'Anís estrella',
        ],
      );
    }

    // 6. Pollo y Aves
    if (corpus.contains('pollo') ||
        corpus.contains('pechuga') ||
        corpus.contains('pavo') ||
        corpus.contains('milanesa de pollo') ||
        corpus.contains('tinga') ||
        corpus.contains('alitas')) {
      return const MaridajeReceta(
        categoriaPerfil: 'Aves & Cocina Blanca',
        vino:
            'Pinot Noir sutil con aromas a frutos del bosque o Chardonnay sin exceso de roble con frescura frutal.',
        destilado:
            'Paloma fresca preparada con Tequila Reposado, toronja natural y escarchado ligero de flor de sal.',
        sinAlcohol:
            'Té verde helado con infusión de durazno, jengibre fresco y hojas de menta.',
        notasArmonia:
            'La suavidad de la carne de ave requiere un maridaje delicado que respete sus notas ligeras y ensalce las hierbas de cocción.',
        temperaturaServicio: '11°C a 13°C',
        tipoCopa: 'Copa Borgoña o vaso Highball con hielo roca',
        ingredientesBebida: [
          'Vino Pinot Noir o Chardonnay',
          'Toronja fresca',
          'Té verde en hojas',
          'Jengibre fresco',
        ],
      );
    }

    // 7. Vegetariano, ensaladas y verduras
    if (corpus.contains('ensalada') ||
        corpus.contains('tofu') ||
        corpus.contains('quinoa') ||
        corpus.contains('espinaca') ||
        corpus.contains('champinon') ||
        corpus.contains('portobello') ||
        corpus.contains('lenteja') ||
        corpus.contains('calabacita') ||
        corpus.contains('aguacate')) {
      return const MaridajeReceta(
        categoriaPerfil: 'Huerto, Verde & Vegetal',
        vino:
            'Verdejo brillante (Rueda) o Sauvignon Blanc herbáceo con recuerdos a lima, manzana verde y pasto recién cortado.',
        destilado:
            'Gin floral con pepino, bayas de enebro y agua tónica ligera con bajo contenido de azúcar.',
        sinAlcohol:
            'Spritzer de manzana verde con albahaca machacada, jugo de uva verde espumoso y hielo frappé.',
        notasArmonia:
            'Las pirazinas y notas verdes naturales del vino hacen un espejo organoléptico perfecto con las hortalizas frescas y vinagretas.',
        temperaturaServicio: '8°C a 10°C (Fresco)',
        tipoCopa: 'Copa de vino blanco o copa balón',
        ingredientesBebida: [
          'Vino Verdejo o Sauvignon Blanc',
          'Manzana verde',
          'Albahaca fresca',
          'Agua tónica light',
        ],
      );
    }

    // 8. Desayunos y Brunch
    if (corpus.contains('huevo') ||
        corpus.contains('omelette') ||
        corpus.contains('hot cake') ||
        corpus.contains('waffle') ||
        corpus.contains('pan tostado') ||
        corpus.contains('avena') ||
        corpus.contains('desayuno')) {
      return const MaridajeReceta(
        categoriaPerfil: 'Brunch & Mañanas Gourmet',
        vino:
            'Mimosa de Prosecco italiano o Cava Brut con jugo recién exprimido de naranja valenciana.',
        destilado:
            'Bloody Mary clásico con vodka, clamato o jugo de tomate, salsa inglesa, toque de tabasco y tallo de apio.',
        sinAlcohol:
            'Infusión fría de frutos rojos silvestres con naranja sanguina, agua gasificada y hierbabuena.',
        notasArmonia:
            'Burbuja fina y acidez matutina que despiertan el paladar, aligerando el huevo y la mantequilla del desayuno.',
        temperaturaServicio: '6°C a 8°C (Muy frío)',
        tipoCopa: 'Copa flauta o copa de coctel alta',
        ingredientesBebida: [
          'Vino Espumoso Prosecco o Cava',
          'Naranjas dulces',
          'Frutos rojos frescos',
          'Apio fresco',
        ],
      );
    }

    // 9. Postres y dulces
    if (corpus.contains('chocolate') ||
        corpus.contains('pastel') ||
        corpus.contains('galleta') ||
        corpus.contains('pay') ||
        corpus.contains('helado') ||
        corpus.contains('flan') ||
        corpus.contains('vainilla') ||
        corpus.contains('cheesecake') ||
        corpus.contains('brownie') ||
        corpus.contains('postre')) {
      return const MaridajeReceta(
        categoriaPerfil: 'Postres & Dulzuras',
        vino:
            'Oporto Tawny, Pedro Ximénez o un Moscato d’Asti italiano con sutil aguja y dulzor frutal aromático.',
        destilado:
            'Carajillo shakeado con Licor 43 y shot de espresso caliente recién extraído, o Baileys sobre esfera de hielo.',
        sinAlcohol:
            'Chocolate artesanal oaxaqueño a la canela preparado en agua o leche ligera, o Espresso descafeinado frappé con cardamomo.',
        notasArmonia:
            'Regla de oro de pastelería: el maridaje debe acompañar el dulzor del postre para que no resulte astringente ni áspero.',
        temperaturaServicio: '10°C a 12°C',
        tipoCopa: 'Copa de licor pequeña o vaso corto para Carajillo',
        ingredientesBebida: [
          'Vino Oporto o Moscato d’Asti',
          'Licor 43 o Café Espresso',
          'Chocolate oaxaqueño',
          'Canela molida',
        ],
      );
    }

    // 10. Fallback armonía general
    return const MaridajeReceta(
      categoriaPerfil: 'Armonía Gastronómica Equilibrada',
      vino:
          'Tempranillo Crianza versátil o Vino Rosado seco que acompaña amablemente preparaciones balanceadas.',
      destilado:
          'Spritz aromático con vermut blanco, hielo roca y cáscara de naranja.',
      sinAlcohol:
          'Limonada con jengibre rallado, hojas de menta y agua mineral gasificada.',
      notasArmonia:
          'Perfil armónico y universal diseñado para refrescar y realzar los condimentos sin imponerse al plato.',
      temperaturaServicio: '11°C a 13°C',
      tipoCopa: 'Copa de vino universal',
      ingredientesBebida: [
        'Vino Tempranillo o Rosado',
        'Limón verde',
        'Menta fresca',
        'Jengibre fresco',
      ],
    );
  }

  /// Consulta al Sommelier IA con Gemini para una recomendación bespoke y personalizada.
  /// Si falla la red o la cuota, recurre inmediatamente al motor heurístico sin bloquear la UI.
  static Future<MaridajeReceta> consultarSommelierIA({
    required String titulo,
    required List<String> ingredientes,
    String? descripcion,
  }) async {
    final heuristico = generarMaridajeHeuristico(
      titulo,
      ingredientes: ingredientes,
      descripcion: descripcion ?? '',
    );

    if (ConfigApi.geminiKey.trim().isEmpty) {
      return heuristico;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: ConfigApi.geminiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.5,
        ),
      );

      final prompt = '''
Eres un Master Sommelier y Mixólogo de renombre internacional en la app culinaria "Jitomate y Cebolla".
Tu tarea es proponer el maridaje perfecto para esta receta:
- Platillo: "$titulo"
- Ingredientes: ${ingredientes.take(15).join(', ')}
${descripcion != null && descripcion.isNotEmpty ? "- Descripción: $descripcion" : ""}

Debes responder ÚNICAMENTE con un objeto JSON válido con esta estructura exacta:
{
  "categoriaPerfil": "Nombre breve del perfil culinario (ej. Mariscos Cítricos, Cortes de Res)",
  "vino": "Recomendación precisa de vino (cepa, región sugerida, notas organolépticas)",
  "destilado": "Coctel o destilado artesanal afín (ej. Mezcal, Tequila, Gin, Bourbon con preparación)",
  "sinAlcohol": "Mocktail artesanal sin alcohol sofisticado y realista para preparar en casa",
  "notasArmonia": "Explicación culinaria concisa de por qué armoniza (grasa, acidez, taninos, umami o dulzor)",
  "temperaturaServicio": "Temperatura ideal (ej. 8°C a 10°C)",
  "tipoCopa": "Tipo de copa o vaso recomendado",
  "ingredientesBebida": ["Ingrediente 1 para comprar", "Ingrediente 2"]
}
No incluyas markdown ni texto fuera del JSON.
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final rawText = response.text;
      if (rawText == null || rawText.trim().isEmpty) return heuristico;

      final limpio = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> data = jsonDecode(limpio);
      return MaridajeReceta.fromMap(data);
    } catch (e) {
      debugPrint('Aviso: Sommelier IA recurrió al motor heurístico ($e)');
      return heuristico;
    }
  }

  /// Identifica si un nombre de insumo corresponde a la Cava / Bar en Casa.
  static bool esItemDeCava(String nombre) {
    final n = _normalizarTexto(nombre);

    // Evitar falsos positivos de alimentos comunes con la palabra blanco/tinto
    if (n.contains('arroz') ||
        n.contains('queso') ||
        n.contains('pan ') ||
        n.contains('huevo') ||
        n.contains('vinagre') ||
        n.contains('chocolate') ||
        n.contains('frijol') ||
        n.contains('cebolla') ||
        n.contains('atun') ||
        n.contains('pescado') ||
        n.contains('salsa')) {
      return false;
    }

    const palabrasCava = [
      'vino',
      'tinto',
      'blanco',
      'rosado',
      'espumoso',
      'cava',
      'prosecco',
      'champagne',
      'mezcal',
      'tequila',
      'whisky',
      'whiskey',
      'bourbon',
      'ron',
      'vodka',
      'gin',
      'ginebra',
      'cerveza',
      'licor',
      'vermut',
      'vermouth',
      'aperol',
      'campari',
      'amaretto',
      'brandy',
      'cognac',
      'tonica',
      'tónica',
      'angostura',
      'curaçao',
      'triple sec',
      'baileys',
      'kahlua',
    ];
    for (final p in palabrasCava) {
      if (RegExp('(?<![a-z])${RegExp.escape(p)}(s|es)?(?![a-z])').hasMatch(n)) {
        return true;
      }
    }
    return false;
  }

  /// Consulta qué botellas o bebidas tiene el usuario registradas en su Despensa.
  static Future<List<String>> obtenerBotellasEnDespensa() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      var query = Supabase.instance.client
          .from('despensa_usuario')
          .select('nombre, cantidad');
      if (user != null) {
        query = query.eq('user_id', user.id);
      }
      final data = await query;
      final List<String> botellas = [];
      for (final item in data) {
        final nombre = (item['nombre'] ?? '').toString();
        if (esItemDeCava(nombre)) {
          botellas.add(nombre);
        }
      }
      return botellas;
    } catch (e) {
      debugPrint('Error al consultar botellas en despensa: $e');
      return [];
    }
  }

  /// Consulta interactiva libre en vivo con el Sommelier IA (Gemini).
  static Future<RespuestaSommelierEnVivo> consultarSommelierEnVivo({
    required String consulta,
    List<String>? botellasEnCava,
  }) async {
    if (ConfigApi.geminiKey.trim().isEmpty) {
      final heuristico = generarMaridajeHeuristico(consulta);
      return RespuestaSommelierEnVivo(
        mensaje:
            '¡Excelente elección culinaria! Para esta preparación te recomiendo un maridaje balanceado.',
        maridaje: heuristico,
      );
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: ConfigApi.geminiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.6,
        ),
      );

      final cavaInfo = (botellasEnCava != null && botellasEnCava.isNotEmpty)
          ? '- Botellas y bebidas que el usuario tiene disponibles en su cava de casa: ${botellasEnCava.join(", ")}. Si alguna combina bien, ¡priorízala!'
          : '';

      final prompt = '''
Eres un Master Sommelier y Mixólogo de talla mundial en la app culinaria "Jitomate y Cebolla".
El usuario te está haciendo una consulta en vivo mientras cocina, planifica una cena o busca con qué maridar:
"$consulta"

$cavaInfo

Responde ÚNICAMENTE con un JSON válido con esta estructura:
{
  "mensaje": "Respuesta cálida, profesional y concisa (máximo 3 párrafos cortos) con recomendaciones claras, consejos de cata o servicio.",
  "vino": "Nombre preciso de vino y cepa recomendada",
  "destilado": "Coctel o destilado afín sugerido",
  "sinAlcohol": "Mocktail artesanal 0.0% alcohol para acompañar",
  "notasArmonia": "Por qué armoniza (equilibrio de grasa, acidez, picor o dulzor)",
  "temperaturaServicio": "Temperatura ideal (ej. 8°C a 10°C)",
  "tipoCopa": "Tipo de copa o cristalería",
  "categoriaPerfil": "Perfil gastronómico",
  "ingredientesBebida": ["Ingrediente 1", "Ingrediente 2"]
}
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final rawText = response.text;
      if (rawText == null || rawText.trim().isEmpty) {
        final fallback = generarMaridajeHeuristico(consulta);
        return RespuestaSommelierEnVivo(
          mensaje:
              'Aquí tienes una recomendación armonizada para elevar tu experiencia gastronómica.',
          maridaje: fallback,
        );
      }

      final limpio = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      final Map<String, dynamic> data = jsonDecode(limpio);
      final maridaje = MaridajeReceta.fromMap(data);
      return RespuestaSommelierEnVivo(
        mensaje: data['mensaje']?.toString() ??
            '¡Excelente maridaje seleccionado por tu Sommelier!',
        maridaje: maridaje,
      );
    } catch (e) {
      debugPrint('Error en Sommelier en vivo ($e)');
      final fallback = generarMaridajeHeuristico(consulta);
      return RespuestaSommelierEnVivo(
        mensaje:
            'Te sugiero este maridaje clásico para equilibrar texturas y notas aromáticas de tu platillo.',
        maridaje: fallback,
      );
    }
  }

  /// Genera una Carta Gourmet de 3 Tiempos con Maridaje para cenas y anfitriones.
  static Future<MenuTresTiemposMaridado> generarMenuTresTiempos({
    required String entrada,
    required String platoFuerte,
    required String postre,
  }) async {
    final maridajeEntrada = generarMaridajeHeuristico(entrada);
    final maridajePlatoFuerte = generarMaridajeHeuristico(platoFuerte);
    final maridajePostre = generarMaridajeHeuristico(postre);

    return MenuTresTiemposMaridado(
      entrada: entrada,
      platoFuerte: platoFuerte,
      postre: postre,
      maridajeEntrada: maridajeEntrada,
      maridajePlatoFuerte: maridajePlatoFuerte,
      maridajePostre: maridajePostre,
    );
  }

  /// Agrega la bebida o ingredientes del maridaje a la Lista de Compras del usuario en Supabase.
  static Future<bool> agregarBebidaAListaCompras(
    String nombreBebida, {
    String cantidad = '1 botella / porción',
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final payload = {
        'nombre': nombreBebida.trim(),
        'cantidad': cantidad,
        'comprado': false,
        if (user != null) 'user_id': user.id,
      };

      await Supabase.instance.client.from('lista_compras').insert(payload);
      return true;
    } catch (e) {
      debugPrint('Error al agregar bebida a lista de compras: $e');
      return false;
    }
  }

  /// Consulta todos los ingredientes guardados en la despensa del usuario.
  static Future<List<String>> obtenerIngredientesEnDespensa() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      var query = Supabase.instance.client
          .from('despensa_usuario')
          .select('nombre');
      if (user != null) {
        query = query.eq('user_id', user.id);
      }
      final data = await query;
      return (data as List)
          .map((item) => (item['nombre'] ?? '').toString())
          .where((nombre) => nombre.trim().isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error al consultar ingredientes en despensa: $e');
      return [];
    }
  }

  /// Analiza con visión multimodal (Gemini) la foto de la etiqueta de una botella.
  /// Identifica la bebida, notas de cata y sugiere platillos idóneos cruzados
  /// con los ingredientes que el usuario tiene en su despensa.
  static Future<ResultadoEscaneoBotella?> escanearBotellaConIA(
    Uint8List imageBytes, {
    List<String>? ingredientesDespensa,
  }) async {
    if (ConfigApi.geminiKey.trim().isEmpty) {
      return null;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: ConfigApi.geminiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.3,
        ),
      );

      final despensaInfo = (ingredientesDespensa != null && ingredientesDespensa.isNotEmpty)
          ? 'Ingredientes que el usuario tiene actualmente en su despensa de casa: ${ingredientesDespensa.join(", ")}.'
          : 'El usuario no tiene ingredientes registrados en despensa.';

      final prompt = '''
Eres un Master Sommelier, Mixólogo y Chef de alta gama en la app "Jitomate y Cebolla".
Analiza minuciosamente la etiqueta de la botella en esta fotografía.

$despensaInfo

INSTRUCCIONES CLAVE:
1. Identifica con la mayor exactitud posible: Nombre comercial de la botella, bodega o destilería, añada si es visible, tipo de bebida (Vino Tinto, Vino Blanco, Mezcal, Cerveza, Tequila, etc.) y variedad/región (ej. "Cabernet Sauvignon • Valle de Guadalupe" o "Mezcal Tobalá • Oaxaca"). Si la imagen no es una botella ni bebida, indícalo amablemente.
2. Proporciona notas de cata breves pero refinadas (cuerpo, aromas principales, taninos/acidez).
3. Recomienda 3 platillos específicos que logren un maridaje excepcional con esta botella.
4. "Ingredientes de la despensa compatibles": De la lista de ingredientes que el usuario tiene en su despensa, lista cuáles combinan perfectamente para preparar una comida para esta botella. Si no tiene insumos afines, sugiere 2 o 3 ingredientes recomendados para comprar.
5. Temperatura de servicio exacta y cristalería ideal recomendada.
6. Tip de oro del sommelier (ej. "Recomendable decantar 20 min antes", "Servir en vaso veladora con rodaja de naranja", etc.).

Responde ÚNICAMENTE en JSON válido con este esquema estricto:
{
  "nombreBotella": "Nombre completo identificado",
  "tipoBebida": "Tipo de bebida",
  "variedadORegion": "Uva / Cepa y Región",
  "notasCata": "Aroma a frutos rojos, cuerpo medio-alto con taninos redondos...",
  "temperaturaServicio": "16°C - 18°C",
  "copaRecomendada": "Copa Burdeos",
  "maridajeRecomendado": "Ideal con carnes asadas, pastas con salsas rojas o quesos curados.",
  "platillosSugeridos": [
    "Platillo 1 sugerido",
    "Platillo 2 sugerido",
    "Platillo 3 sugerido"
  ],
  "ingredientesDespensaCompatibles": [
    "Ingrediente 1",
    "Ingrediente 2"
  ],
  "tipSommelier": "Consejo profesional para disfrutar al máximo esta botella"
}
''';

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];

      final response = await model.generateContent(content);
      final rawText = response.text;
      if (rawText == null || rawText.trim().isEmpty) return null;

      final start = rawText.indexOf('{');
      final end = rawText.lastIndexOf('}');
      if (start == -1 || end == -1) return null;

      final jsonLimpio = rawText.substring(start, end + 1);
      final map = jsonDecode(jsonLimpio) as Map<String, dynamic>;
      return ResultadoEscaneoBotella.fromMap(map);
    } catch (e) {
      debugPrint('Error al escanear botella con IA: $e');
      return null;
    }
  }

  /// Guarda una botella escaneada directamente en la Cava (despensa_usuario).
  static Future<bool> guardarBotellaEnCava(String nombreBotella) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final payload = {
        'nombre': nombreBotella,
        'cantidad': 1,
        'fecha_ingreso': DateTime.now().toIso8601String().split('T')[0],
      };
      if (user != null) {
        payload['user_id'] = user.id;
      }
      await Supabase.instance.client.from('despensa_usuario').insert(payload);
      return true;
    } catch (e) {
      debugPrint('Error al guardar botella en cava: $e');
      return false;
    }
  }
}

/// Respuesta conversacional del Sommelier IA en vivo.
class RespuestaSommelierEnVivo {
  final String mensaje;
  final MaridajeReceta maridaje;

  const RespuestaSommelierEnVivo({
    required this.mensaje,
    required this.maridaje,
  });
}

/// Carta de Menú de 3 Tiempos para anfitriones y cenas con amigos.
class MenuTresTiemposMaridado {
  final String entrada;
  final String platoFuerte;
  final String postre;
  final MaridajeReceta maridajeEntrada;
  final MaridajeReceta maridajePlatoFuerte;
  final MaridajeReceta maridajePostre;

  const MenuTresTiemposMaridado({
    required this.entrada,
    required this.platoFuerte,
    required this.postre,
    required this.maridajeEntrada,
    required this.maridajePlatoFuerte,
    required this.maridajePostre,
  });

  String formatoParaCompartir() {
    final sb = StringBuffer();
    sb.writeln('🍽️ *CARTA DE CENA GOURMET & MARIDAJE* 🍷');
    sb.writeln('_Diseñado por el Sommelier IA de Jitomate y Cebolla_\n');

    sb.writeln('🥗 *1er Tiempo (Entrada):* $entrada');
    sb.writeln('   • 🍷 Maridaje: ${maridajeEntrada.vino}');
    sb.writeln('   • 🍹 Sin alcohol: ${maridajeEntrada.sinAlcohol}\n');

    sb.writeln('🥩 *2do Tiempo (Plato Fuerte):* $platoFuerte');
    sb.writeln('   • 🍷 Maridaje: ${maridajePlatoFuerte.vino}');
    sb.writeln('   • 🥃 Destilado: ${maridajePlatoFuerte.destilado}\n');

    sb.writeln('🍰 *3er Tiempo (Postre):* $postre');
    sb.writeln('   • 🍷 Maridaje: ${maridajePostre.vino}');
    sb.writeln('   • ☕ Coctel/Café: ${maridajePostre.destilado}\n');

    sb.writeln('✨ ¡Buen provecho y feliz velada! 🥂');
    sb.writeln('https://www.jitomateycebolla.com');
    return sb.toString();
  }
}

/// Ficha técnica y gastronómica del escaneo visual de una botella con IA.
class ResultadoEscaneoBotella {
  final String nombreBotella;
  final String tipoBebida;
  final String variedadORegion;
  final String notasCata;
  final String temperaturaServicio;
  final String copaRecomendada;
  final String? maridajeRecomendado;
  final List<String> platillosSugeridos;
  final List<String> ingredientesDespensaCompatibles;
  final String tipSommelier;

  const ResultadoEscaneoBotella({
    required this.nombreBotella,
    required this.tipoBebida,
    required this.variedadORegion,
    required this.notasCata,
    required this.temperaturaServicio,
    required this.copaRecomendada,
    this.maridajeRecomendado,
    required this.platillosSugeridos,
    required this.ingredientesDespensaCompatibles,
    required this.tipSommelier,
  });

  Map<String, dynamic> toMap() => {
        'nombreBotella': nombreBotella,
        'tipoBebida': tipoBebida,
        'variedadORegion': variedadORegion,
        'notasCata': notasCata,
        'temperaturaServicio': temperaturaServicio,
        'copaRecomendada': copaRecomendada,
        'maridajeRecomendado': maridajeRecomendado,
        'platillosSugeridos': platillosSugeridos,
        'ingredientesDespensaCompatibles': ingredientesDespensaCompatibles,
        'tipSommelier': tipSommelier,
      };

  factory ResultadoEscaneoBotella.fromMap(Map<String, dynamic> map) {
    return ResultadoEscaneoBotella(
      nombreBotella:
          (map['nombreBotella'] ?? map['nombre'] ?? 'Bebida Escaneada')
              .toString(),
      tipoBebida:
          (map['tipoBebida'] ?? map['tipo'] ?? 'Vino / Licor').toString(),
      variedadORegion:
          (map['variedadORegion'] ?? map['region'] ?? '').toString(),
      notasCata: (map['notasCata'] ?? map['notas'] ?? '').toString(),
      temperaturaServicio:
          (map['temperaturaServicio'] ?? map['temperatura'] ?? '16°C - 18°C')
              .toString(),
      copaRecomendada:
          (map['copaRecomendada'] ?? map['copa'] ?? 'Copa estándar').toString(),
      maridajeRecomendado: map['maridajeRecomendado']?.toString(),
      platillosSugeridos: (map['platillosSugeridos'] is List)
          ? (map['platillosSugeridos'] as List)
              .map((e) => e.toString())
              .toList()
          : <String>[],
      ingredientesDespensaCompatibles:
          (map['ingredientesDespensaCompatibles'] is List)
              ? (map['ingredientesDespensaCompatibles'] as List)
                  .map((e) => e.toString())
                  .toList()
              : <String>[],
      tipSommelier: (map['tipSommelier'] ?? map['tip'] ?? '').toString(),
    );
  }

  String formatoParaCompartir() {
    final sb = StringBuffer();
    sb.writeln('🍷 *FICHA DE CATA & MARIDAJE SOMMELIER IA* 📸');
    sb.writeln('🍾 *Botella:* $nombreBotella');
    if (variedadORegion.isNotEmpty) {
      sb.writeln('🍇 *Variedad/Origen:* $variedadORegion');
    }
    sb.writeln('✨ *Tipo:* $tipoBebida\n');

    if (notasCata.isNotEmpty) {
      sb.writeln('📝 *Notas de Cata:* $notasCata');
    }
    sb.writeln(
        '❄️ *Servicio:* $temperaturaServicio | 🍷 *Cristalería:* $copaRecomendada\n');

    if (platillosSugeridos.isNotEmpty) {
      sb.writeln('🍽️ *Platillos recomendados para maridar:*');
      for (final p in platillosSugeridos) {
        sb.writeln('  • $p');
      }
      sb.writeln();
    }

    if (tipSommelier.isNotEmpty) {
      sb.writeln('💡 *Tip del Sommelier:* $tipSommelier\n');
    }

    sb.writeln('Descubierto con Jitomate y Cebolla 🍅🧅');
    sb.writeln('https://www.jitomateycebolla.com');
    return sb.toString();
  }
}


