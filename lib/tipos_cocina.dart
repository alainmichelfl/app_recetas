/// Tipos de cocina del mundo soportados por la app para preferencias,
/// planeador semanal y generación inteligente con Chef IA.
class TiposCocina {
  TiposCocina._();

  static const String todas = 'Variada / Todas';
  static const String mexicana = 'Mexicana';
  static const String italiana = 'Italiana';
  static const String japonesa = 'Japonesa';
  static const String thai = 'Thai';
  static const String francesa = 'Francesa';
  static const String espanola = 'Española';
  static const String mediterranea = 'Mediterránea';
  static const String china = 'China';
  static const String india = 'India';
  static const String americana = 'Americana';

  static const List<String> lista = [
    todas,
    mexicana,
    italiana,
    japonesa,
    thai,
    francesa,
    espanola,
    mediterranea,
    china,
    india,
    americana,
  ];

  static const Map<String, String> iconos = {
    todas: '🌎',
    mexicana: '🇲🇽',
    italiana: '🇮🇹',
    japonesa: '🇯🇵',
    thai: '🇹🇭',
    francesa: '🇫🇷',
    espanola: '🇪🇸',
    mediterranea: '🇬🇷',
    china: '🇨🇳',
    india: '🇮🇳',
    americana: '🍔',
  };

  static const Map<String, String> descripciones = {
    todas: 'Variedad global con mezclas de distintas gastronomías del mundo.',
    mexicana: 'Salsas tradicionales, chiles, maíz, frijoles y especias emblemáticas.',
    italiana: 'Pastas frescas, risottos, albahaca, pomodoro, quesos y aceite de oliva.',
    japonesa: 'Arroces, ramen, teriyaki, miso, pescados, algas y balance umami.',
    thai: 'Leche de coco, curry, hierba limón, fideos de arroz, cacahuate y toque cítrico.',
    francesa: 'Quiches, ratatouille, hierbas provenzales, crepas y salsas clásicas.',
    espanola: 'Tapas, paellas, azafrán, sofritos, pimentón y gazpachos frescos.',
    mediterranea: 'Aceite de oliva, pescados, legumbres, hummus, tzatziki y verduras frescas.',
    china: 'Wok, salteados, jengibre, cebollín, arroz frito y equilibrio agridulce.',
    india: 'Currys aromáticos, especias garam masala, lentejas (dal), cúrcuma y naan.',
    americana: 'Bowls, BBQ saludable, hamburguesas caseras, ensaladas y clásicos.',
  };

  static const Map<String, List<String>> palabrasClave = {
    mexicana: [
      'mexicana', 'taco', 'tacos', 'enchilada', 'enchiladas', 'chilaquiles',
      'salsa', 'frijol', 'frijoles', 'tortilla', 'tortillas', 'mole', 'tinga',
      'pozole', 'nopales', 'guacamole', 'jalapeno', 'chile', 'chiles', 'poblano',
      'fajitas', 'quesadilla', 'sopes'
    ],
    italiana: [
      'italiana', 'pasta', 'pastas', 'pizza', 'risotto', 'pesto', 'lasagna',
      'lasaña', 'parmesano', 'albahaca', 'pomodoro', 'carbonara', 'ravioli',
      'espagueti', 'fettuccine', 'mozzarella', 'gnocchi'
    ],
    japonesa: [
      'japonesa', 'sushi', 'ramen', 'teriyaki', 'miso', 'edamames', 'edamame',
      'tempura', 'udon', 'gyoza', 'yakitori', 'soba', 'wakame', 'ajonjoli', 'wasabi'
    ],
    thai: [
      'thai', 'pad thai', 'curry thai', 'curry verde', 'curry rojo', 'coco',
      'leche de coco', 'lemon grass', 'cacahuate', 'jengibre', 'fideos de arroz',
      'tamarindo'
    ],
    francesa: [
      'francesa', 'quiche', 'ratatouille', 'crepas', 'crepa', 'souffle',
      'bechamel', 'dijon', 'bourguignon', 'mostaza dijon', 'hierbas provenzales'
    ],
    espanola: [
      'espanola', 'española', 'paella', 'tapas', 'tortilla espanola',
      'tortilla de patata', 'gazpacho', 'azafran', 'jamon serrano', 'aioli'
    ],
    mediterranea: [
      'mediterranea', 'mediterránea', 'hummus', 'falafel', 'tzatziki',
      'aceituna', 'aceitunas', 'feta', 'aceite de oliva', 'pita', 'garbanzos'
    ],
    china: [
      'china', 'arroz frito', 'chow mein', 'agridulce', 'dumplings', 'dumpling',
      'wonton', 'soya', 'salsa de soya', 'wok', 'sichuan', 'chop suey'
    ],
    india: [
      'india', 'curry indio', 'tikka masala', 'naan', 'garam masala',
      'lentejas', 'dal', 'biryani', 'curcuma', 'tandoori'
    ],
    americana: [
      'americana', 'hamburguesa', 'burger', 'bbq', 'costillas', 'mac and cheese',
      'alitas', 'pancakes', 'waffles', 'coleslaw'
    ],
  };

  /// Serializa la lista para almacenamiento (ej. "Mexicana,Italiana")
  static String serializar(Iterable<String> seleccion) =>
      normalizar(seleccion).join(',');

  /// Deserializa texto a lista de tipos válidos
  static List<String> deserializar(String? texto) {
    if (texto == null || texto.trim().isEmpty) return [todas];
    return normalizar(texto.split(','));
  }

  /// Limpia duplicados y normaliza. Si queda vacío, asigna "Variada / Todas".
  static List<String> normalizar(Iterable<String> seleccion) {
    final limpios = seleccion
        .map((e) => e.trim())
        .where((e) => lista.contains(e) && e != todas)
        .toSet()
        .toList();
    return limpios.isEmpty ? [todas] : limpios;
  }

  /// Verifica si el texto de una receta encaja con alguno de los tipos seleccionados
  static bool recetaCoincide(String texto, List<String> seleccion) {
    if (seleccion.contains(todas) || seleccion.isEmpty) return true;
    final t = texto.toLowerCase();
    for (final tipo in seleccion) {
      if (t.contains(tipo.toLowerCase())) return true;
      final palabras = palabrasClave[tipo];
      if (palabras != null) {
        for (final p in palabras) {
          if (t.contains(p.toLowerCase())) return true;
        }
      }
    }
    return false;
  }

  /// Instrucciones de estilo culinario para el prompt del Chef IA
  static String promptChefIA(List<String> seleccion) {
    if (seleccion.contains(todas) || seleccion.isEmpty) {
      return 'Cocina variada global (puedes combinar sabores mexicanos, mediterráneos, asiáticos, etc.)';
    }
    final listaNombres = seleccion.map((t) => '${iconos[t] ?? ""} $t').join(', ');
    return 'Enfócate con alta prioridad en las siguientes cocinas: $listaNombres. '
        'Asegúrate de que los platillos tengan sabores, ingredientes y técnicas características de estas culturas gastronómicas, adaptadas a insumos comúnmente disponibles en México.';
  }
}
