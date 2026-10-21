import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/perfiles_nutricionales.dart';
import 'package:app_recetas/servicio_cotizador.dart';
import 'package:app_recetas/servicio_despensa.dart';

void main() {
  group('Calibración de Precios y Unidades de Supermercado', () {
    test('Calibra especias infladas por bulto a precios de frasco minorista', () {
      // Si la base de datos tenía $199.75 para canela por kilo, debe calibrar a ~$18 o ~$14 en Central de Abasto
      final precioWalmart = ServicioCotizador.calibrarPrecioUnitario('Canela en polvo', 1, 199.75);
      expect(precioWalmart, lessThanOrEqualTo(22.0));
      expect(precioWalmart, greaterThanOrEqualTo(14.0));

      final precioAbasto = ServicioCotizador.calibrarPrecioUnitario('Canela molida', 4, 199.75);
      expect(precioAbasto, lessThanOrEqualTo(16.0));
      expect(precioAbasto, greaterThanOrEqualTo(12.0));
    });

    test('Calibra frutos secos y semillas al costo de empaque estándar', () {
      final precioNuez = ServicioCotizador.calibrarPrecioUnitario('Nuez pecana', 1, 397.50);
      expect(precioNuez, lessThanOrEqualTo(65.0));
      expect(precioNuez, greaterThanOrEqualTo(45.0));

      final precioNuezAbasto = ServicioCotizador.calibrarPrecioUnitario('Nuez pecana', 4, 397.50);
      expect(precioNuezAbasto, lessThanOrEqualTo(50.0));
    });

    test('Calibra yogurt griego contra precios atípicos', () {
      final precioYogurt = ServicioCotizador.calibrarPrecioUnitario('Yogurt griego natural', 4, 11.90);
      expect(precioYogurt, greaterThanOrEqualTo(30.0));
      expect(precioYogurt, lessThanOrEqualTo(45.0));
    });
  });

  group('Match de Despensa («Puedo cocinar hoy»)', () {
    test('Detecta receta lista para cocinar cuando todos los insumos están en despensa', () {
      const desc = '''
CALORÍAS: 400 kcal
MACROS: 30g P / 20g C / 10g G

📝 INGREDIENTES:
- 500 g de pechuga de pollo
- 2 piezas de jitomate saladet
- 1 pizca de sal

🍳 INSTRUCCIONES:
Cocinar el pollo con el jitomate por 15 minutos.
''';
      final despensa = ['Pechuga de pollo', 'Jitomate saladet'];
      final res = ServicioDespensa.evaluarMatchReceta(
        descripcionReceta: desc,
        nombresEnDespensa: despensa,
      );

      expect(res.listoParaCocinar, isTrue);
      expect(res.faltantes, isEmpty);
      expect(res.porcentaje, equals(1.0));
    });

    test('Detecta falta de 1 ingrediente para badge de advertencia amigable', () {
      const desc = '''
📝 INGREDIENTES:
- 500 g de pechuga de pollo
- 2 piezas de aguacate hass
- 1 taza de arroz integral

🍳 INSTRUCCIONES:
Mezclar y servir.
''';
      final despensa = ['Pechuga de pollo', 'Arroz integral'];
      final res = ServicioDespensa.evaluarMatchReceta(
        descripcionReceta: desc,
        nombresEnDespensa: despensa,
      );

      expect(res.listoParaCocinar, isFalse);
      expect(res.faltaUno, isTrue);
      expect(res.faltantes.length, equals(1));
    });
  });

  group('Sellos y Semáforo Nutricional Automático', () {
    test('Calcula sellos de Alta Proteína y Bajo en Calorías', () {
      final sellos = PerfilesNutricionales.calcularSellosNutricionales(
        calorias: 320,
        proteinas: 35,
        carbs: 15,
        grasas: 8,
      );

      final etiquetas = sellos.map((s) => s.etiqueta).toList();
      expect(etiquetas, contains('Alto en Proteína'));
      expect(etiquetas, contains('Ligero / Déficit'));
      expect(etiquetas, contains('Bajo en Grasa'));
    });

    test('Calcula sello Keto cuando los carbohidratos son reducidos', () {
      final sellos = PerfilesNutricionales.calcularSellosNutricionales(
        calorias: 420,
        proteinas: 28,
        carbs: 8,
        grasas: 28,
      );

      final etiquetas = sellos.map((s) => s.etiqueta).toList();
      expect(etiquetas, contains('Keto / Low-Carb'));
      expect(etiquetas, contains('Alto en Proteína'));
    });
  });
}
