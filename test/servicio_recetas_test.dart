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

    test('Identifica recetas de Recién Salidas del Sartén por es_novedad o heurística de lote', () {
      final recetaNovedadExplicita = {
        'id_receta': 150,
        'titulo': 'Nuevo Guisado',
        'es_novedad': true,
        'es_oficial': true,
      };

      final recetaNovedadTexto = {
        'id_receta': 151,
        'titulo': 'Nuevo Postre',
        'es_novedad': 'true',
        'es_oficial': true,
      };

      final recetaAntiguaNoNovedad = {
        'id_receta': 40,
        'titulo': 'Pechuga al Limón',
        'es_novedad': false,
        'es_oficial': true,
      };

      final recetaHeuristicaLote102 = {
        'id_receta': 110,
        'titulo': 'Picadillo Tradicional',
        'es_oficial': true,
      };

      final recetaHeuristicaPrivada = {
        'id_receta': 115,
        'titulo': 'Privada',
        'es_oficial': false,
        'user_id': 'usuario-123',
      };

      expect(ServicioRecetas.esNovedad(recetaNovedadExplicita), isTrue);
      expect(ServicioRecetas.esNovedad(recetaNovedadTexto), isTrue);
      expect(ServicioRecetas.esNovedad(recetaAntiguaNoNovedad), isFalse);
      expect(ServicioRecetas.esNovedad(recetaHeuristicaLote102), isTrue);
      expect(ServicioRecetas.esNovedad(recetaHeuristicaPrivada), isFalse);
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

    test('Garantiza que el catálogo verificado cubre todas las recetas con URLs optimizadas', () {
      final map = ServicioRecetas.imagenesVerificadasPorId;
      expect(map.length, greaterThanOrEqualTo(94));
      for (final url in map.values) {
        expect(url.isNotEmpty, isTrue);
        if (url.contains('unsplash.com')) {
          expect(url, contains('auto=format'));
          expect(url, contains('w=600'));
        }
      }

      // Verificación específica de recetas reportadas por el usuario:
      // ID 76: Tacos de huevo con nopal (no tacos al pastor)
      final imgTacosHuevo = ServicioRecetas.obtenerImagenOptimizada(
        idReceta: 76,
        titulo: 'Tacos de Huevo con Nopal',
      );
      expect(imgTacosHuevo, isNotNull);
      expect(imgTacosHuevo, isNot(contains('photo-1565299585323'))); // no al pastor
      expect(imgTacosHuevo, contains('tacos_huevo_nopal'));

      // ID 87: Quesadillas de flor de calabaza (no espinaca)
      final imgQuesadillas = ServicioRecetas.obtenerImagenOptimizada(
        idReceta: 87,
        titulo: 'Quesadillas de Flor de Calabaza',
      );
      expect(imgQuesadillas, isNotNull);
      expect(imgQuesadillas, contains('quesadillas_flor_calabaza'));

      // ID 112: Tacos de lechuga con salpicón de pollo (no quinoa)
      final imgSalpicon = ServicioRecetas.obtenerImagenOptimizada(
        idReceta: 112,
        titulo: 'Tacos de Lechuga con Salpicón de Pollo',
      );
      expect(imgSalpicon, isNotNull);
      expect(imgSalpicon, isNot(contains('photo-1543339308'))); // no tazón de quinoa
      expect(imgSalpicon, contains('tacos_lechuga_salpicon_pollo'));

      // ID 116: Sopa de tortilla tradicional saludable (no crema de calabacita)
      final imgSopaTortilla = ServicioRecetas.obtenerImagenOptimizada(
        idReceta: 116,
        titulo: 'Sopa de Tortilla Tradicional Saludable',
      );
      expect(imgSopaTortilla, isNotNull);
      expect(imgSopaTortilla, isNot(contains('photo-1547592166'))); // no crema de calabacita
      expect(imgSopaTortilla, contains('sopa_tortilla_tradicional'));

      // ID 104: Molletes tradicionales con pico de gallo fresco (no tostadas de aguacate)
      final imgMolletes = ServicioRecetas.obtenerImagenOptimizada(
        idReceta: 104,
        titulo: 'Molletes Tradicionales con Pico de Gallo Fresco',
      );
      expect(imgMolletes, isNotNull);
      expect(imgMolletes, isNot(contains('photo-1588137378633-dea1336ce1e2'))); // no aguacate
      expect(imgMolletes, contains('molletes_pico_de_gallo'));

      // ID 129: Copa de yogur con mandarina, guayaba y canela (no fresas)
      final imgYogur = ServicioRecetas.obtenerImagenOptimizada(
        idReceta: 129,
        titulo: 'Copa de Yogur con Mandarina, Guayaba y Canela',
      );
      expect(imgYogur, isNotNull);
      expect(imgYogur, isNot(contains('photo-1488477181946-6428a0291777'))); // no fresas
      expect(imgYogur, contains('copa_yogur_mandarina_guayaba'));

      // ID 105: Bowl de avena cremosa con manzana y canela (no pan francés)
      final imgAvena = ServicioRecetas.obtenerImagenOptimizada(idReceta: 105, titulo: 'Bowl de avena cremosa');
      expect(imgAvena, isNotNull);
      expect(imgAvena, isNot(contains('photo-1484723091739'))); // no pan francés
      expect(imgAvena, contains('1669559809547-6e4c4fe41371')); // avena con manzana

      // ID 106: Tostadas de huevo pochado con aguacate (no tocadiscos de vinilo)
      final imgHuevo = ServicioRecetas.obtenerImagenOptimizada(idReceta: 106, titulo: 'Tostadas de huevo pochado');
      expect(imgHuevo, isNotNull);
      expect(imgHuevo, isNot(contains('photo-1539185441755'))); // no vinilo
      expect(imgHuevo, contains('photo-1525351484163-7529414344d8')); // huevo pochado con aguacate
    });

    test('Retorna null cuando no hay URL ni título', () {
      expect(ServicioRecetas.obtenerImagenOptimizada(), isNull);
      expect(ServicioRecetas.obtenerImagenOptimizada(rawUrl: ''), isNull);
      expect(ServicioRecetas.obtenerImagenOptimizada(rawUrl: '   '), isNull);
    });

    test('Resuelve por semántica determinista cuando la URL es nula, vacía o en lista negra', () {
      // 1. URL de tocadiscos de vinilo (en lista negra) para tostadas de huevo
      final imgViniloRechazado = ServicioRecetas.obtenerImagenOptimizada(
        titulo: 'Tostadas de huevo pochado y aguacate',
        rawUrl: 'https://images.unsplash.com/photo-1539185441755-900388151321',
      );
      expect(imgViniloRechazado, isNotNull);
      expect(imgViniloRechazado, isNot(contains('photo-1539185441755')));
      expect(imgViniloRechazado, contains('photo-1525351484163-7529414344d8')); // Huevo pochado auténtico

      // 2. Receta nueva de avena sin URL
      final imgAvenaNueva = ServicioRecetas.obtenerImagenOptimizada(
        titulo: 'Avena con manzana y nueces',
      );
      expect(imgAvenaNueva, isNotNull);
      expect(imgAvenaNueva, contains('1669559809547-6e4c4fe41371'));

      // 3. Receta nueva de salmón
      final imgSalmon = ServicioRecetas.obtenerImagenOptimizada(
        titulo: 'Filete de salmón a la plancha',
      );
      expect(imgSalmon, contains('photo-1519708227418-c8fd9a32b7a2'));
    });

    test('auditarImagenReceta identifica y sanea URLs discordantes o en lista negra', () {
      // 1. Receta del catálogo oficial (ID 106) con URL de vinilo en la base de datos
      final audit1 = ServicioRecetas.auditarImagenReceta(
        idReceta: 106,
        titulo: 'Tostadas de huevo pochado con aguacate',
        tipoComida: 'Desayuno',
        urlActual: 'https://images.unsplash.com/photo-1539185441755-900388151321',
      );
      expect(audit1['cambiada'], isTrue);
      expect(audit1['url'], contains('photo-1525351484163-7529414344d8'));

      // 2. Receta que ya tiene la URL canónica verificada
      final audit2 = ServicioRecetas.auditarImagenReceta(
        idReceta: 106,
        titulo: 'Tostadas de huevo pochado con aguacate',
        tipoComida: 'Desayuno',
        urlActual: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=600&q=80',
      );
      expect(audit2['cambiada'], isFalse);

      // 3. Receta nueva sin URL (nula)
      final audit3 = ServicioRecetas.auditarImagenReceta(
        idReceta: 9999,
        titulo: 'Bowl de Avena con Plátano',
        tipoComida: 'Desayuno',
        urlActual: null,
      );
      expect(audit3['cambiada'], isTrue);
      expect(audit3['url'], contains('1669559809547-6e4c4fe41371'));
    });
  });
}
