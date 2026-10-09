import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

import 'config_api.dart';

import 'pantalla_chef.dart';
import 'pantalla_despensa.dart';
import 'pantalla_carrito.dart';
import 'pantalla_preferencias.dart';
import 'perfiles_nutricionales.dart';
import 'pantalla_detalle_receta.dart';
import 'servicio_preferencias.dart';
import 'servicio_despensa.dart';
import 'servicio_historial_cocina.dart';
import 'menu_lateral.dart';

// Constante global de primer nivel para evitar errores de null en Hot Reload
const Map<String, String> kDescripcionesObjetivo = {
  PerfilesNutricionales.deficit:
      'Prioriza platillos ligeros (~1,500 kcal/día) para déficit calórico.',
  PerfilesNutricionales.mantenimiento:
      'Balance estándar de nutrientes y energía (~2,000 kcal/día).',
  PerfilesNutricionales.volumen:
      'Platillos con alto aporte proteico y calórico (~2,500 kcal/día).',
  'Keto':
      'Prioriza platillos bajos en carbohidratos (~1,700 kcal/día) y ricos en grasas saludables.',
  'Libre':
      'Variedad total usando todas las recetas registradas en tu catálogo.',
};

class PantallaPlaneador extends StatefulWidget {
  const PantallaPlaneador({super.key});

  @override
  State<PantallaPlaneador> createState() => _PantallaPlaneadorState();
}

class _PantallaPlaneadorState extends State<PantallaPlaneador> {
  List<dynamic> miPlan = [];
  bool cargando = true;
  bool planeandoIA = false;
  String objetivoActivo = PerfilesNutricionales.mantenimiento;
  List<String> _estilos = [PerfilesNutricionales.libre];
  String _alergias = '';
  Set<int> _idsCocinadas = {};
  Set<String> _titulosCocinados = {};

  @override
  void initState() {
    super.initState();
    cargarPlan();
    _cargarObjetivoDesdePreferencias();
  }

  Future<void> _cargarObjetivoDesdePreferencias() async {
    try {
      final prefs = await ServicioPreferencias.obtenerPreferencias();
      if (!mounted) return;
      String objetivo = prefs.estilos.contains(PerfilesNutricionales.keto)
          ? 'Keto'
          : prefs.objetivo;
      if (objetivo == 'Déficit') objetivo = PerfilesNutricionales.deficit;
      if (objetivo == 'Volumen') objetivo = PerfilesNutricionales.volumen;
      if (objetivo.isEmpty) objetivo = PerfilesNutricionales.mantenimiento;

      setState(() {
        _estilos = prefs.estilos;
        _alergias = prefs.alergias;
        objetivoActivo = objetivo;
      });
    } catch (e) {
      debugPrint('Error al leer preferencias en Planeador: $e');
    }
  }

  Future<void> _abrirPreferencias() async {
    final actualizado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PantallaPreferencias()),
    );
    if (actualizado == true || mounted) {
      await _cargarObjetivoDesdePreferencias();
      await cargarPlan();
    }
  }

  Map<String, dynamic> _analizarCumplimiento() {
    final metaMacros =
        PerfilesNutricionales.macrosPara(objetivoActivo, _estilos);
    final int metaCaloriasDia = metaMacros['calorias'] ?? 2000;

    final Map<String, int> caloriasPorDia = {};
    int incompatiblesCount = 0;
    final List<String> recetasIncompatibles = [];

    for (var item in miPlan) {
      final fecha = (item['fecha'] ?? '').toString();
      final receta = item['recetas'] as Map<String, dynamic>? ?? {};
      final cal = int.tryParse(receta['calorias']?.toString() ?? '0') ?? 0;

      if (fecha.isNotEmpty) {
        caloriasPorDia[fecha] = (caloriasPorDia[fecha] ?? 0) + cal;
      }

      final titulo = (receta['titulo'] ?? '').toString();
      final desc = (receta['descripcion'] ?? '').toString();
      final esCompatible = PerfilesNutricionales.recetaCompatible(
        "$titulo $desc",
        _estilos,
        alergias: _alergias,
      );

      if (!esCompatible) {
        incompatiblesCount++;
        if (titulo.isNotEmpty && !recetasIncompatibles.contains(titulo)) {
          recetasIncompatibles.add(titulo);
        }
      }
    }

    final int diasPlaneados = caloriasPorDia.length;
    final int totalCalorias = caloriasPorDia.values.fold(0, (a, b) => a + b);
    final double promedioCalorias =
        diasPlaneados > 0 ? (totalCalorias / diasPlaneados) : 0.0;

    return {
      'metaCalorias': metaCaloriasDia,
      'diasPlaneados': diasPlaneados,
      'promedioCalorias': promedioCalorias,
      'caloriasPorDia': caloriasPorDia,
      'incompatiblesCount': incompatiblesCount,
      'recetasIncompatibles': recetasIncompatibles,
      'totalRecetas': miPlan.length,
    };
  }

  Widget _construirTarjetaCumplimiento() {
    final analisis = _analizarCumplimiento();
    final int metaCal = analisis['metaCalorias'] as int;
    final double promedioCal = analisis['promedioCalorias'] as double;
    final int incompatibles = analisis['incompatiblesCount'] as int;
    final int totalRecetas = analisis['totalRecetas'] as int;
    final int dias = analisis['diasPlaneados'] as int;
    final List<String> noCompatibles =
        (analisis['recetasIncompatibles'] as List).cast<String>();

    final bool esDeficit = objetivoActivo.contains('Déficit');
    final bool esVolumen = objetivoActivo.contains('Volumen');

    Color colorCalorias = Colors.teal;
    String mensajeCalorico =
        'Promedio: ${promedioCal.round()} kcal/día (Meta: $metaCal)';
    IconData iconoCalorias = Icons.check_circle_outline;

    if (dias > 0 && promedioCal > 0) {
      if (esDeficit) {
        if (promedioCal <= metaCal + 100) {
          colorCalorias = Colors.green.shade700;
          mensajeCalorico =
              '🟢 Cumple Déficit (~${promedioCal.round()} kcal/día vs meta $metaCal)';
          iconoCalorias = Icons.check_circle;
        } else {
          colorCalorias = Colors.orange.shade800;
          mensajeCalorico =
              '⚠️ Excede déficit (+${(promedioCal - metaCal).round()} kcal/día)';
          iconoCalorias = Icons.warning_amber_rounded;
        }
      } else if (esVolumen) {
        if (promedioCal >= metaCal - 150) {
          colorCalorias = Colors.green.shade700;
          mensajeCalorico =
              '🟢 Cumple Volumen (~${promedioCal.round()} kcal/día vs meta $metaCal)';
          iconoCalorias = Icons.check_circle;
        } else {
          colorCalorias = Colors.orange.shade800;
          mensajeCalorico =
              '⚠️ Te faltan ~${(metaCal - promedioCal).round()} kcal/día para tu meta';
          iconoCalorias = Icons.trending_up;
        }
      } else {
        final diff = (promedioCal - metaCal).abs();
        if (diff <= 200) {
          colorCalorias = Colors.green.shade700;
          mensajeCalorico =
              '🟢 Balance calórico ideal (~${promedioCal.round()} kcal/día)';
          iconoCalorias = Icons.check_circle;
        } else {
          colorCalorias = Colors.blueGrey;
          mensajeCalorico =
              'Promedio: ${promedioCal.round()} kcal/día (Meta: $metaCal)';
        }
      }
    }

    final bool estilosCumplidos = incompatibles == 0;
    final estilosTexto =
        _estilos.where((e) => e != PerfilesNutricionales.libre).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.teal.shade50.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.track_changes, color: Colors.teal, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Meta: $objetivoActivo',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.teal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: _abrirPreferencias,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade300),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 14, color: Colors.teal),
                      SizedBox(width: 4),
                      Text(
                        'Preferencias ⚙️',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🎯 $metaCal kcal/día',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (estilosTexto.isEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Dieta: Libre',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                )
              else
                ...estilosTexto.map((estilo) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.teal.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        estilo,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade900,
                        ),
                      ),
                    )),
              if (_alergias.trim().isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🚫 ${_alergias.trim()}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 18),
          if (totalRecetas == 0)
            const Text(
              '📅 Aún no tienes comidas en tu plan semanal.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          else ...[
            Row(
              children: [
                Icon(iconoCalorias, size: 16, color: colorCalorias),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    mensajeCalorico,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorCalorias,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  estilosCumplidos
                      ? Icons.verified
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: estilosCumplidos
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    estilosCumplidos
                        ? (estilosTexto.isEmpty
                            ? '✅ Catálogo compatible con dieta Libre'
                            : '✅ 100% compatible con tus estilos (${estilosTexto.join(", ")})')
                        : '⚠️ $incompatibles comida(s) chocan con tus estilos (${noCompatibles.take(2).join(", ")})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: estilosCumplidos
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> cargarPlan() async {
    setState(() => cargando = true);
    try {
      final ids = await ServicioHistorialCocina.obtenerIdsCocinadas();
      final tits = await ServicioHistorialCocina.obtenerTitulosCocinadas();
      final hoy = DateTime.now().toIso8601String().split('T')[0];

      final respuesta = await Supabase.instance.client
          .from('planeador')
          .select(
            'id_planeador, fecha, tipo_comida, id_receta, recetas(titulo, imagen_url, instrucciones, descripcion, calorias)',
          )
          .gte('fecha', hoy)
          .order('fecha', ascending: true);

      if (!mounted) return;
      setState(() {
        miPlan = respuesta;
        _idsCocinadas = ids;
        _titulosCocinados = tits;
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar plan: $e');
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _marcarRecetaPlaneadorComoCocinada({
    required int idPlaneador,
    required int idReceta,
    required String titulo,
    required String textoReceta,
  }) async {
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.soup_kitchen, color: Colors.green),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '¡Cocinaste este platillo! 👨‍🍳🔥',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Deseas registrar "$titulo" como ya preparada y descontar automáticamente sus ingredientes de tu Despensa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancelar'),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'solo_marcar'),
            child: const Text('Solo marcar preparada'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, 'marcar_y_descontar'),
            icon: const Icon(Icons.check),
            label: const Text('Marcar y descontar'),
          ),
        ],
      ),
    );

    if (resultado == null || resultado == 'cancelar' || !mounted) return;

    await ServicioHistorialCocina.marcarComoCocinada(
      idReceta: idReceta,
      titulo: titulo,
      idPlaneador: idPlaneador,
      origen: 'planeador',
    );

    List<String> descontados = [];
    if (resultado == 'marcar_y_descontar') {
      descontados = await ServicioDespensa.descontarIngredientesDeReceta(
        idReceta: idReceta > 0 ? idReceta : null,
        descripcionReceta: textoReceta,
      );
    }

    await cargarPlan();

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (descontados.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '¡"$titulo" registrada como cocinada y descontada de despensa! (${descontados.join(', ')}) 🥫✅',
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('¡"$titulo" registrada como ya cocinada! 👨‍🍳✅'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  void _mostrarSelectorDeObjetivo() {
    String seleccionTemporal = objetivoActivo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.teal, size: 24),
                      SizedBox(width: 10),
                      Text(
                        'Objetivo Nutricional para la Semana',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'La IA seleccionará los platillos de tus 7 días alineados a esta meta:',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 15),
                  ...kDescripcionesObjetivo.keys.map((meta) {
                    final bool elegida = seleccionTemporal == meta;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: elegida ? Colors.teal : Colors.grey.shade200,
                          width: elegida ? 2 : 1,
                        ),
                      ),
                      color: elegida ? Colors.teal.shade50 : Colors.white,
                      child: ListTile(
                        dense: true,
                        title: Text(
                          meta,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: elegida
                                ? Colors.teal.shade900
                                : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          kDescripcionesObjetivo[meta] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: elegida
                                ? Colors.teal.shade800
                                : Colors.grey.shade600,
                          ),
                        ),
                        trailing: elegida
                            ? const Icon(Icons.check_circle, color: Colors.teal)
                            : const Icon(
                                Icons.circle_outlined,
                                color: Colors.grey,
                              ),
                        onTap: () {
                          setStateModal(() => seleccionTemporal = meta);
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 15),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text(
                      'Planear 7 Días con este Objetivo 🚀',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => objetivoActivo = seleccionTemporal);

                      try {
                        final prefsActuales =
                            await ServicioPreferencias.obtenerPreferencias();
                        final objetivoParaGuardar =
                            seleccionTemporal == 'Keto' ||
                                    seleccionTemporal == 'Libre'
                                ? prefsActuales.objetivo
                                : seleccionTemporal;
                        final estilosParaGuardar = seleccionTemporal == 'Keto'
                            ? (prefsActuales.estilos
                                    .contains(PerfilesNutricionales.keto)
                                ? prefsActuales.estilos
                                : [
                                    ...prefsActuales.estilos.where(
                                        (e) => e != PerfilesNutricionales.libre),
                                    PerfilesNutricionales.keto
                                  ])
                            : (seleccionTemporal == 'Libre'
                                ? [PerfilesNutricionales.libre]
                                : prefsActuales.estilos);

                        await ServicioPreferencias.guardarPreferencias(
                          PreferenciasUsuario(
                            objetivo: objetivoParaGuardar,
                            estilos: estilosParaGuardar,
                            alergias: prefsActuales.alergias,
                            superFavorito: prefsActuales.superFavorito,
                            porciones: prefsActuales.porciones,
                            presupuestoSemanal: prefsActuales.presupuestoSemanal,
                            notificaciones: prefsActuales.notificaciones,
                          ),
                        );
                        _cargarObjetivoDesdePreferencias();
                      } catch (e) {
                        debugPrint(
                            'Error al sincronizar objetivo con preferencias: $e');
                      }

                      autocompletarSemanaConObjetivo(seleccionTemporal);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> autocompletarSemanaConObjetivo(String objetivo) async {
    setState(() => planeandoIA = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final resRecetas = await Supabase.instance.client
          .from('recetas')
          .select('id_receta, titulo, tipo_comida, descripcion, calorias');

      final List<Map<String, dynamic>> todas = List<Map<String, dynamic>>.from(
        resRecetas,
      );

      // Solo recetas compatibles con estilos y alergias del perfil
      final compatibles = todas
          .where(
            (r) => PerfilesNutricionales.recetaCompatible(
              "${r['titulo']} ${r['descripcion']}",
              _estilos,
              alergias: _alergias,
            ),
          )
          .toList();

      if (todas.isEmpty || compatibles.isEmpty) {
        if (!mounted) return;
        setState(() => planeandoIA = false);
        await _mostrarAvisoChefIACrearaRecetas(
          objetivo,
          razon: todas.isEmpty
              ? 'Aún no tienes recetas registradas en tu catálogo.'
              : 'Ninguna de tus recetas guardadas coincide con tu estilo de dieta o restricciones de alergias.',
        );
        return;
      }

      List<Map<String, dynamic>> filtrarPorObjetivo(String tipoComida) {
        List<Map<String, dynamic>> base = compatibles.where((r) {
          final tipo = (r['tipo_comida'] ?? '').toString();
          return tipo == tipoComida;
        }).toList();

        if (base.isEmpty) return [];

        if (objetivo == 'Keto') {
          final ketoMatch = base.where((r) {
            final texto = "${r['titulo']} ${r['descripcion']}".toLowerCase();
            return texto.contains('keto') ||
                texto.contains('aguacate') ||
                texto.contains('huevo') ||
                texto.contains('tocino') ||
                texto.contains('almendra');
          }).toList();
          if (ketoMatch.isNotEmpty) return ketoMatch;
        } else if (objetivo == 'Déficit (Baja)' || objetivo == 'Déficit') {
          base.sort((a, b) {
            final calA =
                int.tryParse(a['calorias']?.toString() ?? '500') ?? 500;
            final calB =
                int.tryParse(b['calorias']?.toString() ?? '500') ?? 500;
            return calA.compareTo(calB);
          });
          return base.take(10).toList();
        } else if (objetivo == 'Volumen (Alta)' || objetivo == 'Volumen') {
          final proteMatch = base.where((r) {
            final texto = "${r['titulo']} ${r['descripcion']}".toLowerCase();
            return texto.contains('pollo') ||
                texto.contains('carne') ||
                texto.contains('atun') ||
                texto.contains('proteina') ||
                texto.contains('pavo');
          }).toList();
          if (proteMatch.isNotEmpty) return proteMatch;
        }

        return base;
      }

      List<Map<String, dynamic>> desayunos = filtrarPorObjetivo('Desayuno');
      List<Map<String, dynamic>> comidas = filtrarPorObjetivo('Comida');
      List<Map<String, dynamic>> cenas = filtrarPorObjetivo('Cena');
      List<Map<String, dynamic>> snacks = filtrarPorObjetivo('Snack');

      // 🔍 DETECCIÓN INTELIGENTE DE FALTANTES Y REPETICIONES
      final faltanDesayunos = (7 - desayunos.length).clamp(0, 7);
      final faltanComidas = (7 - comidas.length).clamp(0, 7);
      final faltanCenas = (7 - cenas.length).clamp(0, 7);
      final faltanSnacks = (7 - snacks.length).clamp(0, 7);
      final totalFaltantes =
          faltanDesayunos + faltanComidas + faltanCenas + faltanSnacks;
      int recetasNuevasCreadas = 0;

      // Si faltan opciones o las recetas se tendrían que repetir:
      if (totalFaltantes > 0) {
        if (!mounted) return;
        setState(() => planeandoIA = false);

        final bool? deseaChefIA = await _mostrarDialogoFaltantesORepeticion(
          objetivo: objetivo,
          desayunosFaltan: faltanDesayunos,
          comidasFaltan: faltanComidas,
          cenasFaltan: faltanCenas,
          snacksFaltan: faltanSnacks,
          desayunosActuales: desayunos.length,
          comidasActuales: comidas.length,
          cenasActuales: cenas.length,
          snacksActuales: snacks.length,
        );

        if (!mounted) return;
        setState(() => planeandoIA = true);

        if (deseaChefIA == true) {
          final nuevas = await _generarPlatillosFaltantes(
            objetivo: objetivo,
            faltanDesayunos: faltanDesayunos,
            faltanComidas: faltanComidas,
            faltanCenas: faltanCenas,
            faltanSnacks: faltanSnacks,
          );

          recetasNuevasCreadas = nuevas.length;

          for (var r in nuevas) {
            final tipo = r['tipo_comida']?.toString() ?? 'Comida';
            if (tipo == 'Desayuno') {
              desayunos.add(r);
            } else if (tipo == 'Comida') {
              comidas.add(r);
            } else if (tipo == 'Cena') {
              cenas.add(r);
            } else if (tipo == 'Snack') {
              snacks.add(r);
            }
          }
        }
      }

      if (desayunos.isEmpty) desayunos = List.from(compatibles);
      if (comidas.isEmpty) comidas = List.from(compatibles);
      if (cenas.isEmpty) cenas = List.from(compatibles);
      if (snacks.isEmpty) snacks = List.from(compatibles);

      desayunos.shuffle();
      comidas.shuffle();
      cenas.shuffle();
      snacks.shuffle();

      final hoyDate = DateTime.now();
      final dia7 = hoyDate
          .add(const Duration(days: 6))
          .toIso8601String()
          .split('T')[0];
      final hoyStr = hoyDate.toIso8601String().split('T')[0];

      await Supabase.instance.client
          .from('planeador')
          .delete()
          .gte('fecha', hoyStr)
          .lte('fecha', dia7);

      for (int i = 0; i < 7; i++) {
        final fecha = hoyDate.add(Duration(days: i));
        final fechaStr =
            "${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}";

        Future<void> insertar(
          List<Map<String, dynamic>> lista,
          String tipo,
        ) async {
          if (lista.isNotEmpty) {
            await Supabase.instance.client.from('planeador').insert({
              'fecha': fechaStr,
              'tipo_comida': tipo,
              'id_receta': lista[i % lista.length]['id_receta'],
              'costo_personalizado': 0.0,
            });
          }
        }

        await insertar(desayunos, 'Desayuno');
        await insertar(comidas, 'Comida');
        await insertar(snacks, 'Snack');
        await insertar(cenas, 'Cena');
      }

      await cargarPlan();

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            recetasNuevasCreadas > 0
                ? '¡Semana lista! Chef IA creó $recetasNuevasCreadas recetas nuevas para evitar repeticiones (guardadas en Mis Recetas) 👨‍🍳✨'
                : '¡Semana planeada con objetivo $objetivo! 📅✨',
          ),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('Error al autocompletar plan: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => planeandoIA = false);
    }
  }

  /// 👨‍🍳 Complementa el planeador semanal con 1 Clic usando sugerencias autónomas
  /// del Chef IA, respetando siempre los platillos ya existentes y su libertad creativa culinaria.
  Future<void> complementarPlaneadorConChefIA1Click() async {
    if (planeandoIA) return;
    setState(() => planeandoIA = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final hoyDate = DateTime.now();
      final List<String> proximos7Dias = [];
      for (int i = 0; i < 7; i++) {
        final f = hoyDate.add(Duration(days: i));
        final fStr =
            "${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}";
        proximos7Dias.add(fStr);
      }

      const mealTypes = ['Desayuno', 'Comida', 'Snack', 'Cena'];

      // Mapear qué turnos ya están planeados
      final Set<String> slotsOcupados = {};
      final Set<int> idsEnUso = {};

      for (var item in miPlan) {
        final fecha = (item['fecha'] ?? '').toString();
        final tipo = (item['tipo_comida'] ?? '').toString();
        final idRec = item['id_receta'];
        if (fecha.isNotEmpty && tipo.isNotEmpty) {
          slotsOcupados.add('$fecha|$tipo');
        }
        if (idRec is int) {
          idsEnUso.add(idRec);
        }
      }

      // Encontrar slots vacíos para los próximos 7 días
      final List<Map<String, String>> slotsFaltantes = [];
      for (var f in proximos7Dias) {
        for (var tipo in mealTypes) {
          if (!slotsOcupados.contains('$f|$tipo')) {
            slotsFaltantes.add({'fecha': f, 'tipo_comida': tipo});
          }
        }
      }

      // Si no hay slots vacíos (todos los 28 ya están ocupados)
      if (slotsFaltantes.isEmpty) {
        if (!mounted) return;
        setState(() => planeandoIA = false);

        final bool? deseaRenovar = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.deepOrange),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Semana ya completa!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Text(
              'Tus próximos 7 días ya tienen los 28 platillos asignados.\n\n¿Deseas que el Chef IA renueve creativamente toda tu semana con recetas frescas adaptadas a tu meta ($objetivoActivo)?',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Mantener actual'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Renovar con Chef IA 🚀'),
              ),
            ],
          ),
        );

        if (deseaRenovar == true && mounted) {
          final dia7Str = proximos7Dias.last;
          final hoyStr = proximos7Dias.first;
          await Supabase.instance.client
              .from('planeador')
              .delete()
              .gte('fecha', hoyStr)
              .lte('fecha', dia7Str);
          await cargarPlan();
          await complementarPlaneadorConChefIA1Click();
          return;
        }
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '👨‍🍳 Chef IA preparando sugerencias autónomas para ${slotsFaltantes.length} platillos... 🍳✨',
          ),
          backgroundColor: Colors.deepOrange,
          duration: const Duration(seconds: 4),
        ),
      );

      // 1. Obtener recetas del catálogo en Supabase
      final resRecetas = await Supabase.instance.client
          .from('recetas')
          .select('id_receta, titulo, tipo_comida, descripcion, calorias');

      final List<Map<String, dynamic>> todas = List<Map<String, dynamic>>.from(
        resRecetas,
      );

      // Filtrar compatibles según objetivo y restricciones
      final compatibles = todas
          .where(
            (r) => PerfilesNutricionales.recetaCompatible(
              "${r['titulo']} ${r['descripcion']}",
              _estilos,
              alergias: _alergias,
            ),
          )
          .toList();

      // Separar por tipo de comida
      List<Map<String, dynamic>> dispDesayunos = compatibles
          .where((r) => r['tipo_comida'] == 'Desayuno')
          .toList();
      List<Map<String, dynamic>> dispComidas =
          compatibles.where((r) => r['tipo_comida'] == 'Comida').toList();
      List<Map<String, dynamic>> dispSnacks =
          compatibles.where((r) => r['tipo_comida'] == 'Snack').toList();
      List<Map<String, dynamic>> dispCenas =
          compatibles.where((r) => r['tipo_comida'] == 'Cena').toList();

      // Contar faltantes por categoría
      final int faltanDesayunos = slotsFaltantes
          .where((s) => s['tipo_comida'] == 'Desayuno')
          .length;
      final int faltanComidas =
          slotsFaltantes.where((s) => s['tipo_comida'] == 'Comida').length;
      final int faltanSnacks =
          slotsFaltantes.where((s) => s['tipo_comida'] == 'Snack').length;
      final int faltanCenas =
          slotsFaltantes.where((s) => s['tipo_comida'] == 'Cena').length;

      // Calcular recetas no repetidas disponibles
      final int libresDesayuno = dispDesayunos
          .where((r) => !idsEnUso.contains(r['id_receta']))
          .length;
      final int libresComida =
          dispComidas.where((r) => !idsEnUso.contains(r['id_receta'])).length;
      final int libresCena =
          dispCenas.where((r) => !idsEnUso.contains(r['id_receta'])).length;
      final int libresSnack =
          dispSnacks.where((r) => !idsEnUso.contains(r['id_receta'])).length;

      // Detectar necesidad de recetas creativas autónomas para evitar repeticiones
      int genDesayuno = (faltanDesayunos - libresDesayuno).clamp(0, 2);
      int genComida = (faltanComidas - libresComida).clamp(0, 2);
      int genCena = (faltanCenas - libresCena).clamp(0, 2);
      int genSnack = (faltanSnacks - libresSnack).clamp(0, 2);

      // Si hay al menos 6 espacios a complementar, permitir al Chef IA crear 1 receta con libertad creativa
      int totalAGenerar = genDesayuno + genComida + genCena + genSnack;
      if (totalAGenerar == 0 && slotsFaltantes.length >= 6) {
        genComida = 1;
        totalAGenerar = 1;
      }

      int recetasNuevasCreadas = 0;

      if (totalAGenerar > 0) {
        try {
          final nuevas = await _generarRecetasAutonomasChefIA(
            objetivo: objetivoActivo,
            nDesayunos: genDesayuno,
            nComidas: genComida,
            nCenas: genCena,
            nSnacks: genSnack,
          );

          recetasNuevasCreadas = nuevas.length;

          for (var r in nuevas) {
            final tipo = r['tipo_comida']?.toString() ?? 'Comida';
            if (tipo == 'Desayuno') {
              dispDesayunos.add(r);
            } else if (tipo == 'Comida') {
              dispComidas.add(r);
            } else if (tipo == 'Cena') {
              dispCenas.add(r);
            } else if (tipo == 'Snack') {
              dispSnacks.add(r);
            }
          }
        } catch (e) {
          debugPrint('Chef IA generó error pero continuará con el catálogo: $e');
        }
      }

      // Fallback seguro si alguna lista quedó vacía
      if (dispDesayunos.isEmpty) {
        dispDesayunos = List.from(compatibles.isNotEmpty ? compatibles : todas);
      }
      if (dispComidas.isEmpty) {
        dispComidas = List.from(compatibles.isNotEmpty ? compatibles : todas);
      }
      if (dispCenas.isEmpty) {
        dispCenas = List.from(compatibles.isNotEmpty ? compatibles : todas);
      }
      if (dispSnacks.isEmpty) {
        dispSnacks = List.from(compatibles.isNotEmpty ? compatibles : todas);
      }

      dispDesayunos.shuffle();
      dispComidas.shuffle();
      dispCenas.shuffle();
      dispSnacks.shuffle();

      final Map<String, int> indicesPorTipo = {
        'Desayuno': 0,
        'Comida': 0,
        'Snack': 0,
        'Cena': 0,
      };

      final Map<String, List<Map<String, dynamic>>> listasPorTipo = {
        'Desayuno': dispDesayunos,
        'Comida': dispComidas,
        'Snack': dispSnacks,
        'Cena': dispCenas,
      };

      // Asignar a cada slot faltante respetando la rotación
      for (var slot in slotsFaltantes) {
        final fecha = slot['fecha']!;
        final tipo = slot['tipo_comida']!;
        final lista = listasPorTipo[tipo] ?? dispComidas;

        if (lista.isEmpty) continue;

        // Intentar seleccionar una receta que no se haya usado todavía
        Map<String, dynamic>? seleccion;
        for (var candidata in lista) {
          final id = candidata['id_receta'];
          if (id is int && !idsEnUso.contains(id)) {
            seleccion = candidata;
            idsEnUso.add(id);
            break;
          }
        }

        if (seleccion == null) {
          final idx = indicesPorTipo[tipo] ?? 0;
          seleccion = lista[idx % lista.length];
          indicesPorTipo[tipo] = idx + 1;
        }

        final int idElegido = seleccion['id_receta'] as int;

        await Supabase.instance.client.from('planeador').insert({
          'fecha': fecha,
          'tipo_comida': tipo,
          'id_receta': idElegido,
          'costo_personalizado': 0.0,
        });
      }

      await cargarPlan();

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            recetasNuevasCreadas > 0
                ? '🎉 ¡Semana complementada! Chef IA asignó ${slotsFaltantes.length} comidas ($recetasNuevasCreadas creadas con total libertad creativa y guardadas en Mis Recetas) 👨‍🍳✨'
                : '🎉 ¡Semana complementada con éxito! Chef IA asignó autónomamente ${slotsFaltantes.length} comidas a tus espacios vacíos 📅✨',
          ),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('Error en 1-click complementación del Chef IA: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error al complementar planeador: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => planeandoIA = false);
    }
  }

  /// 👨‍🍳 Genera recetas con plena autonomía y libertad creativa del Chef IA
  Future<List<Map<String, dynamic>>> _generarRecetasAutonomasChefIA({
    required String objetivo,
    required int nDesayunos,
    required int nComidas,
    required int nCenas,
    required int nSnacks,
  }) async {
    final totalAPedir = nDesayunos + nComidas + nCenas + nSnacks;
    if (totalAPedir == 0) return [];

    final peticiones = <String>[];
    if (nDesayunos > 0) peticiones.add('$nDesayunos para "Desayuno"');
    if (nComidas > 0) peticiones.add('$nComidas para "Comida"');
    if (nCenas > 0) peticiones.add('$nCenas para "Cena"');
    if (nSnacks > 0) peticiones.add('$nSnacks para "Snack"');

    final model = GenerativeModel(
      model: 'gemini-3.8-flash',
      apiKey: ConfigApi.geminiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.8, // Libertad creativa y diversidad culinaria
      ),
    );

    final estilosStr = PerfilesNutricionales.instruccionesPrompt(_estilos);
    final alergiasStr = _alergias.trim().isNotEmpty
        ? '- ALERGIAS Y RESTRICCIONES (ESTRICTAMENTE PROHIBIDO USAR): ${_alergias.trim()}'
        : '';

    final prompt = '''
    Eres el Chef Ejecutivo y Nutriólogo Principal de la app "Jitomate y Cebolla".
    Tienes PLENA AUTONOMÍA CULINARIA y TOTAL LIBERTAD CREATIVA para proponer recetas apetitosas, auténticas y balanceadas.
    El usuario necesita complementar su planeador semanal con platillos frescos e inspiradores.

    Crea EXACTAMENTE $totalAPedir recetas deliciosas distribuidas así:
    ${peticiones.map((p) => '- $p').join('\n')}

    Directrices clave:
    1. LIBERTAD CREATIVA: Explora sabores vibrantes (cocina mexicana moderna, mediterránea, bowls saludables, salsas caseras ligeras y texturas ricas).
    2. NUTRICIÓN: Alineado al objetivo calórico: $objetivo
    $estilosStr
    $alergiasStr

    REGLAS ESTRICTAS DE SUPERMERCADO Y MEDIDAS:
    - NO uses gramos (g) ni mililitros (ml) en los ingredientes.
    - Usa SIEMPRE fracciones de Kilo (kg), Litro (L), o "piezas", "paquete", "lata", "frasco".
    - Excluye agua de grifo o cubos de hielo.

    Responde ÚNICAMENTE con un arreglo JSON de $totalAPedir objetos con esta estructura exacta:
    [
      {
        "titulo": "Nombre creativo y antojable del platillo",
        "descripcion": "Descripción concisa resaltando el sabor",
        "tipo_comida": "Desayuno",
        "calorias": 420,
        "macros": "Proteína: 28g | Carbos: 35g | Grasas: 12g",
        "instrucciones": "1. Paso uno.\\n2. Paso dos.",
        "ingredientes": [
          { "nombre_estandar": "pechuga de pollo", "cantidad": 0.35, "unidad": "kg" }
        ]
      }
    ]
    ''';

    final response = await model.generateContent([Content.text(prompt)]);
    String jsonStr = (response.text ?? '[]')
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();

    final List<dynamic> recetasGeneradas = jsonDecode(jsonStr);
    final List<Map<String, dynamic>> recetasGuardadas = [];

    for (var r in recetasGeneradas) {
      final recetaMap = Map<String, dynamic>.from(r as Map);
      final guardada = await _guardarRecetaIAEnSupabase(recetaMap);
      if (guardada != null) {
        recetasGuardadas.add(guardada);
      }
    }

    return recetasGuardadas;
  }

  Future<void> _mostrarAvisoChefIACrearaRecetas(
    String objetivo, {
    required String razon,
  }) async {
    final estilosLegibles = _estilos.where((e) => e != 'Libre').toList();
    final String detalleFiltro = [
      'Meta: $objetivo',
      if (estilosLegibles.isNotEmpty) 'Dieta: ${estilosLegibles.join(', ')}',
      if (_alergias.trim().isNotEmpty) 'Sin: ${_alergias.trim()}',
    ].join(' • ');

    final seleccion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '¡El Chef IA las creará!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(razon, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'Perfil activo: $detalleFiltro',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '¿Quieres que el Chef IA invente automáticamente un menú completo '
              '(Desayuno, Comida, Cena y Snack) a tu medida y arme tu planeador semanal?',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancelar'),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'chef_manual'),
            child: const Text('Ir al Chef IA'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, 'generar_auto'),
            icon: const Icon(Icons.psychology, size: 18),
            label: const Text('¡Crear con IA! 🚀'),
          ),
        ],
      ),
    );

    if (seleccion == 'chef_manual' && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PantallaChef()),
      );
    } else if (seleccion == 'generar_auto' && mounted) {
      await _generarRecetasYCompletarPlan(objetivo);
    }
  }

  Future<void> _generarRecetasYCompletarPlan(String objetivo) async {
    setState(() => planeandoIA = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            '👨‍🍳 Chef IA creando recetas a tu medida para la semana... 🍳✨',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );

      final model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: ConfigApi.geminiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.7,
        ),
      );

      final estilosStr = PerfilesNutricionales.instruccionesPrompt(_estilos);
      final alergiasStr = _alergias.trim().isNotEmpty
          ? '- ALERGIAS Y RESTRICCIONES (ESTRICTAMENTE PROHIBIDO USAR): ${_alergias.trim()}'
          : '';

      final prompt = '''
      Eres el chef ejecutivo y nutriólogo de la app "Jitomate y Cebolla".
      Crea EXACTAMENTE 4 recetas deliciosas, realistas y balanceadas para completar una semana saludable:
      1. Una para "Desayuno"
      2. Una para "Comida"
      3. Una para "Cena"
      4. Una para "Snack"

      Parámetros obligatorios:
      - Objetivo calórico: $objetivo
      $estilosStr
      $alergiasStr

      REGLA DE UNIDADES DE MEDIDA:
      - NO uses gramos (g) ni mililitros (ml) en los ingredientes.
      - Usa SIEMPRE fracciones de Kilo (kg), Litro (L), o bien "piezas", "paquete", "lata", "frasco".

      REGLA CRÍTICA: Responde ÚNICAMENTE con un arreglo JSON de 4 objetos sin markdown ni explicaciones adicionales:
      [
        {
          "titulo": "Nombre atractivo del platillo",
          "descripcion": "Breve descripción",
          "tipo_comida": "Desayuno",
          "calorias": 400,
          "macros": "Proteína: 25g | Carbos: 30g | Grasas: 10g",
          "instrucciones": "1. Paso uno.\\n2. Paso dos.",
          "ingredientes": [
            { "nombre_estandar": "huevo", "cantidad": 2, "unidad": "piezas" }
          ]
        }
      ]
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      String jsonStr = (response.text ?? '[]')
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final List<dynamic> recetasGeneradas = jsonDecode(jsonStr);
      if (recetasGeneradas.isEmpty) {
        throw Exception('El Chef IA no pudo generar las recetas.');
      }

      for (var r in recetasGeneradas) {
        final recetaMap = Map<String, dynamic>.from(r as Map);
        await _guardarRecetaIAEnSupabase(recetaMap);
      }

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('🎉 ¡Chef IA creó tus recetas! Asignando a tu semana...'),
          backgroundColor: Colors.teal,
        ),
      );

      // Ahora que las recetas existen en Supabase, llenamos la semana
      await autocompletarSemanaConObjetivo(objetivo);
    } catch (e) {
      debugPrint('Error generando menú con Chef IA: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error del Chef IA: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => planeandoIA = false);
    }
  }

  /// 💾 Guarda una receta generada por la IA en Supabase de forma completa:
  /// en 'recetas' (con texto estructurado) y en 'receta_detalle' con 'ingredientes_genericos'.
  Future<Map<String, dynamic>?> _guardarRecetaIAEnSupabase(
    Map<String, dynamic> recetaMap,
  ) async {
    try {
      final List<dynamic> ings = recetaMap['ingredientes'] ?? [];
      final String porciones = recetaMap['porciones']?.toString() ?? '2';
      final String calorias = recetaMap['calorias']?.toString() ?? '450';
      final String macros = recetaMap['macros']?.toString() ?? '';
      final String tipo = recetaMap['tipo_comida']?.toString() ?? 'Comida';
      final String instrucciones = recetaMap['instrucciones']?.toString() ?? '';

      final sb = StringBuffer();
      sb.writeln('PORCIONES: $porciones');
      sb.writeln('CALORÍAS: $calorias kcal');
      if (macros.isNotEmpty) sb.writeln('MACROS: $macros');
      sb.writeln('TIPO: $tipo');
      sb.writeln('\n📝 INGREDIENTES:');
      for (var ing in ings) {
        final nom = ing['nombre_estandar']?.toString() ?? '';
        final cant = ing['cantidad']?.toString() ?? '1';
        final uni = ing['unidad']?.toString() ?? 'piezas';
        if (nom.isNotEmpty) sb.writeln('- $cant $uni $nom');
      }
      sb.writeln('\n🍳 INSTRUCCIONES:');
      sb.writeln(instrucciones);

      final String descCompleta = sb.toString().trim();

      final resReceta = await Supabase.instance.client
          .from('recetas')
          .insert({
            'titulo': recetaMap['titulo'],
            'descripcion': descCompleta.isNotEmpty
                ? descCompleta
                : recetaMap['descripcion'],
            'tipo_comida': recetaMap['tipo_comida'],
            'calorias': recetaMap['calorias'] is num
                ? (recetaMap['calorias'] as num).toInt()
                : int.tryParse(recetaMap['calorias']?.toString() ?? '450') ?? 450,
            'macros': recetaMap['macros']?.toString() ?? '',
            'instrucciones': recetaMap['instrucciones']?.toString() ?? '',
            'imagen_url':
                'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=500',
          })
          .select('id_receta, titulo, tipo_comida, descripcion, calorias')
          .single();

      final int idRecetaNueva = resReceta['id_receta'];

      for (var ing in ings) {
        try {
          final nombre =
              ing['nombre_estandar']?.toString().trim().toLowerCase() ?? '';
          if (nombre.isEmpty) continue;
          final cantidad = (ing['cantidad'] is num)
              ? (ing['cantidad'] as num).toDouble()
              : double.tryParse(ing['cantidad']?.toString() ?? '1.0') ?? 1.0;
          final unidad =
              ing['unidad']?.toString().trim().toLowerCase() ?? 'piezas';

          final match = await Supabase.instance.client
              .from('ingredientes_genericos')
              .select('id_ingrediente')
              .eq('nombre_estandar', nombre)
              .maybeSingle();

          int idIng;
          if (match != null) {
            idIng = match['id_ingrediente'];
          } else {
            final nuevo = await Supabase.instance.client
                .from('ingredientes_genericos')
                .insert({'nombre_estandar': nombre})
                .select('id_ingrediente')
                .single();
            idIng = nuevo['id_ingrediente'];
          }

          await Supabase.instance.client.from('receta_detalle').insert({
            'id_receta': idRecetaNueva,
            'id_ingrediente': idIng,
            'cantidad': cantidad,
            'unidad_medida': unidad,
          });
        } catch (e) {
          debugPrint('Ingrediente omitido por error: $e');
        }
      }

      return resReceta;
    } catch (e) {
      debugPrint('Error al guardar receta IA: $e');
      return null;
    }
  }

  /// 💬 Modal interactivo cuando se detecta escasez o repeticiones en el menú semanal
  Future<bool?> _mostrarDialogoFaltantesORepeticion({
    required String objetivo,
    required int desayunosFaltan,
    required int comidasFaltan,
    required int cenasFaltan,
    required int snacksFaltan,
    required int desayunosActuales,
    required int comidasActuales,
    required int cenasActuales,
    required int snacksActuales,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Chef IA: Evitar Repeticiones',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para armar tu semana completa (7 días) sin repetir platillos, detectamos que tus recetas guardadas son limitadas en algunas categorías:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  if (desayunosFaltan > 0)
                    _filaResumenFaltante(
                      '🍳 Desayunos',
                      desayunosActuales,
                      'Faltan $desayunosFaltan para 7 días',
                    ),
                  if (comidasFaltan > 0)
                    _filaResumenFaltante(
                      '🍲 Comidas',
                      comidasActuales,
                      'Faltan $comidasFaltan para 7 días',
                    ),
                  if (cenasFaltan > 0)
                    _filaResumenFaltante(
                      '🌙 Cenas',
                      cenasActuales,
                      'Faltan $cenasFaltan para 7 días',
                    ),
                  if (snacksFaltan > 0)
                    _filaResumenFaltante(
                      '🍎 Snacks',
                      snacksActuales,
                      'Faltan $snacksFaltan para 7 días',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '¿Deseas que el Chef IA cree automáticamente los platillos faltantes para tu objetivo ($objetivo) y los guarde en tu recetario?',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, repetir las que tengo', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.psychology, size: 18),
            label: const Text('¡Crear con Chef IA! 🚀'),
          ),
        ],
      ),
    );
  }

  Widget _filaResumenFaltante(String titulo, int actuales, String detalle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: actuales == 0 ? Colors.red.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$actuales en catálogo • $detalle',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: actuales == 0 ? Colors.red.shade900 : Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🤖 Genera platillos faltantes usando Gemini y los guarda en Supabase ('recetas' y 'receta_detalle')
  Future<List<Map<String, dynamic>>> _generarPlatillosFaltantes({
    required String objetivo,
    required int faltanDesayunos,
    required int faltanComidas,
    required int faltanCenas,
    required int faltanSnacks,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('👨‍🍳 Chef IA creando platillos exclusivos para evitar repeticiones... 🍳✨'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );

    final nDesayuno = faltanDesayunos.clamp(0, 3);
    final nComida = faltanComidas.clamp(0, 3);
    final nCena = faltanCenas.clamp(0, 3);
    final nSnack = faltanSnacks.clamp(0, 3);
    final totalAPedir = nDesayuno + nComida + nCena + nSnack;

    if (totalAPedir == 0) return [];

    final peticiones = <String>[];
    if (nDesayuno > 0) peticiones.add('$nDesayuno para "Desayuno"');
    if (nComida > 0) peticiones.add('$nComida para "Comida"');
    if (nCena > 0) peticiones.add('$nCena para "Cena"');
    if (nSnack > 0) peticiones.add('$nSnack para "Snack"');

    try {
      final model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: ConfigApi.geminiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.7,
        ),
      );

      final estilosStr = PerfilesNutricionales.instruccionesPrompt(_estilos);
      final alergiasStr = _alergias.trim().isNotEmpty
          ? '- ALERGIAS Y RESTRICCIONES (ESTRICTAMENTE PROHIBIDO USAR): ${_alergias.trim()}'
          : '';

      final prompt = '''
      Eres el chef ejecutivo y nutriólogo de la app "Jitomate y Cebolla".
      El usuario necesita platillos adicionales para su planeador semanal para evitar repetir comidas.
      Crea EXACTAMENTE $totalAPedir recetas deliciosas, variadas y balanceadas distribuidas así:
      ${peticiones.map((p) => '- $p').join('\n')}

      Parámetros obligatorios:
      - Objetivo calórico: $objetivo
      $estilosStr
      $alergiasStr

      REGLA DE UNIDADES DE MEDIDA:
      - NO uses gramos (g) ni mililitros (ml) en los ingredientes.
      - Usa SIEMPRE fracciones de Kilo (kg), Litro (L), o bien "piezas", "paquete", "lata", "frasco".

      REGLA CRÍTICA: Responde ÚNICAMENTE con un arreglo JSON de $totalAPedir objetos sin markdown:
      [
        {
          "titulo": "Nombre del platillo",
          "descripcion": "Breve descripción",
          "tipo_comida": "Desayuno",
          "calorias": 420,
          "macros": "Proteína: 25g | Carbos: 35g | Grasas: 12g",
          "instrucciones": "1. Paso uno.\\n2. Paso dos.",
          "ingredientes": [
            { "nombre_estandar": "huevo", "cantidad": 2, "unidad": "piezas" }
          ]
        }
      ]
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      String jsonStr = (response.text ?? '[]')
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final List<dynamic> recetasGeneradas = jsonDecode(jsonStr);
      final List<Map<String, dynamic>> recetasGuardadas = [];

      for (var r in recetasGeneradas) {
        final recetaMap = Map<String, dynamic>.from(r as Map);
        final guardada = await _guardarRecetaIAEnSupabase(recetaMap);
        if (guardada != null) {
          recetasGuardadas.add(guardada);
        }
      }

      return recetasGuardadas;
    } catch (e) {
      debugPrint('Error generando platillos faltantes con Chef IA: $e');
      return [];
    }
  }

  /// ✨ Sugiere un platillo individual alternativo con el Chef IA para una tarjeta del planeador
  Future<void> _sugerirPlatilloIndividualConIA({
    required int idPlaneador,
    required String fecha,
    required String tipoComida,
    required String tituloActual,
  }) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Chef IA: Sugerir Platillo ✨',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Deseas que el Chef IA invente una receta diferente para tu $tipoComida del día $fecha en lugar de "$tituloActual"?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                'Meta: $objetivoActivo • Dieta: ${_estilos.join(', ')}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'El nuevo platillo se asignará a este día y quedará guardado para siempre en "Mis Recetas".',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.psychology, size: 18),
            label: const Text('¡Crear y Reemplazar!'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => planeandoIA = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '👨‍🍳 Chef IA creando un platillo alternativo de $tipoComida... 🍳✨',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );

      final model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: ConfigApi.geminiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.7,
        ),
      );

      final estilosStr = PerfilesNutricionales.instruccionesPrompt(_estilos);
      final alergiasStr = _alergias.trim().isNotEmpty
          ? '- ALERGIAS Y RESTRICCIONES (ESTRICTAMENTE PROHIBIDO USAR): ${_alergias.trim()}'
          : '';

      final prompt = '''
      Eres el chef ejecutivo y nutriólogo de la app "Jitomate y Cebolla".
      Crea EXACTAMENTE 1 receta deliciosa, creativa y diferente a "$tituloActual" para la categoría "$tipoComida".

      Parámetros obligatorios:
      - Objetivo calórico: $objetivoActivo
      $estilosStr
      $alergiasStr

      REGLA DE UNIDADES DE MEDIDA:
      - NO uses gramos (g) ni mililitros (ml) en los ingredientes.
      - Usa SIEMPRE fracciones de Kilo (kg), Litro (L), o bien "piezas", "paquete", "lata", "frasco".

      REGLA CRÍTICA: Responde ÚNICAMENTE con un arreglo JSON de 1 objeto sin markdown:
      [
        {
          "titulo": "Nombre atractivo del platillo",
          "descripcion": "Breve descripción",
          "tipo_comida": "$tipoComida",
          "calorias": 450,
          "macros": "Proteína: 30g | Carbos: 40g | Grasas: 15g",
          "instrucciones": "1. Paso uno.\\n2. Paso dos.",
          "ingredientes": [
            { "nombre_estandar": "ingrediente", "cantidad": 1, "unidad": "piezas" }
          ]
        }
      ]
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      String jsonStr = (response.text ?? '[]')
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final List<dynamic> recetasGeneradas = jsonDecode(jsonStr);
      if (recetasGeneradas.isEmpty) {
        throw Exception('El Chef IA no pudo generar la receta.');
      }

      final recetaMap = Map<String, dynamic>.from(recetasGeneradas[0] as Map);
      final nuevaReceta = await _guardarRecetaIAEnSupabase(recetaMap);

      if (nuevaReceta == null) {
        throw Exception('No se pudo guardar la receta en la base de datos.');
      }

      await Supabase.instance.client
          .from('planeador')
          .update({'id_receta': nuevaReceta['id_receta']})
          .eq('id_planeador', idPlaneador);

      await cargarPlan();

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '¡Chef IA creó "${nuevaReceta['titulo']}" y la agregó al planeador y a Mis Recetas! 👨‍🍳✨',
          ),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('Error al sugerir platillo con Chef IA: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => planeandoIA = false);
    }
  }

  Future<void> borrarTodoElPlan() async {
    bool? confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Empezar de nuevo?'),
        content: const Text(
          'Esto borrará todo tu plan actual de la semana. ¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Borrar todo',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => cargando = true);
    try {
      final hoyStr = DateTime.now().toIso8601String().split('T')[0];
      await Supabase.instance.client
          .from('planeador')
          .delete()
          .gte('fecha', hoyStr);
      await cargarPlan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Plan reiniciado con éxito. ¡Listo para empezar de nuevo! 🧹',
            ),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al limpiar plan: $e');
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> eliminarDelPlan(int idPlaneador) async {
    setState(() => cargando = true);
    try {
      await Supabase.instance.client
          .from('planeador')
          .delete()
          .eq('id_planeador', idPlaneador);
      await cargarPlan();
    } catch (e) {
      debugPrint('Error al eliminar plato: $e');
      if (mounted) setState(() => cargando = false);
    }
  }

  void exportarTodaLaSemana() {
    if (miPlan.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay platillos en el planeador para exportar.'),
        ),
      );
      return;
    }

    for (var item in miPlan) {
      final receta = item['recetas'] ?? {};
      final tituloReceta = receta['titulo'] ?? 'Receta';
      final tipoComida = item['tipo_comida'] ?? 'Comida';
      final fechaStr = item['fecha'];

      DateTime fechaOriginal = DateTime.parse(fechaStr);
      int hora = 14;
      if (tipoComida == 'Desayuno') hora = 9;
      if (tipoComida == 'Cena') hora = 20;
      if (tipoComida == 'Snack') hora = 17;

      DateTime fechaInicio = DateTime(
        fechaOriginal.year,
        fechaOriginal.month,
        fechaOriginal.day,
        hora,
        0,
      );
      DateTime fechaFin = fechaInicio.add(const Duration(hours: 1));

      final Event event = Event(
        title: '🧑‍🍳 Cocinar: $tituloReceta',
        description: 'Receta de Jitomate y Cebolla.\nTipo: $tipoComida',
        location: 'Mi Cocina',
        startDate: fechaInicio,
        endDate: fechaFin,
        allDay: false,
      );

      Add2Calendar.addEvent2Cal(event);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Platillos listos para agregarse a tu calendario! 📅'),
        backgroundColor: Colors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final desayunos = miPlan
        .where((i) => i['tipo_comida'] == 'Desayuno')
        .toList();
    final comidas = miPlan.where((i) => i['tipo_comida'] == 'Comida').toList();
    final snacks = miPlan.where((i) => i['tipo_comida'] == 'Snack').toList();
    final cenas = miPlan.where((i) => i['tipo_comida'] == 'Cena').toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      drawer: const MenuLateral(rutaActual: 'planeador'),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú principal',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Mi Planeador 📅',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.kitchen),
            tooltip: 'Mi Despensa',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PantallaDespensa()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Chef IA',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PantallaChef()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            tooltip: 'Lista de Compras',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PantallaCarrito()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                // 🍏 Tarjeta Inteligente de Objetivo Nutricional y Cumplimiento
                _construirTarjetaCumplimiento(),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: planeandoIA
                        ? null
                        : complementarPlaneadorConChefIA1Click,
                    icon: planeandoIA
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(
                      planeandoIA
                          ? 'Chef IA planeando tu semana...'
                          : 'Complementar con Chef IA (1 Clic) 👨‍🍳✨',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: planeandoIA ? null : _mostrarSelectorDeObjetivo,
                        icon: const Icon(
                          Icons.tune,
                          size: 16,
                          color: Colors.deepOrange,
                        ),
                        label: const Text(
                          'Personalizar',
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.deepOrange.shade300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: exportarTodaLaSemana,
                        icon: const Icon(
                          Icons.calendar_month,
                          size: 16,
                          color: Colors.teal,
                        ),
                        label: const Text(
                          'Exportar',
                          style: TextStyle(
                            color: Colors.teal,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.teal),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: borrarTodoElPlan,
                        icon: const Icon(
                          Icons.delete_sweep,
                          size: 16,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Reiniciar',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 💡 Banner de Recordatorio de Despensa
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.kitchen_outlined,
                        color: Colors.amber.shade800,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Consejo de Ahorro 💡',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Revisa tu despensa antes de autollenar tu semana para evitar comprar duplicados.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cargando
                ? Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : miPlan.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu_rounded,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tu planeador está listo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Toca "Complementar con Chef IA (1 Clic)" para que el chef sugiera tus comidas de la semana con total creatividad y balance.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(15),
                    children: [
                      if (desayunos.isNotEmpty) ...[
                        _crearSeccionCategoria(
                          '🍳 Desayunos',
                          desayunos,
                          Colors.orange,
                        ),
                        const SizedBox(height: 15),
                      ],
                      if (comidas.isNotEmpty) ...[
                        _crearSeccionCategoria(
                          '🍲 Comidas',
                          comidas,
                          Colors.green,
                        ),
                        const SizedBox(height: 15),
                      ],
                      if (snacks.isNotEmpty) ...[
                        _crearSeccionCategoria(
                          '🍎 Snacks',
                          snacks,
                          Colors.redAccent,
                        ),
                        const SizedBox(height: 15),
                      ],
                      if (cenas.isNotEmpty) ...[
                        _crearSeccionCategoria(
                          '🌙 Cenas',
                          cenas,
                          Colors.indigo,
                        ),
                        const SizedBox(height: 15),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _crearSeccionCategoria(
    String titulo,
    List<dynamic> items,
    Color colorTema,
  ) {
    final totalCalCategoria = items.fold<int>(0, (acc, item) {
      final receta = item['recetas'] as Map<String, dynamic>? ?? {};
      final c = int.tryParse(receta['calorias']?.toString() ?? '0') ?? 0;
      return acc + c;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bookmark, color: colorTema, size: 20),
            const SizedBox(width: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorTema,
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                '${items.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: colorTema.withValues(alpha: 0.15),
              visualDensity: VisualDensity.compact,
            ),
            if (totalCalCategoria > 0) ...[
              const Spacer(),
              Text(
                '~$totalCalCategoria kcal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          final receta = item['recetas'] ?? {};
          final tituloReceta = receta['titulo'] ?? 'Receta eliminada';
          final imagen = receta['imagen_url'];
          final int calorias =
              int.tryParse(receta['calorias']?.toString() ?? '0') ?? 0;

          final textoRecetaMagico =
              receta['descripcion'] ??
              receta['instrucciones'] ??
              'Parece que esta receta no tiene instrucciones detalladas. ¡Usa tu creatividad de Chef!';
          final idReceta = item['id_receta'] ?? 0;

          final bool esCompatible = PerfilesNutricionales.recetaCompatible(
            "$tituloReceta $textoRecetaMagico",
            _estilos,
            alergias: _alergias,
          );

          final bool fueCocinada = (idReceta > 0 && _idsCocinadas.contains(idReceta)) ||
              _titulosCocinados.contains(tituloReceta.toLowerCase().trim());

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(
                color: fueCocinada
                    ? Colors.green.shade400
                    : (!esCompatible
                        ? Colors.red.shade300
                        : colorTema.withValues(alpha: 0.3)),
                width: 1.5,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PantallaDetalleReceta(
                      idReceta: idReceta,
                      titulo: tituloReceta,
                      descripcion: textoRecetaMagico,
                      imagenUrl: imagen,
                    ),
                  ),
                );
                await cargarPlan();
              },
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: imagen != null && imagen.toString().isNotEmpty
                    ? Image.network(
                        imagen,
                        width: 55,
                        height: 55,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 55,
                        height: 55,
                        color: colorTema.withValues(alpha: 0.1),
                        child: Icon(Icons.restaurant, color: colorTema),
                      ),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        item['fecha'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colorTema,
                          fontSize: 13,
                        ),
                      ),
                      if (fueCocinada) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.soup_kitchen,
                                size: 10,
                                color: Colors.white,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Preparada',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (calorias > 0)
                    Text(
                      '🔥 $calorias kcal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
                      ),
                    ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tituloReceta,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fueCocinada)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green.shade300,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.soup_kitchen,
                              size: 13,
                              color: Colors.green.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '¡Aviso: Ya preparaste este platillo! 👨‍🍳✅',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!esCompatible)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 13,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'No se ajusta a tu estilo (${_estilos.where((e) => e != PerfilesNutricionales.libre).take(1).join()})',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: Colors.orange,
                      size: 22,
                    ),
                    tooltip: 'Chef IA: Sugerir platillo diferente (guardar en mis recetas)',
                    onPressed: () => _sugerirPlatilloIndividualConIA(
                      idPlaneador: item['id_planeador'],
                      fecha: item['fecha'],
                      tipoComida: item['tipo_comida']?.toString() ?? 'Comida',
                      tituloActual: tituloReceta,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      fueCocinada
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: fueCocinada
                          ? Colors.green.shade600
                          : Colors.grey.shade400,
                      size: 24,
                    ),
                    tooltip: fueCocinada
                        ? '¡Ya preparada! Toca para volver a registrar o descontar'
                        : 'Marcar como cocinada y descontar despensa',
                    onPressed: () => _marcarRecetaPlaneadorComoCocinada(
                      idPlaneador: item['id_planeador'],
                      idReceta: idReceta,
                      titulo: tituloReceta,
                      textoReceta: textoRecetaMagico,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.grey,
                      size: 22,
                    ),
                    tooltip: 'Eliminar del planeador',
                    onPressed: () => eliminarDelPlan(item['id_planeador']),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
