import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/utensilios_cocina.dart';

void main() {
  group('UtensiliosCocina - Catálogo y Serialización', () {
    test('Catálogo contiene 10 utensilios clave', () {
      expect(UtensiliosCocina.catalogo.length, 10);
      final ids = UtensiliosCocina.catalogo.map((u) => u.id).toSet();
      expect(ids.contains('sarten'), isTrue);
      expect(ids.contains('licuadora'), isTrue);
      expect(ids.contains('air_fryer'), isTrue);
      expect(ids.contains('thermomix'), isTrue);
      expect(ids.contains('horno'), isTrue);
    });

    test('Por defecto incluye sartén y licuadora', () {
      final porDefecto = UtensiliosCocina.porDefecto;
      expect(porDefecto.contains('sarten'), isTrue);
      expect(porDefecto.contains('licuadora'), isTrue);
    });

    test('Deserializar con null o vacío retorna los valores por defecto', () {
      expect(UtensiliosCocina.deserializar(null), equals(UtensiliosCocina.porDefecto));
      expect(UtensiliosCocina.deserializar(''), equals(UtensiliosCocina.porDefecto));
      expect(UtensiliosCocina.deserializar('   '), equals(UtensiliosCocina.porDefecto));
    });

    test('Serializar y deserializar es simétrico', () {
      final lista = ['sarten', 'air_fryer', 'thermomix'];
      final serializado = UtensiliosCocina.serializar(lista);
      expect(serializado, contains('sarten'));
      expect(serializado, contains('air_fryer'));
      expect(serializado, contains('thermomix'));

      final recuperada = UtensiliosCocina.deserializar(serializado);
      expect(recuperada, containsAll(['sarten', 'air_fryer', 'thermomix']));
    });
  });

  group('UtensiliosCocina - Detección de Faltantes y Prompt Chef', () {
    test('Detecta equipo faltante si la receta lo requiere explícitamente', () {
      // El usuario solo tiene sarten y licuadora
      final misUtensilios = ['sarten', 'licuadora'];
      const recetaConHornoYAirFryer =
          'Precalentar el horno a 200°C. Colocar en charola para hornear y luego dorar en la freidora de aire.';

      final faltantes = UtensiliosCocina.detectarUtensiliosFaltantes(
        textoReceta: recetaConHornoYAirFryer,
        misUtensilios: misUtensilios,
      );

      final idsFaltantes = faltantes.map((f) => f.id).toList();
      expect(idsFaltantes.contains('horno'), isTrue);
      expect(idsFaltantes.contains('air_fryer'), isTrue);
    });

    test('No reporta faltantes si el usuario cuenta con los electrodomésticos', () {
      final misUtensilios = ['sarten', 'licuadora', 'horno', 'air_fryer'];
      const receta = 'Hornear a 180°C y pasar por la freidora de aire.';

      final faltantes = UtensiliosCocina.detectarUtensiliosFaltantes(
        textoReceta: receta,
        misUtensilios: misUtensilios,
      );

      expect(faltantes, isEmpty);
    });

    test('Genera instrucciones para el prompt del Chef con advertencia de ausentes', () {
      final prompt = UtensiliosCocina.instruccionesPrompt(['sarten', 'licuadora']);
      expect(prompt, contains('EQUIPO Y UTENSILIOS DISPONIBLES'));
      expect(prompt, contains('Sartén y Estufa'));
      expect(prompt, contains('RESTRICCIÓN DE EQUIPO (MUY IMPORTANTE)'));
      expect(prompt, contains('PROHIBIDO diseñar recetas que obligatoriamente requieran estos equipos ausentes'));
    });
  });
}
