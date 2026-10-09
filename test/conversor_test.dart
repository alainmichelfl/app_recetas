import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/conversor_unidades.dart';

void main() {
  group('Pruebas de Categorización y Conversión de Supermercado', () {
    test('1. Aceite de ajonjolí -> Abarrotes y Alacena', () {
      expect(ConversorUnidades.determinarCategoria('Aceite de ajonjolí'), 'Abarrotes y Alacena');
      expect(ConversorUnidades.determinarCategoria('Ajonjolí'), 'Abarrotes y Alacena');
      expect(ConversorUnidades.determinarCategoria('Ajo'), 'Frutas y Verduras');
      expect(ConversorUnidades.determinarCategoria('Diente de ajo'), 'Frutas y Verduras');
    });

    test('2. Huevo -> 1 cartón (cartera 12-18 pzas)', () {
      final item = ConversorUnidades.normalizarParaSupermercado('huevo', 5, 'piezas');
      expect(item.textoCantidad, '1 cartón (cartera 12-18 pzas)');
      expect(item.unidad, 'cartón');
      expect(item.cantidad, 1.0);
    });

    test('3. Distinción de chispas de chocolate y cacao', () {
      expect(
        ConversorUnidades.canonicalizarNombre('chispas de chocolate 70% cacao'),
        'Chispas de chocolate 70% cacao',
      );
      expect(
        ConversorUnidades.canonicalizarNombre('chispas de chocolate amargo'),
        'Chispas de chocolate amargo',
      );
      expect(
        ConversorUnidades.canonicalizarNombre('chispas de chocolate'),
        'Chispas de chocolate',
      );

      expect(
        ConversorUnidades.nombresCoinciden('Chispas de chocolate', 'Chispas de chocolate amargo'),
        false,
      );
      expect(
        ConversorUnidades.nombresCoinciden('Chispas de chocolate', 'Chispas de chocolate 70% cacao'),
        false,
      );
      expect(
        ConversorUnidades.nombresCoinciden('Chispas de chocolate amargo', 'Chispas de chocolate 70% cacao'),
        false,
      );
    });

    test('4. Corrección de artículos en categorías específicas', () {
      expect(ConversorUnidades.determinarCategoria('Chile en polvo Tajín'), 'Abarrotes y Alacena');
      expect(ConversorUnidades.determinarCategoria('Tajín'), 'Abarrotes y Alacena');
      expect(ConversorUnidades.determinarCategoria('Edamames'), 'Frutas y Verduras');
      expect(ConversorUnidades.determinarCategoria('Edamame'), 'Frutas y Verduras');
      expect(ConversorUnidades.determinarCategoria('Endulzante sin calorías'), 'Abarrotes y Alacena');
      expect(ConversorUnidades.determinarCategoria('Stevia'), 'Abarrotes y Alacena');
      expect(ConversorUnidades.determinarCategoria('Guacamole'), 'Abarrotes y Alacena');
      expect(ConversorUnidades.determinarCategoria('Jengibre'), 'Frutas y Verduras');
      expect(ConversorUnidades.determinarCategoria('Maíz palomero'), 'Abarrotes y Alacena');
      expect(ConversorUnidades.determinarCategoria('Romero fresco'), 'Especias y Condimentos');
      expect(ConversorUnidades.determinarCategoria('Rábanos'), 'Frutas y Verduras');
      expect(ConversorUnidades.determinarCategoria('Rábano'), 'Frutas y Verduras');
    });
  });
}
