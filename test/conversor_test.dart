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

    test('5. Consolidación de extracto de vainilla, escencia, estracto y esencia', () {
      expect(ConversorUnidades.canonicalizarNombre('extracto de vainilla'), 'Extracto de vainilla');
      expect(ConversorUnidades.canonicalizarNombre('estracto de vainilla'), 'Extracto de vainilla');
      expect(ConversorUnidades.canonicalizarNombre('esencia de vainilla'), 'Extracto de vainilla');
      expect(ConversorUnidades.canonicalizarNombre('escencia de vainilla'), 'Extracto de vainilla');
      expect(ConversorUnidades.canonicalizarNombre('vainilla'), 'Extracto de vainilla');

      expect(
        ConversorUnidades.nombresCoinciden('estracto de vainilla', 'escencia de vainilla'),
        true,
      );
      expect(
        ConversorUnidades.nombresCoinciden('extracto de vainilla', 'esencia de vainilla'),
        true,
      );
      expect(
        ConversorUnidades.determinarCategoria('Extracto de vainilla'),
        'Especias y Condimentos',
      );
    });
  });

  group('Frutas y verduras en kg (redondeo a 0.05 kg)', () {
    test('Redondeo al múltiplo de 0.05 kg más cercano (mínimo 0.05)', () {
      expect(ConversorUnidades.redondearKg(0.16), 0.15);
      expect(ConversorUnidades.redondearKg(0.02), 0.05);
      expect(ConversorUnidades.redondearKg(0.96), 0.95);
      expect(ConversorUnidades.redondearKg(1.0), 1.0);
    });

    test('1 plátano -> 0.15 kg (≈ 1 pza)', () {
      final item = ConversorUnidades.normalizarParaSupermercado('plátano', 1, 'pza');
      expect(item.unidad, 'kg');
      expect(item.cantidad, 0.15);
      expect(item.textoCantidad, '0.15 kg (≈ 1 pza)');
    });

    test('Una penca de plátanos son ~6 piezas (~0.95 kg)', () {
      final item = ConversorUnidades.parsearLineaIngrediente('1 penca de plátano');
      expect(item.unidad, 'kg');
      expect(item.cantidad, 0.95);
      expect(item.textoCantidad, '0.95 kg (≈ 6 pzas)');
    });

    test('Jitomate: piezas y gramos convergen a kg', () {
      final porPiezas = ConversorUnidades.parsearLineaIngrediente('2 jitomates');
      expect(porPiezas.unidad, 'kg');
      expect(porPiezas.cantidad, 0.25);
      final porGramos = ConversorUnidades.parsearLineaIngrediente('250 g de jitomate');
      expect(porGramos.cantidad, 0.25);
    });

    test('Piezas pequeñas nunca bajan de 0.05 kg', () {
      final limon = ConversorUnidades.normalizarParaSupermercado('limón', 1, 'pza');
      expect(limon.cantidad, 0.05);
      final chile = ConversorUnidades.normalizarParaSupermercado('chile serrano', 3, 'pza');
      expect(chile.cantidad, 0.05);
    });

    test('Despensa interpreta frutas y verduras como kg', () {
      expect(
        ConversorUnidades.formatearParaDespensa('Plátano', 0.95),
        '0.95 kg (≈ 6 pzas) en despensa',
      );
      expect(ConversorUnidades.pasoKgFrutaVerdura('plátano'), 0.15);
    });
  });
}
