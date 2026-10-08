import 'package:flutter/material.dart';

import 'servicio_despensa.dart';
import 'servicio_historial_cocina.dart';

class PantallaModoCocina extends StatefulWidget {
  final String recetaInstrucciones;
  final int? idReceta;
  final String? titulo;
  final double multiplicador;
  final List<String>? listaIngredientes;
  final String? textoInstrucciones;

  const PantallaModoCocina({
    super.key,
    required this.recetaInstrucciones,
    this.idReceta,
    this.titulo,
    this.multiplicador = 1.0,
    this.listaIngredientes,
    this.textoInstrucciones,
  });

  @override
  State<PantallaModoCocina> createState() => _PantallaModoCocinaState();
}

class _PantallaModoCocinaState extends State<PantallaModoCocina> {
  final PageController _pageController = PageController();

  // 💡 Estructura inteligente para manejar diferentes tipos de tarjetas
  List<Map<String, dynamic>> paginasCocina = [];
  int _pasoActual = 0;

  @override
  void initState() {
    super.initState();
    _procesarInstrucciones();
  }

  void _procesarInstrucciones() {
    paginasCocina.clear();

    // 1. Tarjeta Cero: "Antes del Fuego 🔥" (Ingredientes y Utensilios)
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
      sb.writeln('\n🔪 UTENSILIOS Y MISE EN PLACE:');
      sb.writeln('• Tabla de picar y cuchillo afilado');
      sb.writeln('• Sartén, comal u olla (según corresponda)');
      sb.writeln('• Espátula, cuchara o pinzas de cocina');
      sb.writeln('• ¡Lava, mide y pica todo antes de encender el fuego!');
      textoMiseEnPlace = sb.toString();
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

      if (textoMiseEnPlace.isNotEmpty && !textoMiseEnPlace.toUpperCase().contains('UTENSILIO')) {
        textoMiseEnPlace += '\n\n🔪 UTENSILIOS RECOMENDADOS:\n• Sartén / Olla\n• Tabla y cuchillo\n• Espátula o pala';
      }
    }

    if (textoMiseEnPlace.isNotEmpty) {
      textoMiseEnPlace = textoMiseEnPlace.replaceAll(RegExp(r'\*\*'), '');
      paginasCocina.add({
        'tipo': 'preparacion',
        'titulo': 'Antes del Fuego 🔥',
        'contenido': textoMiseEnPlace,
      });
    }

    // 2. Extraer y procesar los pasos individuales
    String textoPasos = "";
    if (widget.textoInstrucciones != null && widget.textoInstrucciones!.trim().isNotEmpty) {
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
          palabraEncontrada = palabra;
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
      for (var linea in lineas) {
        String paso = linea.trim();
        paso = paso.replaceAll(RegExp(r'^[\*\-\•]\s*'), '');
        paso = paso.replaceAll(RegExp(r'\*\*'), '');
        paso = paso.replaceAll(RegExp(r'^\d+\.\s*'), '');

        if (paso.length > 8) {
          paginasCocina.add({
            'tipo': 'paso',
            'titulo': 'Paso a Paso',
            'contenido': paso,
          });
        }
      }
    }

    if (paginasCocina.isEmpty) {
      paginasCocina.add({
        'tipo': 'paso',
        'titulo': 'Preparación',
        'contenido': widget.recetaInstrucciones,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos cuántos pasos reales hay (restando la tarjeta de preparación)
    int totalPasosReales = paginasCocina
        .where((p) => p['tipo'] == 'paso')
        .length;
    int contadorPasos = 0;

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
        title: const Text(
          'Modo Cocina',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Barra de progreso superior
          LinearProgressIndicator(
            value: (_pasoActual + 1) / paginasCocina.length,
            backgroundColor: Colors.grey[800],
            color: const Color(0xFFE53935),
            minHeight: 6,
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

                if (!esPreparacion) {
                  contadorPasos++;
                }

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
                                  : const Color(0xFFE53935)
                                        .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  esPreparacion
                                      ? Icons.kitchen
                                      : Icons.restaurant,
                                  size: 18,
                                  color: esPreparacion
                                      ? Colors.orange[800]
                                      : const Color(0xFFD32F2F),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  esPreparacion
                                      ? pagina['titulo']
                                      : 'Paso $contadorPasos de $totalPasosReales',
                                  style: TextStyle(
                                    color: esPreparacion
                                        ? Colors.orange[800]
                                        : const Color(0xFFD32F2F),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),

                          // 💡 Contenido Dinámico (Alineado a la izquierda para listas, centrado para pasos)
                          Expanded(
                            child: SingleChildScrollView(
                              child: Text(
                                pagina['contenido'],
                                textAlign: esPreparacion
                                    ? TextAlign.left
                                    : TextAlign.center,
                                style: TextStyle(
                                  fontSize: esPreparacion ? 18 : 26,
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
                      : const Color(0xFFE53935),
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
}
