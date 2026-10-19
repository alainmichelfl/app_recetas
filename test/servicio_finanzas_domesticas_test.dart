import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_finanzas_domesticas.dart';

void main() {
  group('ServicioFinanzasDomesticas - Ahorro vs Delivery (P24)', () {
    test('Calcula ahorro por platillo, semanal, mensual y anual correctamente', () {
      // 14 comidas planeadas, gasto de súper = $800 MXN
      // Costo por platillo = $800 / 14 = ~$57.14 MXN
      // Delivery benchmark = 14 * $140 = $1,960 MXN
      // Ahorro semanal = $1,960 - $800 = $1,160 MXN
      final res = ServicioFinanzasDomesticas.calcularAhorroVsDelivery(
        costoTotalSuper: 800.0,
        comidasPlaneadas: 14,
      );

      final double costoPlatillo = res['costoPorPlatillo'];
      final double ahorroSem = res['ahorroSemanal'];
      final double ahorroMes = res['ahorroMensual'];
      final double ahorroAnio = res['ahorroAnual'];

      expect(costoPlatillo, inInclusiveRange(57.0, 57.5));
      expect(ahorroSem, inInclusiveRange(1159.0, 1161.0));
      expect(ahorroMes, greaterThan(4000.0));
      expect(ahorroAnio, greaterThan(50000.0));
      expect(res['metafora'], isNotEmpty);
    });

    test('Retorna ahorro 0 cuando no hay costo de súper registrado', () {
      final res = ServicioFinanzasDomesticas.calcularAhorroVsDelivery(
        costoTotalSuper: 0.0,
        comidasPlaneadas: 0,
      );

      expect(res['ahorroSemanal'], equals(0.0));
    });
  });

  group('ServicioFinanzasDomesticas - Monitor de Merma y Rescate Culinario (P24)', () {
    test('Identifica ingredientes perecederos frescos en la despensa', () {
      final despensa = [
        {
          'id_item': 1,
          'nombre': 'Jitomate Saladet',
          'cantidad': 2.0,
          'precio': 30.0,
          'fecha_ingreso': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        },
        {
          'id_item': 2,
          'nombre': 'Pechuga de Pollo',
          'cantidad': 1.0,
          'precio': 120.0,
          'fecha_ingreso': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        },
        {
          'id_item': 3,
          'nombre': 'Sal de grano',
          'cantidad': 1.0,
          'precio': 18.0,
          'fecha_ingreso': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        },
      ];

      final enRiesgo = ServicioFinanzasDomesticas.detectarInsumosEnRiesgo(despensa);

      // Jitomate y Pechuga son perecederos; Sal de grano no lo es con 1 día
      expect(enRiesgo.length, equals(2));
      expect(enRiesgo.any((e) => e.nombre.contains('Pollo')), isTrue);
      expect(enRiesgo.any((e) => e.nombre.contains('Jitomate')), isTrue);
      expect(enRiesgo.any((e) => e.nombre == 'Sal de grano'), isFalse);
    });

    test('Detecta artículos antiguos (>4 días) como riesgo de merma aunque sean no perecederos', () {
      final despensa = [
        {
          'id_item': 10,
          'nombre': 'Arroz blanco',
          'cantidad': 1.0,
          'precio': 25.0,
          'fecha_ingreso': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(),
        },
      ];

      final enRiesgo = ServicioFinanzasDomesticas.detectarInsumosEnRiesgo(despensa);
      expect(enRiesgo.length, equals(1));
      expect(enRiesgo.first.nombre, equals('Arroz blanco'));
    });
  });

  group('ServicioFinanzasDomesticas - Ranking Costo-Proteína del Mercado (P24)', () {
    test('Catálogo contiene alimentos clave ordenados o evaluados por gramo', () {
      final items = ServicioFinanzasDomesticas.obtenerRankingCostoProteina();

      expect(items.length, greaterThanOrEqualTo(6));
      expect(items.any((it) => it.nombre.contains('Lentejas')), isTrue);
      expect(items.any((it) => it.nombre.contains('Huevo')), isTrue);
      expect(items.any((it) => it.nombre.contains('Pollo')), isTrue);

      // Las lentejas tienen el costo por gramo de proteína más económico (< $0.25 MXN/g)
      final lentejas = items.firstWhere((it) => it.nombre.contains('Lentejas'));
      expect(lentejas.costoPorGramo, lessThan(0.25));

      // La carne de res es de mayor costo (> $0.80 MXN/g)
      final resItem = items.firstWhere((it) => it.nombre.contains('Res'));
      expect(resItem.costoPorGramo, greaterThan(0.80));
    });
  });

  group('ServicioFinanzasDomesticas - Exportador de Estado de Cuenta Culinario (P24)', () {
    test('Formatea texto para compartir en WhatsApp con todas las secciones clave', () {
      const reporte = ReporteFinancieroHogar(
        presupuestoSemanal: 1500.0,
        costoSuperSemanal: 1100.0,
        costoPorPlatillo: 78.5,
        comidasPlaneadas: 14,
        ahorroSemanalVsDelivery: 860.0,
        proyeccionAhorroMensual: 3723.0,
        proyeccionAhorroAnual: 44720.0,
        capitalDespensa: 3450.0,
        capitalEnRiesgoDesperdicio: 250.0,
        insumosEnRiesgo: [],
      );

      final texto = reporte.formatearParaCompartir();

      expect(texto, contains('ESTADO DE CUENTA CULINARIO'));
      expect(texto, contains('Jitomate y Cebolla'));
      expect(texto, contains('1500.00'));
      expect(texto, contains('860.00'));
      expect(texto, contains('3723.00'));
      expect(texto, contains('3450.00'));
    });
  });
}
