import 'dart:async';
import 'package:flutter/material.dart';

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

  // 💡 Estructura inteligente para manejar diferentes tipos de tarjetas
  List<Map<String, dynamic>> paginasCocina = [];
  int _pasoActual = 0;

  @override
  void initState() {
    super.initState();
    _modoActual = widget.modoInicial;

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
                ? 'Thermomix TM5/TM6 🤖'
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

  Widget _construirSelectorModo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
                        overflow: TextOverflow.ellipsis,
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
        title: Text(
          _modoActual == ModoElectrodomestico.thermomix
              ? 'Modo Thermomix 🤖'
              : _modoActual == ModoElectrodomestico.airFryer
                  ? 'Modo Air Fryer 🍟'
                  : 'Modo Cocina 🔥',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
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
              _construirSelectorModo(),

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
                      padding: const EdgeInsets.all(20.0),
                      child: Card(
                        color: Colors.white,
                        elevation: 10,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 25,
                            vertical: 30,
                          ),
                          child: Column(
                            mainAxisAlignment: esPreparacion
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              // 💡 Etiqueta Superior Dinámica
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
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
                                    Text(
                                      esPreparacion
                                          ? pagina['titulo']
                                          : 'Paso $numPaso de $totalPasosReales (${_modoActual.etiqueta.split(' ')[0]})',
                                      style: TextStyle(
                                        color: esPreparacion
                                            ? Colors.orange[800]
                                            : colorActual,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
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
                                      fontSize: esPreparacion ? 17 : 24,
                                      height: esPreparacion ? 1.6 : 1.4,
                                      fontWeight: esPreparacion
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 30.0,
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
                      label: Text(
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

  @override
  void dispose() {
    _temporizadorLimpiezaVoz?.cancel();
    _servicioVoz.dispose();
    _pageController.dispose();
    super.dispose();
  }
}
