import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'config_api.dart';

class ServicioIA {
  static const String _apiKey = ConfigApi.geminiKey;

  // ✅ Modelo activo oficial actualizado a gemini-2.5-flash para máxima estabilidad
  static const String _urlGemini =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=$_apiKey';

  // 🔄 PETICIÓN BLINDADA CON REINTENTO AUTOMÁTICO EN CASO DE ERROR 503 O 429
  static Future<String?> _hacerPeticion(
    Map<String, dynamic> cuerpo, {
    bool forzarJson = true,
  }) async {
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

    int intentos = 0;
    const maxIntentos = 3;

    while (intentos < maxIntentos) {
      intentos++;
      try {
        final respuesta = await http.post(
          Uri.parse(_urlGemini),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        );

        if (respuesta.statusCode == 200) {
          final datos = jsonDecode(respuesta.body);
          final candidate = datos['candidates'][0];

          if (candidate['content'] == null) {
            debugPrint('⚠️ Gemini bloqueó: ${candidate['finishReason']}');
            return null;
          }

          return candidate['content']['parts'][0]['text'];
        } else if (respuesta.statusCode == 503 || respuesta.statusCode == 429) {
          debugPrint(
            '⏳ Google saturado (${respuesta.statusCode}). Reintentando ($intentos/$maxIntentos) en 8 segundos...',
          );
          await Future.delayed(const Duration(seconds: 8));
        } else {
          debugPrint(
            '❌ Error de Google (${respuesta.statusCode}):\n${respuesta.body}',
          );
          return '❌ Error de Google (${respuesta.statusCode}):\n${respuesta.body}';
        }
      } catch (e) {
        debugPrint('⏳ Error de red ($e). Reintentando en 5 segundos...');
        await Future.delayed(const Duration(seconds: 5));
      }
    }

    return null;
  }

  // 🧾 ESCÁNER AVANZADO DE TICKETS DE SUPERMERCADO
  static Future<Map<String, dynamic>?> leerTicketSupermercado(
    Uint8List imageBytes,
  ) async {
    const prompt = '''
    Eres un asistente financiero y de cocina experto en supermercados de México (Walmart, Soriana, La Comer, Chedraui, Sam's Club, Costco, etc.).
    Lee cuidadosamente este ticket de compra.

    REGLAS ESTRICTAS:
    1. Identifica el nombre de la cadena o tienda. Si no es evidente, asigna "Walmart".
    2. Extrae ÚNICAMENTE artículos que sean COMIDA, BEBIDAS o INGREDIENTES culinarios. Ignora ropa, higiene, etc.
    3. Limpia el nombre del producto quitando abreviaturas (ej. "JITOMATE BOLA KG" -> "Jitomate bola").
    4. UNIDADES DE MEDIDA (CRÍTICO): Si el ticket marca gramos (g) o mililitros (ml), CONVIÉRTELO SIEMPRE a Kilos (kg) o Litros (L) dividiendo entre 1000 (ej. 1602g = 1.602). Si es por pieza, extrae el número de piezas.
    5. Extrae el precio total cobrado por ese artículo.

    Devuelve ESTRICTAMENTE un objeto JSON con este formato:
    {
      "supermercado": "Walmart",
      "articulos": [
        {"nombre": "Aguacate Hass", "cantidad": 1.0, "precio": 45.50},
        {"nombre": "Pechuga de pollo", "cantidad": 1.602, "precio": 120.00}
      ]
    }
    ''';

    final base64Imagen = base64Encode(imageBytes);

    final Map<String, dynamic> cuerpo = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inlineData": {"mimeType": "image/jpeg", "data": base64Imagen},
            },
          ],
        },
      ],
    };

    final textoRespuesta = await _hacerPeticion(cuerpo, forzarJson: true);
    if (textoRespuesta == null || textoRespuesta.contains('❌ Error')) {
      return null;
    }

    try {
      final start = textoRespuesta.indexOf('{');
      final end = textoRespuesta.lastIndexOf('}');
      if (start == -1 || end == -1) return null;

      final jsonLimpio = textoRespuesta.substring(start, end + 1);
      return jsonDecode(jsonLimpio) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error al decodificar ticket: $e');
      return null;
    }
  }

  // 🧹 SANEADOR QUIRÚRGICO DE RECETAS
  static Future<String?> pulirOrtografiaYFormatoReceta(
    String textoOriginal,
  ) async {
    final prompt =
        '''
    Eres un Editor Culinario y Lingüista experto en español. Corrige el texto de la siguiente receta.
    1. Repara letras mochas por OCR (ej. "Echuga orejona" -> "Lechuga orejona").
    2. Cada ingrediente DEBE ir en su propio renglón iniciando con un guion (-). Separa listas unidas por "y" o comas.
    3. Elimina redundancias ("Pechugas deshuesadas y pechugas a la parrilla" -> "- Pechuga de pollo deshuesada").
    4. Corrige tildes (sésamo, limón, plátano, brócoli, orégano, chía, champiñón, atún).
    5. NO agregues la palabra "TÍTULO:".
    6. AGUA PARA COCINAR Y HIELO: Si en los ingredientes aparece agua de la llave, agua caliente, agua fría o agua para hervir (ej. "2 tazas de agua", "1 litro de agua", "agua hirviendo", "hielo"), ELIMÍNALA de la lista de ingredientes (el agua se utiliza en el modo preparación, pero no debe listarse como insumo de compra en el supermercado). Los caldos (caldo vegetal, caldo de pollo) SÍ deben permanecer.
    Devuelve ÚNICAMENTE el texto final de la receta corregida.

    Texto a corregir:
    $textoOriginal
    ''';

    final Map<String, dynamic> cuerpo = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
    };

    final respuesta = await _hacerPeticion(cuerpo, forzarJson: false);
    if (respuesta == null || respuesta.contains('❌ Error')) {
      return null;
    }
    return respuesta.trim();
  }

  // 📸 ESCÁNER DE RECETAS POR FOTO
  static Future<Map<String, dynamic>?> escanearRecetaDeFoto(
    Uint8List imageBytes,
  ) async {
    const prompt = '''
    Eres un Master Chef y transcriptor experto. Analiza la imagen de esta receta.
    Devuelve ÚNICAMENTE un objeto JSON válido con las llaves: "titulo", "tipo_comida" ("Desayuno", "Comida", "Cena", "Snack") y "descripcion".
    En "descripcion", comienza directamente con PORCIONES, TIEMPO, DIFICULTAD, CALORÍAS y MACROS, seguido de 📝 INGREDIENTES y 🍳 INSTRUCCIONES. Cada ingrediente con guion (-).
    ''';

    final base64Imagen = base64Encode(imageBytes);

    final Map<String, dynamic> cuerpo = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {
              "inlineData": {"mimeType": "image/jpeg", "data": base64Imagen},
            },
          ],
        },
      ],
    };

    final textoRespuesta = await _hacerPeticion(cuerpo, forzarJson: true);
    if (textoRespuesta == null || textoRespuesta.contains('❌ Error')) {
      return null;
    }

    try {
      final start = textoRespuesta.indexOf('{');
      final end = textoRespuesta.lastIndexOf('}');
      if (start == -1 || end == -1) return null;

      final jsonLimpio = textoRespuesta.substring(start, end + 1);
      return jsonDecode(jsonLimpio) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error al decodificar receta de foto: $e');
      return null;
    }
  }

  // 💡 IA PARA INVENTAR RECETAS
  static Future<String> inventarReceta(
    List<String> ingredientesDisponibles,
    String tipoComidaSugerida,
    String tipoDieta, {
    bool modoPerruno = false,
  }) async {
    String instruccionIngredientesHumano = ingredientesDisponibles.isEmpty
        ? "INSTRUCCIÓN DE INGREDIENTES: Tienes total libertad creativa."
        : "INSTRUCCIÓN DE INGREDIENTES: Usa ALGUNOS de estos ingredientes:\n${ingredientesDisponibles.join(', ')}";

    String instruccionIngredientesPerruno = ingredientesDisponibles.isEmpty
        ? "INSTRUCCIÓN DE INGREDIENTES: Usa ingredientes 100% seguros para perros (ej. pollo hervido, avena, zanahoria, manzana)."
        : "INSTRUCCIÓN DE INGREDIENTES: Usa ALGUNOS de estos ingredientes:\n${ingredientesDisponibles.join(', ')}";

    final String promptPerruno =
        '''
Eres un Veterinario Nutricionista y Chef para Mascotas. Inventa una receta de PREMIOS o COMIDA SEGURA PARA PERROS.
$instruccionIngredientesPerruno
REGLA DE ORO: EXCLUYE INGREDIENTES TÓXICOS PARA PERROS (cebolla, ajo, chocolate, uvas, aguacate, sal).
La PRIMERA línea debe ser el nombre. Luego PORCIONES, TIEMPO, DIFICULTAD, CALORÍAS, MACROS, TIPO, DIETAS IDEALES, 📝 INGREDIENTES y 🍳 INSTRUCCIONES.
''';

    final String promptHumano =
        '''
Eres un Master Chef y Nutriólogo experto. Inventa una receta para $tipoComidaSugerida con dieta "$tipoDieta".
$instruccionIngredientesHumano
La PRIMERA línea debe ser el nombre. Luego PORCIONES, TIEMPO, DIFICULTAD, CALORÍAS, MACROS, TIPO, DIETAS IDEALES, 📝 INGREDIENTES y 🍳 INSTRUCCIONES. Cada ingrediente con guion (-).
''';

    final Map<String, dynamic> cuerpo = {
      "contents": [
        {
          "parts": [
            {"text": modoPerruno ? promptPerruno : promptHumano},
          ],
        },
      ],
    };

    final textoRespuesta = await _hacerPeticion(cuerpo, forzarJson: false);
    return textoRespuesta?.trim() ?? 'No pude inventar una receta esta vez. 😔';
  }

  static Future<List<int>> generarPlanSemanal(
    List<Map<String, dynamic>> recetasDisponibles,
  ) async {
    final prompt =
        '''
Selecciona exactamente 7 recetas para la semana. Devuelve un array JSON con 7 IDs enteros:
${jsonEncode(recetasDisponibles)}
Ejemplo: [1, 5, 2, 8, 3, 4, 7]
''';

    final Map<String, dynamic> cuerpo = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
    };

    final textoRespuesta = await _hacerPeticion(cuerpo);
    if (textoRespuesta == null || textoRespuesta.contains('❌ Error')) {
      return recetasDisponibles
          .take(7)
          .map((e) => e['id_receta'] as int)
          .toList();
    }

    try {
      final start = textoRespuesta.indexOf('[');
      final end = textoRespuesta.lastIndexOf(']');
      if (start == -1 || end == -1) throw Exception();
      final jsonArrayString = textoRespuesta.substring(start, end + 1);
      List<dynamic> decodificado = jsonDecode(jsonArrayString);
      return decodificado.map((e) => int.parse(e.toString())).toList();
    } catch (_) {
      return recetasDisponibles
          .take(7)
          .map((e) => e['id_receta'] as int)
          .toList();
    }
  }

  static Future<List<String>> generarListaCompras(
    List<String> instruccionesRecetas,
    List<String> miDespensa,
  ) async {
    final prompt =
        '''
Compara estas recetas con mi despensa y dime qué falta comprar.
Recetas: ${instruccionesRecetas.join('\n')}
Despensa: ${miDespensa.join(', ')}
Devuelve estrictamente un array JSON de strings con faltantes.
''';

    final Map<String, dynamic> cuerpo = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
    };

    final textoRespuesta = await _hacerPeticion(cuerpo);
    if (textoRespuesta == null ||
        textoRespuesta.isEmpty ||
        textoRespuesta.contains('❌ Error')) {
      return [];
    }
    try {
      final start = textoRespuesta.indexOf('[');
      final end = textoRespuesta.lastIndexOf(']');
      if (start == -1 || end == -1) return [];
      final jsonArrayString = textoRespuesta.substring(start, end + 1);
      List<dynamic> decodificado = jsonDecode(jsonArrayString);
      return decodificado.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<String> compararSupermercados(List<String> listaCompras) async {
    if (listaCompras.isEmpty) return 'Tu lista de compras está vacía.';

    final prompt =
        '''
Experto en compras en México. Analiza dónde surtir: ${listaCompras.join(', ')}.
Compara Walmart, Soriana, La Comer, Costco y Sam's Club con viñetas y un ganador final.
''';

    final Map<String, dynamic> cuerpo = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
          ],
        },
      ],
    };

    final textoRespuesta = await _hacerPeticion(cuerpo, forzarJson: false);
    return textoRespuesta?.trim() ??
        '❌ No pude generar la comparativa esta vez. 😔';
  }

  // 📦 PARSEADOR RELACIONAL PARA MIGRACIÓN A RECETA_DETALLE
  static Future<Map<String, dynamic>?> estructurarIngredientesReceta(
    String descripcion,
  ) async {
    const prompt = '''
    Eres un asistente experto de base de datos culinarias y compras de supermercado en México.
    Analiza el texto de esta receta y extrae las instrucciones y los ingredientes en un formato estructurado para venta de supermercado.

    REGLAS ESTRICTAS:
    1. EXCLUYE estrictamente: agua de grifo/llave, agua tibia, agua caliente, agua fría, agua hirviendo, hielo, cubos de hielo, o pizcas de sal que no se compran como artículo principal.
    2. ESTANDARIZA el nombre de cada ingrediente al nombre genérico de producto en supermercado (ej. "Pechuga de pollo", "Limón", "Frijoles negros", "Queso panela", "Queso oaxaca", "Tortillas de maíz", "Tostadas horneadas", "Bistec de res", "Carne molida de pavo", "Crema de cacahuate", "Semillas de ajonjolí", "Leche de almendra", "Lechuga orejona", "Chiles chipotle", "Elote amarillo", "Aceite en spray").
    3. CONVIERTE medidas de cocina a formato comercial de supermercado:
       - Si pide cucharadas o tazas de aderezos, salsas, cremas untables: cantidad 1, unidad "frasco".
       - Si pide semillas, especias (ajonjolí, chía, canela): cantidad 1, unidad "frasco / bolsita".
       - Si pide tostadas, tortillas, wraps o pan: cantidad 1, unidad "paquete".
       - Si pide carnes con peso (ej. 300g bistec, 500g carne de pavo): mantén el peso exacto (ej. cantidad: 300, unidad: "g").
       - Si pide lechugas: cantidad 1, unidad "pieza".
       - Si pide leches o bebidas en taza: cantidad 1, unidad "litro / envase".
       - Si pide jugo de limones (ej. jugo de 6 limones): cantidad 6, unidad "pza", nombre "Limón".
       - Si pide quesos en rebanadas o gramos pequeños: cantidad 1, unidad "paquete".
       - Si pide piezas enteras (aguacate, manzana, plátano, jitomate): mantén la cantidad entera y unidad "pza".
    4. En "instrucciones", extrae únicamente los pasos de cocción limpios numerados (ej. "1. Cortar...\\n2. Cocinar...").

    Devuelve ÚNICAMENTE un objeto JSON con este formato exacto:
    {
      "instrucciones": "1. Mezclar los ingredientes...\\n2. Cocinar a fuego medio...",
      "ingredientes": [
        {"nombre": "Pechuga de pollo", "cantidad": 500.0, "unidad": "g"},
        {"nombre": "Limón", "cantidad": 2.0, "unidad": "pza"},
        {"nombre": "Crema de cacahuate", "cantidad": 1.0, "unidad": "frasco"}
      ]
    }
    ''';

    final Map<String, dynamic> cuerpo = {
      "contents": [
        {
          "parts": [
            {"text": prompt},
            {"text": "Receta a procesar:\n$descripcion"},
          ],
        },
      ],
    };

    final respuesta = await _hacerPeticion(cuerpo, forzarJson: true);
    if (respuesta == null || respuesta.contains('❌ Error')) {
      return null;
    }

    try {
      final start = respuesta.indexOf('{');
      final end = respuesta.lastIndexOf('}');
      if (start == -1 || end == -1) return null;
      final jsonLimpio = respuesta.substring(start, end + 1);
      return jsonDecode(jsonLimpio) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('🚨 Error decodificando JSON de Gemini: $e');
      return null;
    }
  }
}
