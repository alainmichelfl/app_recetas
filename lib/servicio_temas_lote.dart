import 'dart:math';
import 'servicio_temporadas_mexico.dart';

/// Grupos temáticos principales para la generación masiva de recetas oficiales.
enum GrupoTemaLote {
  temporada('🍂 Temporada México', 'Insumos de cosecha agrícola local por mes'),
  cocinasMundo('🌍 Cocinas del Mundo', 'Gastronomías emblemáticas internacionales'),
  estilosVida('⚡ Cocina Práctica', 'Técnicas express, cero trastes y batch cooking'),
  fitnessSalud('💪 Fitness & Salud', 'Metas nutricionales, macros y nutrición clínica'),
  ahorroAntojos('🪙 Ahorro & Antojos', 'Economía familiar, brunch y fines de semana');

  final String etiqueta;
  final String descripcion;
  const GrupoTemaLote(this.etiqueta, this.descripcion);
}

/// Representa una opción preconfigurada de tema o especial culinario para Gemini.
class OpcionTemaLote {
  final String id;
  final GrupoTemaLote grupo;
  final String tituloCorto;
  final String icono;
  final String temaCompleto;
  final String resumenEnfoque;
  final String directrizPrompt;

  const OpcionTemaLote({
    required this.id,
    required this.grupo,
    required this.tituloCorto,
    required this.icono,
    required this.temaCompleto,
    required this.resumenEnfoque,
    required this.directrizPrompt,
  });
}

/// Catálogo integral de los 37 temas culinarios oficiales para la carga masiva con IA.
class ServicioTemasLote {
  ServicioTemasLote._();

  static List<OpcionTemaLote> obtenerTodos() {
    return [
      ..._obtenerTemasTemporada(),
      ..._temasCocinasMundo,
      ..._temasEstilosVida,
      ..._temasFitnessSalud,
      ..._temasAhorroAntojos,
    ];
  }

  static List<OpcionTemaLote> obtenerPorGrupo(GrupoTemaLote grupo) {
    switch (grupo) {
      case GrupoTemaLote.temporada:
        return _obtenerTemasTemporada();
      case GrupoTemaLote.cocinasMundo:
        return _temasCocinasMundo;
      case GrupoTemaLote.estilosVida:
        return _temasEstilosVida;
      case GrupoTemaLote.fitnessSalud:
        return _temasFitnessSalud;
      case GrupoTemaLote.ahorroAntojos:
        return _temasAhorroAntojos;
    }
  }

  /// Retorna la opción correspondiente a la temporada y mes actual.
  static OpcionTemaLote obtenerTemporadaActual([DateTime? fecha]) {
    final temp = ServicioTemporadasMexico.obtenerTemporadaActual(fecha);
    return _convertirTemporadaMes(temp);
  }

  /// Selecciona un tema al azar de entre todos los disponibles (Ruleta Sorpresa).
  static OpcionTemaLote obtenerAleatorio([Random? random]) {
    final rng = random ?? Random();
    final todos = obtenerTodos();
    return todos[rng.nextInt(todos.length)];
  }

  // --- CONVERTIDOR DE ALMANAQUE ESTACIONAL ---
  static List<OpcionTemaLote> _obtenerTemasTemporada() {
    return ServicioTemporadasMexico.obtenerTodosLosMeses()
        .map(_convertirTemporadaMes)
        .toList();
  }

  static OpcionTemaLote _convertirTemporadaMes(TemporadaMes temp) {
    return OpcionTemaLote(
      id: 'temp_${temp.mesNumero}',
      grupo: GrupoTemaLote.temporada,
      tituloCorto: temp.nombreMes,
      icono: temp.icono,
      temaCompleto: temp.temaSugerido,
      resumenEnfoque: 'Cosecha de ${temp.nombreMes}: ${temp.resumenIngredientes}',
      directrizPrompt: ServicioTemporadasMexico.generarDirectrizEstacionalPrompt(temp),
    );
  }

  // --- 1. COCINAS DEL MUNDO (10 Cocinas) ---
  static const List<OpcionTemaLote> _temasCocinasMundo = [
    OpcionTemaLote(
      id: 'cocina_italia',
      grupo: GrupoTemaLote.cocinasMundo,
      tituloCorto: 'Italia',
      icono: '🇮🇹',
      temaCompleto: 'Especial Italia: Pastas Frescas, Risottos y Cocina Mediterránea Práctica',
      resumenEnfoque: 'Pastas al dente, salsas pomodoro y pesto, risottos, albahaca y aceite de oliva virgen.',
      directrizPrompt: '''
ENFOQUE GASTRONÓMICO: Cocina Italiana Tradicional y Mediterránea.
DIRECTRICES ESPECÍFICAS:
1. Diseña platillos inspirados en Italia pero adaptados a ingredientes de supermercados mexicanos (Walmart, Soriana, La Comer).
2. Usa pastas secas de calidad, jitomate guaje para salsas pomodoro caseras, albahaca fresca, ajo, orégano, quesos parmesano o mozzarella, champiñones y aceite de oliva.
3. Asegura opciones balanceadas: Desayunos tipo frittata con espinacas; Comidas con pastas o risottos acompañados de proteína magra; Cenas con minestrone ligero o carpaccio de calabacita; Snacks tipo bruschettas crujientes.
''',
    ),
    OpcionTemaLote(
      id: 'cocina_francia',
      grupo: GrupoTemaLote.cocinasMundo,
      tituloCorto: 'Francia',
      icono: '🇫🇷',
      temaCompleto: 'Especial Francia: Bistró Casero, Quiches, Ratatouille y Crepas',
      resumenEnfoque: 'Técnicas de bistró francés, sofrito mirepoix, quiches ligeros, ratatouille y hierbas provenzales.',
      directrizPrompt: '''
ENFOQUE GASTRONÓMICO: Bistró Francés Casero y Saludable.
DIRECTRICES ESPECÍFICAS:
1. Reinterpreta clásicos franceses haciéndolos prácticos y accesibles en México sin exceso de mantequilla pesada.
2. Incorpora quiches ligeros de verduras y queso panela/gruyère, ratatouille provenzal con calabacita y berenjena, crepas saladas de espinacas y pollo, y pechugas a la mostaza de Dijon o hierbas finas.
3. Equilibra tiempos: incluye versiones express en sartén y desglosa tiempo activo vs cocción.
''',
    ),
    OpcionTemaLote(
      id: 'cocina_espana',
      grupo: GrupoTemaLote.cocinasMundo,
      tituloCorto: 'España',
      icono: '🇪🇸',
      temaCompleto: 'Especial España: Tapas Ibéricas, Arroces a la Cazuela y Tortilla de Patatas',
      resumenEnfoque: 'Tapas de taberna, paella y arroces mixtos, tortilla de patatas jugosa, gazpacho y pimentón de la vera.',
      directrizPrompt: '''
ENFOQUE GASTRONÓMICO: Taberna Española y Cocina Ibérica.
DIRECTRICES ESPECÍFICAS:
1. Sofrito español base con cebolla, ajo, pimentón dulce y jitomate maduro.
2. Recetas clave: tortilla española de patatas jugosa, arroces caldosos o secos con pollo y verduras, gazpacho andaluz refrescante, champiñones al ajillo y albóndigas en salsa de tomate.
3. Ingredientes accesibles en México: papas, huevo fresco, pimientos morrones, aceite de oliva, pimentón dulce y pescados blancos.
''',
    ),
    OpcionTemaLote(
      id: 'cocina_mexico',
      grupo: GrupoTemaLote.cocinasMundo,
      tituloCorto: 'México Gourmet',
      icono: '🇲🇽',
      temaCompleto: 'Especial México: Tradición Gourmet, Moles Ligeros, Tinga y Pescados',
      resumenEnfoque: 'Salsas tatemadas en molcajete, moles ligeros, antojitos al comal horneados y pescados a la veracruzana.',
      directrizPrompt: '''
ENFOQUE GASTRONÓMICO: Cocina Mexicana Tradicional Saludable y Fusión Contemporánea.
DIRECTRICES ESPECÍFICAS:
1. Platillos llenos de sabor mexicano sin frituras profundas: cocciones al comal, salsas tatemadas, caldos y guisados de cazuela.
2. Utiliza maíz, frijoles de la olla, chiles poblanos, serranos y secos (guajillo, ancho), epazote, cilantro, aguacate y queso fresco.
3. Desayunos con chilaquiles horneados o huevos al comal; Comidas con pescado a la veracruzana o tinga de pollo magra; Cenas con sopes de nopal o ensaladas con queso panela.
''',
    ),
    OpcionTemaLote(
      id: 'cocina_japon',
      grupo: GrupoTemaLote.cocinasMundo,
      tituloCorto: 'Japón & Asia',
      icono: '🇯🇵',
      temaCompleto: 'Especial Japón & Oriente: Bowls Teriyaki, Ramen Casero y Salteados Umami',
      resumenEnfoque: 'Bowls de salmón y arroz sushi, teriyaki casero bajo en azúcar, ramen balanceado y salteados con sésamo.',
      directrizPrompt: '''
ENFOQUE GASTRONÓMICO: Cocina Japonesa y Asiática Cotidiana (Washoku Práctico).
DIRECTRICES ESPECÍFICAS:
1. Prioriza el balance umami con salsa de soya reducida en sodio, jengibre fresco rallado, vinagre de arroz, cebollín y aceite de ajonjolí.
2. Ideas: Bowls de salmón o pollo teriyaki con brócoli al vapor, ramen casero con caldo aromático y huevo poché, salteados rápidos en sartén (yakisoba de verduras) y edamames al ajillo.
3. Ingredientes que el usuario pueda conseguir en Walmart/Soriana o La Comer sin requerir tiendas asiáticas especializadas.
''',
    ),
    OpcionTemaLote(
      id: 'cocina_tailandia',
      grupo: GrupoTemaLote.cocinasMundo,
      tituloCorto: 'Tailandia',
      icono: '🇹🇭',
      temaCompleto: 'Especial Tailandia: Pad Thai Ligero, Currys con Coco y Fideos Salteados',
      resumenEnfoque: 'Leche de coco, curry aromático, fideos de arroz, cacahuate, hierbas frescas y toque cítrico de lima.',
      directrizPrompt: '''
ENFOQUE GASTRONÓMICO: Cocina Tailandesa y Sudeste Asiático.
DIRECTRICES ESPECÍFICAS:
1. Equilibrio de los 4 pilares thai: dulce natural, ácido (jugo de limón), salado y especiado aromático.
2. Usa leche de coco ligera, curry en polvo o pasta accesible, cacahuate tostado picado, fideos de arroz o vermicelli, cilantro y pimientos.
3. Platillos sugeridos: Pad Thai con camarón o pollo, curry verde o amarillo de verduras con pechuga, ensalada thai crujiente de col y pepino.
''',
    ),
    OpcionTemaLote(
      id: 'cocina_mediterraneo',
      grupo: GrupoTemaLote.cocinasMundo,
      tituloCorto: 'Mediterráneo',
      icono: '🇬🇷',
      temaCompleto: 'Especial Mediterráneo: Dieta Cardiosaludable, Hummus, Pescados y Feta',
      resumenEnfoque: 'Aceite de oliva extra virgen, ensaladas griegas, tzatziki con yogur griego, hummus y pescados con limón.',
      directrizPrompt: '''
ENFOQUE GASTRONÓMICO: Cocina Griega y Mediterránea Clásica.
DIRECTRICES ESPECÍFICAS:
1. Considerada el patrón de oro nutricional: rica en grasas monoinsaturadas (oliva), antioxidantes y proteínas limpias.
2. Incorpora pepino, jitomate cherry, aceitunas negras, queso feta o panela, garbanzos (hummus casero), orégano seco y filetes de pescado blanco o salmón a la plancha.
3. Snacks con dips de yogur griego (tzatziki) y bastones de vegetales crujientes.
''',
    ),
    OpcionTemaLote(
      id: 'cocina_india',
      grupo: GrupoTemaLote.cocinasMundo,
      tituloCorto: 'India & Currys',
      icono: '🇮🇳',
      temaCompleto: 'Especial India: Pollo Tikka Masala, Dal de Lentejas y Currys Aromáticos',
      resumenEnfoque: 'Especias digestivas (cúrcuma, comino, jengibre), dal de lentejas amarillas, currys aromáticos y arroz basmati.',
      directrizPrompt: '''
ENFOQUE GASTRONÓMICO: Cocina de la India Práctica y Antiinflamatoria.
DIRECTRICES ESPECÍFICAS:
1. Uso protagónico de especias antiinflamatorias: cúrcuma, jengibre, comino, cilantro molido, garam masala o curry suave.
2. Destacan los platos con legumbres: Dal de lentejas amarillas o cafés, curry de garbanzos (Chana Masala) y pollo Tikka Masala con salsa de tomate y yogur.
3. Desayunos y cenas con tés aromáticos y opciones reconfortantes para el sistema digestivo.
''',
    ),
    OpcionTemaLote(
      id: 'cocina_latina',
      grupo: GrupoTemaLote.cocinasMundo,
      tituloCorto: 'Perú & Caribe',
      icono: '🇵🇪',
      temaCompleto: 'Especial Perú & Caribe: Ceviches Cítricos, Lomo Saltado y Arroces',
      resumenEnfoque: 'Ceviches peruanos frescos con camote y elote, lomo saltado al wok, plátano macho y toques caribeños.',
      directrizPrompt: '''
ENFOQUE GASTRONÓMICO: Cocina Peruana y Fusión Caribeña.
DIRECTRICES ESPECÍFICAS:
1. Resalta la acidez vibrante del limón con cebolla morada crujiente, camote cocido, elote dulce y chiles frescos.
2. Platillos clave: Ceviche de pescado blanco o atún con leche de tigre casera, lomo saltado con jitomate y cebolla en gajos, arroz con frijoles negros (moros y cristianos) y tostones horneados.
''',
    ),
    OpcionTemaLote(
      id: 'cocina_americana',
      grupo: GrupoTemaLote.cocinasMundo,
      tituloCorto: 'Americana Fit',
      icono: '🍔',
      temaCompleto: 'Especial Americana Saludable: Burgers Artesanales, BBQ Casera y Bowls',
      resumenEnfoque: 'Hamburguesas gourmet magras de pavo o res, salsa BBQ casera sin azúcar, ensalada coleslaw y bowls.',
      directrizPrompt: '''
ENFOQUE GASTRONÓMICO: American Comfort Food Reinterpretado Saludable.
DIRECTRICES ESPECÍFICAS:
1. Convierte los favoritos estadounidenses en versiones altas en proteína y bajas en grasas saturadas.
2. Hamburguesas en pan integral o envueltas en lechuga con carne magra, salsa BBQ casera a base de jitomate y manzana, papas gajo horneadas con especias, y ensalada de col con yogur griego.
''',
    ),
  ];

  // --- 2. ESTILOS DE VIDA & COCINA PRÁCTICA (4 Temas) ---
  static const List<OpcionTemaLote> _temasEstilosVida = [
    OpcionTemaLote(
      id: 'estilo_cero_trastes',
      grupo: GrupoTemaLote.estilosVida,
      tituloCorto: 'Cero Trastes',
      icono: '🍳',
      temaCompleto: 'Especial Cero Trastes: 20 Recetas en 1 Solo Sartén, Charola o Air Fryer',
      resumenEnfoque: 'Técnica One-Pan / One-Pot: todo se cocina en 1 solo recipiente. Cero pilas de vajilla sucia.',
      directrizPrompt: '''
ENFOQUE: Técnica Cero Trastes (One-Pan / One-Pot).
REGLA INFLEXIBLE:
- Las 20 recetas DEBEN prepararse utilizando ÚNICAMENTE 1 sartén, 1 charola de horno, 1 olla o la canastilla de la Air Fryer.
- No se permite ensuciar licuadoras adicionales ni recipientes secundarios.
- En la descripción resalta con orgullo: "🍳 Técnica Cero Trastes: todo en 1 sartén. Tiempo activo: X min | Cocción: Y min..."
''',
    ),
    OpcionTemaLote(
      id: 'estilo_express_15m',
      grupo: GrupoTemaLote.estilosVida,
      tituloCorto: 'Express ≤15m',
      icono: '⏱️',
      temaCompleto: 'Especial Express ≤15 Minutos: Platillos Completos y Nutritivos en Tiempo Récord',
      resumenEnfoque: 'Tiempo total de reloj ≤ 15 min. Proteínas rápidas, cortes delgados y cocciones vivas.',
      directrizPrompt: '''
ENFOQUE: Cocina Express de Alta Velocidad (≤ 15 minutos totales).
REGLA INFLEXIBLE:
- Las 20 recetas DEBEN completarse en un tiempo TOTAL (activo + cocción) menor o igual a 15 minutos de reloj.
- Usa proteínas de cocción rápida (huevo, fajitas de pollo delgadas, bistec en tiras, atún en agua, queso panela, camarones precocidos).
- Vegetales en cortes finos (julianas, cubitos pequeños) para saltear en 3-5 minutos.
''',
    ),
    OpcionTemaLote(
      id: 'estilo_batch_cooking',
      grupo: GrupoTemaLote.estilosVida,
      tituloCorto: 'Batch Cooking',
      icono: '🍱',
      temaCompleto: 'Especial Batch Cooking & Prep: Comidas que Duran 5 Días y Recalientan Delicioso',
      resumenEnfoque: 'Platillos aptos para cocinar en bloque el domingo; aguantan refrigeración y congelador sin resecarse.',
      directrizPrompt: '''
ENFOQUE: Batch Cooking y Meal Prep Semanal.
DIRECTRICES ESPECÍFICAS:
1. Platillos con salsas y caldos base que mejoran su sabor con los días y no se resecan al recalentar en microondas o sartén.
2. Guisados de carne molida, pollo deshebrado en salsa morita o verde, arroces integrales, legumbres guisadas y verduras asadas.
3. En la descripción incluye un tip de conservación: "❄️ Se conserva hasta 5 días en refri o 1 mes congelado."
''',
    ),
    OpcionTemaLote(
      id: 'estilo_sin_estufa',
      grupo: GrupoTemaLote.estilosVida,
      tituloCorto: 'Sin Estufa',
      icono: '🥗',
      temaCompleto: 'Especial Sin Estufa: Bowls, Ensaladas Saciantes y Tostas en Frío',
      resumenEnfoque: 'Cocina en frío de ensamble: cero sartenes ni estufa encendida. Frescura y saciedad rápida.',
      directrizPrompt: '''
ENFOQUE: Ensamble en Frío y Cocina Sin Fuego.
REGLA INFLEXIBLE:
- Cero estufa ni horno. Todo se prepara mediante técnicas de corte, ensamble y aderezado en frío.
- Bowls saciantes de granos cocidos o legumbres con verduras crujientes, ceviches marinados en limón, wraps fríos en tortillas de linaza o lechuga, tostas de aguacate y queso fresco.
- Ideal para días de calor o cuando se carece de estufa disponible.
''',
    ),
    OpcionTemaLote(
      id: 'estilo_lunch_escolar_kids',
      grupo: GrupoTemaLote.estilosVida,
      tituloCorto: 'Lunch Escolar 🎒',
      icono: '🎒',
      temaCompleto: 'Especial Lunch Escolar & Snacks: Loncheras Saludables y Fáciles para Niños',
      resumenEnfoque: 'Snacks nutritivos, loncheras balanceadas y preparaciones prácticas para niños/as que papás y mamás pueden adelantar fácilmente.',
      directrizPrompt: '''
ENFOQUE: Snacks y Lunches Escolares para Niños y Niñas.
DIRECTRICES ESPECÍFICAS:
1. Platillos coloridos, apetitosos, sin frituras industriales, ni azúcares añadidos refinados.
2. Formatos ideales para loncheras y recipientes herméticos o térmicos: rollitos de jamón y panela, wraps ligeros, bastones crujientes con dip de yogurt o hummus, brochetas seguras de fruta, galletas caseras de avena, chips horneados y muffins salados o dulces naturales.
3. Fáciles de comer con las manos o tenedor pequeño, que se mantengan frescos durante horas sin batirse.
4. Tiempos de preparación rápidos de adelantar la noche anterior o armar express en la mañana.
''',
    ),
  ];

  // --- 3. FITNESS & NUTRICIÓN CLÍNICA (5 Temas) ---
  static const List<OpcionTemaLote> _temasFitnessSalud = [
    OpcionTemaLote(
      id: 'fitness_high_protein',
      grupo: GrupoTemaLote.fitnessSalud,
      tituloCorto: 'High-Protein',
      icono: '💪',
      temaCompleto: 'Especial Alta en Proteína: 35g a 50g de Proteína Magra por Platillo',
      resumenEnfoque: 'Proteína magra para ganancia muscular y recuperación: pechuga, res magra, claras, atún y legumbres.',
      directrizPrompt: '''
ENFOQUE: Alta Densidad Proteica (High-Protein / Fitness).
REGLA INFLEXIBLE:
- Cada una de las 20 recetas DEBE aportar entre 35g y 50g de proteína de alto valor biológico por porción.
- En el campo "macros" detalla explícitamente: "Proteína: Xg (35-50g) | Carbos: Yg | Grasas: Zg".
- Combina pechuga de pollo, claras de huevo, atún, carne molida magra 95/5, lomo de cerdo y legumbres con quesos bajos en grasa.
''',
    ),
    OpcionTemaLote(
      id: 'fitness_deficit_calorico',
      grupo: GrupoTemaLote.fitnessSalud,
      tituloCorto: 'Déficit & Volumen',
      icono: '⚖️',
      temaCompleto: 'Especial Déficit Calórico: Platos Gigantes de Gran Volumen con Menos de 450 kcal',
      resumenEnfoque: 'Alimentos voluminosos y saciantes con alta fibra y proteína magra: llena el plato con < 450 kcal.',
      directrizPrompt: '''
ENFOQUE: Pérdida de Grasa mediante Volumen Alimentario (High Volume / Low Calorie).
REGLA INFLEXIBLE:
- Ninguna receta debe superar las 450 kcal por porción completa.
- Maximiza el volumen visual y la saciedad gástrica usando champiñones, calabacitas, coliflor, brócoli, espinacas y nopales combinados con proteínas magras.
- Cero salsas cremosas grasas o aceites desmedidos.
''',
    ),
    OpcionTemaLote(
      id: 'fitness_keto_limpio',
      grupo: GrupoTemaLote.fitnessSalud,
      tituloCorto: 'Keto Limpio',
      icono: '🥑',
      temaCompleto: 'Especial Keto Limpio: Menos de 15g de Carbohidratos Netos y Grasas Buenas',
      resumenEnfoque: 'Cetosis nutricional limpia: aguacate, salmón, huevo, queso de calidad y verduras de hoja verde.',
      directrizPrompt: '''
ENFOQUE: Cetosis Nutricional Limpia (Clean Keto / Low Carb).
REGLA INFLEXIBLE:
- Menos de 15g de carbohidratos netos por porción.
- Cero azúcares, harinas, arroz, maíz, papas ni frutas con alta fructosa.
- Prioriza aguacate Hass, aceite de oliva, nueces, queso panela/oaxaca, huevos enteros, salmón, pollo con piel o carne de res magra con verduras verdes (espinaca, calabacita, espárragos).
''',
    ),
    OpcionTemaLote(
      id: 'fitness_baja_grasa',
      grupo: GrupoTemaLote.fitnessSalud,
      tituloCorto: 'Baja en Grasa',
      icono: '🌿',
      temaCompleto: 'Especial Baja en Grasa: Digestión Ligera, Cuidado Hepático y Vesicular',
      resumenEnfoque: 'Menos de 10g de grasa por porción. Cocciones al vapor, pochados, caldos y cero frituras.',
      directrizPrompt: '''
ENFOQUE: Dieta Baja en Grasa / Cuidado Digestivo y Hepático.
REGLA INFLEXIBLE:
- Menos de 10g de grasa total por porción. Cero frituras, mantecas, mayonesas enteras o empanizados.
- Cocciones al vapor, pochadas, en caldillo de jitomate o en Air Fryer con apenas unas gotas de aceite en spray.
- Excelente para usuarios con requerimientos de vesícula, digestión sensible o definición muscular magra.
''',
    ),
    OpcionTemaLote(
      id: 'fitness_diabetes_glucosa',
      grupo: GrupoTemaLote.fitnessSalud,
      tituloCorto: 'Control Glucosa',
      icono: '🩺',
      temaCompleto: 'Especial Glucosa Estable: Bajo Índice Glucémico y Alta Fibra para Diabetes',
      resumenEnfoque: 'Alimentos de absorción lenta: legumbres, granos enteros, nopal y proteína sin picos de azúcar.',
      directrizPrompt: '''
ENFOQUE: Control Glucémico y Prevención de Picos de Insulina (Apto para Diabetes y Resistencia a la Insulina).
REGLA INFLEXIBLE:
- Ingredientes con índice glucémico bajo y moderado. Alta presencia de fibra soluble (nopal, avena integral, linaza, chía, frijoles negros).
- Cero azúcares añadidos, mieles ni harinas refinadas.
- Cada carbohidrato complejo debe ir acompañado de proteína y fibra para ralentizar la digestión.
''',
    ),
  ];

  // --- 4. AHORRO & ANTOJOS DE FIN DE SEMANA (6 Temas) ---
  static const List<OpcionTemaLote> _temasAhorroAntojos = [
    OpcionTemaLote(
      id: 'ahorro_super_economico',
      grupo: GrupoTemaLote.ahorroAntojos,
      tituloCorto: 'Súper Económico',
      icono: '🪙',
      temaCompleto: 'Especial Súper Económico: Platillos Nutritivos por Menos de \$35 MXN por Porción',
      resumenEnfoque: 'Ahorro extremo para la quincena: huevo, frijol, lentejas, arroz, papa y pollo rendidor.',
      directrizPrompt: '''
ENFOQUE: Máximo Ahorro Doméstico y Rendimiento Presupuestal (< \$35 MXN por porción).
DIRECTRICES ESPECÍFICAS:
1. Utiliza los insumos de mejor relación costo-nutrición del mercado mexicano: huevo fresco, lentejas, frijoles negros, papa, zanahoria, cebolla, jitomate, avena y piezas económicas de pollo.
2. Demuestra que comer saludable y delicioso no es caro. Platillos rendidores familiares (tortitas de papa con atún, lentejas charras vegetarianas, entomatadas con queso panela).
''',
    ),
    OpcionTemaLote(
      id: 'ahorro_cero_merma',
      grupo: GrupoTemaLote.ahorroAntojos,
      tituloCorto: 'Cero Merma',
      icono: '🌱',
      temaCompleto: 'Especial Rescate de Despensa: Cero Desperdicio y Aprovechamiento Total',
      resumenEnfoque: 'Recetas inteligentes para transformar sobrantes típicos (pan duro, verduras maduras, arroz frío).',
      directrizPrompt: '''
ENFOQUE: Cocina Antidesperdicio (Zero-Waste & Rescate Culinario).
DIRECTRICES ESPECÍFICAS:
1. Transforma ingredientes que suelen echarse a perder en el refrigerador: jitomates muy maduros convertidos en salsas, pan duro en tostas o budín salado, restos de arroz en croquetas horneadas, verduras varias en cremas sedosas.
2. Enseña al usuario el arte del aprovechamiento integral de ingredientes.
''',
    ),
    OpcionTemaLote(
      id: 'antojos_brunch_domingo',
      grupo: GrupoTemaLote.ahorroAntojos,
      tituloCorto: 'Brunch Domingo',
      icono: '🥞',
      temaCompleto: 'Especial Brunch de Domingo: Hotcakes de Avena, Huevos Pochados y Chilaquiles',
      resumenEnfoque: 'Desayunos tardíos de fin de semana para consentir a la familia de forma nutritiva y deliciosa.',
      directrizPrompt: '''
ENFOQUE: Brunch y Desayunos de Fin de Semana.
DIRECTRICES ESPECÍFICAS:
1. Platillos vistosos, reconfortantes y alegres: Hotcakes esponjosos de avena y plátano, huevos pochados sobre tosta de aguacate y jitomate cherry, chilaquiles con totopos horneados y salsa cremosa de chipotle, cazuelitas de huevo al horno con queso.
2. Adecuado tanto para consentirse como para mantenerse dentro de los objetivos de salud.
''',
    ),
    OpcionTemaLote(
      id: 'antojos_taqueria_casera',
      grupo: GrupoTemaLote.ahorroAntojos,
      tituloCorto: 'Taquería Casera',
      icono: '🌮',
      temaCompleto: 'Especial Noche de Tacos: Al Pastor en Sartén, Suadero Magro y Salsas Tatemadas',
      resumenEnfoque: 'Tacos callejeros mexicanos reinterpretados para hacer en casa con menos grasa y todo el sabor.',
      directrizPrompt: '''
ENFOQUE: Noche de Taquería Mexicana Saludable en Casa.
DIRECTRICES ESPECÍFICAS:
1. Recrea los favoritos de la taquería con métodos caseros: carne al pastor marinada con achiote y piña asada en sartén, alambre de bistec con pimientos y queso derretido, tacos de pescado estilo ensenada horneados, tacos dorados de pollo al air fryer.
2. En cada receta incluye una salsa casera rápida (verde cruda con aguacate, roja tatemada, habanero con cebolla morada).
''',
    ),
    OpcionTemaLote(
      id: 'antojos_pizza_pasta',
      grupo: GrupoTemaLote.ahorroAntojos,
      tituloCorto: 'Pizza & Pasta Fit',
      icono: '🍕',
      temaCompleto: 'Especial Pizza & Pasta Fit: Masas en Sartén, Salsas Caseras y Queso Gratinado',
      resumenEnfoque: 'Antojos italianos en versión ligera: pizzas en sartén con masa delgada y pastas ricas en proteína.',
      directrizPrompt: '''
ENFOQUE: Pizza y Pasta Ligera sin Culpa.
DIRECTRICES ESPECÍFICAS:
1. Bases crujientes rápidas para pizza (en sartén con harina de avena, masa integral fina o base de coliflor/huevo), salsa pomodoro natural y quesos ligeros gratinados.
2. Pastas combinadas con abundantes verduras salteadas (calabacitas, champiñones, pimientos) y pechuga de pollo o atún para balancear carbohidratos con proteína.
''',
    ),
    OpcionTemaLote(
      id: 'antojos_postres_sin_azucar',
      grupo: GrupoTemaLote.ahorroAntojos,
      tituloCorto: 'Postres Fit',
      icono: '🍰',
      temaCompleto: 'Especial Postres Saludables: Mugcakes en 2 min, Brownies de Avena y Sin Azúcar',
      resumenEnfoque: 'Antojos dulces saludables endulzados con fruta (plátano, manzana) o canela. Cero azúcar refinada.',
      directrizPrompt: '''
ENFOQUE: Postres y Snacks Dulces Saludables (Sin Azúcar Refinada).
DIRECTRICES ESPECÍFICAS:
1. Endulzados con el dulzor natural de frutas (plátano maduro, puré de manzana), vainilla, canela o dátiles.
2. Recetas clave: Mugcake de avena y cacao al microondas en 2 min, galletas de avena y plátano de 3 ingredientes, mousse de yogur griego con frutos rojos, peras al horno con canela y nuez.
3. Ideales para la categoría "Snack" o cierres de comida ligeros.
''',
    ),
  ];
}
