import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_recetas.dart';

void main() {
  group('ServicioRecetas - Lógica de Segmentación y Audiencia', () {
    const String myUid = 'user-12345';
    const String otherUid = 'user-67890';

    test('Identifica recetas oficiales cuando es_oficial es true o user_id es null', () {
      final recetaOficial1 = {
        'id_receta': 1,
        'titulo': 'Chilaquiles Rojos',
        'es_oficial': true,
        'user_id': null,
      };

      final recetaOficial2 = {
        'id_receta': 2,
        'titulo': 'Tacos al Pastor',
        'es_oficial': 'true',
        'user_id': 'admin-uid',
      };

      final recetaBaseSinUserId = {
        'id_receta': 3,
        'titulo': 'Sopa de Verduras',
      };

      expect(ServicioRecetas.esOficial(recetaOficial1), isTrue);
      expect(ServicioRecetas.esOficial(recetaOficial2), isTrue);
      expect(ServicioRecetas.esOficial(recetaBaseSinUserId), isTrue);
    });

    test('Identifica recetas propias del usuario', () {
      final miReceta = {
        'id_receta': 10,
        'titulo': 'Mi Ensalada Especial',
        'es_oficial': false,
        'user_id': myUid,
        'es_publica': false,
      };

      final otraReceta = {
        'id_receta': 11,
        'titulo': 'Receta de Otra Persona',
        'es_oficial': false,
        'user_id': otherUid,
        'es_publica': true,
      };

      expect(ServicioRecetas.esMiReceta(miReceta, myUid), isTrue);
      expect(ServicioRecetas.esMiReceta(otraReceta, myUid), isFalse);
    });

    test('Identifica recetas compartidas con la comunidad', () {
      final recetaComunidad = {
        'id_receta': 20,
        'titulo': 'Pastel de la Abuela',
        'es_oficial': false,
        'user_id': otherUid,
        'es_publica': true,
      };

      final recetaPrivadaDeOtro = {
        'id_receta': 21,
        'titulo': 'Secreto Familiar',
        'es_oficial': false,
        'user_id': otherUid,
        'es_publica': false,
      };

      final miReceta = {
        'id_receta': 22,
        'titulo': 'Mi propia receta',
        'es_oficial': false,
        'user_id': myUid,
        'es_publica': true,
      };

      expect(ServicioRecetas.esComunidad(recetaComunidad, myUid), isTrue);
      expect(ServicioRecetas.esComunidad(recetaPrivadaDeOtro, myUid), isFalse);
      expect(ServicioRecetas.esComunidad(miReceta, myUid), isFalse); // Es mía, no de la comunidad externa
    });

    test('Identifica recetas caninas por tipo_comida o título', () {
      expect(
        ServicioRecetas.esRecetaCanina({'tipo_comida': 'Snack Canino'}),
        isTrue,
      );
      expect(
        ServicioRecetas.esRecetaCanina({'tipo_comida': 'Premio Perruno'}),
        isTrue,
      );
      expect(
        ServicioRecetas.esRecetaCanina({'tipo_comida': 'Receta Canina'}),
        isTrue,
      );
      expect(
        ServicioRecetas.esRecetaCanina({'titulo': 'Galletas para perro de avena'}),
        isTrue,
      );
      expect(
        ServicioRecetas.esRecetaCanina({'tipo_comida': 'Comida', 'titulo': 'Enchiladas Verdes'}),
        isFalse,
      );
      expect(
        ServicioRecetas.esRecetaCanina({'tipo_comida': 'Desayuno', 'titulo': 'Huevos con jamón'}),
        isFalse,
      );
    });
  });
}
