import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_recetas/servicio_rate_limit_ia.dart';
import 'package:app_recetas/servicio_ia_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ServicioRateLimitIA.resetearParaPruebas();
    ServicioIAGateway.forzarFallbackLocal = false;
    ServicioIAGateway.clienteHttpMock = null;
  });

  group('ServicioRateLimitIA - Control de Cuotas y Cooldown (Blindaje R1)', () {
    test('Permite la primera consulta y reporta cuota restante completa', () async {
      final prefs = await SharedPreferences.getInstance();
      final permiso = await ServicioRateLimitIA.verificarPermiso(prefsOverride: prefs);

      expect(permiso.permitido, isTrue);
      expect(permiso.esCooldown, isFalse);
      expect(permiso.consultasRestantes, equals(ServicioRateLimitIA.limitePorHora));
    });

    test('Bloquea peticiones consecutivas inmediatas por Cooldown (3 segundos)', () async {
      final prefs = await SharedPreferences.getInstance();
      final ahora = DateTime.now();

      // Registramos primer llamado exitoso
      await ServicioRateLimitIA.registrarLlamadoExitoso(
        prefsOverride: prefs,
        tiempoOverride: ahora,
      );

      // Verificamos inmediatamente (1 segundo después)
      final intentoInmediato = await ServicioRateLimitIA.verificarPermiso(
        prefsOverride: prefs,
        tiempoActualOverride: ahora.add(const Duration(seconds: 1)),
      );

      expect(intentoInmediato.permitido, isFalse);
      expect(intentoInmediato.esCooldown, isTrue);
      expect(intentoInmediato.motivo.toLowerCase(), contains('espera'));

      // Verificamos después de transcurrido el cooldown (4 segundos después)
      final intentoPosterior = await ServicioRateLimitIA.verificarPermiso(
        prefsOverride: prefs,
        tiempoActualOverride: ahora.add(const Duration(seconds: 4)),
      );

      expect(intentoPosterior.permitido, isTrue);
      expect(intentoPosterior.esCooldown, isFalse);
      expect(intentoPosterior.consultasRestantes, equals(ServicioRateLimitIA.limitePorHora - 1));
    });

    test('Bloquea al alcanzar la cuota horaria de 25 consultas', () async {
      final prefs = await SharedPreferences.getInstance();
      final ahora = DateTime.now();

      // Simulamos 25 llamadas espaciadas dentro de la última hora
      final tiemposSimulados = List.generate(
        25,
        (i) => ahora.subtract(Duration(minutes: 50 - (i * 2))).millisecondsSinceEpoch.toString(),
      );
      await prefs.setStringList(ServicioRateLimitIA.claveHistorial, tiemposSimulados);

      // Pasamos el cooldown de memoria
      ServicioRateLimitIA.resetearParaPruebas();

      final permiso = await ServicioRateLimitIA.verificarPermiso(
        prefsOverride: prefs,
        tiempoActualOverride: ahora,
      );

      expect(permiso.permitido, isFalse);
      expect(permiso.esCooldown, isFalse);
      expect(permiso.consultasRestantes, equals(0));
      expect(permiso.motivo, contains('cuota de seguridad'));
    });

    test('Ignora llamadas que tienen más de 1 hora de antigüedad en la ventana móvil', () async {
      final prefs = await SharedPreferences.getInstance();
      final ahora = DateTime.now();

      // 5 llamadas de hace 2 horas y 2 llamadas recientes
      final viejas = List.generate(
        5,
        (i) => ahora.subtract(Duration(hours: 2, minutes: i)).millisecondsSinceEpoch.toString(),
      );
      final recientes = [
        ahora.subtract(const Duration(minutes: 15)).millisecondsSinceEpoch.toString(),
        ahora.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch.toString(),
      ];

      await prefs.setStringList(ServicioRateLimitIA.claveHistorial, [...viejas, ...recientes]);
      ServicioRateLimitIA.resetearParaPruebas();

      final permiso = await ServicioRateLimitIA.verificarPermiso(
        prefsOverride: prefs,
        tiempoActualOverride: ahora,
      );

      expect(permiso.permitido, isTrue);
      // Solo las 2 llamadas recientes deben descontar de la cuota
      expect(permiso.consultasRestantes, equals(ServicioRateLimitIA.limitePorHora - 2));
    });
  });

  group('ServicioIAGateway - Pasarela Híbrida y Fallback Seguro (Blindaje R1)', () {
    test('Intercepta peticiones bloqueadas por Rate Limit sin gastar recursos de red', () async {
      final prefs = await SharedPreferences.getInstance();
      final ahora = DateTime.now();

      // Forzar que se sobrepasó la cuota horaria
      final timestamps = List.generate(
        25,
        (i) => ahora.subtract(Duration(minutes: 30 - i)).millisecondsSinceEpoch.toString(),
      );
      await prefs.setStringList(ServicioRateLimitIA.claveHistorial, timestamps);
      ServicioRateLimitIA.resetearParaPruebas();

      final respuesta = await ServicioIAGateway.ejecutarPeticion(
        cuerpo: {
          'contents': [
            {
              'parts': [
                {'text': 'Dame una receta'}
              ]
            }
          ]
        },
      );

      expect(respuesta, isNotNull);
      expect(respuesta, startsWith('⚠️'));
      expect(respuesta, contains('cuota de seguridad'));
    });

    test('Ejecuta fallback directo a Gemini cuando se fuerza el modo local', () async {
      ServicioIAGateway.forzarFallbackLocal = true;

      // Mock de respuesta exitosa de Gemini API
      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': '{"nombre": "Tacos de Pollo al Pastor"}'}
              ]
            },
            'finishReason': 'STOP'
          }
        ]
      });

      ServicioIAGateway.clienteHttpMock = MockClient((request) async {
        expect(request.url.toString(), contains('generativelanguage.googleapis.com'));
        return http.Response(mockResponse, 200, headers: {'content-type': 'application/json'});
      });

      final respuesta = await ServicioIAGateway.ejecutarPeticion(
        cuerpo: {
          'contents': [
            {
              'parts': [
                {'text': 'Genera receta'}
              ]
            }
          ]
        },
        forzarJson: true,
      );

      expect(respuesta, isNotNull);
      expect(respuesta, contains('Tacos de Pollo al Pastor'));
    });

    test('Maneja respuestas de bloqueo o formato inválido de Gemini sin romperse', () async {
      ServicioIAGateway.forzarFallbackLocal = true;

      final mockBloqueo = jsonEncode({
        'candidates': [
          {
            'content': null,
            'finishReason': 'SAFETY'
          }
        ]
      });

      ServicioIAGateway.clienteHttpMock = MockClient((request) async {
        return http.Response(mockBloqueo, 200, headers: {'content-type': 'application/json'});
      });

      final respuesta = await ServicioIAGateway.ejecutarPeticion(
        cuerpo: {
          'contents': [
            {
              'parts': [
                {'text': 'Consulta con bloqueo'}
              ]
            }
          ]
        },
      );

      expect(respuesta, isNull);
    });
  });
}
