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

    test('3. Consolidación de chispas de chocolate 70% cacao y coincidencia con anaquel', () {
      expect(
        ConversorUnidades.canonicalizarNombre('chispas de chocolate 70% cacao'),
        'Chispas de chocolate 70% cacao',
      );
      expect(
        ConversorUnidades.canonicalizarNombre('chispas de chocolate amargo'),
        'Chispas de chocolate 70% cacao',
      );
      expect(
        ConversorUnidades.canonicalizarNombre('chispas de chocolate'),
        'Chispas de chocolate 70% cacao',
      );
      expect(
        ConversorUnidades.canonicalizarNombre('chocolate amargo'),
        'Chispas de chocolate 70% cacao',
      );
      expect(
        ConversorUnidades.canonicalizarNombre('chocolate amargo 70%'),
        'Chispas de chocolate 70% cacao',
      );

      // Coincidencia con catálogo de supermercado (ID 72 y 148) para cotización
      expect(
        ConversorUnidades.nombresCoinciden('Chispas de chocolate 70% cacao', 'Chispas de chocolate amargo'),
        true,
      );
      expect(
        ConversorUnidades.nombresCoinciden('Chispas de chocolate 70% cacao', 'Chocolate amargo 70%'),
        true,
      );
      // No debe coincidir con chocolate blanco ni chocolate con leche
      expect(
        ConversorUnidades.nombresCoinciden('Chispas de chocolate 70% cacao', 'Chocolate blanco'),
        false,
      );
      expect(
        ConversorUnidades.determinarCategoria('Chispas de chocolate 70% cacao'),
        'Abarrotes y Alacena',
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
