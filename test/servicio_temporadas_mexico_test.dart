import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_temporadas_mexico.dart';

void main() {
  group('ServicioTemporadasMexico - Calendario Estacional y Prompt de Cosecha', () {
    test('Obtiene los 12 meses del almanaque correctamente', () {
      final meses = ServicioTemporadasMexico.obtenerTodosLosMeses();
      expect(meses.length, equals(12));
      expect(meses.first.nombreMes, equals('Enero'));
      expect(meses.last.nombreMes, equals('Diciembre'));
    });

    test('Mes de Octubre tiene calabaza de castilla, camote, canela y manzana', () {
      final octubre = ServicioTemporadasMexico.obtenerPorMes(10);
      expect(octubre.nombreMes, equals('Octubre'));
      expect(octubre.icono, equals('🍂'));
      expect(octubre.ingredientesClave, contains('calabaza de castilla'));
      expect(octubre.ingredientesClave, contains('camote amarillo y morado'));
      expect(octubre.ingredientesClave, contains('manzana mexicana'));
      expect(octubre.ingredientesClave, contains('canela'));
    });

    test('Mes de Septiembre tiene chile poblano, granada y nuez de castilla', () {
      final septiembre = ServicioTemporadasMexico.obtenerPorMes(9);
      expect(septiembre.nombreMes, equals('Septiembre'));
      expect(septiembre.icono, equals('🇲🇽'));
      expect(septiembre.ingredientesClave, contains('granada roja'));
      expect(septiembre.ingredientesClave, contains('nuez de castilla'));
      expect(septiembre.ingredientesClave, contains('chile poblano'));
    });

    test('Mes de Marzo tiene ingredientes de Cuaresma y Primavera', () {
      final marzo = ServicioTemporadasMexico.obtenerPorMes(3);
      expect(marzo.nombreMes, equals('Marzo'));
      expect(marzo.ingredientesClave, contains('habas verdes'));
      expect(marzo.ingredientesClave, contains('pescado blanco'));
      expect(marzo.ingredientesClave, contains('quelites'));
    });

    test('obtenerTemporadaActual responde con fecha simulada o actual', () {
      final fechaSimulada = DateTime(2026, 10, 20);
      final temp = ServicioTemporadasMexico.obtenerTemporadaActual(fechaSimulada);
      expect(temp.mesNumero, equals(10));
      expect(temp.nombreMes, equals('Octubre'));
    });

    test('generarDirectrizEstacionalPrompt incluye reglas estrictas para evitar azar', () {
      final octubre = ServicioTemporadasMexico.obtenerPorMes(10);
      final prompt = ServicioTemporadasMexico.generarDirectrizEstacionalPrompt(octubre);

      expect(prompt, contains('NO generes recetas al azar'));
      expect(prompt, contains('Octubre'));
      expect(prompt, contains('calabaza de castilla'));
      expect(prompt, contains('tianguis, recauderías y supermercados de México'));
    });
  });
}
