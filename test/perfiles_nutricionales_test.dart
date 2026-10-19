import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/perfiles_nutricionales.dart';

void main() {
  group('PerfilesNutricionales - Dieta Baja en Grasa (P17)', () {
    test('Contiene la constante y estilo "Baja en grasa"', () {
      expect(PerfilesNutricionales.bajaEnGrasa, 'Baja en grasa');
      expect(
        PerfilesNutricionales.estilos.contains(PerfilesNutricionales.bajaEnGrasa),
        isTrue,
      );
    });

    test('Normaliza alias como "Libre de grasa" o "sin grasa" hacia "Baja en grasa"', () {
      final resultado1 = PerfilesNutricionales.normalizar(['Libre de grasa']);
      expect(resultado1, contains('Baja en grasa'));

      final resultado2 = PerfilesNutricionales.normalizar(['sin grasa']);
      expect(resultado2, contains('Baja en grasa'));

      final resultado3 = PerfilesNutricionales.normalizar(['Baja en grasa']);
      expect(resultado3, contains('Baja en grasa'));
    });

    test('Ajusta macros a máx 20g de grasa y redistribuye calorías', () {
      final macrosBase = PerfilesNutricionales.macrosPara(
        PerfilesNutricionales.mantenimiento,
        [PerfilesNutricionales.libre],
      );
      expect(macrosBase['grasas'], greaterThan(20));

      final macrosBajaEnGrasa = PerfilesNutricionales.macrosPara(
        PerfilesNutricionales.mantenimiento,
        [PerfilesNutricionales.bajaEnGrasa],
      );
      expect(macrosBajaEnGrasa['grasas'], 20);
      expect(
        macrosBajaEnGrasa['carbs']!,
        greaterThan(macrosBase['carbs']!),
      );
    });

    test('Filtra recetas incompatibles con ingredientes grasos', () {
      // Recetas con manteca o chicharrón deben ser marcadas como incompatibles
      final compatible1 = PerfilesNutricionales.recetaCompatible(
        'Tacos de chicharrón prensado con manteca',
        [PerfilesNutricionales.bajaEnGrasa],
      );
      expect(compatible1, isFalse);

      final compatible2 = PerfilesNutricionales.recetaCompatible(
        'Pollo al vapor con verduras y arroz integral',
        [PerfilesNutricionales.bajaEnGrasa],
      );
      expect(compatible2, isTrue);
    });

    test('Instrucción IA para Chef está definida', () {
      final instruccion =
          PerfilesNutricionales.instruccionIA[PerfilesNutricionales.bajaEnGrasa];
      expect(instruccion, isNotNull);
      expect(instruccion, contains('BAJA EN GRASA'));
    });
  });
}
