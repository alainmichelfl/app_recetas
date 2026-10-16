import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum ComandoVoz {
  siguiente,
  anterior,
  terminar,
  desconocido,
}

class ServicioVozCocina {
  final SpeechToText _speech = SpeechToText();
  bool _inicializado = false;
  bool _escuchandoActivo = false;
  bool _debeContinuarEscuchando = false;

  Function()? onSiguiente;
  Function()? onAnterior;
  Function()? onTerminar;
  Function(String texto)? onTextoReconocido;
  Function(bool escuchando)? onEstadoCambiado;

  bool get estaEscuchando => _escuchandoActivo;
  bool get estaInicializado => _inicializado;

  /// Inicializa el motor de reconocimiento de voz
  Future<bool> inicializar() async {
    if (_inicializado) return true;

    try {
      _inicializado = await _speech.initialize(
        onError: (val) {
          debugPrint('🎙️ Error de voz: ${val.errorMsg}');
          _escuchandoActivo = false;
          onEstadoCambiado?.call(false);
          _intentarReanudar();
        },
        onStatus: (status) {
          debugPrint('🎙️ Estado de voz: $status');
          if (status == 'listening') {
            _escuchandoActivo = true;
            onEstadoCambiado?.call(true);
          } else if (status == 'notListening' || status == 'done') {
            _escuchandoActivo = false;
            onEstadoCambiado?.call(false);
            _intentarReanudar();
          }
        },
      );
      return _inicializado;
    } catch (e) {
      debugPrint('🚨 Error inicializando SpeechToText: $e');
      _inicializado = false;
      return false;
    }
  }

  /// Inicia el bucle de escucha de comandos de voz manos libres
  Future<void> iniciarEscucha() async {
    _debeContinuarEscuchando = true;

    if (!_inicializado) {
      final ok = await inicializar();
      if (!ok) return;
    }

    _escucharCiclo();
  }

  void _escucharCiclo() {
    if (!_debeContinuarEscuchando || _escuchandoActivo) return;

    try {
      _speech.listen(
        onResult: (result) {
          final texto = result.recognizedWords.toLowerCase().trim();
          if (texto.isNotEmpty) {
            onTextoReconocido?.call(result.recognizedWords);
            procesarComando(texto);
          }
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          pauseFor: const Duration(seconds: 3),
          localeId: 'es_MX',
        ),
      );
    } catch (e) {
      debugPrint('Error al invocar listen(): $e');
      _intentarReanudar();
    }
  }

  void _intentarReanudar() {
    if (!_debeContinuarEscuchando) return;
    Timer(const Duration(milliseconds: 600), () {
      if (_debeContinuarEscuchando && !_escuchandoActivo) {
        _escucharCiclo();
      }
    });
  }

  /// Detiene el reconocimiento de voz
  Future<void> detenerEscucha() async {
    _debeContinuarEscuchando = false;
    _escuchandoActivo = false;
    onEstadoCambiado?.call(false);
    try {
      await _speech.stop();
    } catch (_) {}
  }

  /// Interpreta texto crudo y retorna el comando detectado
  static ComandoVoz interpretarTexto(String texto) {
    final t = texto.toLowerCase().trim();
    if (t.contains('siguiente') ||
        t.contains('avanzar') ||
        t.contains('próximo') ||
        t.contains('proximo') ||
        t.contains('continuar') ||
        t.contains('adelante') ||
        t.contains('ya quedó') ||
        t.contains('ya quedo') ||
        t.contains('listo')) {
      return ComandoVoz.siguiente;
    }

    if (t.contains('atrás') ||
        t.contains('atras') ||
        t.contains('anterior') ||
        t.contains('regresar') ||
        t.contains('volver')) {
      return ComandoVoz.anterior;
    }

    if (t.contains('terminar') ||
        t.contains('finalizar') ||
        t.contains('acabar') ||
        t.contains('terminé') ||
        t.contains('termine')) {
      return ComandoVoz.terminar;
    }

    return ComandoVoz.desconocido;
  }

  /// Interpreta el comando hablado en español y ejecuta las retrollamadas
  ComandoVoz procesarComando(String texto) {
    final comando = interpretarTexto(texto);
    switch (comando) {
      case ComandoVoz.siguiente:
        onSiguiente?.call();
        break;
      case ComandoVoz.anterior:
        onAnterior?.call();
        break;
      case ComandoVoz.terminar:
        onTerminar?.call();
        break;
      case ComandoVoz.desconocido:
        break;
    }
    return comando;
  }

  /// Limpieza de recursos
  void dispose() {
    detenerEscucha();
  }
}
