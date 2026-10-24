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

    test('ConfiguracionRecordatorios valores por defecto y persistencia', () async {
      final configDefault = await ServicioRecordatorios.obtenerConfiguracion();
      expect(configDefault.alertaDescongelar, isTrue);
      expect(configDefault.horaDescongelar, '20:00');
      expect(configDefault.alertaMermaRefri, isTrue);
      expect(configDefault.diasUmbralMerma, 4);
      expect(configDefault.alertaAyunoIntermitente, isFalse);

      final customConfig = const ConfiguracionRecordatorios(
        alertaDescongelar: false,
        horaDescongelar: '21:00',
        alertaMermaRefri: true,
        diasUmbralMerma: 5,
        alertaAyunoIntermitente: true,
        horaInicioVentana: '13:00',
        horaFinVentana: '21:00',
        minutosAnticipacionAyuno: 20,
      );

      await ServicioRecordatorios.guardarConfiguracion(customConfig);
      final guardada = await ServicioRecordatorios.obtenerConfiguracion();
      expect(guardada.alertaDescongelar, isFalse);
      expect(guardada.horaDescongelar, '21:00');
      expect(guardada.diasUmbralMerma, 5);
      expect(guardada.alertaAyunoIntermitente, isTrue);
      expect(guardada.horaInicioVentana, '13:00');
      expect(guardada.horaFinVentana, '21:00');
    });

    test('calcularEstadoVentanaAyuno calcula estados de pre-apertura, abierta y pre-cierre', () {
      const config = ConfiguracionRecordatorios(
        alertaAyunoIntermitente: true,
        horaInicioVentana: '12:00',
        horaFinVentana: '20:00',
        minutosAnticipacionAyuno: 30,
      );

      // 11:45 AM -> 15 min antes de abrir (pre-apertura)
      final preApertura = ServicioRecordatorios.calcularEstadoVentanaAyuno(
        config,
        ahora: DateTime(2026, 10, 19, 11, 45),
      );
      expect(preApertura, contains('Apertura en 15 min'));

      // 14:00 PM -> dentro de la ventana (abierta)
      final abierta = ServicioRecordatorios.calcularEstadoVentanaAyuno(
        config,
        ahora: DateTime(2026, 10, 19, 14, 0),
      );
      expect(abierta, contains('Ventana de alimentación abierta'));

      // 19:40 PM -> 20 min antes del cierre (pre-cierre)
      final preCierre = ServicioRecordatorios.calcularEstadoVentanaAyuno(
        config,
        ahora: DateTime(2026, 10, 19, 19, 40),
      );
      expect(preCierre, contains('Cierre de ventana en 20 min'));

      // 22:00 PM -> en período de ayuno
      final ayuno = ServicioRecordatorios.calcularEstadoVentanaAyuno(
        config,
        ahora: DateTime(2026, 10, 19, 22, 0),
      );
      expect(ayuno, contains('En período de ayuno'));
    });

    test('ConfiguracionRecordatorios soporta lunch escolar y persistencia', () async {
      final configDefault = await ServicioRecordatorios.obtenerConfiguracion();
      expect(configDefault.alertaLunchEscolar, isTrue);
      expect(configDefault.horaLunchEscolar, '20:30');

      final updated = configDefault.copyWith(
        alertaLunchEscolar: false,
        horaLunchEscolar: '19:45',
      );
      await ServicioRecordatorios.guardarConfiguracion(updated);

      final recargada = await ServicioRecordatorios.obtenerConfiguracion();
      expect(recargada.alertaLunchEscolar, isFalse);
      expect(recargada.horaLunchEscolar, '19:45');
    });

    test('detectarAlertaLunchEscolar detecta platillos y respeta atenderlo', () async {
      final manana = DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0];

      final plan = [
        {
          'id_planeador': 201,
          'fecha': manana,
          'tipo_comida': 'Lunch Escolar',
          'recetas': {
            'id_receta': 68,
            'titulo': 'Rollitos de jamón de pavo con panela',
            'descripcion': 'Rollitos fáciles y ricos en proteína para llevar.',
          },
        },
      ];

      // 1. Detecta la alerta escolar para mañana
      var alerta = await ServicioRecordatorios.detectarAlertaLunchEscolar(plan);
      expect(alerta, isNotNull);
      expect(alerta!.activa, isTrue);
      expect(alerta.platilloSugerido, 'Rollitos de jamón de pavo con panela');

      // 2. Al marcar como atendido, ya no debe mostrarla
      await ServicioRecordatorios.marcarLunchEscolarComoAtendido(alerta.idIdentificador);
      alerta = await ServicioRecordatorios.detectarAlertaLunchEscolar(plan);
      expect(alerta, isNull);
    });
  });
}
