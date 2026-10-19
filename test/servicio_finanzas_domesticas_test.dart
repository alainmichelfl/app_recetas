import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  group('ServicioFinanzasDomesticas - Reto Antidesperdicio Cero Merma (P25)', () {
    setUp(() {
      // Mock inicial de SharedPreferences
      SharedPreferences.setMockInitialValues({});
    });

    test('Inicia con racha 0 y desbloquea insignias conforme avanza la racha', () async {
      final inicial = await ServicioFinanzasDomesticas.obtenerEstadoRachaZeroWaste();
      expect(inicial.diasRacha, equals(0));
      expect(inicial.registradoHoy, isFalse);
      expect(inicial.insignias.length, equals(4));
      expect(inicial.proximaInsignia?.id, equals('guardian_despensa'));

      // Registrar día 1
      final dia1 = await ServicioFinanzasDomesticas.registrarDiaSinDesperdicio(razon: 'Día 1');
      expect(dia1.diasRacha, equals(1));
      expect(dia1.registradoHoy, isTrue);
      expect(dia1.ahorroEstimadoAcumulado, equals(85.0));

      // Re-consultar hoy no debe duplicar la racha
      final dia1Bis = await ServicioFinanzasDomesticas.registrarDiaSinDesperdicio(razon: 'Día 1 otra vez');
      expect(dia1Bis.diasRacha, equals(1));
    });

    test('Insignias del catálogo tienen metas calibradas en 3, 7, 14 y 30 días', () async {
      final estado = await ServicioFinanzasDomesticas.obtenerEstadoRachaZeroWaste();
      final insignias = estado.insignias;

      expect(insignias[0].diasRequeridos, equals(3));
      expect(insignias[0].titulo, contains('Guardián'));

      expect(insignias[1].diasRequeridos, equals(7));
      expect(insignias[1].titulo, contains('Chef Consciente'));

      expect(insignias[2].diasRequeridos, equals(14));
      expect(insignias[2].titulo, contains('Maestro Cero Merma'));

      expect(insignias[3].diasRequeridos, equals(30));
      expect(insignias[3].titulo, contains('Inversionista del Súper'));
    });
  });

  group('ServicioFinanzasDomesticas - Club del Súper y Ahorro Mensual (P25)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Meta por defecto es \$3,000 MXN y permite personalizarse', () async {
      final metaDefault = await ServicioFinanzasDomesticas.obtenerMetaAhorroMensual();
      expect(metaDefault, equals(3000.0));

      await ServicioFinanzasDomesticas.guardarMetaAhorroMensual(4500.0);
      final metaActualizada = await ServicioFinanzasDomesticas.obtenerMetaAhorroMensual();
      expect(metaActualizada, equals(4500.0));
    });

    test('Calcula progreso de meta mensual y porcentaje cumplido correctamente', () async {
      // 10 comidas caseras preparadas este mes
      final desafio = await ServicioFinanzasDomesticas.obtenerDesafioAhorroMensual(
        comidasMes: 10,
      );

      expect(desafio.metaAhorroMensual, equals(3000.0));
      expect(desafio.comidasCaserasMes, equals(10));
      // 10 platillos * $85 ahorro = $850 MXN
      expect(desafio.ahorroLogradoMes, equals(850.0));
      expect(desafio.porcentajeCumplido, closeTo(28.33, 0.5));
      expect(desafio.diasRestantesMes, greaterThanOrEqualTo(0));
      expect(desafio.estadoMensaje, isNotEmpty);
      expect(desafio.metafora, isNotEmpty);
    });
  });
}

