import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'conversor_unidades.dart';

class ResultadoMatchDespensa {
  final int totalPrincipales;
  final int disponibles;
  final List<String> faltantes;
  final double porcentaje;

  const ResultadoMatchDespensa({
    required this.totalPrincipales,
    required this.disponibles,
    required this.faltantes,
    required this.porcentaje,
  });

  bool get listoParaCocinar => faltantes.isEmpty && totalPrincipales > 0;
  bool get faltaUno => faltantes.length == 1;
}

class ServicioDespensa {
  ServicioDespensa._();

  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Descuenta de `despensa_usuario` los ingredientes usados al cocinar una receta.
  /// Toma en cuenta el [multiplicador] de porciones.
  /// Devuelve la lista de nombres de ingredientes que se descontaron con éxito.
  static Future<List<String>> descontarIngredientesDeReceta({
    int? idReceta,
    required String descripcionReceta,
    double multiplicador = 1.0,
  }) async {
    final List<String> descontados = [];

    try {
      // 1. Obtener los ingredientes requeridos (prioriza base relacional si existe)
      List<Map<String, dynamic>> ingredientesReceta = [];

      if (idReceta != null && idReceta > 0) {
        final detalles = await _supabase
            .from('receta_detalle')
            .select(
              'cantidad, unidad_medida, ingredientes_genericos(nombre_estandar)',
            )
            .eq('id_receta', idReceta);

        for (var d in (detalles as List)) {
          final gen = d['ingredientes_genericos'];
          final String nombre = gen != null
              ? (gen['nombre_estandar'] ?? '').toString()
              : '';
          final double cant = (d['cantidad'] is num)
              ? (d['cantidad'] as num).toDouble()
              : 1.0;
          final String unidad = (d['unidad_medida'] ?? '').toString();

          if (nombre.isNotEmpty) {
            final norm = ConversorUnidades.normalizarParaSupermercado(
              nombre,
              cant * multiplicador,
              unidad,
            );
            ingredientesReceta.add({
              'nombre': norm.nombre.toLowerCase().trim(),
              'cantidad': norm.cantidad,
              'esEspecia': ConversorUnidades.esEspecia(norm.nombre),
            });
          }
        }
      }

      // Si no había en la tabla relacional, extraemos del texto de la receta
      if (ingredientesReceta.isEmpty) {
        ingredientesReceta = _extraerIngredientesDeTexto(
          descripcionReceta,
          multiplicador,
        );
      }

      if (ingredientesReceta.isEmpty) return descontados;

      // 2. Obtener la despensa actual del usuario
      final despensaData = await _supabase
          .from('despensa_usuario')
          .select('id_item, nombre, cantidad');

      final List despensa = despensaData as List;
      if (despensa.isEmpty) return descontados;

      // 3. Cruzar y descontar
      for (var ing in ingredientesReceta) {
        final String nombreIng = ing['nombre'].toString();
        final double cantRequerida = (ing['cantidad'] is num)
            ? (ing['cantidad'] as num).toDouble()
            : 1.0;
        final bool esEspecia = ing['esEspecia'] == true;

        // Buscar coincidencia en despensa (nombre coincide de forma robusta)
        dynamic itemMatch;
        for (var item in despensa) {
          final String nombreDesp =
              (item['nombre'] ?? '').toString();
          if (ConversorUnidades.nombresCoinciden(nombreDesp, nombreIng)) {
            itemMatch = item;
            break;
          }
        }

        if (itemMatch != null) {
          final idItem = itemMatch['id_item'];

          // Si es especia/condimento/aceite, no agotamos el frasco entero por una pizca
          if (esEspecia) {
            descontados.add(itemMatch['nombre'].toString());
            continue;
          }

          final double cantActual = (itemMatch['cantidad'] is num)
              ? (itemMatch['cantidad'] as num).toDouble()
              : 1.0;

          final double restante = cantActual - cantRequerida;

          if (restante <= 0.05) {
            // Se consumió todo: eliminar de la despensa
            await _supabase
                .from('despensa_usuario')
                .delete()
                .eq('id_item', idItem);
          } else {
            // Descontar la porción usada
            await _supabase
                .from('despensa_usuario')
                .update({
                  'cantidad': double.parse(restante.toStringAsFixed(2)),
                })
                .eq('id_item', idItem);
          }

          descontados.add(itemMatch['nombre'].toString());
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error al descontar ingredientes de despensa: $e');
    }

    return descontados;
  }

  /// Parsea líneas con guiones o viñetas en la sección de ingredientes
  static List<Map<String, dynamic>> _extraerIngredientesDeTexto(
    String texto,
    double multiplicador,
  ) {
    final List<Map<String, dynamic>> resultado = [];
    final lineas = texto.split('\n');
    bool enIngredientes = false;

    for (var linea in lineas) {
      final l = linea.trim();
      if (l.toUpperCase().contains('INGREDIENTES:')) {
        enIngredientes = true;
        continue;
      }
      if (enIngredientes && l.toUpperCase().contains('INSTRUCCIONES:')) {
        break;
      }

      if (enIngredientes &&
          (l.startsWith('-') || l.startsWith('*') || l.startsWith('•'))) {
        final norm = ConversorUnidades.parsearLineaIngrediente(l);
        if (norm.nombre.isNotEmpty) {
          resultado.add({
            'nombre': norm.nombre.toLowerCase().trim(),
            'cantidad': norm.cantidad * multiplicador,
            'esEspecia': ConversorUnidades.esEspecia(norm.nombre),
          });
        }
      }
    }

    return resultado;
  }

  /// Analiza qué tan disponible está una receta con base en la despensa actual del usuario.
  static ResultadoMatchDespensa evaluarMatchReceta({
    required String descripcionReceta,
    required List<String> nombresEnDespensa,
  }) {
    final ingReceta = _extraerIngredientesDeTexto(descripcionReceta, 1.0);
    // Filtrar ingredientes principales (excluyendo agua y especias comunes de alacena)
    final principales = ingReceta.where((i) {
      final String n = (i['nombre'] ?? '').toString();
      if (ConversorUnidades.esAgua(n)) return false;
      if (ConversorUnidades.esEspecia(n)) return false;
      return true;
    }).toList();

    if (principales.isEmpty) {
      return const ResultadoMatchDespensa(
        totalPrincipales: 0,
        disponibles: 0,
        faltantes: [],
        porcentaje: 0.0,
      );
    }

    int disp = 0;
    final List<String> faltantes = [];

    for (var ing in principales) {
      final String nombreIng = ing['nombre'].toString();
      bool encontrado = false;
      for (var enDesp in nombresEnDespensa) {
        if (ConversorUnidades.nombresCoinciden(enDesp, nombreIng)) {
          encontrado = true;
          break;
        }
      }
      if (encontrado) {
        disp++;
      } else {
        faltantes.add(nombreIng);
      }
    }

    final double pct = principales.isNotEmpty ? (disp / principales.length) : 0.0;
    return ResultadoMatchDespensa(
      totalPrincipales: principales.length,
      disponibles: disp,
      faltantes: faltantes,
      porcentaje: pct,
    );
  }
}
