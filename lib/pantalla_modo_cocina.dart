import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'servicio_despensa.dart';
import 'servicio_historial_cocina.dart';
import 'servicio_copiloto_cocina.dart';
import 'servicio_voz_cocina.dart';

class PantallaModoCocina extends StatefulWidget {
  final String recetaInstrucciones;
  final int? idReceta;
  final String? titulo;
  final double multiplicador;
  final List<String>? listaIngredientes;
  final String? textoInstrucciones;
  final ModoElectrodomestico modoInicial;

  const PantallaModoCocina({
    super.key,
    required this.recetaInstrucciones,
    this.idReceta,
    this.titulo,
    this.multiplicador = 1.0,
    this.listaIngredientes,
    this.textoInstrucciones,
    this.modoInicial = ModoElectrodomestico.tradicional,
  });

  @override
  State<PantallaModoCocina> createState() => _PantallaModoCocinaState();
}

class _PantallaModoCocinaState extends State<PantallaModoCocina> {
  final PageController _pageController = PageController();

  late ModoElectrodomestico _modoActual;
  final Map<ModoElectrodomestico, String> _instruccionesPorModo = {};
  bool _adaptandoIA = false;

  // 🎙️ Servicio de voz para modo manos libres
  final ServicioVozCocina _servicioVoz = ServicioVozCocina();
  bool _modoVozActivo = false;
  bool _microfonoEscuchando = false;
  String? _ultimoTextoVoz;
  Timer? _temporizadorLimpiezaVoz;

  // ⏱️ Temporizador inteligente integrado
  Timer? _temporizadorCocina;
  int _segundosTotales = 0;
  int _segundosRestantes = 0;
  bool _temporizadorActivo = false;
  String _tituloTemporizador = '';

  // 💡 Estructura inteligente para manejar diferentes tipos de tarjetas
  List<Map<String, dynamic>> paginasCocina = [];
  int _pasoActual = 0;
  bool _pantallaSiempreEncendida = true;

  @override
  void initState() {
    super.initState();
    _modoActual = widget.modoInicial;

    // Activar WakeLock para mantener pantalla encendida mientras cocinas
    try {
      WakelockPlus.enable();
    } catch (e) {
      debugPrint('Aviso al activar WakeLock: $e');
    }

    // Cachear la versión inicial si se nos pasó
    final textoBase = widget.textoInstrucciones ?? widget.recetaInstrucciones;
    _instruccionesPorModo[_modoActual] = textoBase;

    _procesarInstrucciones();
    _configurarServicioVoz();
  }

  void _configurarServicioVoz() {
    _servicioVoz.onSiguiente = () {
      if (!mounted) return;
      if (_pasoActual < paginasCocina.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _finalizarYCocinar();
      }
    };

    _servicioVoz.onAnterior = () {
      if (!mounted) return;
      if (_pasoActual > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    };

    _servicioVoz.onTerminar = () {
      if (!mounted) return;
      _finalizarYCocinar();
    };

    _servicioVoz.onTextoReconocido = (texto) {
      if (!mounted) return;
      setState(() {
        _ultimoTextoVoz = texto;
      });
      _temporizadorLimpiezaVoz?.cancel();
      _temporizadorLimpiezaVoz = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() => _ultimoTextoVoz = null);
        }
      });
    };

    _servicioVoz.onEstadoCambiado = (escuchando) {
      if (!mounted) return;
      setState(() {
        _microfonoEscuchando = escuchando;
      });
    };
  }

  Future<void> _alternarModoVoz() async {
    if (_modoVozActivo) {
      await _servicioVoz.detenerEscucha();
      if (mounted) {
        setState(() {
          _modoVozActivo = false;
          _microfonoEscuchando = false;
          _ultimoTextoVoz = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modo manos libres desactivado 🔇'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      final inicializado = await _servicioVoz.inicializar();
      if (!inicializado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo acceder al micrófono para el modo manos libres.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      await _servicioVoz.iniciarEscucha();
      if (mounted) {
        setState(() {
          _modoVozActivo = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎙️ Modo Manos Libres Activo. Di "Siguiente", "Atrás" o "Terminar" sin tocar la pantalla.'),
            backgroundColor: Colors.teal,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _procesarInstrucciones() {
    paginasCocina.clear();

    // 1. Tarjeta Cero: "Mise en Place / Antes del Fuego" (Ingredientes y Utensilios)
    String textoMiseEnPlace = "";

    if (widget.listaIngredientes != null && widget.listaIngredientes!.isNotEmpty) {
      final sb = StringBuffer();
      sb.writeln('📝 INGREDIENTES REQUERIDOS:\n');
      for (var ing in widget.listaIngredientes!) {
        final limpio = ing.trim().replaceFirst(RegExp(r'^[\-\*]\s*'), '').trim();
        if (limpio.isNotEmpty) {
          sb.writeln('• $limpio');
        }
      }

      sb.writeln('\n🔪 EQUIPO Y MISE EN PLACE:');
      if (_modoActual == ModoElectrodomestico.thermomix) {
        sb.writeln('• Vaso Thermomix con cuchillas bien ensambladas y bloqueadas');
        sb.writeln('• Tapa y cubilete puestos');
        sb.writeln('• Espátula con collarín de seguridad');
        sb.writeln('• Mariposa o Cestillo a la mano (si la receta lo indica)');
        sb.writeln('• Recipiente Varoma limpio');
      } else if (_modoActual == ModoElectrodomestico.airFryer) {
        sb.writeln('• Canastilla de la freidora limpia y seca');
        sb.writeln('• Pinzas con punta de silicón (no metálicas)');
        sb.writeln('• Aceite en spray o brocha de cocina');
        sb.writeln('• Papel perforado para air fryer (opcional)');
      } else {
        sb.writeln('• Tabla de picar y cuchillo afilado');
        sb.writeln('• Sartén, comal u olla (según corresponda)');
        sb.writeln('• Espátula, cuchara o pinzas de cocina');
      }
      sb.writeln('• ¡Lava, mide y prepara todo antes de iniciar!');
      textoMiseEnPlace = sb.toString();
    } else {
      String textoCrudo = _instruccionesPorModo[_modoActual] ?? widget.recetaInstrucciones;

      final palabrasClave = [
        'INSTRUCCIONES',
        'PREPARACIÓN',
        'PREPARACION',
        'PASOS',
        'ELABORACIÓN',
        'ELABORACION',
      ];

      int indiceCorte = -1;

      for (var palabra in palabrasClave) {
        final idx = textoCrudo.toUpperCase().indexOf(palabra);
        if (idx != -1) {
          indiceCorte = idx;
          break;
        }
      }

      if (indiceCorte != -1 && indiceCorte > 0) {
        textoMiseEnPlace = textoCrudo.substring(0, indiceCorte).trim();
      } else {
        int idxIng = textoCrudo.toUpperCase().indexOf('INGREDIENTES');
        if (idxIng != -1) {
          textoMiseEnPlace = textoCrudo;
        }
      }

      if (textoMiseEnPlace.isNotEmpty && !textoMiseEnPlace.toUpperCase().contains('UTENSILIO') && !textoMiseEnPlace.toUpperCase().contains('EQUIPO')) {
        if (_modoActual == ModoElectrodomestico.thermomix) {
          textoMiseEnPlace += '\n\n🤖 EQUIPO THERMOMIX:\n• Vaso y tapa con cubilete\n• Espátula con collarín\n• Cestillo / Varoma';
        } else if (_modoActual == ModoElectrodomestico.airFryer) {
          textoMiseEnPlace += '\n\n🍟 EQUIPO AIR FRYER:\n• Canastilla limpia\n• Pinzas de silicón\n• Aceite en spray';
        } else {
          textoMiseEnPlace += '\n\n🔪 UTENSILIOS RECOMENDADOS:\n• Sartén / Olla\n• Tabla y cuchillo\n• Espátula o pala';
        }
      }
    }

    if (textoMiseEnPlace.isNotEmpty) {
      textoMiseEnPlace = textoMiseEnPlace.replaceAll(RegExp(r'\*\*'), '');
      paginasCocina.add({
        'tipo': 'preparacion',
        'titulo': _modoActual == ModoElectrodomestico.thermomix
            ? 'Mise en Place Thermomix 🤖'
            : _modoActual == ModoElectrodomestico.airFryer
                ? 'Mise en Place Air Fryer 🍟'
                : 'Antes del Fuego 🔥',
        'contenido': textoMiseEnPlace,
      });
    }

    // 2. Extraer y procesar los pasos individuales
    String textoPasos = "";
    if (_instruccionesPorModo[_modoActual] != null &&
        _instruccionesPorModo[_modoActual]!.trim().isNotEmpty) {
      textoPasos = _instruccionesPorModo[_modoActual]!.trim();
    } else if (widget.textoInstrucciones != null &&
        widget.textoInstrucciones!.trim().isNotEmpty) {
      textoPasos = widget.textoInstrucciones!.trim();
    } else {
      String textoCrudo = widget.recetaInstrucciones;
      final palabrasClave = [
        'INSTRUCCIONES',
        'PREPARACIÓN',
        'PREPARACION',
        'PASOS',
        'ELABORACIÓN',
        'ELABORACION',
      ];

      int indiceCorte = -1;
      String palabraEncontrada = '';

      for (var palabra in palabrasClave) {
        final idx = textoCrudo.toUpperCase().indexOf(palabra);
        if (idx != -1) {
          indiceCorte = idx;
          break;
        }
      }

      if (indiceCorte != -1 && indiceCorte > 0) {
        int inicioPasos = indiceCorte + palabraEncontrada.length;
        if (inicioPasos < textoCrudo.length && textoCrudo[inicioPasos] == ':') {
          inicioPasos++;
        }
        textoPasos = textoCrudo.substring(inicioPasos).trim();
      } else {
        textoPasos = textoCrudo;
      }
    }

    if (textoPasos.isNotEmpty) {
      final lineas = textoPasos.split('\n');
      int numeroPaso = 1;
      for (var linea in lineas) {
        String paso = linea.trim();
        paso = paso.replaceAll(RegExp(r'^[\*\-\•]\s*'), '');
        paso = paso.replaceAll(RegExp(r'\*\*'), '');
        paso = paso.replaceAll(
          RegExp(r'^(?:paso\s*\d+[:\.]?|\d+[\.\)]\s*)', caseSensitive: false),
          '',
        );

        if (paso.length > 5) {
          final ParametrosPasoRobot params = ServicioCopilotoCocina.parsearPaso(
            paso,
            modo: _modoActual,
          );

          paginasCocina.add({
            'tipo': 'paso',
            'titulo': _modoActual == ModoElectrodomestico.thermomix
                ? 'Thermomix (TM5/TM6/TM7) 🤖'
                : _modoActual == ModoElectrodomestico.airFryer
                    ? 'Air Fryer 🍟'
                    : 'Paso a Paso',
            'numeroPaso': numeroPaso++,
            'contenido': params.textoLimpio.isNotEmpty ? params.textoLimpio : paso,
            'parametros': params,
          });
        }
      }
    }

    if (paginasCocina.isEmpty) {
      paginasCocina.add({
        'tipo': 'paso',
        'titulo': 'Preparación',
        'numeroPaso': 1,
        'contenido': widget.recetaInstrucciones,
      });
    }
  }

  Future<void> _cambiarModo(ModoElectrodomestico nuevoModo) async {
    if (nuevoModo == _modoActual) return;

    // Si no tenemos instrucciones adaptadas aún para ese modo, y no es el tradicional
    if (nuevoModo != ModoElectrodomestico.tradicional &&
        !_instruccionesPorModo.containsKey(nuevoModo)) {
      // Preguntar al usuario si desea adaptar con IA
      final bool? confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Text(nuevoModo.icono, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Adaptar a ${nuevoModo == ModoElectrodomestico.thermomix ? "Thermomix 🤖" : "Air Fryer 🍟"}',
                ),
              ),
            ],
          ),
          content: Text(
            nuevoModo == ModoElectrodomestico.thermomix
                ? '¿Deseas que el Chef IA programe esta receta con los tiempos, temperaturas (Varoma/120°C), velocidades y giro inverso exactos para Thermomix?'
                : '¿Deseas que el Chef IA adapte los tiempos y temperaturas optimizados para cocinar en Freidora de Aire?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No, ver estándar'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: nuevoModo.colorPrimario,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('¡Sí, adaptar con IA!'),
            ),
          ],
        ),
      );

      if (confirmar == true) {
        await _adaptarConIA(nuevoModo);
        return;
      }
    }

    setState(() {
      _modoActual = nuevoModo;
      _pasoActual = 0;
      _procesarInstrucciones();
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  Future<void> _adaptarConIA(ModoElectrodomestico modo) async {
    setState(() => _adaptandoIA = true);

    try {
      final String ingredientesTexto = (widget.listaIngredientes != null && widget.listaIngredientes!.isNotEmpty)
          ? widget.listaIngredientes!.join('\n')
          : widget.recetaInstrucciones;

      final String instruccionesTexto = widget.textoInstrucciones ?? widget.recetaInstrucciones;

      final resultado = await ServicioCopilotoCocina.adaptarReceta(
        titulo: widget.titulo ?? 'Receta',
        ingredientes: ingredientesTexto,
        instrucciones: instruccionesTexto,
        modo: modo,
      );

      if (!mounted) return;

      if (resultado != null && resultado.isNotEmpty) {
        setState(() {
          _instruccionesPorModo[modo] = resultado;
          _modoActual = modo;
          _pasoActual = 0;
          _procesarInstrucciones();
        });

        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Receta adaptada con éxito a ${modo.etiqueta}! 👨‍🍳✨'),
            backgroundColor: modo.colorPrimario,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No fue posible adaptar la receta con IA en este momento.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al adaptar con IA: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _adaptandoIA = false);
      }
    }
  }

  Widget _construirSelectorModo({bool isLandscape = false}) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, isLandscape ? 2 : 4, 16, isLandscape ? 4 : 10),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[750] ?? Colors.grey.shade700, width: 0.8),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: ModoElectrodomestico.values.map((modo) {
          final bool isSelected = _modoActual == modo;
          return Expanded(
            child: GestureDetector(
              onTap: () => _cambiarModo(modo),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? modo.colorPrimario : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: modo.colorPrimario.withValues(alpha: 0.45),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(modo.icono, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          modo == ModoElectrodomestico.thermomix
                              ? 'Thermomix'
                              : modo == ModoElectrodomestico.airFryer
                                  ? 'Air Fryer'
                                  : 'Tradicional',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[400],
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _construirChipRobot(IconData icono, String valor, Color colorTema) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: colorTema.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: colorTema.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: colorTema),
          const SizedBox(width: 5),
          Text(
            valor,
            style: TextStyle(
              color: colorTema,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int totalPasosReales = paginasCocina
        .where((p) => p['tipo'] == 'paso')
        .length;

    final Color colorActual = _modoActual.colorPrimario;
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _modoActual == ModoElectrodomestico.thermomix
                ? 'Modo Thermomix 🤖'
                : _modoActual == ModoElectrodomestico.airFryer
                    ? 'Modo Air Fryer 🍟'
                    : 'Modo Cocina 🔥',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _pantallaSiempreEncendida ? Icons.wb_sunny : Icons.wb_sunny_outlined,
              color: _pantallaSiempreEncendida ? Colors.amberAccent : Colors.white60,
            ),
            tooltip: _pantallaSiempreEncendida
                ? 'Pantalla siempre activa (Encendida) ☀️'
                : 'Pantalla normal (Ahorro de batería)',
            onPressed: () {
              setState(() {
                _pantallaSiempreEncendida = !_pantallaSiempreEncendida;
              });
              try {
                WakelockPlus.toggle(enable: _pantallaSiempreEncendida);
              } catch (_) {}
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_pantallaSiempreEncendida
                      ? 'Pantalla activa: no se apagará mientras cocinas ☀️🍳'
                      : 'Modo ahorro de batería activado'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _modoVozActivo
                    ? (_microfonoEscuchando
                        ? Colors.redAccent.withValues(alpha: 0.25)
                        : Colors.teal.withValues(alpha: 0.25))
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _modoVozActivo ? Icons.mic : Icons.mic_none,
                color: _modoVozActivo
                    ? (_microfonoEscuchando ? Colors.redAccent : Colors.tealAccent)
                    : Colors.white,
              ),
            ),
            tooltip: _modoVozActivo
                ? 'Desactivar Modo Manos Libres'
                : 'Activar Modo Manos Libres (Voz)',
            onPressed: _alternarModoVoz,
          ),
          if (_modoActual != ModoElectrodomestico.tradicional)
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
              tooltip: 'Re-adaptar con IA',
              onPressed: () => _adaptarConIA(_modoActual),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Selector de Electrodoméstico / Equipo
              _construirSelectorModo(isLandscape: isLandscape),

              // Barra de progreso superior
              LinearProgressIndicator(
                value: paginasCocina.isNotEmpty
                    ? (_pasoActual + 1) / paginasCocina.length
                    : 1.0,
                backgroundColor: Colors.grey[800],
                color: colorActual,
                minHeight: 6,
              ),

              // Banner interactivo del Modo Manos Libres por Voz
              if (_modoVozActivo)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _microfonoEscuchando
                        ? Colors.red.shade900.withValues(alpha: 0.45)
                        : Colors.teal.shade900.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _microfonoEscuchando ? Colors.redAccent : Colors.tealAccent,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _microfonoEscuchando ? Icons.mic : Icons.mic_none,
                        size: 18,
                        color: _microfonoEscuchando ? Colors.redAccent : Colors.tealAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _ultimoTextoVoz != null
                              ? '🗣️ "$_ultimoTextoVoz"'
                              : '🎙️ Manos libres: Di "Siguiente", "Atrás" o "Terminar"',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: _alternarModoVoz,
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.close, size: 16, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),

              // Banner interactivo del Temporizador Activo
              if (_segundosRestantes > 0)
                _construirBannerFlotanteTemporizador(),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _pasoActual = index);
                  },
                  itemCount: paginasCocina.length,
                  itemBuilder: (context, index) {
                    final pagina = paginasCocina[index];
                    final bool esPreparacion = pagina['tipo'] == 'preparacion';
                    final int numPaso = pagina['numeroPaso'] ?? index;
                    final ParametrosPasoRobot? params =
                        pagina['parametros'] as ParametrosPasoRobot?;

                    return Padding(
                      padding: EdgeInsets.all(isLandscape ? 8.0 : 20.0),
                      child: Card(
                        color: Colors.white,
                        elevation: 10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isLandscape ? 20 : 30),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isLandscape ? 16 : 25,
                            vertical: isLandscape ? 14 : 30,
                          ),
                          child: Column(
                            mainAxisAlignment: esPreparacion
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              // 💡 Etiqueta Superior Dinámica
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isLandscape ? 14 : 20,
                                  vertical: isLandscape ? 5 : 8,
                                ),
                                decoration: BoxDecoration(
                                  color: esPreparacion
                                      ? Colors.orange.withValues(alpha: 0.15)
                                      : colorActual.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      esPreparacion
                                          ? Icons.kitchen
                                          : (_modoActual == ModoElectrodomestico.thermomix
                                              ? Icons.smart_toy_outlined
                                              : _modoActual == ModoElectrodomestico.airFryer
                                                  ? Icons.air_outlined
                                                  : Icons.restaurant),
                                      size: 18,
                                      color: esPreparacion
                                          ? Colors.orange[800]
                                          : colorActual,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          esPreparacion
                                              ? pagina['titulo']
                                              : 'Paso $numPaso de $totalPasosReales (${_modoActual.etiqueta.split(' ')[0]})',
                                          style: TextStyle(
                                            color: esPreparacion
                                                ? Colors.orange[800]
                                                : colorActual,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isLandscape ? 14 : 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 💡 Parámetros de Robot / Thermomix / Air Fryer
                              if (!esPreparacion && params != null && params.tieneParametros) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: colorActual.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colorActual.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      if (params.tiempo != null)
                                        _construirChipRobot(
                                          Icons.timer_outlined,
                                          params.tiempo!,
                                          colorActual,
                                        ),
                                      if (params.temperatura != null)
                                        _construirChipRobot(
                                          Icons.thermostat,
                                          params.temperatura!,
                                          colorActual,
                                        ),
                                      if (params.giro != null)
                                        _construirChipRobot(
                                          Icons.rotate_left,
                                          params.giro!,
                                          colorActual,
                                        ),
                                      if (params.velocidad != null)
                                        _construirChipRobot(
                                          Icons.speed,
                                          params.velocidad!,
                                          colorActual,
                                        ),
                                      if (params.accesorio != null)
                                        _construirChipRobot(
                                          Icons.widgets_outlined,
                                          params.accesorio!,
                                          colorActual,
                                        ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 25),

                              // 💡 Contenido Dinámico
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Text(
                                    pagina['contenido'],
                                    textAlign: esPreparacion
                                        ? TextAlign.left
                                        : TextAlign.center,
                                    style: TextStyle(
                                      fontSize: esPreparacion
                                          ? (isLandscape ? 15 : 17)
                                          : (isLandscape ? 19 : 24),
                                      height: esPreparacion ? 1.5 : 1.35,
                                      fontWeight: esPreparacion
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                              if (!esPreparacion)
                                _construirSeccionTemporizadorPaso(
                                  pagina['contenido'] ?? '',
                                  params?.tiempo,
                                  numPaso,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Botonera Inferior
              Builder(
                builder: (context) {
                  final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: isLandscape ? 10.0 : 26.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Botón Anterior
                        Opacity(
                          opacity: _pasoActual > 0 ? 1.0 : 0.0,
                          child: FloatingActionButton(
                            heroTag: 'btnAnterior',
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                            onPressed: _pasoActual > 0
                                ? () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                            child: const Icon(Icons.arrow_back_ios_new),
                          ),
                        ),

                        // Botón Siguiente / Terminar
                        FloatingActionButton.extended(
                          heroTag: 'btnSiguiente',
                          backgroundColor: _pasoActual == paginasCocina.length - 1
                              ? Colors.green
                              : colorActual,
                          foregroundColor: Colors.white,
                          onPressed: () {
                            if (_pasoActual < paginasCocina.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            } else {
                              _finalizarYCocinar();
                            }
                          },
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _pasoActual == paginasCocina.length - 1
                                  ? '¡Terminar!'
                                  : _pasoActual == 0 &&
                                        paginasCocina[0]['tipo'] == 'preparacion'
                                  ? '¡A Cocinar!'
                                  : 'Siguiente Paso',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          icon: Icon(
                            _pasoActual == paginasCocina.length - 1
                                ? Icons.check_circle
                                : _pasoActual == 0 &&
                                      paginasCocina[0]['tipo'] == 'preparacion'
                                  ? Icons.local_fire_department
                                  : Icons.arrow_forward_ios,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          // Overlay de carga cuando Gemini adapta la receta
          if (_adaptandoIA)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: colorActual),
                  const SizedBox(height: 20),
                  Text(
                    'Programando para ${_modoActual.etiqueta}...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El Chef IA está calculando tiempos, temperaturas y velocidades exactas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _finalizarYCocinar() async {
    final bool? descontar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.green),
            SizedBox(width: 8),
            Text('¡Receta Cocinada! 👨‍🍳🔥'),
          ],
        ),
        content: const Text(
          '¿Deseas descontar automáticamente los ingredientes utilizados de tu Despensa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, solo terminar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check),
            label: const Text('Sí, descontar'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    Navigator.pop(context);

    // 🍳 Registrar la receta en el historial de recetas cocinadas
    final String tituloFinal = widget.titulo ?? 'Receta preparada';
    await ServicioHistorialCocina.marcarComoCocinada(
      idReceta: widget.idReceta ?? 0,
      titulo: tituloFinal,
      origen: 'modo_cocina',
    );

    if (descontar == true) {
      final descontados =
          await ServicioDespensa.descontarIngredientesDeReceta(
            idReceta: widget.idReceta,
            descripcionReceta: widget.recetaInstrucciones,
            multiplicador: widget.multiplicador,
          );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (descontados.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '¡Listo! Receta guardada como cocinada y se descontaron de tu despensa: ${descontados.join(', ')} 🥫✅',
            ),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              '¡Buen provecho! Receta marcada como cocinada 👨‍🍳✅ (No se encontraron ingredientes para descontar en despensa).',
            ),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Excelente trabajo, Chef! Receta guardada como cocinada 👨‍🍳🔥'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // =========================================================================
  // ⏱️ TEMPORIZADOR INTELIGENTE INTEGRADO
  // =========================================================================

  int? _extraerSegundosDeTexto(String texto, {String? paramTiempo}) {
    if (paramTiempo != null && paramTiempo.trim().isNotEmpty) {
      final s = _parsearCadenaASegundos(paramTiempo);
      if (s != null && s > 0) return s;
    }
    return _parsearCadenaASegundos(texto);
  }

  int? _parsearCadenaASegundos(String texto) {
    final t = texto.toLowerCase();
    // 1. Minutos (ej. "15 min", "15 minutos", "2.5 min")
    final matchMin =
        RegExp(r'(\d+(?:\.\d+)?)\s*(?:minutos?|min)\b').firstMatch(t);
    if (matchMin != null) {
      final val = double.tryParse(matchMin.group(1) ?? '');
      if (val != null) return (val * 60).round();
    }
    // 2. Segundos (ej. "30 seg", "45 segundos")
    final matchSeg = RegExp(r'(\d+)\s*(?:segundos?|seg|s)\b').firstMatch(t);
    if (matchSeg != null) {
      final val = int.tryParse(matchSeg.group(1) ?? '');
      if (val != null) return val;
    }
    // 3. Horas (ej. "1 hora", "2 hrs")
    final matchHora =
        RegExp(r'(\d+(?:\.\d+)?)\s*(?:horas?|hrs?|h)\b').firstMatch(t);
    if (matchHora != null) {
      final val = double.tryParse(matchHora.group(1) ?? '');
      if (val != null) return (val * 3600).round();
    }
    return null;
  }

  String _formatearTiempoRestante(int totalSegundos) {
    final int horas = totalSegundos ~/ 3600;
    final int minutos = (totalSegundos % 3600) ~/ 60;
    final int segundos = totalSegundos % 60;
    if (horas > 0) {
      return '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
    }
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  String _formatearMinutosOSegundos(int seg) {
    if (seg >= 3600) {
      final h = seg ~/ 3600;
      final m = (seg % 3600) ~/ 60;
      return m > 0 ? '$h h $m min' : '$h h';
    }
    if (seg >= 60) {
      final m = seg ~/ 60;
      final s = seg % 60;
      return s > 0 ? '$m min $s seg' : '$m min';
    }
    return '$seg seg';
  }

  void _iniciarTemporizador(int segundos, String titulo) {
    _temporizadorCocina?.cancel();
    setState(() {
      _segundosTotales = segundos;
      _segundosRestantes = segundos;
      _temporizadorActivo = true;
      _tituloTemporizador = titulo;
    });

    _temporizadorCocina = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_segundosRestantes > 1) {
        setState(() {
          _segundosRestantes--;
        });
      } else {
        timer.cancel();
        setState(() {
          _segundosRestantes = 0;
          _temporizadorActivo = false;
        });
        _notificarFinTemporizador(titulo);
      }
    });
  }

  void _alternarPausaTemporizador() {
    if (!_temporizadorActivo && _segundosRestantes > 0) {
      setState(() => _temporizadorActivo = true);
      _temporizadorCocina = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_segundosRestantes > 1) {
          setState(() => _segundosRestantes--);
        } else {
          timer.cancel();
          setState(() {
            _segundosRestantes = 0;
            _temporizadorActivo = false;
          });
          _notificarFinTemporizador(_tituloTemporizador);
        }
      });
    } else if (_temporizadorActivo) {
      _temporizadorCocina?.cancel();
      setState(() => _temporizadorActivo = false);
    }
  }

  void _ajustarSegundosTemporizador(int deltaSegundos) {
    setState(() {
      final nuevo = _segundosRestantes + deltaSegundos;
      _segundosRestantes = nuevo > 0 ? nuevo : 0;
      if (_segundosRestantes > _segundosTotales) {
        _segundosTotales = _segundosRestantes;
      }
    });
  }

  void _cancelarTemporizador() {
    _temporizadorCocina?.cancel();
    setState(() {
      _segundosRestantes = 0;
      _segundosTotales = 0;
      _temporizadorActivo = false;
      _tituloTemporizador = '';
    });
  }

  void _notificarFinTemporizador(String titulo) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.alarm_on,
                  color: Colors.deepOrange, size: 28),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '¡Tiempo cumplido! ⏰',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'El temporizador para "$titulo" ha finalizado. Revisa tu preparación.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido 👍',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _construirSeccionTemporizadorPaso(
    String contenido,
    String? paramTiempo,
    int numPaso,
  ) {
    if (_segundosRestantes > 0) {
      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.orange.shade900,
              const Color(0xFFD32F2F),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      _tituloTemporizador.isNotEmpty
                          ? _tituloTemporizador
                          : 'Temporizador Activo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _cancelarTemporizador,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close, color: Colors.white70, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatearTiempoRestante(_segundosRestantes),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _segundosTotales > 0
                    ? (_segundosRestantes / _segundosTotales)
                    : 0,
                backgroundColor: Colors.white24,
                color: const Color(0xFFFFD700),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _ajustarSegundosTemporizador(-60),
                  child: const Text('-1 min', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade900,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    _temporizadorActivo ? Icons.pause : Icons.play_arrow,
                    size: 16,
                  ),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _temporizadorActivo ? 'Pausar' : 'Reanudar',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  onPressed: _alternarPausaTemporizador,
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _ajustarSegundosTemporizador(60),
                  child: const Text('+1 min', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final int? seg =
        _extraerSegundosDeTexto(contenido, paramTiempo: paramTiempo);
    if (seg == null || seg <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepOrange.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 3,
        ),
        icon: const Icon(Icons.timer_outlined, size: 20),
        label: Text(
          '⏱️ Iniciar temporizador (${_formatearMinutosOSegundos(seg)})',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: () => _iniciarTemporizador(
          seg,
          'Paso $numPaso (${_formatearMinutosOSegundos(seg)})',
        ),
      ),
    );
  }

  Widget _construirBannerFlotanteTemporizador() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepOrange.shade900.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orangeAccent, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            _temporizadorActivo ? Icons.timer : Icons.timer_off_outlined,
            size: 18,
            color: const Color(0xFFFFD700),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '⏱️ ${_tituloTemporizador.isNotEmpty ? _tituloTemporizador : "Temporizador"}: ${_formatearTiempoRestante(_segundosRestantes)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              _temporizadorActivo
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: Colors.white,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _alternarPausaTemporizador,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 16),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _cancelarTemporizador,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    try {
      WakelockPlus.disable();
    } catch (_) {}
    _temporizadorCocina?.cancel();
    _temporizadorLimpiezaVoz?.cancel();
    _servicioVoz.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
