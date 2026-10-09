import 'package:supabase_flutter/supabase_flutter.dart';

/// Conversor inteligente y homogéneo de unidades culinarias a unidades de supermercado.
/// Permite que la lista de compras, cotizaciones de súper y despensa no se confundan con
/// "pizcas", "cucharaditas", "gramos sueltos" o "mililitros".
class ItemSupermercado {
  final String nombre;
  final double cantidad; // Valor numérico para cálculos (ej. 0.5 para 0.5 kg, 1.0 para 1 frasco)
  final String unidad; // "kg", "L", "pza", "manojo", "frasco", "paquete", "lata", "cabeza", "botella"
  final String textoCantidad; // Texto formateado para mostrar en la app: "0.5 kg", "1 manojo", "1 frasco"

  const ItemSupermercado({
    required this.nombre,
    required this.cantidad,
    required this.unidad,
    required this.textoCantidad,
  });

  @override
  String toString() => '$textoCantidad $nombre';
}

class ConversorUnidades {
  ConversorUnidades._();

  /// Quita acentos para comparaciones robustas e insensibles a diacríticos
  static String sinAcentos(String s) {
    return s
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

  /// Comprueba si dos nombres de ingredientes coinciden de forma inteligente,
  /// evitando falsos positivos por subcadenas cortas (ej. "agua" en "aguacate").
  static bool nombresCoinciden(String a, String b) {
    final cleanA = sinAcentos(a).trim();
    final cleanB = sinAcentos(b).trim();
    if (cleanA.isEmpty || cleanB.isEmpty) return false;
    if (cleanA == cleanB) return true;

    // Distinguir explícitamente manzana verde vs manzana roja
    if ((cleanA.contains('verde') && cleanB.contains('roja')) ||
        (cleanA.contains('roja') && cleanB.contains('verde'))) {
      return false;
    }

    // Chocolates y chispas: para repostería y cotización en súper, chispas y chocolate amargo/70% coinciden
    final bool aChoc = cleanA.contains('chispas') || cleanA.contains('chocolate');
    final bool bChoc = cleanB.contains('chispas') || cleanB.contains('chocolate');
    if (aChoc && bChoc) {
      final bool aBlanco = cleanA.contains('blanco');
      final bool bBlanco = cleanB.contains('blanco');
      if (aBlanco != bBlanco) return false;

      final bool aLeche = cleanA.contains('con leche');
      final bool bLeche = cleanB.contains('con leche');
      if (aLeche != bLeche) return false;

      return true;
    }

    // Si alguno es corto (<= 4 letras como "agua", "sal", "ajo"), exigir palabra completa
    if (cleanA.length <= 4 || cleanB.length <= 4) {
      final regA = RegExp(r'\b' + RegExp.escape(cleanA) + r'\b');
      final regB = RegExp(r'\b' + RegExp.escape(cleanB) + r'\b');
      return regA.hasMatch(cleanB) || regB.hasMatch(cleanA);
    }

    return cleanA.contains(cleanB) || cleanB.contains(cleanA);
  }

  // 🌿 Hierbas frescas: en el súper o verdulería siempre se compran por manojo
  static const Set<String> _hierbasFrescas = {
    'cilantro',
    'perejil',
    'epazote',
    'hierbabuena',
    'menta',
    'albahaca',
    'romero',
    'tomillo',
    'eneldo',
    'cebollin',
    'cebollino',
    'laurel fresco',
    'estragon',
    'mejorana',
    'espinaca',
    'espinacas',
    'berros',
    'arugula',
    'acelga',
    'esparrago',
    'esparragos',
  };

  // 🧂 Especias secas y condimentos: no compras una pizca, compras 1 frasco / sobre
  static const Set<String> _especiasYCondimentos = {
    'sal',
    'sal fina',
    'sal de grano',
    'sal marina',
    'pimienta',
    'pimienta negra',
    'pimienta molida',
    'oregano',
    'oregano seco',
    'comino',
    'canela',
    'canela molida',
    'paprika',
    'pimenton',
    'clavo',
    'nuez moscada',
    'ajo en polvo',
    'cebolla en polvo',
    'polvo para hornear',
    'bicarbonato',
    'levadura',
    'curcuma',
    'chile en polvo',
    'consome',
    'caldo de pollo en polvo',
    'achiote',
    'romero',
    'romero seco',
    'romero fresco',
    'tomillo',
    'tomillo seco',
    'laurel',
  };

  // 🫒 Aceites, vinagres y salsas / abarrotes líquidos y condimentos de alacena:
  static const Set<String> _aceitesYSalsas = {
    'aceite de oliva',
    'aceite de oliva extra virgen',
    'aceite vegetal',
    'aceite de canola',
    'aceite de maiz',
    'aceite de aguacate',
    'aceite de coco',
    'aceite de ajonjoli',
    'aceite en spray',
    'aceite',
    'vinagre',
    'vinagre blanco',
    'vinagre de manzana',
    'vinagre balsamico',
    'salsa de soya',
    'salsa inglesa',
    'salsa maggi',
    'vainilla',
    'extracto de vainilla',
    'miel',
    'miel de abeja',
    'miel de agave',
    'mostaza',
    'mayonesa',
    'aderezo',
    'aderezo cesar',
    'guacamole',
    'endulzante sin calorias',
    'endulzante',
    'stevia',
    'splenda',
    'monk fruit',
    'tajin',
    'chile en polvo tajin',
  };

  // 🥜 Frutos secos, semillas y botanas: en el súper se compran por paquete / bolsa (no piezas sueltas)
  static const Set<String> _frutosSecosYBotanas = {
    'almendra',
    'almendras',
    'nuez',
    'nueces',
    'nuez pecana',
    'nuez de castilla',
    'cacahuate',
    'cacahuates',
    'cacahuete',
    'cacahuetes',
    'arandano',
    'arandanos',
    'pasa',
    'pasas',
    'pasitas',
    'pistache',
    'pistaches',
    'semilla de girasol',
    'semillas de girasol',
    'semilla de calabaza',
    'semillas de calabaza',
    'pepitas',
    'chia',
    'linaza',
    'ajonjoli',
    'semilla de ajonjoli',
    'semillas de ajonjoli',
    'amaranto',
    'amaranto natural',
    'amaranto tostado',
    'maiz palomero',
    'palomitas',
    'edamame',
    'edamames',
    'vainas de edamame',
    'chispas de chocolate',
    'chispas de chocolate amargo',
    'chispas de chocolate 70% cacao',
    'chispas de chocolate semiamargo',
    'chocolate amargo',
    'chocolate amargo 70% cacao',
    'chocolate amargo 70%',
    'chocolate 70% cacao',
  };

  // 🍞 Panadería, tostadas, tortillas, galletas: se compran por paquete (no 4 tostadas sueltas)
  static const Set<String> _panaderiaYTortilleria = {
    'tostada',
    'tostadas',
    'tostadas horneadas',
    'tortilla',
    'tortillas',
    'tortillas de maiz',
    'tortillas de harina',
    'tortilla integral',
    'tortillas integrales',
    'totopos',
    'nachos',
    'galletas',
    'pan de caja',
    'pan integral',
    'pan blanco',
    'pan molido',
    'pan tostado',
    'crutones',
    'croutons',
  };

  // 🥫 Enlatados típicos
  static const Set<String> _enlatados = {
    'atun en agua',
    'atun en aceite',
    'atun enlatado',
    'lata de atun',
    'sardina',
    'sardinas',
    'elote',
    'elotes',
    'chile chipotle',
    'chiles chipotle',
    'chiles chipotles',
    'chipotle',
    'chiles en vinagre',
    'leche evaporada',
    'leche condensada',
    'media crema',
    'pure de tomate',
    'pasta de tomate',
  };

  // 🌶️ Chiles secos: en el supermercado se compran por paquete / bolsa (100g)
  static const Set<String> _chilesSecos = {
    'chile guajillo',
    'chiles guajillo',
    'guajillo',
    'chile ancho',
    'chiles anchos',
    'chile pasilla',
    'chiles pasilla',
    'chile morita',
    'chiles morita',
    'chile cascabel',
    'chile de arbol seco',
    'chiles secos',
    'chile seco',
  };

  // 🥩 Carnes y proteínas vendidas por kilo en mostrador
  static const Set<String> _carnesYProteinas = {
    'pollo',
    'pechuga',
    'pechuga de pollo',
    'pechugas de pollo',
    'pechugas',
    'muslo',
    'pierna',
    'milanesa de pollo',
    'filete de pollo',
    'bistec',
    'bistec de res',
    'carne',
    'carne de res',
    'carne de cerdo',
    'carne molida',
    'carne molida de res',
    'carne molida de pavo',
    'molida de res',
    'molida de pollo',
    'molida de pavo',
    'arrachera',
    'cerdo',
    'puerco',
    'pavo',
    'pescado',
    'filete de pescado',
    'tilapia',
    'salmon',
    'atun fresco',
    'medallon de atun',
    'camaron',
    'camarones',
  };

  // 🧀 Quesos y embutidos: se compran por paquete (250g - 400g), nunca por kilos enteros a granel
  static const Set<String> _quesosYEmbutidos = {
    'queso',
    'queso panela',
    'queso oaxaca',
    'queso manchego',
    'queso crema',
    'queso parmesano',
    'queso cottage',
    'queso mozzarella',
    'jamon',
    'jamon de pavo',
    'tocino',
    'salchicha',
    'salchichas',
  };

  // 🌾 Pastas, granos y cereales de paquete
  static const Set<String> _pastasYGranos = {
    'arroz',
    'frijol',
    'frijoles',
    'lenteja',
    'lentejas',
    'garbanzo',
    'garbanzos',
    'avena',
    'hojuelas de avena',
    'avena molida',
    'harina',
    'harina de trigo',
    'harina integral',
    'espagueti',
    'pasta',
    'fideo',
    'macarron',
    'quinoa',
    'soya texturizada',
  };

  // 🥚 Huevos
  static const Set<String> _huevos = {
    'huevo',
    'huevos',
    'clara de huevo',
    'claras de huevo',
    'blanquillo',
  };

  /// Normaliza cualquier ingrediente culinario a su presentación y unidad real de supermercado.
  static ItemSupermercado normalizarParaSupermercado(
    String nombreCrudo,
    double cantidadReceta,
    String unidadReceta,
  ) {
    if (esAgua(nombreCrudo)) {
      return const ItemSupermercado(
        nombre: 'Agua',
        cantidad: 0.0,
        unidad: '',
        textoCantidad: '',
      );
    }

    final nombreLimpio = canonicalizarNombre(nombreCrudo);
    final normNombre = sinAcentos(nombreLimpio);
    final normUnidad = sinAcentos(unidadReceta).trim();
    final double cantSegura = cantidadReceta <= 0 ? 1.0 : cantidadReceta;

    // 1. Ajos (dientes -> cabezas de ajo)
    if (normNombre.contains('ajo') &&
        !normNombre.contains('polvo') &&
        !normNombre.contains('aceite')) {
      if (normUnidad.contains('diente') || normUnidad.isEmpty || normUnidad == 'pza') {
        final cabezas = (cantSegura / 6.0).ceilToDouble().clamp(1.0, 10.0);
        return ItemSupermercado(
          nombre: 'Ajo',
          cantidad: cabezas,
          unidad: 'cabeza',
          textoCantidad: '${cabezas.toInt()} cabeza${cabezas > 1 ? 's' : ''}',
        );
      }
    }

    // 1.5. Chiles secos (chile guajillo, ancho, pasilla, etc.) -> 1 paquete (100g)
    for (var cs in _chilesSecos) {
      if (normNombre.contains(cs)) {
        return ItemSupermercado(
          nombre: _capitalizar(nombreLimpio),
          cantidad: 1.0,
          unidad: 'paquete',
          textoCantidad: '1 paquete (100g)',
        );
      }
    }

    // 2. Hierbas frescas y espárragos (cilantro, perejil, albahaca, espárragos...) -> manojo
    for (var hierba in _hierbasFrescas) {
      if (normNombre.contains(hierba)) {
        final manojos = (cantSegura < 1.0 ? 1.0 : cantSegura.ceilToDouble()).clamp(1.0, 10.0);
        return ItemSupermercado(
          nombre: _capitalizar(hierba),
          cantidad: manojos,
          unidad: 'manojo',
          textoCantidad: '${manojos.toInt()} manojo${manojos > 1 ? 's' : ''}',
        );
      }
    }

    // 2.5. Pescados y mariscos frescos (medallón de atún fresco, atún fresco, salmón, pescado) -> piezas o kg (NUNCA latas)
    if (normNombre.contains('medallon') ||
        (normNombre.contains('atun') && (normNombre.contains('fresco') || (!normNombre.contains('agua') && !normNombre.contains('aceite') && !normNombre.contains('lata'))))) {
      final pzas = cantSegura.ceilToDouble().clamp(1.0, 20.0);
      return ItemSupermercado(
        nombre: 'Medallón de atún fresco',
        cantidad: pzas,
        unidad: 'pza',
        textoCantidad: '${pzas.toInt()} pza${pzas > 1 ? 's' : ''}',
      );
    }

    // 2.6. Jitomate Saladet / bola fresco -> piezas o kg (¡NUNCA jamás frasco!)
    if (normNombre.contains('jitomate') &&
        !normNombre.contains('pure') &&
        !normNombre.contains('pasta')) {
      if (normUnidad.contains('kg') || normUnidad.contains('kilo')) {
        final kg = (cantSegura * 100).round() / 100.0;
        return ItemSupermercado(
          nombre: 'Jitomate Saladet',
          cantidad: kg,
          unidad: 'kg',
          textoCantidad: '$kg kg',
        );
      } else if (normUnidad.contains('g') || (cantSegura > 15 && !normUnidad.contains('pza'))) {
        final kg = ((cantSegura / 1000.0) * 100).round() / 100.0;
        return ItemSupermercado(
          nombre: 'Jitomate Saladet',
          cantidad: kg,
          unidad: 'kg',
          textoCantidad: '$kg kg',
        );
      } else {
        final pzas = cantSegura.ceilToDouble().clamp(1.0, 30.0);
        return ItemSupermercado(
          nombre: 'Jitomate Saladet',
          cantidad: pzas,
          unidad: 'pza',
          textoCantidad: '${pzas.toInt()} pza${pzas > 1 ? 's' : ''}',
        );
      }
    }

    // 2.7. Tomate cherry o baby -> paquete (domo)
    if (normNombre.contains('cherry') || normNombre.contains('tomate baby')) {
      final double paquetes = (cantSegura > 10 ? (cantSegura / 250.0) : 1.0).ceilToDouble().clamp(1.0, 10.0);
      return ItemSupermercado(
        nombre: 'Tomate cherry',
        cantidad: paquetes,
        unidad: 'paquete',
        textoCantidad: '${paquetes.toInt()} paquete${paquetes > 1 ? 's' : ''} (domo)',
      );
    }

    // 2.8. Frutos rojos, berries, frambuesas, zarzamoras -> paquete / domo (¡NUNCA 1 sola pieza!)
    if (normNombre.contains('frutos rojos') ||
        normNombre.contains('fruto rojo') ||
        normNombre.contains('frutos del bosque') ||
        normNombre.contains('berries') ||
        normNombre.contains('zarzamora') ||
        normNombre.contains('frambuesa') ||
        normNombre.contains('mora azul')) {
      final double paquetes = (cantSegura > 10 ? (cantSegura / 250.0) : 1.0).ceilToDouble().clamp(1.0, 10.0);
      return ItemSupermercado(
        nombre: _capitalizar(nombreLimpio),
        cantidad: paquetes,
        unidad: 'paquete',
        textoCantidad: '${paquetes.toInt()} paquete${paquetes > 1 ? 's' : ''}',
      );
    }

    // 2.9. Agua de coco -> Litros (L) o botella
    if (normNombre.contains('agua de coco')) {
      double litros = cantSegura;
      if (normUnidad.contains('ml')) {
        litros = cantSegura / 1000.0;
      } else if (normUnidad.contains('taza') || normUnidad.contains('vaso')) {
        litros = cantSegura * 0.25;
      } else if (normUnidad.contains('pza') || normUnidad.contains('pieza') || normUnidad.isEmpty) {
        litros = cantSegura;
      }
      final double lRedondeado = (litros * 100).round() / 100.0;
      final String formattedL = lRedondeado == lRedondeado.toInt()
          ? '${lRedondeado.toInt()}'
          : lRedondeado.toStringAsFixed(2);
      return ItemSupermercado(
        nombre: 'Agua de coco',
        cantidad: lRedondeado,
        unidad: 'L',
        textoCantidad: '$formattedL L',
      );
    }

    // 3. Especias secas y condimentos (pizca, cdita, cda) -> 1 frasco / sobre
    for (var especia in _especiasYCondimentos) {
      if (normNombre.contains(especia)) {
        return ItemSupermercado(
          nombre: _capitalizar(nombreLimpio),
          cantidad: 1.0,
          unidad: 'frasco',
          textoCantidad: '1 frasco',
        );
      }
    }

    // 4. Aceites, vinagres y salsas condimentarias (cucharada, chorrito) -> 1 botella / frasco
    for (var aceite in _aceitesYSalsas) {
      if (normNombre.contains(aceite)) {
        return ItemSupermercado(
          nombre: _capitalizar(nombreLimpio),
          cantidad: 1.0,
          unidad: 'botella',
          textoCantidad: '1 botella',
        );
      }
    }

    // 5. Enlatados (atún en agua, elotes, chipotles) -> latas
    // Se valida ANTES de líquidos para que "atún en agua" nunca se marque como líquido.
    for (var lata in _enlatados) {
      if (normNombre.contains(lata) &&
          !normNombre.contains('fresco') &&
          !normNombre.contains('medallon')) {
        final double numLatas = cantSegura < 1.0 ? 1.0 : cantSegura.ceilToDouble();
        return ItemSupermercado(
          nombre: _capitalizar(nombreLimpio),
          cantidad: numLatas,
          unidad: 'lata',
          textoCantidad: '${numLatas.toInt()} lata${numLatas > 1 ? 's' : ''}',
        );
      }
    }

    // 6. Frutos secos, semillas y botanas (almendras, nueces, ajonjolí, etc.) -> paquete / bolsa
    // Un súper nunca vende 4 almendras sueltas ni litros de semillas.
    for (var botana in _frutosSecosYBotanas) {
      if (normNombre.contains(botana)) {
        double paquetes = 1.0;
        if (normUnidad.contains('kg') || normUnidad.contains('kilo')) {
          paquetes = cantSegura.ceilToDouble().clamp(1.0, 10.0);
        } else if (normUnidad.contains('g') || normUnidad.contains('gram')) {
          paquetes = (cantSegura / 250.0).ceilToDouble().clamp(1.0, 10.0);
        }
        return ItemSupermercado(
          nombre: _capitalizar(nombreLimpio),
          cantidad: paquetes,
          unidad: 'paquete',
          textoCantidad: '${paquetes.toInt()} paquete${paquetes > 1 ? 's' : ''}',
        );
      }
    }

    // 7. Panadería, tostadas, tortillas, galletas, totopos -> paquete
    // Un supermercado no vende 4 tostadas sueltas: vende 1 paquete.
    for (var pan in _panaderiaYTortilleria) {
      if (normNombre.contains(pan)) {
        double paquetes = 1.0;
        if (normUnidad.contains('kg') || normUnidad.contains('kilo')) {
          paquetes = cantSegura.ceilToDouble().clamp(1.0, 10.0);
        } else if (cantSegura > 15) {
          paquetes = (cantSegura / 20.0).ceilToDouble().clamp(1.0, 10.0);
        }
        return ItemSupermercado(
          nombre: _capitalizar(nombreLimpio),
          cantidad: paquetes,
          unidad: 'paquete',
          textoCantidad: '${paquetes.toInt()} paquete${paquetes > 1 ? 's' : ''}',
        );
      }
    }

    // 8. Huevos -> cartón (cartera de 12 o 18 pzas)
    for (var h in _huevos) {
      if (normNombre.contains(h)) {
        final double cartones = cantSegura <= 18.0
            ? 1.0
            : (cantSegura / 18.0).ceilToDouble().clamp(1.0, 5.0);
        return ItemSupermercado(
          nombre: 'Huevo',
          cantidad: cartones,
          unidad: 'cartón',
          textoCantidad: '${cartones.toInt()} cartón${cartones > 1 ? 'es' : ''} (cartera 12-18 pzas)',
        );
      }
    }

    // 8.5. Quesos y embutidos de paquete (panela, manchego, jamón) -> paquetes
    for (var q in _quesosYEmbutidos) {
      if (normNombre.contains(q)) {
        double paquetes = 1.0;
        if (normUnidad.contains('kg') || normUnidad.contains('kilo')) {
          paquetes = cantSegura.ceilToDouble().clamp(1.0, 5.0);
        } else if (cantSegura > 400) {
          paquetes = (cantSegura / 400.0).ceilToDouble().clamp(1.0, 5.0);
        }
        return ItemSupermercado(
          nombre: _capitalizar(nombreLimpio),
          cantidad: paquetes,
          unidad: 'paquete',
          textoCantidad: '${paquetes.toInt()} paquete${paquetes > 1 ? 's' : ''}',
        );
      }
    }

    // 9. Carnes y proteínas a granel -> Kilogramos (kg)
    for (var carne in _carnesYProteinas) {
      if (normNombre.contains(carne)) {
        double kg = cantSegura;
        final bool esYaKg = normUnidad == 'kg' ||
            normUnidad == 'kilo' ||
            normUnidad == 'kilos' ||
            normUnidad == 'kilogramo' ||
            normUnidad == 'kilogramos';

        if (esYaKg) {
          kg = cantSegura; // Ya viene en kg, ¡NUNCA dividir entre 1000!
        } else if (normUnidad.contains('g') || normUnidad.contains('gram') || cantSegura > 20) {
          kg = cantSegura / 1000.0;
        } else if (normUnidad.contains('pza') ||
            normUnidad.contains('bistec') ||
            normUnidad.contains('filete') ||
            normUnidad.contains('pechuga') ||
            normUnidad.contains('medallon') ||
            normNombre.contains('pechuga') ||
            normNombre.contains('filete') ||
            normNombre.contains('bistec') ||
            normNombre.contains('medallon')) {
          kg = cantSegura * 0.2; // Aprox 200g por pieza o filete
        } else if (normUnidad.contains('rebanada')) {
          kg = cantSegura * 0.03; // Aprox 30g por rebanada de jamón o queso
        }
        if (kg < 0.1) kg = 0.1; // Garantizar que nunca sea 0 kg
        final double kgRedondeado = (kg * 100).round() / 100.0;
        final String formattedKg = kgRedondeado == kgRedondeado.toInt()
            ? '${kgRedondeado.toInt()}'
            : kgRedondeado.toStringAsFixed(2);
        return ItemSupermercado(
          nombre: _capitalizar(nombreLimpio),
          cantidad: kgRedondeado,
          unidad: 'kg',
          textoCantidad: '$formattedKg kg',
        );
      }
    }

    // 10. Pastas y granos secos -> paquetes
    for (var grano in _pastasYGranos) {
      if (normNombre.contains(grano)) {
        double paquetes = 1.0;
        if (normUnidad.contains('kg') || normUnidad.contains('kilo')) {
          paquetes = cantSegura.ceilToDouble().clamp(1.0, 10.0);
        } else if (cantSegura > 2) {
          paquetes = (cantSegura / 2.0).ceilToDouble().clamp(1.0, 10.0);
        }
        return ItemSupermercado(
          nombre: _capitalizar(nombreLimpio),
          cantidad: paquetes,
          unidad: 'paquete',
          textoCantidad: '${paquetes.toInt()} paquete${paquetes > 1 ? 's' : ''}',
        );
      }
    }

    // 11. Líquidos a granel (leche, caldo, jugo, agua sola o de coco) -> Litros (L)
    // REGLA FUNDAMENTAL: ¡NUNCA confundir 'aguacate' con 'agua', ni 'en agua'!
    final bool esLiquidoPorNombre = normNombre.contains('leche') ||
        normNombre.contains('caldo') ||
        normNombre.contains('jugo') ||
        normNombre.contains('yogurt') ||
        normNombre.contains('yogur') ||
        (RegExp(r'\bagua\b').hasMatch(normNombre) &&
            !normNombre.contains('aguacate') &&
            !normNombre.contains('en agua'));

    final bool esUnidadLiquida = normUnidad == 'l' ||
        normUnidad == 'lt' ||
        normUnidad == 'lts' ||
        normUnidad == 'litro' ||
        normUnidad == 'litros' ||
        normUnidad == 'ml' ||
        normUnidad == 'mililitro' ||
        normUnidad == 'mililitros' ||
        (esLiquidoPorNombre && (normUnidad.contains('taza') || normUnidad.contains('vaso')));

    if (esLiquidoPorNombre || esUnidadLiquida) {
      double litros = cantSegura;
      if (normUnidad.contains('ml') || (cantSegura > 20 && !esLiquidoPorNombre)) {
        litros = cantSegura / 1000.0;
      } else if (normUnidad.contains('taza') || normUnidad.contains('vaso')) {
        litros = cantSegura * 0.25;
      }
      final double lRedondeado = (litros * 100).round() / 100.0;
      final String formattedL = lRedondeado == lRedondeado.toInt()
          ? '${lRedondeado.toInt()}'
          : lRedondeado.toStringAsFixed(2);
      return ItemSupermercado(
        nombre: _capitalizar(nombreLimpio),
        cantidad: lRedondeado,
        unidad: 'L',
        textoCantidad: '$formattedL L',
      );
    }

    // 12. Peso genérico en gramos -> kg
    if (normUnidad == 'g' || normUnidad == 'gr' || normUnidad == 'gramo' || normUnidad == 'gramos') {
      final double kg = (cantSegura / 1000.0);
      final double kgRedondeado = (kg * 100).round() / 100.0;
      return ItemSupermercado(
        nombre: _capitalizar(nombreLimpio),
        cantidad: kgRedondeado,
        unidad: 'kg',
        textoCantidad: '$kgRedondeado kg',
      );
    }

    // 13. Peso genérico en kilos -> kg
    if (normUnidad == 'kg' || normUnidad == 'kilo' || normUnidad == 'kilos' || normUnidad == 'kilogramo') {
      final double kgRedondeado = (cantSegura * 100).round() / 100.0;
      return ItemSupermercado(
        nombre: _capitalizar(nombreLimpio),
        cantidad: kgRedondeado,
        unidad: 'kg',
        textoCantidad: '$kgRedondeado kg',
      );
    }

    // 14. Pizcas o cucharadas genéricas sin clasificar -> 1 frasco
    if (normUnidad.contains('pizca') ||
        normUnidad.contains('cda') ||
        normUnidad.contains('cucharad')) {
      return ItemSupermercado(
        nombre: _capitalizar(nombreLimpio),
        cantidad: 1.0,
        unidad: 'frasco',
        textoCantidad: '1 frasco',
      );
    }

    // 15. Por defecto: Piezas (pza) para verduras, frutas y productos enteros
    // (Ej. Aguacate hass -> 1 pza, Limón -> 3 pzas, Cebolla -> 1 pza, Jitomate -> 2 pzas)
    final double pzas = cantSegura.ceilToDouble();
    return ItemSupermercado(
      nombre: _capitalizar(nombreLimpio),
      cantidad: pzas,
      unidad: 'pza',
      textoCantidad: '${pzas.toInt()} pza${pzas > 1 ? 's' : ''}',
    );
  }

  /// Parsea una línea en texto libre (ej: "- 500 g de pechuga de pollo", "- 4 tostadas", "- 1 aguacate hass")
  static ItemSupermercado parsearLineaIngrediente(String linea) {
    String l = linea.trim();
    if (esAgua(l)) {
      return const ItemSupermercado(
        nombre: 'Agua',
        cantidad: 0.0,
        unidad: '',
        textoCantidad: '',
      );
    }

    if (l.startsWith('-') || l.startsWith('*') || l.startsWith('•')) {
      l = l.substring(1).trim();
    }

    // Extraer número o fracción (ej: "1/2", "0.5", "500", "2")
    double cantidad = 1.0;
    final matchFraccion = RegExp(r'^(\d+)/(\d+)').firstMatch(l);
    final matchDecimal = RegExp(r'^(\d+(?:[\.,]\d+)?)').firstMatch(l);

    if (matchFraccion != null) {
      final num = double.tryParse(matchFraccion.group(1)!) ?? 1.0;
      final den = double.tryParse(matchFraccion.group(2)!) ?? 1.0;
      cantidad = den > 0 ? (num / den) : 1.0;
      l = l.substring(matchFraccion.group(0)!.length).trim();
    } else if (matchDecimal != null) {
      cantidad = double.tryParse(matchDecimal.group(1)!.replaceAll(',', '.')) ?? 1.0;
      l = l.substring(matchDecimal.group(1)!.length).trim();
    }

    // Extraer unidad segura
    String unidad = '';
    final matchUnidad = RegExp(
      r'^(litros?|lts?|lt|kilogramos?|kilos?|kg|gramos?|gr|mililitros?|mls?|ml|cucharaditas?|cditas?|cucharadas?|cdas?|paquetes?|bolsas?|latas?|piezas?|pzas?|frascos?|botes?|dientes?|manojos?|ramitas?|ramas?|rebanadas?|tazas?|vasos?|pizcas?|cuadros?|l\b|g\b)(?=\s|\.|$|\d)',
      caseSensitive: false,
    ).firstMatch(l);

    if (matchUnidad != null) {
      unidad = matchUnidad.group(1)!.toLowerCase();
      l = l.substring(matchUnidad.group(0)!.length).trim();
      if (l.startsWith('.')) l = l.substring(1).trim();
    }

    // Limpiar conectores como "de", "del"
    l = l.replaceFirst(RegExp(r'^(de\s+|del\s+)', caseSensitive: false), '').trim();

    return normalizarParaSupermercado(l, cantidad, unidad);
  }

  /// Verifica si un ingrediente es agua para cocinar (la cual no se agrega a la lista de compras)
  static bool esAgua(String s) {
    final clean = sinAcentos(s).trim();
    if (clean.contains('coco') || clean.contains('mineral') || clean.contains('gas')) {
      return false;
    }
    if (clean.contains('caldo') || clean.contains('consome')) {
      return false;
    }
    final regAgua = RegExp(
      r'^(?:tazas?|vasos?|litros?|lts?|lt|l|ml|mililitros?|gotas?|chorritos?|\d+(?:[\.,]\d+)?\s*(?:tazas?|vasos?|l|lt|lts|ml)?\s*(?:de\s+)?)?agua(?:\s+(?:natural|purificada|fria|tibia|caliente|de la llave|potable|hervida|corriente))?$',
    );
    if (regAgua.hasMatch(clean)) return true;
    if (clean == 'agua') return true;
    return false;
  }

  /// Limpia cortes, técnicas culinarias, adjetivos de tamaño y homóloga sinónimos
  /// a nombres de producto reales de anaquel de supermercado.
  static String canonicalizarNombre(String s) {
    var r = s.trim();

    // 1. Quitar notas entre paréntesis (ej: "jitomate (maduro)" -> "jitomate")
    r = r.replaceAll(RegExp(r'\([^)]*\)'), '').trim();

    // 2. Si dice "agua o caldo...", normalizar directamente a Caldo vegetal
    final sNorm = sinAcentos(r);
    if (sNorm.contains('agua o caldo') || sNorm.contains('itros de agua o caldo')) {
      return 'Caldo vegetal';
    }

    // 3. Quitar números, fracciones y puntos iniciales (ej: "2 pechugas", "1 papa", ".025 chipotle")
    r = r.replaceFirst(RegExp(r'^[\d\.,\/\s]+'), '').trim();

    // 4. Quitar palabras de unidad/corte iniciales seguidas de "de" o "del" (ej: "cuadros de chocolate", "hojuelas de avena", "vainas de edamame")
    r = r.replaceFirst(
      RegExp(
        r'^(?:cuadros?|piezas?|pzas?|rebanadas?|filetes?|tiras?|trozos?|dientes?|hojuelas?|latas?|paquetes?|cucharadas?|tazas?|litros?|kilos?|vainas?|medallones?)\s+(?:de\s+|del\s+)',
        caseSensitive: false,
      ),
      '',
    ).trim();

    // 5. Quitar palabras de corte, preparación culinaria y adjetivos descriptivos
    r = r.replaceAll(
      RegExp(
        r'\b(en cubos|en cubitos|cortad[ao]s? en cubos|en tiras|en rodajas|en juliana|en trozos|en cuadritos|picad[ao]s?|finamente picad[ao]s?|rebanad[ao]s?|finamente rebanad[ao]s?|rallad[ao]s?|trocead[ao]s?|lavad[ao]s? y trocead[ao]s?|deshuesad[ao]s?|a la parrilla|asado|cocid[ao]s? y picad[ao]s?|cocid[ao]s?|limpi[ao]s?|congelad[ao]s?|para wrap o burrito|para wrap|para burrito|para decorar|para freir|al gusto|opcional|pequeñ[ao]s?|median[ao]s?|grand[es]*)\b',
        caseSensitive: false,
      ),
      '',
    ).trim();

    // Quitar espacios repetidos
    r = r.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // 6. Diccionario canónico de homólogos frecuentes
    final norm = sinAcentos(r);

    if (norm.contains('pechuga') && norm.contains('pollo')) {
      return 'Pechuga de pollo';
    }
    if (norm.contains('atun en agua') || norm.contains('atun en aceite')) {
      return 'Atún en agua';
    }
    if (norm.contains('atun fresco') || norm.contains('medallon de atun') || norm.contains('medallones de atun')) {
      return 'Medallón de atún fresco';
    }
    // Chispas de chocolate y variantes de chocolate
    if (norm.contains('chispas') || norm.contains('chocolate')) {
      if (norm.contains('blanco')) return 'Chocolate blanco';
      if (norm.contains('con leche')) return 'Chocolate con leche';
      return 'Chispas de chocolate 70% cacao';
    }
    if (norm == 'avena' || norm.contains('hojuelas de avena') || norm.contains('avena en hojuelas')) {
      return 'Avena en hojuelas';
    }
    if (norm == 'cilantro' || norm.contains('cilantro')) {
      return 'Cilantro';
    }
    if (norm == 'espinaca' || norm.contains('espinaca')) {
      return 'Espinaca';
    }
    if (norm == 'canela' || norm.contains('canela')) {
      return 'Canela en polvo';
    }
    if (norm == 'aceite' || norm.contains('aceite vegetal') || norm.contains('aceite de canola') || norm.contains('aceite en spray')) {
      return 'Aceite vegetal';
    }
    if (norm.contains('aceite de oliva')) {
      return 'Aceite de oliva';
    }
    if (norm == 'jitomate' || norm.contains('jitomate saladet') || norm.contains('jitomate bola')) {
      return 'Jitomate Saladet';
    }
    if (norm.contains('tomate baby') || norm.contains('tomate cherry')) {
      return 'Tomate cherry';
    }
    if (norm.contains('sal marina') || norm == 'sal' || norm.contains('sal fina')) {
      return 'Sal marina fina';
    }
    if (norm.contains('yogurt') || norm.contains('yogur')) {
      return 'Yogurt griego natural';
    }
    if (norm.contains('chile serrano') || norm.contains('chile verde')) {
      return 'Chile Serrano';
    }
    if (norm == 'papa' || norm.contains('papa blanca') || norm.contains('papas')) {
      return 'Papa blanca';
    }
    if (norm.contains('edamame')) {
      return 'Edamames';
    }
    if (norm.contains('lechuga orejona')) {
      return 'Lechuga orejona';
    }
    if (norm.contains('tortilla') && norm.contains('integral')) {
      return 'Tortillas de harina integral';
    }
    if (norm.contains('tortilla') && (norm.contains('maiz') || norm == 'tortillas')) {
      return 'Tortillas de maíz';
    }
    if (norm == 'limon' || norm == 'limones' || norm == 'imones' || norm == 'imónes') {
      return 'Limón';
    }
    if (norm.contains('lechuga') || norm.startsWith('echuga')) {
      return 'Lechuga orejona';
    }
    if (norm.contains('mantequilla de cacahuate') || norm.contains('crema de cacahuate')) {
      return 'Mantequilla de cacahuate';
    }
    if (norm == 'aguacate' || norm.contains('aguacate hass')) {
      return 'Aguacate';
    }
    if (norm.contains('col blanca') || norm.contains('col finamente') || norm == 'col') {
      return 'Col blanca';
    }
    if (norm.contains('nopal')) {
      return 'Nopales';
    }
    if (norm.contains('amaranto')) {
      return 'Amaranto';
    }
    if (norm.contains('oregano')) {
      return 'Orégano';
    }
    if (norm.contains('caldo de verdura') || norm.contains('caldo vegetal')) {
      return 'Caldo vegetal';
    }
    if (norm.contains('chipotle')) {
      return 'Chiles chipotle';
    }
    if (norm.contains('manzana verde')) {
      return 'Manzana verde';
    }
    if (norm.contains('manzana roja') ||
        norm.contains('manzana gala') ||
        norm.contains('manzana golden') ||
        norm.contains('manzana fuji')) {
      return 'Manzana roja';
    }
    if (norm.contains('esparrago')) {
      return 'Espárragos';
    }
    if (norm.contains('guajillo')) {
      return 'Chile guajillo';
    }
    if (norm.contains('fruto rojo') || norm.contains('frutos rojos') || norm.contains('berries')) {
      return 'Frutos rojos';
    }
    if (norm.contains('agua de coco')) {
      return 'Agua de coco';
    }
    if (norm.contains('carne molida de pavo') || norm.contains('molida de pavo')) {
      return 'Carne molida de pavo';
    }
    if (norm.contains('carne molida de res') || norm.contains('molida de res')) {
      return 'Carne molida de res';
    }
    if (norm.contains('bistec')) {
      return 'Bistec de res';
    }
    if (norm.contains('huevo') || norm.contains('blanquillo')) {
      return 'Huevo';
    }
    if (norm.contains('tajin')) {
      return 'Chile en polvo Tajín';
    }
    if (norm.contains('endulzante') || norm.contains('stevia') || norm.contains('splenda')) {
      return 'Endulzante sin calorías';
    }
    if (norm.contains('guacamole')) {
      return 'Guacamole';
    }
    if (norm.contains('jengibre')) {
      return 'Jengibre';
    }
    if (norm.contains('maiz palomero') || norm.contains('palomitas')) {
      return 'Maíz palomero';
    }
    if (norm.contains('romero')) {
      return norm.contains('seco') ? 'Romero seco' : 'Romero fresco';
    }
    if (norm.contains('rabano')) {
      return 'Rábanos';
    }

    if (r.isEmpty) return s;
    return _capitalizar(r);
  }

  /// Determina si un ingrediente es fruta o verdura fresca cuyos precios de supermercado en México
  /// se cobran por kilogramo (kg), para convertir conteos de piezas al peso correspondiente.
  static bool esFrutaOVerduraPorKilo(String nombre) {
    final n = sinAcentos(nombre).trim();
    const produce = {
      'limon', 'jitomate', 'tomate', 'cebolla', 'aguacate', 'papa', 'platano',
      'manzana', 'pepino', 'calabacita', 'zanahoria', 'chayote', 'camote',
      'pimiento', 'naranja', 'pera', 'durazno', 'nopal', 'nopales', 'fresa',
      'mango', 'guayaba', 'toronja', 'mandarina', 'uvas', 'uva', 'chile serrano',
      'chile jalapeño', 'chile poblano', 'chile habanero', 'chile verde', 'chile',
    };
    return produce.any((p) => n.contains(p));
  }

  /// Retorna el peso promedio en kilogramos (kg) de una sola pieza de fruta o verdura.
  static double pesoAproximadoKilosPorPieza(String nombre) {
    final n = sinAcentos(nombre).trim();
    if (n.contains('limon')) return 0.06;
    if (n.contains('jitomate') || n.contains('tomate') || n.contains('zanahoria')) return 0.12;
    if (n.contains('cebolla') || n.contains('calabacita') || n.contains('papa')) return 0.15;
    if (n.contains('aguacate') || n.contains('manzana') || n.contains('pimiento')) return 0.18;
    if (n.contains('platano') || n.contains('pera') || n.contains('durazno')) return 0.16;
    if (n.contains('pepino')) return 0.25;
    if (n.contains('nopal')) return 0.10;
    if (n.contains('naranja') || n.contains('toronja')) return 0.22;
    if (n.contains('serrano') || n.contains('habanero') || n.contains('chile verde')) return 0.015;
    if (n.contains('jalapeno')) return 0.03;
    if (n.contains('poblano')) return 0.10;
    if (n.contains('chile') || n.contains('guajillo') || n.contains('ancho')) return 0.015;
    if (n.contains('diente de ajo') || n.contains('dientes de ajo')) return 0.01;
    if (n.contains('ajo')) return 0.05;
    return 0.15;
  }

  static double _extraerNumeroSeguro(dynamic v) {
    if (v == null) return 1.0;
    if (v is num) return v.toDouble();
    final m = RegExp(r'[0-9]+(?:\.[0-9]+)?').firstMatch(v.toString());
    if (m != null) return double.tryParse(m.group(0)!) ?? 1.0;
    return 1.0;
  }

  static String extraerUnidadSegura(dynamic v, String nombreOUnidadDefecto) {
    final normNom = sinAcentos(nombreOUnidadDefecto);
    final s = sinAcentos(v?.toString() ?? '').trim();

    // 0. Si es Jitomate fresco, ¡NUNCA frasco!
    if (normNom.contains('jitomate') && !normNom.contains('pure') && !normNom.contains('pasta')) {
      if (s.contains('kg') || s.contains('kilo')) return 'kg';
      return 'pza';
    }

    // 0.1 Si es atún fresco o medallón de atún, ¡NUNCA lata!
    if (normNom.contains('medallon') ||
        (normNom.contains('atun') && (normNom.contains('fresco') || (!normNom.contains('agua') && !normNom.contains('aceite') && !normNom.contains('lata'))))) {
      if (s.contains('kg') || s.contains('kilo')) return 'kg';
      return 'pza';
    }

    // 0.2 Líquidos específicos como agua de coco
    if (normNom.contains('agua de coco')) {
      return 'L';
    }

    // 0.3 Espárragos
    if (normNom.contains('esparrago')) {
      return 'manojo';
    }

    // 0.4 Tomate cherry o frutos rojos
    if (normNom.contains('cherry') ||
        normNom.contains('frutos rojos') ||
        normNom.contains('berries') ||
        normNom.contains('frambuesa') ||
        normNom.contains('zarzamora')) {
      return 'paquete';
    }

    // 0.5 Chiles secos (guajillo, ancho, etc.)
    if (normNom.contains('guajillo') ||
        normNom.contains('pasilla') ||
        normNom.contains('morita') ||
        normNom.contains('chile seco') ||
        normNom.contains('chiles secos')) {
      return 'paquete';
    }

    // 0.6 Huevo -> cartón (cartera de 12-18 pzas)
    if (normNom.contains('huevo') || normNom.contains('blanquillo')) {
      return 'cartón';
    }

    if (s.contains('carton') || s.contains('cartón')) return 'cartón';
    if (s.contains('lata')) return 'lata';
    if (s.contains('paquete') || s.contains('bolsa')) return 'paquete';
    if (s.contains('frasco') || s.contains('sobre')) return 'frasco';
    if (s.contains('botella')) return 'botella';
    if (s.contains('manojo')) return 'manojo';
    if (s.contains('cabeza')) return 'cabeza';
    if (s.contains('kg') || s.contains('kilo')) return 'kg';
    if ((s.contains('litro') || s.contains('lt') || s == 'l' || s.contains('lts') || s.contains('ml')) &&
        !s.contains('lata') &&
        !s.contains('paquete')) {
      return 'L';
    }
    if (normNom.contains('atun en agua') || normNom.contains('chipotle')) return 'lata';
    if (normNom.contains('tortilla') ||
        normNom.contains('tostada') ||
        normNom.contains('avena') ||
        normNom.contains('amaranto') ||
        normNom.contains('almendra') ||
        normNom.contains('nuez') ||
        normNom.contains('edamame') ||
        normNom.contains('arroz') ||
        normNom.contains('lenteja') ||
        normNom.contains('semilla') ||
        normNom.contains('palomero')) {
      return 'paquete';
    }
    if (normNom.contains('pechuga') || normNom.contains('carne') || normNom.contains('bistec')) {
      return 'kg';
    }
    return 'pza';
  }

  static String _extraerUnidadSegura(dynamic v, String nombreOUnidadDefecto) =>
      extraerUnidadSegura(v, nombreOUnidadDefecto);

  /// Inserta un ingrediente en la lista de compras o incrementa la cantidad si ya existe,
  /// evitando duplicados y descartando agua.
  static Future<void> agregarOActualizarItemEnCarrito(
    SupabaseClient supabase,
    ItemSupermercado item, {
    bool comprado = false,
  }) async {
    if (esAgua(item.nombre) || item.cantidad <= 0) return;

    final String canNombre = canonicalizarNombre(item.nombre);
    final String key = sinAcentos(canNombre);

    final res = await supabase
        .from('lista_compras')
        .select('id, nombre, cantidad, comprado');

    final List lista = res as List;
    Map<String, dynamic>? itemExistente;
    for (var r in lista) {
      final nomExistente = canonicalizarNombre((r['nombre'] ?? '').toString());
      if (sinAcentos(nomExistente) == key) {
        itemExistente = r;
        break;
      }
    }

    if (itemExistente != null) {
      final int idExistente = itemExistente['id'] as int;
      final String cantExistenteStr = (itemExistente['cantidad'] ?? '1').toString();
      final double cantExistenteNum = _extraerNumeroSeguro(cantExistenteStr);
      final String unidadExistente = _extraerUnidadSegura(cantExistenteStr, canNombre);

      double nuevaCant = cantExistenteNum;
      if (unidadExistente == 'frasco' || unidadExistente == 'botella') {
        nuevaCant = 1.0;
      } else if (unidadExistente == 'cartón' || key.contains('huevo')) {
        final double suma = cantExistenteNum + item.cantidad;
        nuevaCant = suma <= 18.0 ? 1.0 : (suma / 18.0).ceilToDouble().clamp(1.0, 3.0);
      } else if (unidadExistente == 'paquete') {
        nuevaCant = (cantExistenteNum + item.cantidad).clamp(1.0, 5.0).ceilToDouble();
      } else {
        nuevaCant = ((cantExistenteNum + item.cantidad) * 100).round() / 100.0;
      }

      String nuevoTexto = '$nuevaCant $unidadExistente';
      if (unidadExistente == 'cartón' || key.contains('huevo')) {
        final int cInt = nuevaCant.ceil();
        nuevoTexto = '$cInt cartón${cInt > 1 ? 'es' : ''} (cartera 12-18 pzas)';
      } else if (unidadExistente == 'pza' ||
          unidadExistente == 'cabeza' ||
          unidadExistente == 'lata' ||
          unidadExistente == 'paquete') {
        final int cInt = nuevaCant.ceil();
        nuevoTexto = '$cInt $unidadExistente${cInt > 1 ? 's' : ''}';
      } else if (unidadExistente == 'kg' || unidadExistente == 'L') {
        nuevoTexto = nuevaCant == nuevaCant.toInt()
            ? '${nuevaCant.toInt()} $unidadExistente'
            : '${nuevaCant.toStringAsFixed(2)} $unidadExistente';
      }

      await supabase.from('lista_compras').update({
        'nombre': canNombre,
        'cantidad': nuevoTexto,
      }).eq('id', idExistente);
    } else {
      await supabase.from('lista_compras').insert({
        'nombre': canNombre,
        'cantidad': item.textoCantidad,
        'comprado': comprado,
      });
    }
  }

  /// Limpia duplicados y elimina agua en toda la tabla 'lista_compras' de Supabase
  static Future<void> consolidarCarritoEnBaseDeDatos(
    SupabaseClient supabase,
  ) async {
    final res = await supabase
        .from('lista_compras')
        .select('id, nombre, cantidad, comprado')
        .order('id', ascending: true);
    final List items = res as List;
    if (items.isEmpty) return;

    final Map<String, Map<String, dynamic>> consolidado = {};
    final List<int> idsAEliminar = [];

    for (var r in items) {
      final int id = r['id'] as int;
      final String rawNombre = (r['nombre'] ?? '').toString();
      final String rawCant = (r['cantidad'] ?? '1').toString();
      final bool comprado = r['comprado'] ?? false;

      if (esAgua(rawNombre)) {
        idsAEliminar.add(id);
        continue;
      }

      final String canNombre = canonicalizarNombre(rawNombre);
      final String key = sinAcentos(canNombre);

      double cantNum = _extraerNumeroSeguro(rawCant);
      String unidad = _extraerUnidadSegura(rawCant, canNombre);

      if (key.contains('huevo') || rawNombre.toLowerCase().contains('huevo')) {
        // En compras para casa, 1 a 18 huevos siempre es 1 solo cartón (cartera 12-18 pzas).
        // Si la base guardó 5 (de 5 piezas o 5 cartones erróneos), se normaliza a 1 cartón.
        cantNum = cantNum <= 18.0 ? 1.0 : (cantNum / 18.0).ceilToDouble().clamp(1.0, 3.0);
        unidad = 'cartón';
      }

      if (consolidado.containsKey(key)) {
        final prev = consolidado[key]!;
        final double prevCant = prev['cantNum'] as double;
        final String prevUnidad = prev['unidad'] as String;

        if (prevUnidad == 'frasco' || prevUnidad == 'botella') {
          prev['cantNum'] = 1.0;
        } else if (prevUnidad == 'cartón' || key.contains('huevo')) {
          final double suma = prevCant + cantNum;
          prev['cantNum'] = suma <= 18.0 ? 1.0 : (suma / 18.0).ceilToDouble().clamp(1.0, 3.0);
          prev['unidad'] = 'cartón';
        } else if (prevUnidad == 'paquete') {
          final double nueva = (prevCant + cantNum).clamp(1.0, 5.0);
          prev['cantNum'] = nueva.ceilToDouble();
        } else {
          prev['cantNum'] = ((prevCant + cantNum) * 100).round() / 100.0;
        }
        prev['comprado'] = (prev['comprado'] as bool) && comprado;
        idsAEliminar.add(id);
      } else {
        consolidado[key] = {
          'idPrincipal': id,
          'nombre': canNombre,
          'cantNum': cantNum,
          'unidad': unidad,
          'comprado': comprado,
        };
      }
    }

    for (var entry in consolidado.values) {
      final int id = entry['idPrincipal'] as int;
      final double c = entry['cantNum'] as double;
      final String u = entry['unidad'] as String;
      String textoCant = '';
      if (u == 'cartón' || entry['nombre'].toString().toLowerCase().contains('huevo')) {
        final int cInt = c <= 18.0 ? 1 : (c / 18.0).ceil().clamp(1, 3);
        textoCant = '$cInt cartón${cInt > 1 ? 'es' : ''} (cartera 12-18 pzas)';
      } else if (u == 'pza' || u == 'lata' || u == 'cabeza' || u == 'paquete') {
        final int cInt = c.ceil();
        textoCant = '$cInt $u${cInt > 1 ? 's' : ''}';
      } else if (u == 'kg' || u == 'L') {
        textoCant = c == c.toInt() ? '${c.toInt()} $u' : '${c.toStringAsFixed(2)} $u';
      } else {
        textoCant = '$c $u';
      }

      await supabase.from('lista_compras').update({
        'nombre': entry['nombre'],
        'cantidad': textoCant,
        'comprado': entry['comprado'],
      }).eq('id', id);
    }

    if (idsAEliminar.isNotEmpty) {
      await supabase.from('lista_compras').delete().inFilter('id', idsAEliminar);
    }
  }

  static bool esEspecia(String nombre) {
    final n = sinAcentos(nombre).trim();
    for (var e in _especiasYCondimentos) {
      if (n.contains(e)) return true;
    }
    for (var a in _aceitesYSalsas) {
      if (n.contains(a)) return true;
    }
    return false;
  }

  /// Formatea la cantidad y unidad adecuada para mostrar en la despensa
  static String formatearParaDespensa(String nombre, dynamic cantidadRaw) {
    if (cantidadRaw == null) return 'Disponible';
    final double cant = (cantidadRaw is num)
        ? cantidadRaw.toDouble()
        : double.tryParse(cantidadRaw.toString()) ?? 1.0;

    final item = normalizarParaSupermercado(nombre, cant, '');
    return '${item.textoCantidad} en despensa';
  }

  /// Extrae y sincroniza automáticamente los ingredientes de un texto de receta
  /// en 'ingredientes_genericos' y 'receta_detalle'. Devuelve la cantidad de ingredientes vinculados.
  static Future<int> sincronizarIngredientesDeTexto(
    SupabaseClient supabase,
    int idReceta,
    String texto,
  ) async {
    int insertados = 0;
    final lineas = texto.split('\n');
    bool enIngredientes = false;
    final List<String> lineasIng = [];

    for (var l in lineas) {
      final trim = l.trim();
      if (trim.toUpperCase().contains('INGREDIENTES')) {
        enIngredientes = true;
        continue;
      }
      if (enIngredientes && trim.toUpperCase().contains('INSTRUCCIONES')) {
        break;
      }
      if (enIngredientes ||
          trim.startsWith('-') ||
          trim.startsWith('*') ||
          trim.startsWith('•')) {
        if (trim.startsWith('-') ||
            trim.startsWith('*') ||
            trim.startsWith('•')) {
          lineasIng.add(trim);
        }
      }
    }

    if (lineasIng.isEmpty) return 0;

    for (var linea in lineasIng) {
      final l = linea.replaceFirst(RegExp(r'^[\-\*\•]\s*'), '').trim();
      if (l.length < 2) continue;

      // Desglosar líneas compuestas como "Sal y pimienta"
      final List<String> subItems = [];
      final lower = sinAcentos(l);
      if (lower.contains('sal y pimienta') || lower.contains('sal, pimienta')) {
        subItems.add('Sal');
        subItems.add('Pimienta');
        if (lower.contains('ajo en polvo')) {
          subItems.add('Ajo en polvo');
        }
      } else {
        subItems.add(l);
      }

      for (var sub in subItems) {
        if (ConversorUnidades.esAgua(sub)) continue;
        final item = ConversorUnidades.parsearLineaIngrediente(sub);
        if (item.nombre.isEmpty || ConversorUnidades.esAgua(item.nombre) || item.cantidad <= 0) continue;

        try {
          // Buscar o registrar en ingredientes_genericos
          final resGen = await supabase
              .from('ingredientes_genericos')
              .select('id_ingrediente')
              .ilike('nombre_estandar', item.nombre)
              .limit(1);

          int idGen;
          if (resGen.isNotEmpty) {
            idGen = resGen[0]['id_ingrediente'];
          } else {
            final nuevoGen = await supabase
                .from('ingredientes_genericos')
                .insert({'nombre_estandar': item.nombre})
                .select('id_ingrediente')
                .single();
            idGen = nuevoGen['id_ingrediente'];

            // Asignar precios estimados para los 3 supermercados
            final double p1 = (25 + (item.nombre.length % 20)).toDouble();
            await supabase.from('precios_supermercado').insert([
              {'id_ingrediente': idGen, 'id_supermercado': 1, 'precio': p1},
              {
                'id_ingrediente': idGen,
                'id_supermercado': 2,
                'precio': (p1 * 0.95).roundToDouble(),
              },
              {
                'id_ingrediente': idGen,
                'id_supermercado': 3,
                'precio': (p1 * 1.08).roundToDouble(),
              },
            ]);
          }

          // Comprobar si ya existe en receta_detalle
          final yaExiste = await supabase
              .from('receta_detalle')
              .select('id_receta')
              .eq('id_receta', idReceta)
              .eq('id_ingrediente', idGen)
              .limit(1);

          if (yaExiste.isEmpty) {
            await supabase.from('receta_detalle').insert({
              'id_receta': idReceta,
              'id_ingrediente': idGen,
              'cantidad': item.cantidad,
              'unidad_medida': item.unidad,
            });
            insertados++;
          }
        } catch (e) {
          // Ignorar duplicados o errores menores en red
        }
      }
    }

    return insertados;
  }

  /// Determina la categoría del supermercado para organizar la lista de compras:
  /// Frutas y Verduras, Carnes y Aves, Pescados y Mariscos, Lácteos y Huevos,
  /// Panadería y Tortillería, Abarrotes y Alacena, Especias y Condimentos, Otros.
  static String determinarCategoria(String nombre) {
    final n = sinAcentos(nombre).trim();

    // 0. REGLA FUNDAMENTAL DE ACEITES:
    // Todos los aceites comestibles (oliva, ajonjolí, vegetal, aguacate, coco, spray, etc.)
    // van DIRECTAMENTE a Abarrotes y Alacena (¡nunca a frutas o verduras!).
    if (n.contains('aceite')) {
      return 'Abarrotes y Alacena';
    }

    // 1. Pescados y Mariscos (revisar antes de carnes generales)
    if (n.contains('atun fresco') ||
        n.contains('medallon de atun') ||
        n.contains('medallones de atun') ||
        n.contains('salmon') ||
        n.contains('pescado') ||
        n.contains('filete de pescado') ||
        n.contains('tilapia') ||
        n.contains('camaron') ||
        n.contains('camarones') ||
        n.contains('marisco') ||
        n.contains('pulpo') ||
        n.contains('calamar') ||
        n.contains('almeja') ||
        n.contains('mejillon')) {
      return 'Pescados y Mariscos';
    }

    // 2. Carnes y Aves
    if (n.contains('pollo') ||
        n.contains('pechuga') ||
        n.contains('muslo') ||
        n.contains('pierna') ||
        n.contains('milanesa') ||
        n.contains('bistec') ||
        n.contains('arrachera') ||
        n.contains('carne molida') ||
        n.contains('molida de') ||
        (n.contains('res') && !n.contains('fres')) ||
        (n.contains('carne') && !n.contains('chile')) ||
        n.contains('cerdo') ||
        n.contains('puerco') ||
        n.contains('pavo') ||
        n.contains('jamon') ||
        n.contains('tocino') ||
        n.contains('salchicha')) {
      return 'Carnes y Aves';
    }

    // 3. Lácteos y Huevos
    if (n.contains('huevo') ||
        n.contains('blanquillo') ||
        n.contains('clara de huevo') ||
        n.contains('claras') ||
        n.contains('leche') ||
        n.contains('queso') ||
        n.contains('panela') ||
        n.contains('oaxaca') ||
        n.contains('manchego') ||
        n.contains('yogurt') ||
        n.contains('yogur') ||
        n.contains('crema') ||
        n.contains('mantequilla') ||
        n.contains('cottage') ||
        n.contains('requeson')) {
      return 'Lácteos y Huevos';
    }

    // 4. Frutas y Verduras (Verduras, hortalizas, tubérculos y frutas frescas)
    // NOTA CLAVE: Para 'ajo', exigir palabra completa para evitar falsos positivos con 'ajonjoli'!
    final bool esAjoSeguro = (n.contains('diente de ajo') ||
            n.contains('cabeza de ajo') ||
            RegExp(r'\bajo\b').hasMatch(n)) &&
        !n.contains('ajonjoli') &&
        !n.contains('polvo');

    if (n.contains('jitomate') ||
        (n.contains('tomate') && !n.contains('pure') && !n.contains('pasta')) ||
        (n.contains('cebolla') && !n.contains('polvo')) ||
        esAjoSeguro ||
        n.contains('limon') ||
        (n.contains('aguacate') && !n.contains('aceite')) ||
        n.contains('esparrago') ||
        n.contains('cilantro') ||
        n.contains('perejil') ||
        n.contains('espinaca') ||
        n.contains('lechuga') ||
        n.contains('manzana') ||
        n.contains('platano') ||
        n.contains('zanahoria') ||
        n.contains('papa') ||
        n.contains('nopal') ||
        n.contains('edamame') || // Solicitado: edamames verdura o congelados
        n.contains('jengibre') || // Solicitado: jengibre verduras
        n.contains('rabano') || // Solicitado: rábanos verduras / tubérculo
        n.contains('chile serrano') ||
        n.contains('chile jalapeño') ||
        n.contains('chile jalapeno') ||
        n.contains('chile poblano') ||
        n.contains('chile habanero') ||
        n.contains('chile verde') ||
        n.contains('calabacita') ||
        n.contains('pepino') ||
        n.contains('pimiento') ||
        n.contains('frutos rojos') ||
        n.contains('fresa') ||
        n.contains('champiñon') ||
        n.contains('champinon') ||
        n.contains('champiñones') ||
        n.contains('setas') ||
        n.contains('hongos') ||
        n.contains('col ') ||
        n.contains('col blanca') ||
        n.contains('col morada') ||
        n.contains('coliflor') ||
        n.contains('brocoli') ||
        n.contains('apio') ||
        n.contains('betabel') ||
        n.contains('chayote') ||
        n.contains('mango') ||
        n.contains('naranja') ||
        n.contains('moras') ||
        n.contains('berries') ||
        n.contains('frambuesa') ||
        n.contains('zarzamora') ||
        n.contains('pera') ||
        n.contains('uva') ||
        n.contains('sandia') ||
        n.contains('melon') ||
        n.contains('piña') ||
        n.contains('pina') ||
        n.contains('guayaba') ||
        n.contains('papaya') ||
        n.contains('durazno') ||
        n.contains('kiwi')) {
      return 'Frutas y Verduras';
    }

    // 5. Panadería y Tortillería
    if (n.contains('tortilla') ||
        n.contains('tostada') ||
        n.contains('pan ') ||
        n.contains('pan de') ||
        n.contains('pan integral') ||
        n.contains('pan blanco') ||
        n.contains('pan molido') ||
        n.contains('totopo') ||
        n.contains('bolillo') ||
        n.contains('telera') ||
        n.contains('galleta') ||
        n.contains('cruton')) {
      return 'Panadería y Tortillería';
    }

    // 6. Especias y Condimentos
    if (n.contains('sal ') ||
        n == 'sal' ||
        n.contains('pimienta') ||
        n.contains('oregano') ||
        n.contains('canela') ||
        n.contains('paprika') ||
        n.contains('comino') ||
        n.contains('clavo') ||
        n.contains('curcuma') ||
        n.contains('ajo en polvo') ||
        n.contains('cebolla en polvo') ||
        n.contains('polvo para hornear') ||
        n.contains('bicarbonato') ||
        n.contains('levadura') ||
        n.contains('vainilla') ||
        n.contains('laurel') ||
        n.contains('romero') || // Solicitado: romero fresco / seco en especias
        n.contains('tomillo') ||
        n.contains('albahaca') ||
        n.contains('eneldo') ||
        n.contains('achiote') ||
        n.contains('consome') ||
        n.contains('caldo de pollo en polvo')) {
      return 'Especias y Condimentos';
    }

    // 7. Abarrotes y Alacena
    if (n.contains('tajin') || // Solicitado: tajín abarrote
        n.contains('endulzante') || // Solicitado: endulzante abarrote/alacena
        n.contains('stevia') ||
        n.contains('splenda') ||
        n.contains('monk fruit') ||
        n.contains('guacamole') || // Solicitado: guacamole abarrote/alacena
        n.contains('palomero') || // Solicitado: maíz palomero abarrote
        n.contains('palomitas') ||
        n.contains('arroz') ||
        n.contains('frijol') ||
        n.contains('lenteja') ||
        n.contains('garbanzo') ||
        n.contains('avena') ||
        n.contains('pasta') ||
        n.contains('espagueti') ||
        n.contains('fideo') ||
        n.contains('quinoa') ||
        n.contains('harina') ||
        n.contains('atun') ||
        n.contains('sardina') ||
        n.contains('elote') ||
        n.contains('chipotle') ||
        n.contains('guajillo') ||
        n.contains('ancho') ||
        n.contains('pasilla') ||
        n.contains('morita') ||
        n.contains('chile seco') ||
        n.contains('agua de coco') ||
        n.contains('leche evaporada') ||
        n.contains('leche condensada') ||
        n.contains('media crema') ||
        n.contains('pure de tomate') ||
        n.contains('pasta de tomate') ||
        n.contains('vinagre') ||
        n.contains('miel') ||
        n.contains('azucar') ||
        n.contains('mayonesa') ||
        n.contains('mostaza') ||
        n.contains('salsa') ||
        n.contains('aderezo') ||
        n.contains('almendra') ||
        n.contains('nuez') ||
        n.contains('cacahuate') ||
        n.contains('pistache') ||
        n.contains('chia') ||
        n.contains('linaza') ||
        n.contains('ajonjoli') || // Semillas de ajonjolí en abarrotes
        n.contains('semilla') ||
        n.contains('pepitas') ||
        n.contains('amaranto') ||
        n.contains('chocolate') ||
        n.contains('chispas') ||
        n.contains('cacao')) {
      return 'Abarrotes y Alacena';
    }

    return 'Otros';
  }

  static String _capitalizar(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
