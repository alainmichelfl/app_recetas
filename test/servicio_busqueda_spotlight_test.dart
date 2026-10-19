import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_busqueda_spotlight.dart';

void main() {
  group('ServicioBusquedaSpotlight - Búsqueda Global', () {
    final mockRecetas = [
      {
        'id': 1,
        'titulo': 'Tacos de Pescado Ensenada',
        'descripcion': 'Deliciosos tacos con aderezo de chipotle y col morada',
        'categoria': 'Pescados y Mariscos',
      },
      {
        'id': 2,
        'titulo': 'Sopa de Lentejas Casera',
        'descripcion': 'Receta clásica con verduras picadas y tocino',
        'categoria': 'Comida Casera',
      },
    ];

    final mockDespensa = [
      {
        'id_item': 101,
        'nombre': 'Jitomate Saladet',
        'cantidad': '1',
        'unidad_medida': 'kg',
      },
      {
        'id_item': 102,
        'nombre': 'Vino Tinto Cabernet Sauvignon',
        'cantidad': '2',
        'unidad_medida': 'botellas',
      },
      {
        'id_item': 103,
        'nombre': 'Pechuga de Pollo',
        'cantidad': '500',
        'unidad_medida': 'g',
      },
      {
        'id_item': 104,
        'nombre': 'Cerveza Corona Extra',
        'cantidad': '6',
        'unidad_medida': 'latas',
      },
    ];

    test('Query menor a 2 caracteres retorna lista vacía', () {
      final res = ServicioBusquedaSpotlight.buscar(
        query: 'a',
        recetas: mockRecetas,
        despensa: mockDespensa,
      );
      expect(res, isEmpty);
    });

    test('Encuentra recetas por título o descripción con insensibilidad a acentos', () {
      final res = ServicioBusquedaSpotlight.buscar(
        query: 'pescado',
        recetas: mockRecetas,
        despensa: mockDespensa,
      );

      final recetasEncontradas =
          res.where((r) => r.tipo == TipoResultadoSpotlight.receta).toList();
      expect(recetasEncontradas.isNotEmpty, isTrue);
      expect(recetasEncontradas.first.titulo, contains('Tacos de Pescado'));
    });

    test('Encuentra insumos de despensa y asigna zona física', () {
      final res = ServicioBusquedaSpotlight.buscar(
        query: 'jitomate',
        recetas: mockRecetas,
        despensa: mockDespensa,
      );

      final despensaEncontrada =
          res.where((r) => r.tipo == TipoResultadoSpotlight.despensa).toList();
      expect(despensaEncontrada.isNotEmpty, isTrue);
      expect(despensaEncontrada.first.titulo, equals('Jitomate Saladet'));
      expect(despensaEncontrada.first.ubicacion, isNotNull);
    });

    test('Identifica bebidas alcohólicas de despensa y las categoriza como Cava', () {
      final resVino = ServicioBusquedaSpotlight.buscar(
        query: 'cabernet',
        recetas: mockRecetas,
        despensa: mockDespensa,
      );

      final cavaVino =
          resVino.where((r) => r.tipo == TipoResultadoSpotlight.cava).toList();
      expect(cavaVino.isNotEmpty, isTrue);
      expect(cavaVino.first.titulo, contains('Vino Tinto'));

      final resCerveza = ServicioBusquedaSpotlight.buscar(
        query: 'cerveza',
        recetas: mockRecetas,
        despensa: mockDespensa,
      );
      final cavaCerveza =
          resCerveza.where((r) => r.tipo == TipoResultadoSpotlight.cava).toList();
      expect(cavaCerveza.isNotEmpty, isTrue);
    });

    test('Encuentra electrodomésticos y utensilios por nombre o palabra clave', () {
      final resAirfryer = ServicioBusquedaSpotlight.buscar(
        query: 'airfryer',
        recetas: mockRecetas,
        despensa: mockDespensa,
      );
      final utensilios = resAirfryer
          .where((r) => r.tipo == TipoResultadoSpotlight.utensilio)
          .toList();
      expect(utensilios.isNotEmpty, isTrue);
      expect(utensilios.first.titulo, contains('Freidora'));

      final resBatidora = ServicioBusquedaSpotlight.buscar(
        query: 'kitchenaid',
        recetas: mockRecetas,
        despensa: mockDespensa,
      );
      final batidora = resBatidora
          .where((r) => r.tipo == TipoResultadoSpotlight.utensilio)
          .toList();
      expect(batidora.isNotEmpty, isTrue);
      expect(batidora.first.titulo, contains('Batidora'));
    });
  });
}
