import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_bienestar.dart';

void main() {
  group('ServicioBienestar - Calculadora Metabólica Mifflin-St Jeor (P23)', () {
    test('Calcula BMR para hombre y mujer correctamente', () {
      // Hombre: 70kg, 175cm, 25 años
      // BMR = 10(70) + 6.25(175) - 5(25) + 5 = 700 + 1093.75 - 125 + 5 = 1673.75 -> 1674
      final bmrHombre = ServicioBienestar.calcularBmr(
        pesoKg: 70.0,
        alturaCm: 175.0,
        edad: 25,
        esHombre: true,
      );
      expect(bmrHombre, inInclusiveRange(1670, 1680));

      // Mujer: 60kg, 160cm, 30 años
      // BMR = 10(60) + 6.25(160) - 5(30) - 161 = 600 + 1000 - 150 - 161 = 1289
      final bmrMujer = ServicioBienestar.calcularBmr(
        pesoKg: 60.0,
        alturaCm: 160.0,
        edad: 30,
        esHombre: false,
      );
      expect(bmrMujer, inInclusiveRange(1285, 1295));
    });

    test('Factor de actividad multiplica adecuadamente el TDEE', () {
      expect(ServicioBienestar.factorActividad('sedentario'), equals(1.2));
      expect(ServicioBienestar.factorActividad('moderado'), equals(1.55));
      expect(ServicioBienestar.factorActividad('intenso'), equals(1.725));
      expect(ServicioBienestar.factorActividad('atleta'), equals(1.9));
    });

    test('Plan nutricional en déficit calórico reduce calorías y protege proteína', () {
      final plan = ServicioBienestar.calcularPlanNutricional(
        pesoKg: 80.0,
        alturaCm: 180.0,
        edad: 30,
        esHombre: true,
        nivelActividad: 'moderado',
        objetivo: 'Déficit',
      );

      expect(plan.caloriasObjetivo, lessThan(plan.tdee));
      expect(plan.proteinasGramos, equals(160)); // 80kg * 2.0g/kg
      expect(plan.grasasGramos, greaterThan(30));
      expect(plan.carbohidratosGramos, greaterThan(50));
    });

    test('Plan nutricional en superávit añade calorías para hipertrofia', () {
      final plan = ServicioBienestar.calcularPlanNutricional(
        pesoKg: 75.0,
        alturaCm: 175.0,
        edad: 24,
        esHombre: true,
        nivelActividad: 'moderado',
        objetivo: 'Superávit',
      );

      expect(plan.caloriasObjetivo, greaterThan(plan.tdee));
      expect(plan.proteinasGramos, equals(150)); // 75kg * 2.0g/kg
    });
  });

  group('ServicioBienestar - Temporizador de Ayuno Intermitente (P23)', () {
    test('Horas según protocolo son exactas', () {
      expect(ServicioBienestar.horasPorProtocolo('16/8'), equals(16));
      expect(ServicioBienestar.horasPorProtocolo('14/10'), equals(14));
      expect(ServicioBienestar.horasPorProtocolo('12/12'), equals(12));
      expect(ServicioBienestar.horasPorProtocolo('18/6'), equals(18));
      expect(ServicioBienestar.horasPorProtocolo('20/4'), equals(20));
    });

    test('Evalúa estado fuera de ayuno (ventana de comida)', () {
      final estado = ServicioBienestar.evaluarEstadoAyuno(
        enAyuno: false,
        protocolo: '16/8',
      );

      expect(estado.enAyuno, isFalse);
      expect(estado.progreso, equals(0.0));
      expect(estado.completado, isFalse);
      expect(estado.faseFisiologica, contains('Ventana'));
    });

    test('Evalúa fases biológicas de ayuno transcurrido', () {
      final ahora = DateTime.now();

      // Fase 1: 2 horas de ayuno
      final estadoFase1 = ServicioBienestar.evaluarEstadoAyuno(
        enAyuno: true,
        protocolo: '16/8',
        inicio: ahora.subtract(const Duration(hours: 2)),
        ahora: ahora,
      );
      expect(estadoFase1.faseFisiologica, contains('Digestión'));
      expect(estadoFase1.progreso, inInclusiveRange(0.1, 0.15));
      expect(estadoFase1.completado, isFalse);

      // Fase 3: 14 horas de ayuno (Autofagia activa)
      final estadoFase3 = ServicioBienestar.evaluarEstadoAyuno(
        enAyuno: true,
        protocolo: '16/8',
        inicio: ahora.subtract(const Duration(hours: 14)),
        ahora: ahora,
      );
      expect(estadoFase3.faseFisiologica, contains('Autofagia'));
      expect(estadoFase3.progreso, inInclusiveRange(0.85, 0.90));
      expect(estadoFase3.completado, isFalse);

      // Ayuno completado: 17 horas de ayuno en protocolo 16/8
      final estadoCompletado = ServicioBienestar.evaluarEstadoAyuno(
        enAyuno: true,
        protocolo: '16/8',
        inicio: ahora.subtract(const Duration(hours: 17)),
        ahora: ahora,
      );
      expect(estadoCompletado.completado, isTrue);
      expect(estadoCompletado.progreso, equals(1.0));
      expect(estadoCompletado.faseFisiologica, contains('Cumplido'));
    });
  });

  group('ServicioBienestar - Semáforo de Densidad Nutricional (P23)', () {
    test('Día balanceado óptimo obtiene Grado A+ o A', () {
      final eval = ServicioBienestar.evaluarDensidadDia(
        vasosAgua: 8,
        metaVasosAgua: 8,
        caloriasConsumidas: 1950,
        metaCalorias: 2000,
        proteinasConsumidas: 140,
        metaProteinas: 140,
        comidasPlaneadasHoy: 3,
      );

      expect(eval.puntuacion, greaterThanOrEqualTo(85));
      expect(eval.grado, equals('A+'));
      expect(eval.titulo, contains('Óptima'));
    });

    test('Día con desbalance alerta de proteína o hidratación faltante', () {
      final eval = ServicioBienestar.evaluarDensidadDia(
        vasosAgua: 2,
        metaVasosAgua: 8,
        caloriasConsumidas: 800,
        metaCalorias: 2000,
        proteinasConsumidas: 30,
        metaProteinas: 140,
        comidasPlaneadasHoy: 0,
      );

      expect(eval.puntuacion, lessThan(60));
      expect(eval.consejos.any((c) => c.contains('agua') || c.contains('hidratar')), isTrue);
      expect(eval.consejos.any((c) => c.contains('proteína')), isTrue);
    });
  });
}
