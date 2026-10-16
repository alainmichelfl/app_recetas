class UtensilioItem {
  final String id;
  final String nombre;
  final String icono;
  final String descripcion;
  final bool activoPorDefecto;
  final List<String> palabrasClave;

  const UtensilioItem({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.descripcion,
    this.activoPorDefecto = false,
    this.palabrasClave = const [],
  });
}

class UtensiliosCocina {
  static const List<UtensilioItem> catalogo = [
    UtensilioItem(
      id: 'sarten',
      nombre: 'Sartén y Estufa',
      icono: '🍳',
      descripcion: 'Sartén antiadherente, comal u olla a fuego directo',
      activoPorDefecto: true,
      palabrasClave: ['sartén', 'sarten', 'comal', 'estufa', 'freír', 'sofreír', 'hervir', 'dorar'],
    ),
    UtensilioItem(
      id: 'licuadora',
      nombre: 'Licuadora / Procesador',
      icono: '🌪️',
      descripcion: 'Para triturar salsas, licuados, purés y caldos',
      activoPorDefecto: true,
      palabrasClave: ['licuadora', 'licuar', 'licúa', 'licue', 'procesador', 'procesar'],
    ),
    UtensilioItem(
      id: 'nutribullet',
      nombre: 'Nutribullet / Personal',
      icono: '🥤',
      descripcion: 'Extractor para smoothies, batidos de proteína y bowls express',
      activoPorDefecto: false,
      palabrasClave: [
        'nutribullet',
        'nutri bullet',
        'licuadora personal',
        'magic bullet',
        'ninja personal',
        'smoothie',
        'batido de proteína',
        'smoothie bowl',
      ],
    ),
    UtensilioItem(
      id: 'horno',
      nombre: 'Horno Convencional',
      icono: '🍞',
      descripcion: 'Horno de gas/eléctrico para gratinar, hornear y asar',
      activoPorDefecto: false,
      palabrasClave: ['horno', 'hornear', 'hornea', 'precalentar horno', 'gratinar', 'charola para hornear'],
    ),
    UtensilioItem(
      id: 'air_fryer',
      nombre: 'Freidora de Aire',
      icono: '🍟',
      descripcion: 'Cocción crujiente por convección rápida sin aceite',
      activoPorDefecto: false,
      palabrasClave: ['air fryer', 'freidora de aire', 'canastilla de la freidora'],
    ),
    UtensilioItem(
      id: 'thermomix',
      nombre: 'Thermomix / Robot',
      icono: '🤖',
      descripcion: 'Robot inteligente con control de temperatura y cuchillas',
      activoPorDefecto: false,
      palabrasClave: ['thermomix', 'varoma', 'vaso de thermomix', 'giro inverso'],
    ),
    UtensilioItem(
      id: 'olla_presion',
      nombre: 'Olla de Presión',
      icono: '⚡',
      descripcion: 'Olla exprés o Instant Pot para cocción ultra rápida',
      activoPorDefecto: false,
      palabrasClave: ['olla de presión', 'olla exprés', 'olla expres', 'instant pot', 'a presión'],
    ),
    UtensilioItem(
      id: 'microondas',
      nombre: 'Horno de Microondas',
      icono: '♨️',
      descripcion: 'Descongelar, calentar y cocer al vapor en minutos',
      activoPorDefecto: true,
      palabrasClave: ['microondas', 'en el microondas', 'calentar al micro'],
    ),
    UtensilioItem(
      id: 'sandwichera',
      nombre: 'Sandwichera / Waflera',
      icono: '🥪',
      descripcion: 'Prensa para paninis, sándwiches tostados y wafles',
      activoPorDefecto: false,
      palabrasClave: ['sandwichera', 'waflera', 'tostador de pan', 'panini maker'],
    ),
    UtensilioItem(
      id: 'batidora',
      nombre: 'Batidora de Mano / Turmix',
      icono: '🥣',
      descripcion: 'Batidora de inmersión para cremas o batir claras',
      activoPorDefecto: false,
      palabrasClave: ['batidora', 'batir a punto de nieve', 'turmix', 'batidora de inmersión'],
    ),
    UtensilioItem(
      id: 'parrilla',
      nombre: 'Parrilla / Asador',
      icono: '🥩',
      descripcion: 'Asador al carbón o grill para carnes y verduras tatemadas',
      activoPorDefecto: false,
      palabrasClave: ['asador', 'a la parrilla', 'al carbón', 'parrillada', 'tatemar al carbón'],
    ),
  ];

  /// Lista de IDs por defecto
  static List<String> get porDefecto =>
      catalogo.where((u) => u.activoPorDefecto).map((u) => u.id).toList();

  /// Deserializa string guardado (ej. "sarten,licuadora,air_fryer")
  static List<String> deserializar(String? raw) {
    if (raw == null || raw.trim().isEmpty) return porDefecto;
    final tokens = raw.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toList();
    final idsValidos = catalogo.map((u) => u.id).toSet();
    final filtrados = tokens.where((t) => idsValidos.contains(t)).toList();
    return filtrados.isEmpty ? porDefecto : filtrados;
  }

  /// Serializa lista de IDs a string separado por comas
  static String serializar(List<String> ids) {
    return ids.toSet().join(',');
  }

  /// Obtiene un item por su ID
  static UtensilioItem? obtener(String id) {
    final lower = id.toLowerCase();
    for (var u in catalogo) {
      if (u.id == lower) return u;
    }
    return null;
  }

  /// Analiza si una receta requiere algún equipo que el usuario NO tiene registrado.
  /// Retorna la lista de utensilios faltantes para esa receta.
  static List<UtensilioItem> detectarUtensiliosFaltantes({
    required String textoReceta,
    required List<String> misUtensilios,
  }) {
    final textoLower = textoReceta.toLowerCase();
    final setMisUtensilios = misUtensilios.map((e) => e.toLowerCase()).toSet();
    final List<UtensilioItem> faltantes = [];

    for (var item in catalogo) {
      // Si el usuario ya lo tiene, no falta
      if (setMisUtensilios.contains(item.id)) continue;

      // Sartén y estufa son tan básicos que no marcamos advertencia a menos que falte algo específico
      if (item.id == 'sarten') continue;

      // Buscar si el texto menciona palabras clave del utensilio
      for (var palabra in item.palabrasClave) {
        if (textoLower.contains(palabra)) {
          faltantes.add(item);
          break;
        }
      }
    }

    return faltantes;
  }

  /// Genera texto amigable para inyectar en el prompt del Chef IA
  static String instruccionesPrompt(List<String> misUtensilios) {
    if (misUtensilios.isEmpty) return '';

    final nombresTengo = misUtensilios
        .map((id) => obtener(id)?.nombre)
        .whereType<String>()
        .toList();

    final noTengo = catalogo
        .where((u) => !misUtensilios.contains(u.id))
        .map((u) => u.nombre)
        .toList();

    final sb = StringBuffer();
    sb.writeln('- EQUIPO Y UTENSILIOS DISPONIBLES EN LA COCINA DEL USUARIO: ${nombresTengo.join(', ')}.');
    if (noTengo.isNotEmpty) {
      sb.writeln('  * RESTRICCIÓN DE EQUIPO (MUY IMPORTANTE): El usuario NO TIENE: ${noTengo.join(', ')}. PROHIBIDO diseñar recetas que obligatoriamente requieran estos equipos ausentes (ej. si no tiene horno, no pidas hornear; si no tiene air fryer, no pidas freidora de aire; adáptalo a sartén o estufa).');
    }

    return sb.toString().trim();
  }
}
