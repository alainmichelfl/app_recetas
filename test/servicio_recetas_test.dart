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

  group('ServicioRecetas - Resolución y Optimización de Imágenes', () {
    test('Retorna la imagen curada por ID cuando existe en el catálogo verificado', () {
      final imgPancakes = ServicioRecetas.obtenerImagenOptimizada(
        idReceta: 36,
        titulo: 'Pancakes de Avena',
        rawUrl: 'https://images.unsplash.com/photo-broken',
      );
      expect(imgPancakes, contains('photo-1506084868230-bb9d95c24759'));

      final imgPicadillo = ServicioRecetas.obtenerImagenOptimizada(
        idReceta: 110,
        titulo: 'Picadillo Tradicional',
        rawUrl: null,
      );
      expect(imgPicadillo, contains('photo-1590655367923-fa80b7e61b6c'));
    });

    test('Maneja el caso especial del picadillo por título cuando la URL es nula o rota', () {
      final img = ServicioRecetas.obtenerImagenOptimizada(
        titulo: 'Picadillo Tradicional Casero',
        rawUrl: 'https://images.unsplash.com/photo-546069901-ba9599a7e63c',
      );
      expect(img, contains('photo-1590655367923-fa80b7e61b6c'));
    });

    test('Optimiza URLs de Unsplash con parámetros para dispositivos móviles', () {
      const urlSimple = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c';
      final optimizada = ServicioRecetas.obtenerImagenOptimizada(
        rawUrl: urlSimple,
      );
      expect(optimizada, contains('auto=format'));
      expect(optimizada, contains('fit=crop'));
      expect(optimizada, contains('w=600'));
    });

    test('Garantiza que todas las 48 imágenes del mapa verificado son 100% únicas', () {
      final map = ServicioRecetas.imagenesVerificadasPorId;
      expect(map.length, equals(48));
      final uniqueUrls = map.values.toSet();
      expect(uniqueUrls.length, equals(48));
    });

    test('Retorna null cuando no hay URL ni coincidencia', () {
      expect(ServicioRecetas.obtenerImagenOptimizada(), isNull);
      expect(ServicioRecetas.obtenerImagenOptimizada(rawUrl: ''), isNull);
      expect(ServicioRecetas.obtenerImagenOptimizada(rawUrl: '   '), isNull);
    });
  });
}
