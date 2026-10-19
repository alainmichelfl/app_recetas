import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_sommelier.dart';

void main() {
  group('ServicioSommelier - Motor Heurístico de Maridaje (P18)', () {
    test('Maridaje para mariscos y pescados', () {
      final maridaje = ServicioSommelier.generarMaridajeHeuristico(
        'Ceviche de camarón y pulpo con aguacate',
        ingredientes: ['camarón', 'pulpo', 'limón', 'jitomate', 'cilantro'],
      );

      expect(maridaje.categoriaPerfil, contains('Mariscos'));
      expect(maridaje.vino.toLowerCase(), contains('sauvignon blanc'));
      expect(maridaje.destilado.toLowerCase(), anyOf(contains('gin'), contains('mezcal')));
      expect(maridaje.sinAlcohol.toLowerCase(), contains('pepino'));
      expect(maridaje.temperaturaServicio, contains('7°C'));
      expect(maridaje.ingredientesBebida, isNotEmpty);
    });

    test('Maridaje para cortes y carne de res', () {
      final maridaje = ServicioSommelier.generarMaridajeHeuristico(
        'Rib Eye a la parrilla con papas al romero',
        ingredientes: ['corte rib eye', 'sal de grano', 'papas', 'romero'],
      );

      expect(maridaje.categoriaPerfil, contains('Cortes'));
      expect(maridaje.vino.toLowerCase(), anyOf(contains('cabernet'), contains('malbec')));
      expect(maridaje.destilado.toLowerCase(), anyOf(contains('whisky'), contains('old fashioned')));
      expect(maridaje.sinAlcohol.toLowerCase(), contains('cold brew'));
    });

    test('Maridaje para pastas italianas', () {
      final maridaje = ServicioSommelier.generarMaridajeHeuristico(
        'Espagueti a la boloñesa tradicional con queso parmesano',
        ingredientes: ['pasta', 'jitomate', 'carne molida', 'parmesano'],
      );

      expect(maridaje.categoriaPerfil, contains('Italiana'));
      expect(maridaje.vino.toLowerCase(), contains('chianti'));
      expect(maridaje.destilado.toLowerCase(), anyOf(contains('aperol'), contains('negroni')));
    });

    test('Maridaje para postres y dulces', () {
      final maridaje = ServicioSommelier.generarMaridajeHeuristico(
        'Pastel de chocolate amargo con helado de vainilla',
        ingredientes: ['chocolate', 'harina', 'vainilla', 'azúcar'],
      );

      expect(maridaje.categoriaPerfil, contains('Postres'));
      expect(maridaje.vino.toLowerCase(), anyOf(contains('oporto'), contains('moscato')));
      expect(maridaje.destilado.toLowerCase(), anyOf(contains('carajillo'), contains('baileys')));
      expect(maridaje.sinAlcohol.toLowerCase(), contains('chocolate'));
    });

    test('Formato de resumen para compartir y serialización', () {
      final maridaje = ServicioSommelier.generarMaridajeHeuristico(
        'Tacos de arrachera asada',
      );

      final resumen = maridaje.resumenParaCompartir('Tacos de arrachera');
      expect(resumen, contains('Vino:'));
      expect(resumen, contains('Destilado / Cóctel:'));
      expect(resumen, contains('Sin Alcohol:'));
      expect(resumen, contains('Jitomate y Cebolla'));

      final mapa = maridaje.toMap();
      final reconstruido = MaridajeReceta.fromMap(mapa);
      expect(reconstruido.vino, maridaje.vino);
      expect(reconstruido.destilado, maridaje.destilado);
      expect(reconstruido.sinAlcohol, maridaje.sinAlcohol);
      expect(reconstruido.categoriaPerfil, maridaje.categoriaPerfil);
    });
  });
}
