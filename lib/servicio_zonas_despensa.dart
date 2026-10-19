import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'servicio_sommelier.dart';

/// Zonas de almacenamiento físico en el hogar para la despensa.
enum ZonaDespensa {
  refrigerador,
  congelador,
  alacena,
  cava;

  String get id {
    switch (this) {
      case ZonaDespensa.refrigerador:
        return 'refrigerador';
      case ZonaDespensa.congelador:
        return 'congelador';
      case ZonaDespensa.alacena:
        return 'alacena';
      case ZonaDespensa.cava:
        return 'cava';
    }
  }

  String get nombre {
    switch (this) {
      case ZonaDespensa.refrigerador:
        return 'Refrigerador';
      case ZonaDespensa.congelador:
        return 'Congelador';
      case ZonaDespensa.alacena:
        return 'Alacena Seca';
      case ZonaDespensa.cava:
        return 'Cava & Bar';
    }
  }

  String get emoji {
    switch (this) {
      case ZonaDespensa.refrigerador:
        return '❄️';
      case ZonaDespensa.congelador:
        return '🧊';
      case ZonaDespensa.alacena:
        return '🥫';
      case ZonaDespensa.cava:
        return '🍷';
    }
  }

  IconData get icono {
    switch (this) {
      case ZonaDespensa.refrigerador:
        return Icons.kitchen;
      case ZonaDespensa.congelador:
        return Icons.ac_unit_rounded;
      case ZonaDespensa.alacena:
        return Icons.inventory_2_outlined;
      case ZonaDespensa.cava:
        return Icons.wine_bar_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ZonaDespensa.refrigerador:
        return Colors.blue.shade700;
      case ZonaDespensa.congelador:
        return Colors.cyan.shade800;
      case ZonaDespensa.alacena:
        return Colors.amber.shade900;
      case ZonaDespensa.cava:
        return const Color(0xFF5B1228);
    }
  }

  Color get fondoColor {
    switch (this) {
      case ZonaDespensa.refrigerador:
        return Colors.blue.shade50;
      case ZonaDespensa.congelador:
        return Colors.cyan.shade50;
      case ZonaDespensa.alacena:
        return Colors.amber.shade50;
      case ZonaDespensa.cava:
        return const Color(0xFFFBECEF);
    }
  }

  String get descripcionCorta {
    switch (this) {
      case ZonaDespensa.refrigerador:
        return 'Frescos, lácteos y porciones de la semana (<=4°C)';
      case ZonaDespensa.congelador:
        return 'Proteínas, vegetales y batch cooking guardado (-18°C)';
      case ZonaDespensa.alacena:
        return 'Granos, pastas, aceites, harinas, conservas y especias';
      case ZonaDespensa.cava:
        return 'Vinos, cervezas, licores y destilados para maridaje';
    }
  }

  static ZonaDespensa desdeId(String? id) {
    switch (id?.toLowerCase().trim()) {
      case 'congelador':
        return ZonaDespensa.congelador;
      case 'alacena':
      case 'alacena seca':
        return ZonaDespensa.alacena;
      case 'cava':
      case 'cava & bar':
        return ZonaDespensa.cava;
      case 'refrigerador':
      default:
        return ZonaDespensa.refrigerador;
    }
  }
}

/// Servicio que gestiona la categorización por zonas físicas de la despensa doméstica
/// y la persistencia de personalizaciones de ubicación del usuario.
class ServicioZonasDespensa {
  static const String prefClaveOverrides = 'pref_zonas_despensa_overrides_v1';

  /// Detecta la zona física por defecto según heurísticas avanzadas del ingrediente.
  static ZonaDespensa detectarZonaPorDefecto(String nombre) {
    final n = _normalizar(nombre);

    // 1. Cava & Bar (Sommelier)
    if (ServicioSommelier.esItemDeCava(nombre)) {
      return ZonaDespensa.cava;
    }

    // 2. Congelador explícito
    if (n.contains('congelad') ||
        n.contains('hielo') ||
        n.contains('helado') ||
        n.contains('nieve') ||
        n.contains('pulpa congelada') ||
        n.contains('edamame') ||
        n.contains('congelar') ||
        n.contains('ultra congelad')) {
      return ZonaDespensa.congelador;
    }

    // 3. Refrigerador (Frescos, lácteos, carnes frescas, embutidos)
    if (_esRefrigerador(n)) {
      return ZonaDespensa.refrigerador;
    }

    // 4. Alacena Seca (Abarrotes, granos, semillas, aceites, especias, panadería)
    if (_esAlacenaSeca(n)) {
      return ZonaDespensa.alacena;
    }

    // Fallback inteligente: si contiene palabras de especias o botes -> alacena, si no -> refri
    return ZonaDespensa.alacena;
  }

  static bool _esAlacenaSeca(String n) {
    return n.contains('arroz') ||
        n.contains('frijol') ||
        n.contains('lenteja') ||
        n.contains('garbanzo') ||
        n.contains('habas') ||
        n.contains('pasta') ||
        n.contains('espagueti') ||
        n.contains('fideo') ||
        n.contains('macarron') ||
        n.contains('avena') ||
        n.contains('harina') ||
        n.contains('aceite') ||
        n.contains('vinagre') ||
        n.contains('atun en lata') ||
        n.contains('atún en lata') ||
        n.contains('sardina') ||
        n.contains('consome') ||
        n.contains('consomé') ||
        RegExp(r'\b(sal)\b').hasMatch(n) ||
        n.contains('pimienta') ||
        n.contains('oregano') ||
        n.contains('orégano') ||
        n.contains('canela') ||
        n.contains('comino') ||
        n.contains('laurel') ||
        n.contains('clavo') ||
        n.contains('tomillo') ||
        n.contains('romero seco') ||
        n.contains('azucar') ||
        n.contains('azúcar') ||
        n.contains('miel') ||
        n.contains('cafe') ||
        n.contains('café') ||
        RegExp(r'\b(te|té)\b').hasMatch(n) ||
        n.contains('galleta') ||
        RegExp(r'\b(pan|panes)\b').hasMatch(n) ||
        n.contains('cereal') ||
        n.contains('maiz') ||
        n.contains('maíz') ||
        n.contains('palomitas') ||
        n.contains('nuez') ||
        n.contains('nueces') ||
        n.contains('almendra') ||
        n.contains('cacahuate') ||
        n.contains('chia') ||
        n.contains('chía') ||
        n.contains('linaza') ||
        n.contains('ajonjoli') ||
        n.contains('ajonjolí') ||
        n.contains('chile seco') ||
        n.contains('ancho') ||
        n.contains('guajillo') ||
        n.contains('pasilla') ||
        n.contains('pure de tomate') ||
        n.contains('puré de tomate') ||
        n.contains('pasta de tomate') ||
        n.contains('chispas de chocolate') ||
        n.contains('chocolate amargo') ||
        n.contains('extracto de vainilla') ||
        n.contains('esencia de vainilla') ||
        n.contains('polvo para hornear') ||
        n.contains('bicarbonato') ||
        n.contains('stevia') ||
        n.contains('splenda') ||
        n.contains('monk fruit') ||
        n.contains('tajin') ||
        n.contains('tajín');
  }

  static bool _esRefrigerador(String n) {
    return n.contains('leche') ||
        n.contains('queso') ||
        n.contains('crema') ||
        n.contains('yogur') ||
        n.contains('mantequilla') ||
        n.contains('margarina') ||
        n.contains('jamon') ||
        n.contains('jamón') ||
        n.contains('salchicha') ||
        n.contains('tocino') ||
        n.contains('huevo') ||
        n.contains('mayonesa') ||
        n.contains('aderezo') ||
        n.contains('mostaza') ||
        n.contains('jitomate') ||
        n.contains('tomate') ||
        n.contains('cebolla') ||
        n.contains('ajo') ||
        n.contains('cilantro') ||
        n.contains('perejil') ||
        n.contains('lechuga') ||
        n.contains('espinaca') ||
        n.contains('acelga') ||
        n.contains('zanahoria') ||
        n.contains('calabac') ||
        n.contains('aguacate') ||
        n.contains('pepino') ||
        n.contains('champiñ') ||
        n.contains('setas') ||
        n.contains('apio') ||
        n.contains('brocoli') ||
        n.contains('brócoli') ||
        n.contains('coliflor') ||
        n.contains('pimiento') ||
        n.contains('chile fresco') ||
        n.contains('serrano') ||
        n.contains('jalapeño') ||
        n.contains('poblano') ||
        n.contains('limon') ||
        n.contains('limón') ||
        n.contains('manzana') ||
        n.contains('platano') ||
        n.contains('plátano') ||
        n.contains('fresa') ||
        n.contains('uva') ||
        n.contains('sandia') ||
        n.contains('sandía') ||
        n.contains('melon') ||
        n.contains('melón') ||
        n.contains('naranja') ||
        n.contains('mandarina') ||
        n.contains('pollo') ||
        n.contains('carne') ||
        n.contains('res') ||
        n.contains('cerdo') ||
        n.contains('puerco') ||
        n.contains('pescado') ||
        n.contains('salmon') ||
        n.contains('salmón') ||
        n.contains('atun fresco') ||
        n.contains('atún fresco') ||
        n.contains('camaron') ||
        n.contains('camarón') ||
        n.contains('tupper') ||
        n.contains('guisado');
  }

  static String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
  }

  /// Clave única para guardar overrides (usa id_item si existe, o el nombre normalizado).
  static String obtenerClaveItem(dynamic item) {
    if (item is Map) {
      if (item['id_item'] != null) {
        return 'id_${item['id_item']}';
      }
      if (item['nombre'] != null) {
        return 'nom_${_normalizar(item['nombre'].toString())}';
      }
    }
    return 'nom_${_normalizar(item.toString())}';
  }

  /// Obtiene todos los overrides guardados en SharedPreferences.
  static Future<Map<String, String>> obtenerOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefClaveOverrides);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, String>.from(decoded);
      }
    } catch (e) {
      debugPrint('Error leyendo overrides de zonas: $e');
    }
    return {};
  }

  /// Guarda una nueva asignación de zona para un ítem específico.
  static Future<void> asignarZona({
    required dynamic item,
    required ZonaDespensa nuevaZona,
  }) async {
    try {
      final clave = obtenerClaveItem(item);
      final overrides = await obtenerOverrides();
      overrides[clave] = nuevaZona.id;

      // También guardar por nombre por si se vuelve a comprar el mismo artículo en el futuro
      if (item is Map && item['nombre'] != null) {
        overrides['nom_${_normalizar(item['nombre'].toString())}'] = nuevaZona.id;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefClaveOverrides, jsonEncode(overrides));
    } catch (e) {
      debugPrint('Error guardando override de zona: $e');
    }
  }

  /// Resuelve la zona final de un ítem considerando primero los overrides del usuario.
  static ZonaDespensa resolverZona(
    dynamic item,
    Map<String, String> overrides,
  ) {
    final String nombre = (item is Map ? item['nombre'] : item)?.toString() ?? '';
    final String claveId = obtenerClaveItem(item);
    final String claveNom = 'nom_${_normalizar(nombre)}';

    if (overrides.containsKey(claveId)) {
      return ZonaDespensa.desdeId(overrides[claveId]);
    }
    if (overrides.containsKey(claveNom)) {
      return ZonaDespensa.desdeId(overrides[claveNom]);
    }

    return detectarZonaPorDefecto(nombre);
  }

  /// Calcula conteos de insumos por zona para una lista dada de artículos.
  static Map<ZonaDespensa, int> contarPorZonas(
    List items,
    Map<String, String> overrides,
  ) {
    final Map<ZonaDespensa, int> conteos = {
      ZonaDespensa.refrigerador: 0,
      ZonaDespensa.congelador: 0,
      ZonaDespensa.alacena: 0,
      ZonaDespensa.cava: 0,
    };

    for (final item in items) {
      final zona = resolverZona(item, overrides);
      conteos[zona] = (conteos[zona] ?? 0) + 1;
    }

    return conteos;
  }
}
