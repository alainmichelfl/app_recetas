import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_voz_cocina.dart';

void main() {
  group('ServicioVozCocina - Interpretación de Comandos', () {
    test('Interpreta correctamente comando "siguiente"', () {
      expect(ServicioVozCocina.interpretarTexto('siguiente'), ComandoVoz.siguiente);
      expect(ServicioVozCocina.interpretarTexto('siguiente paso por favor'), ComandoVoz.siguiente);
      expect(ServicioVozCocina.interpretarTexto('avanzar'), ComandoVoz.siguiente);
      expect(ServicioVozCocina.interpretarTexto('adelante'), ComandoVoz.siguiente);
      expect(ServicioVozCocina.interpretarTexto('listo'), ComandoVoz.siguiente);
      expect(ServicioVozCocina.interpretarTexto('ya quedó'), ComandoVoz.siguiente);
    });

    test('Interpreta correctamente comando "anterior"', () {
      expect(ServicioVozCocina.interpretarTexto('atrás'), ComandoVoz.anterior);
      expect(ServicioVozCocina.interpretarTexto('atras'), ComandoVoz.anterior);
      expect(ServicioVozCocina.interpretarTexto('regresar'), ComandoVoz.anterior);
      expect(ServicioVozCocina.interpretarTexto('paso anterior'), ComandoVoz.anterior);
      expect(ServicioVozCocina.interpretarTexto('volver'), ComandoVoz.anterior);
    });

    test('Interpreta correctamente comando "terminar"', () {
      expect(ServicioVozCocina.interpretarTexto('terminar'), ComandoVoz.terminar);
      expect(ServicioVozCocina.interpretarTexto('finalizar receta'), ComandoVoz.terminar);
      expect(ServicioVozCocina.interpretarTexto('ya terminé'), ComandoVoz.terminar);
      expect(ServicioVozCocina.interpretarTexto('acabar'), ComandoVoz.terminar);
    });

    test('Identifica texto no relacionado como desconocido', () {
      expect(ServicioVozCocina.interpretarTexto('agrega dos jitomates'), ComandoVoz.desconocido);
      expect(ServicioVozCocina.interpretarTexto('hola chef'), ComandoVoz.desconocido);
    });

    test('procesarComando ejecuta la retrollamada adecuada', () {
      final servicio = ServicioVozCocina();
      bool siguienteLlamado = false;
      bool anteriorLlamado = false;
      bool terminarLlamado = false;

      servicio.onSiguiente = () => siguienteLlamado = true;
      servicio.onAnterior = () => anteriorLlamado = true;
      servicio.onTerminar = () => terminarLlamado = true;

      servicio.procesarComando('siguiente');
      expect(siguienteLlamado, isTrue);
      expect(anteriorLlamado, isFalse);

      servicio.procesarComando('ir atrás');
      expect(anteriorLlamado, isTrue);

      servicio.procesarComando('terminar la preparación');
      expect(terminarLlamado, isTrue);
    });
  });
}
