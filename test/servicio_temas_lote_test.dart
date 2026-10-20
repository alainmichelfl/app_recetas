import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_temas_lote.dart';

void main() {
  group('ServicioTemasLote - Catálogo Integral de 37 Especiales y Ruleta Sorpresa', () {
    test('Contiene exactamente 37 temas oficiales distribuidos en 5 grupos', () {
      final todos = ServicioTemasLote.obtenerTodos();
      expect(todos.length, equals(37));

      final temporadas = ServicioTemasLote.obtenerPorGrupo(GrupoTemaLote.temporada);
      expect(temporadas.length, equals(12));

      final cocinas = ServicioTemasLote.obtenerPorGrupo(GrupoTemaLote.cocinasMundo);
      expect(cocinas.length, equals(10));

      final estilos = ServicioTemasLote.obtenerPorGrupo(GrupoTemaLote.estilosVida);
      expect(estilos.length, equals(4));

      final fitness = ServicioTemasLote.obtenerPorGrupo(GrupoTemaLote.fitnessSalud);
      expect(fitness.length, equals(5));

      final ahorro = ServicioTemasLote.obtenerPorGrupo(GrupoTemaLote.ahorroAntojos);
      expect(ahorro.length, equals(6));
    });

    test('Todos los temas tienen títulos, íconos y directrices de prompt bien formadas', () {
      final todos = ServicioTemasLote.obtenerTodos();
      for (final t in todos) {
        expect(t.id.isNotEmpty, isTrue);
        expect(t.tituloCorto.isNotEmpty, isTrue);
        expect(t.icono.isNotEmpty, isTrue);
        expect(t.temaCompleto.isNotEmpty, isTrue);
        expect(t.directrizPrompt.isNotEmpty, isTrue);
        expect(t.resumenEnfoque.isNotEmpty, isTrue);
      }
    });

    test('Obtener temporada actual responde correctamente', () {
      final fechaSimulada = DateTime(2026, 10, 20);
      final temaOctubre = ServicioTemasLote.obtenerTemporadaActual(fechaSimulada);

      expect(temaOctubre.grupo, equals(GrupoTemaLote.temporada));
      expect(temaOctubre.tituloCorto, equals('Octubre'));
      expect(temaOctubre.icono, equals('🍂'));
      expect(temaOctubre.directrizPrompt, contains('calabaza de castilla'));
    });

    test('Ruleta Sorpresa (obtenerAleatorio) retorna un tema válido del catálogo', () {
      final tema = ServicioTemasLote.obtenerAleatorio();
      expect(tema, isNotNull);
      expect(tema.tituloCorto.isNotEmpty, isTrue);
      expect(tema.temaCompleto.isNotEmpty, isTrue);
    });

    test('Cocina Italia, Cero Trastes y High Protein tienen directrices especializadas', () {
      final cocinas = ServicioTemasLote.obtenerPorGrupo(GrupoTemaLote.cocinasMundo);
      final italia = cocinas.firstWhere((c) => c.id == 'cocina_italia');
      expect(italia.directrizPrompt, contains('Italiana'));
      expect(italia.icono, equals('🇮🇹'));

      final estilos = ServicioTemasLote.obtenerPorGrupo(GrupoTemaLote.estilosVida);
      final ceroTrastes = estilos.firstWhere((e) => e.id == 'estilo_cero_trastes');
      expect(ceroTrastes.directrizPrompt, contains('One-Pan'));
      expect(ceroTrastes.icono, equals('🍳'));

      final fitness = ServicioTemasLote.obtenerPorGrupo(GrupoTemaLote.fitnessSalud);
      final highProtein = fitness.firstWhere((f) => f.id == 'fitness_high_protein');
      expect(highProtein.directrizPrompt, contains('35g y 50g de proteína'));
      expect(highProtein.icono, equals('💪'));
    });
  });
}
