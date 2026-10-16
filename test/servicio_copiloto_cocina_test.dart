import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_copiloto_cocina.dart';

void main() {
  group('ServicioCopilotoCocina - Parseo de Pasos y Parámetros Robot', () {
    test('Parsea paso Thermomix con corchetes estándar', () {
      const paso = '[5 seg | Sin temp | Vel 5] Picar la cebolla y los dientes de ajo en el vaso.';
      final params = ServicioCopilotoCocina.parsearPaso(
        paso,
        modo: ModoElectrodomestico.thermomix,
      );

      expect(params.tieneParametros, isTrue);
      expect(params.tiempo, '5 seg');
      expect(params.temperatura, 'Sin temp');
      expect(params.velocidad, 'Vel 5');
      expect(params.textoLimpio, 'Picar la cebolla y los dientes de ajo en el vaso.');
    });

    test('Parsea paso complejo con Varoma, Giro inverso y Mariposa', () {
      const paso = '[25 min | Varoma | Giro inverso ↺ | Vel cuchara 🥄 | Mariposa 🦋] Añadir el pollo y las papas.';
      final params = ServicioCopilotoCocina.parsearPaso(
        paso,
        modo: ModoElectrodomestico.thermomix,
      );

      expect(params.tieneParametros, isTrue);
      expect(params.tiempo, '25 min');
      expect(params.temperatura, 'Varoma');
      expect(params.velocidad, contains('cuchara'));
      expect(params.giro, contains('inverso'));
      expect(params.accesorio, contains('Mariposa'));
      expect(params.textoLimpio, 'Añadir el pollo y las papas.');
    });

    test('Parsea paso Air Fryer con temperatura, tiempo y volteo', () {
      const paso = '[190°C | 18 min | Agitar a los 9 min] Colocar los trozos de pechuga en la canastilla.';
      final params = ServicioCopilotoCocina.parsearPaso(
        paso,
        modo: ModoElectrodomestico.airFryer,
      );

      expect(params.tieneParametros, isTrue);
      expect(params.temperatura, '190°C');
      expect(params.tiempo, '18 min');
      expect(params.accesorio, contains('Agitar'));
      expect(params.textoLimpio, 'Colocar los trozos de pechuga en la canastilla.');
    });

    test('Detecta contextualmente parámetros Thermomix sin corchetes', () {
      const paso = 'Programar 15 min a 100°C en velocidad 2 con giro inverso.';
      final params = ServicioCopilotoCocina.parsearPaso(
        paso,
        modo: ModoElectrodomestico.thermomix,
      );

      expect(params.tieneParametros, isTrue);
      expect(params.tiempo, '15 min');
      expect(params.temperatura, '100°C');
      expect(params.velocidad, contains('velocidad 2'));
      expect(params.giro, contains('Giro inverso'));
    });

    test('Paso tradicional sin parámetros no genera falsos positivos', () {
      const paso = 'Mezclar la ensalada con el aderezo en un tazón hondo.';
      final params = ServicioCopilotoCocina.parsearPaso(
        paso,
        modo: ModoElectrodomestico.tradicional,
      );

      expect(params.tieneParametros, isFalse);
      expect(params.tiempo, isNull);
      expect(params.temperatura, isNull);
      expect(params.velocidad, isNull);
      expect(params.textoLimpio, 'Mezclar la ensalada con el aderezo en un tazón hondo.');
    });
  });
}
