import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_cocina_express.dart';

void main() {
  group('ServicioCocinaExpress - Extracción de Tiempos y Desglose', () {
    test('Extrae minutos de campo tiempo_preparacion explícito', () {
      final receta = {
        'titulo': 'Quesadillas con guacamole',
        'tiempo_preparacion': '15 minutos',
      };
      final minutos = ServicioCocinaExpress.extraerMinutosTotales(receta);
      expect(minutos, 15);
    });

    test('Extrae minutos de texto de descripción o instrucciones', () {
      final receta = {
        'titulo': 'Salteado de verduras con pollo',
        'descripcion': 'TIEMPO: 12 min\nCalorías: 350 kcal',
      };
      final minutos = ServicioCocinaExpress.extraerMinutosTotales(receta);
      expect(minutos, 12);
    });

    test('Convierte horas a minutos correctamente', () {
      final receta = {
        'titulo': 'Guisado de res a fuego lento',
        'descripcion': 'Tiempo: 1 hora y media',
      };
      final minutos = ServicioCocinaExpress.extraerMinutosTotales(receta);
      expect(minutos, 60);
    });

    test('Calcula desglose activo y pasivo para recetas sin fuego', () {
      final receta = {
        'titulo': 'Wrap frío de atún con aguacate',
        'descripcion': 'Ensalada fría y tosta en 8 minutos sin cocción.',
        'tiempo_preparacion': '8 min',
      };
      final desglose = ServicioCocinaExpress.calcularDesglose(receta);
      expect(desglose.totalMinutos, 8);
      expect(desglose.activoMinutos, 8);
      expect(desglose.pasivoMinutos, 0);
    });

    test('Calcula desglose activo y pasivo para recetas al horno (mayor tiempo pasivo)', () {
      final receta = {
        'titulo': 'Pechuga gratinada al horno',
        'descripcion': 'Hornear a 180°C por 30 minutos.',
        'tiempo_preparacion': '30 min',
      };
      final desglose = ServicioCocinaExpress.calcularDesglose(receta);
      expect(desglose.totalMinutos, 30);
      expect(desglose.pasivoMinutos > desglose.activoMinutos, isTrue);
    });
  });

  group('ServicioCocinaExpress - Conteo de Ingredientes y Filtros', () {
    test('Cuenta ingredientes estructurados o con guiones', () {
      final receta = {
        'titulo': 'Tacos de huevo con frijol',
        'descripcion': '''
        INGREDIENTES:
        - 2 huevos
        - 1/2 taza de frijoles refritos
        - 2 tortillas de maíz
        - 1 rebanada de aguacate
        
        INSTRUCCIONES:
        1. Calentar tortillas y freír huevo.
        ''',
      };
      final total = ServicioCocinaExpress.contarIngredientes(receta);
      expect(total, 4);
    });

    test('esExpress20 califica recetas <= 20 min', () {
      final rapida = {'tiempo_preparacion': '15 min'};
      final lenta = {'tiempo_preparacion': '45 min'};

      expect(ServicioCocinaExpress.esExpress20(rapida), isTrue);
      expect(ServicioCocinaExpress.esExpress20(lenta), isFalse);
    });

    test('esFacil5 califica recetas con 5 o menos ingredientes', () {
      final facil = {
        'descripcion': 'INGREDIENTES:\n- Pollo\n- Jitomate\n- Cebolla\n- Aceite\n\nINSTRUCCIONES:\n1. Saltear.',
      };
      final compleja = {
        'descripcion': 'INGREDIENTES:\n- A\n- B\n- C\n- D\n- E\n- F\n- G\n\nINSTRUCCIONES:\n1. Mezclar.',
      };

      expect(ServicioCocinaExpress.esFacil5(facil), isTrue);
      expect(ServicioCocinaExpress.esFacil5(compleja), isFalse);
    });

    test('esCeroTrastes detecta palabras clave de una sola sartén o air fryer', () {
      final onePot = {
        'titulo': 'Arroz salteado en una sola sartén',
        'instrucciones': 'Cocinar todo en el mismo sartén para no ensuciar.',
      };
      final airFryer = {
        'titulo': 'Fajitas de pollo en Air Fryer',
        'instrucciones': 'Colocar en la freidora de aire por 12 minutos.',
      };
      final tradicional = {
        'titulo': 'Caldo tlalpeño',
        'instrucciones': 'Hervir en una olla y freír en otra sartén aparte.',
      };

      expect(ServicioCocinaExpress.esCeroTrastes(onePot), isTrue);
      expect(ServicioCocinaExpress.esCeroTrastes(airFryer), isTrue);
      expect(ServicioCocinaExpress.esCeroTrastes(tradicional), isFalse);
    });

    test('esSinFuego detecta ensaladas, wraps, tostas o ceviches fríos', () {
      final wrap = {'titulo': 'Wrap de jamón de pavo con espinacas'};
      final ceviche = {'titulo': 'Ceviche de atún sin cocción'};
      final sopaCaliente = {'titulo': 'Sopa azteca caliente'};

      expect(ServicioCocinaExpress.esSinFuego(wrap), isTrue);
      expect(ServicioCocinaExpress.esSinFuego(ceviche), isTrue);
      expect(ServicioCocinaExpress.esSinFuego(sopaCaliente), isFalse);
    });

    test('esBatchReady detecta aprovechamiento de bases del domingo', () {
      final batch = {
        'titulo': 'Bowl de pollo con arroz cocido del batch cooking',
        'instrucciones': 'Tomar el arroz cocido y la pechuga deshebrada ya lista.',
      };
      expect(ServicioCocinaExpress.esBatchReady(batch), isTrue);
    });

    test('cumpleFiltroExpress evalúa correctamente cada enum', () {
      final recetaRapida = {
        'titulo': 'Tostas de aguacate',
        'tiempo_preparacion': '10 min',
        'descripcion': 'INGREDIENTES:\n- Pan\n- Aguacate\n- Sal\n\nINSTRUCCIONES:\nMontar tosta sin fuego.',
      };

      expect(ServicioCocinaExpress.cumpleFiltroExpress(recetaRapida, FiltroExpress.todos), isTrue);
      expect(ServicioCocinaExpress.cumpleFiltroExpress(recetaRapida, FiltroExpress.express20), isTrue);
      expect(ServicioCocinaExpress.cumpleFiltroExpress(recetaRapida, FiltroExpress.faciles5), isTrue);
      expect(ServicioCocinaExpress.cumpleFiltroExpress(recetaRapida, FiltroExpress.sinFuego), isTrue);
    });
  });

  group('ServicioCocinaExpress - Generador de Prompts para Chef IA', () {
    test('Construye prompt con reglas de tiempo estricto y cero trastes', () {
      final prompt = ServicioCocinaExpress.construirInstruccionesPromptExpress(
        tiempoMaximoMinutos: 15,
        modoCeroTrastes: true,
        modoSinFuego: true,
      );

      expect(prompt.contains('15 MINUTOS'), isTrue);
      expect(prompt.contains('Tiempo activo: X min'), isTrue);
      expect(prompt.contains('CERO TRASTES'), isTrue);
      expect(prompt.contains('SIN FUEGO'), isTrue);
    });
  });
}
