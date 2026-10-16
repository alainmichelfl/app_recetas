import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_recetas/servicio_recordatorios.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ServicioRecordatorios - Detección de Proteínas para Descongelar', () {
    test('Detecta pollo para platillo de mañana', () async {
      final manana = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0];

      final plan = [
        {
          'id_planeador': 101,
          'fecha': manana,
          'tipo_comida': 'Comida',
          'recetas': {
            'titulo': 'Pechuga Cordon Bleu',
            'descripcion': 'Deliciosa pechuga de pollo rellena de jamón y queso empanizada.',
          },
        },
      ];

      final alerta = await ServicioRecordatorios.detectarAlertaDescongelacion(plan);
      expect(alerta, isNotNull);
      expect(alerta!.requiereDescongelado, isTrue);
      expect(alerta.esParaManana, isTrue);
      expect(alerta.platillo, 'Pechuga Cordon Bleu');
      expect(alerta.proteina, contains('pollo'));
    });

    test('Detecta carne de res o molida', () async {
      final manana = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0];

      final plan = [
        {
          'id_planeador': 102,
          'fecha': manana,
          'tipo_comida': 'Cena',
          'recetas': {
            'titulo': 'Hamburguesas Caseras',
            'descripcion': 'Preparadas con carne molida de res, sazonada con pimienta.',
          },
        },
      ];

      final alerta = await ServicioRecordatorios.detectarAlertaDescongelacion(plan);
      expect(alerta, isNotNull);
      expect(alerta!.proteina, contains('carne molida'));
    });

    test('Ignora platillos vegetarianos o sin carne congelable', () async {
      final manana = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0];

      final plan = [
        {
          'id_planeador': 103,
          'fecha': manana,
          'tipo_comida': 'Comida',
          'recetas': {
            'titulo': 'Ensalada Griega',
            'descripcion': 'Lechuga, pepino, aceitunas y queso feta con aderezo.',
          },
        },
      ];

      final alerta = await ServicioRecordatorios.detectarAlertaDescongelacion(plan);
      expect(alerta, isNull);
    });

    test('Respeta cuando el usuario ya marcó "Ya lo bajé"', () async {
      final manana = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0];

      final plan = [
        {
          'id_planeador': 104,
          'fecha': manana,
          'tipo_comida': 'Comida',
          'recetas': {
            'titulo': 'Salmón a la plancha',
            'descripcion': 'Filete de salmón fresco con finas hierbas y limón.',
          },
        },
      ];

      // Primera vez: detecta alerta
      var alerta = await ServicioRecordatorios.detectarAlertaDescongelacion(plan);
      expect(alerta, isNotNull);

      // Usuario marca como atendido
      await ServicioRecordatorios.marcarComoAtendido(alerta!.idIdentificador);

      // Segunda vez: ya no debe saltar alerta
      alerta = await ServicioRecordatorios.detectarAlertaDescongelacion(plan);
      expect(alerta, isNull);
    });
  });
}
