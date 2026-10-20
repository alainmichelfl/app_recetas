/// Servicio del Calendario y Almanaque Estacional Gastronómico de México.
/// 
/// Mapea el mes actual con los productos agrícolas reales en cosecha en México
/// (tianguis, mercados locales y supermercados), evitando que la IA genere recetas
/// al azar y garantizando autenticidad estacional en la carga masiva y sugerencias.
class TemporadaMes {
  final int mesNumero;
  final String nombreMes;
  final String nombreTemporada;
  final String icono;
  final String temaSugerido;
  final List<String> ingredientesClave;
  final String enfoqueGastronomico;

  const TemporadaMes({
    required this.mesNumero,
    required this.nombreMes,
    required this.nombreTemporada,
    required this.icono,
    required this.temaSugerido,
    required this.ingredientesClave,
    required this.enfoqueGastronomico,
  });

  String get resumenIngredientes => ingredientesClave.join(', ');
}

class ServicioTemporadasMexico {
  static const Map<int, TemporadaMes> _almanaque = {
    1: TemporadaMes(
      mesNumero: 1,
      nombreMes: 'Enero',
      nombreTemporada: 'Invierno & Nuevo Comienzo',
      icono: '❄️',
      temaSugerido: 'Especial Enero: Cocina Reconfortante, Caldos y Propósitos Saludables',
      ingredientesClave: [
        'guayaba',
        'mandarina',
        'naranja',
        'acelgas',
        'espinacas',
        'zanahoria',
        'chayote',
        'calabaza de castilla',
        'frijoles de la olla',
        'pechuga de pollo',
      ],
      enfoqueGastronomico:
          'Caldos calientes, cremas ligeras de verduras, guisados desintoxicantes con verduras de invierno y platos balanceados para arrancar el año.',
    ),
    2: TemporadaMes(
      mesNumero: 2,
      nombreMes: 'Febrero',
      nombreTemporada: 'Invierno Tardío & Cuaresma Temprana',
      icono: '🍓',
      temaSugerido: 'Especial Febrero: Sabores de Invierno Tardío, Frutos Rojos y Nopales',
      ingredientesClave: [
        'fresas',
        'zarzamoras',
        'naranja valencia',
        'nopales',
        'calabacitas',
        'brócoli',
        'coliflor',
        'pescado blanco',
        'queso panela',
      ],
      enfoqueGastronomico:
          'Guisados con nopales en salsa verde o pasilla, caldos de pescado, ensaladas templadas y desayunos con frutos rojos frescos.',
    ),
    3: TemporadaMes(
      mesNumero: 3,
      nombreMes: 'Marzo',
      nombreTemporada: 'Primavera & Cuaresma',
      icono: '🌸',
      temaSugerido: 'Especial Marzo: Primavera, Cuaresma, Quelites y Pescados Frescos',
      ingredientesClave: [
        'nopales',
        'habas verdes',
        'quelites',
        'espárragos',
        'piña',
        'mango ataulfo',
        'limón',
        'jitomate',
        'pescado blanco',
        'atún',
      ],
      enfoqueGastronomico:
          'Tostadas frescas, guisados con habas verdes y nopales, ceviches cítricos, pescados a la plancha con hierbas y ensaladas primaverales.',
    ),
    4: TemporadaMes(
      mesNumero: 4,
      nombreMes: 'Abril',
      nombreTemporada: 'Plena Primavera & Frescura',
      icono: '🥑',
      temaSugerido: 'Especial Abril: Cocina Fresca Primaveral, Bowls y Sin Horno',
      ingredientesClave: [
        'mango ataulfo',
        'melón',
        'sandía',
        'pepino',
        'jícama',
        'aguacate',
        'chile serrano',
        'limón',
        'pechuga de pavo',
      ],
      enfoqueGastronomico:
          'Bowls frescos, rollitos de pavo, ensaladas crujientes de jícama y pepino, tostadas de atún o tinga fría, y platos hidratantes y rápidos.',
    ),
    5: TemporadaMes(
      mesNumero: 5,
      nombreMes: 'Mayo',
      nombreTemporada: 'Primavera Cálida & Frutas Tropicales',
      icono: '🥭',
      temaSugerido: 'Especial Mayo: Cítricos, Mangos, Papaya y Salteados Ligeros',
      ingredientesClave: [
        'mango',
        'piña miel',
        'papaya',
        'durazno criollo',
        'aguacate hass',
        'ejotes',
        'calabacitas criollas',
        'jitomate guaje',
      ],
      enfoqueGastronomico:
          'Salteados rápidos en sartén, fajitas con pimientos, ensaladas tropicales con vinagretas de limón, y snacks energéticos con frutas y yogur.',
    ),
    6: TemporadaMes(
      mesNumero: 6,
      nombreMes: 'Junio',
      nombreTemporada: 'Inicio de Verano & Cosecha Temprana',
      icono: '🌽',
      temaSugerido: 'Especial Junio: Elotes Tiernos, Flor de Calabaza y Champiñones',
      ingredientesClave: [
        'elotes tiernos',
        'flor de calabaza',
        'champiñones',
        'higos',
        'durazno',
        'ciruela',
        'calabacitas',
        'epazote',
      ],
      enfoqueGastronomico:
          'Sopas de flor de calabaza y elote tierno, quesadillas con epazote, guisados de pollo con champiñones en salsa morita o verde.',
    ),
    7: TemporadaMes(
      mesNumero: 7,
      nombreMes: 'Julio',
      nombreTemporada: 'Pleno Verano & Hongos de Lluvia',
      icono: '🍄',
      temaSugerido: 'Especial Julio: Sabores del Campo, Hongos, Huitlacoche y Tunas',
      ingredientesClave: [
        'huitlacoche',
        'hongos silvestres y champiñones',
        'elotes',
        'flor de calabaza',
        'tunas',
        'ciruelas',
        'nopales tiernos',
      ],
      enfoqueGastronomico:
          'Guisados campesinos con hongos y huitlacoche, esquites preparados caseros, cremas suaves de elote y postres frescos con tuna verde.',
    ),
    8: TemporadaMes(
      mesNumero: 8,
      nombreMes: 'Agosto',
      nombreTemporada: 'Verano Tardío & Preludio Otoñal',
      icono: '🫑',
      temaSugerido: 'Especial Agosto: Chiles Poblanos, Rajas, Durazno Criollo y Elote',
      ingredientesClave: [
        'chiles poblanos',
        'granada roja',
        'durazno criollo',
        'manzana panochera',
        'pera lechera',
        'elotes',
        'queso oaxaca',
      ],
      enfoqueGastronomico:
          'Rajas con crema y elote, picadillos dulces y salados, cremas de poblano, y ensaladas de frutas de hueso con nueces y queso de cabra.',
    ),
    9: TemporadaMes(
      mesNumero: 9,
      nombreMes: 'Septiembre',
      nombreTemporada: 'Mes Patrio & Sabores Tradicionales',
      icono: '🇲🇽',
      temaSugerido: 'Especial Septiembre: Orgullo Mexicano, Nuez de Castilla, Tinga y Maíz',
      ingredientesClave: [
        'granada roja',
        'nuez de castilla',
        'chile poblano',
        'maíz pozolero',
        'jitomate',
        'cebolla blanca',
        'pollo deshebrado',
        'carne de res para deshebrar',
        'aguacate',
      ],
      enfoqueGastronomico:
          'Antojitos saludables horneados o al comal, sopes de maíz con frijoles y tinga casera, pozole balanceado con muchas verduras, y platillos tricolores.',
    ),
    10: TemporadaMes(
      mesNumero: 10,
      nombreMes: 'Octubre',
      nombreTemporada: 'Otoño Cosecha & Sabores Cálidos',
      icono: '🍂',
      temaSugerido: 'Especial Octubre: Cosecha de Otoño (Calabaza de Castilla, Camote, Canela y Manzana)',
      ingredientesClave: [
        'calabaza de castilla',
        'camote amarillo y morado',
        'manzana mexicana',
        'canela',
        'mandarina',
        'guayaba',
        'tejocote',
        'betabel',
        'hongos',
        'pechuga de pollo',
      ],
      enfoqueGastronomico:
          'Bowls de avena tibia con manzana y canela, cremas otoñales de calabaza asada, guisados de pollo o res con camote especiado, y compotas caseras sin azúcar.',
    ),
    11: TemporadaMes(
      mesNumero: 11,
      nombreMes: 'Noviembre',
      nombreTemporada: 'Otoño Pleno & Tradición de Muertos',
      icono: '🎃',
      temaSugerido: 'Especial Noviembre: Sabores de Tradición, Mole, Calabaza en Tacha y Cítricos',
      ingredientesClave: [
        'calabaza de castilla',
        'piloncillo',
        'canela',
        'tejocote',
        'mandarina',
        'naranja',
        'guayaba',
        'camote',
        'pipián o mole ligero',
      ],
      enfoqueGastronomico:
          'Guisados aromáticos de pipián o mole con pollo, postres y desayunos reconfortantes con calabaza y canela, y bebidas tibias de frutas.',
    ),
    12: TemporadaMes(
      mesNumero: 12,
      nombreMes: 'Diciembre',
      nombreTemporada: 'Invierno & Fiestas Decembrinas',
      icono: '🎄',
      temaSugerido: 'Especial Diciembre: Fiestas Decembrinas, Ponche, Manzana y Guisados Festivos',
      ingredientesClave: [
        'tejocote',
        'guayaba',
        'caña de azúcar',
        'manzana amarilla',
        'mandarina',
        'ciruela pasa',
        'romeritos',
        'pescado blanco',
        'pavo',
        'lomo de cerdo magro',
      ],
      enfoqueGastronomico:
          'Ensaladas navideñas ligeras (manzana, nuez, apio y yogur), caldos calientes festivos, guisados al horno jugosos y ponche nutritivo sin azúcar agregada.',
    ),
  };

  /// Obtiene la información estacional del mes en curso o de una fecha específica.
  static TemporadaMes obtenerTemporadaActual([DateTime? fecha]) {
    final f = fecha ?? DateTime.now();
    return _almanaque[f.month] ?? _almanaque[10]!;
  }

  /// Obtiene la temporada por número de mes (1 al 12).
  static TemporadaMes obtenerPorMes(int mes) {
    return _almanaque[mes] ?? _almanaque[10]!;
  }

  /// Lista de los 12 meses con sus temas para selección rápida del administrador.
  static List<TemporadaMes> obtenerTodosLosMeses() {
    return _almanaque.values.toList();
  }

  /// Genera las directrices estacionales rigurosas para inyectar en el prompt de Gemini.
  static String generarDirectrizEstacionalPrompt(TemporadaMes temporada) {
    return '''
CONTEXTO ESTACIONAL Y COSECHA MEXICANA:
- Mes calendario: ${temporada.nombreMes}
- Temporada activa: ${temporada.nombreTemporada}
- INGREDIENTES CLAVE DE TEMPORADA A PRIORIZAR OBLIGATORIAMENTE: ${temporada.resumenIngredientes}
- Perfil gastronómico del mes: ${temporada.enfoqueGastronomico}

DIRECTRICES ESTACIONALES RIGUROSAS:
1. NO generes recetas al azar ni desconectadas de la estación actual de México.
2. Al menos 12 de las 20 recetas DEBEN incorporar prominentemente los ingredientes de cosecha listados arriba (fáciles de conseguir en tianguis, recauderías y supermercados de México).
3. Adapta los ingredientes de estación creativamente en las 4 categorías:
   * Desayunos: bowls tibios, avenas, tostadas o huevos con verduras/frutas de la estación.
   * Comidas: cremas otoñales/invernales, guisados reconfortantes o platos frescos con productos de temporada.
   * Cenas: opciones ligeras, salteados, sopas o caldos de fácil digestión con ingredientes de la temporada.
   * Snacks: opciones energéticas, chips horneados, compotas naturales o ensaladitas de estación.
''';
  }
}
