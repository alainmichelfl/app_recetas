import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_batch_cooking.dart';

void main() {
  group('ServicioBatchCooking - Generación de Guía Dominical (P25)', () {
    test('Estructura 4 bloques de 30 minutos secuenciales para completar 2 horas', () {
      final planEjemplo = [
        {
          'fecha': '2026-10-20',
          'tipo_comida': 'Comida',
          'recetas': {
            'titulo': 'Pechuga de Pollo con Arroz y Calabacitas Asadas',
            'descripcion': 'Platillo balanceado con pechuga jugosa, arroz al vapor y verduras.',
          },
        },
        {
          'fecha': '2026-10-21',
          'tipo_comida': 'Cena',
          'recetas': {
            'titulo': 'Ensalada Fresca de Atún con Vinagreta y Frijoles',
            'descripcion': 'Cena ligera con atún en agua, frijoles negros y lechuga crujiente.',
          },
        },
      ];

      final guia = ServicioBatchCooking.generarGuiaDesdePlan(planEjemplo);

      expect(guia.totalPlatillos, equals(2));
      expect(guia.platillosPlaneados, contains('Pechuga de Pollo con Arroz y Calabacitas Asadas'));
      expect(guia.platillosPlaneados, contains('Ensalada Fresca de Atún con Vinagreta y Frijoles'));

      // Verificar las 4 etapas secuenciales
      expect(guia.etapas.length, equals(4));

      final etapa1 = guia.etapas[0];
      expect(etapa1.bloqueNumero, equals(1));
      expect(etapa1.tiempoEstimado, contains('0 - 30'));
      expect(etapa1.titulo, contains('Horno'));
      expect(etapa1.tareas.length, greaterThanOrEqualTo(3));

      final etapa2 = guia.etapas[1];
      expect(etapa2.bloqueNumero, equals(2));
      expect(etapa2.tiempoEstimado, contains('30 - 60'));
      expect(etapa2.titulo, contains('Proteínas'));

      final etapa3 = guia.etapas[2];
      expect(etapa3.bloqueNumero, equals(3));
      expect(etapa3.tiempoEstimado, contains('60 - 90'));
      expect(etapa3.titulo, contains('Salsas'));

      final etapa4 = guia.etapas[3];
      expect(etapa4.bloqueNumero, equals(4));
      expect(etapa4.tiempoEstimado, contains('90 - 120'));
      expect(etapa4.titulo, contains('Porcionado'));

      // Reglas de conservación
      expect(guia.reglasConservacion.length, greaterThanOrEqualTo(3));
      expect(guia.reglasConservacion.any((r) => r.contains('3-4')), isTrue);
    });

    test('Formatea texto para compartir en WhatsApp con checklist y emojis', () {
      final planEjemplo = [
        {
          'fecha': '2026-10-20',
          'tipo_comida': 'Comida',
          'recetas': {
            'titulo': 'Fajitas de Res con Pimientos y Arroz',
            'descripcion': 'Carne tierna con pimientos y cebolla.',
          },
        },
      ];

      final guia = ServicioBatchCooking.generarGuiaDesdePlan(planEjemplo);
      final texto = guia.formatearParaCompartir();

      expect(texto, contains('BATCH COOKING & PREP DAY (2 HORAS)'));
      expect(texto, contains('Jitomate y Cebolla'));
      expect(texto, contains('Min 0 - 30'));
      expect(texto, contains('Min 30 - 60'));
      expect(texto, contains('Min 60 - 90'));
      expect(texto, contains('Min 90 - 120'));
      expect(texto, contains('Reglas de Conservación'));
    });

    test('Genera fallback coherente cuando el plan está vacío', () {
      final guia = ServicioBatchCooking.generarGuiaDesdePlan([]);

      expect(guia.etapas.length, equals(4));
      expect(guia.etapas.first.tareas.isNotEmpty, isTrue);
      expect(guia.reglasConservacion.isNotEmpty, isTrue);
    });
  });
}
