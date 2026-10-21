import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'conversor_unidades.dart';

enum NivelFrescura {
  fresco,
  consumirPronto,
  porVencer,
}

class EstadoFrescuraItem {
  final NivelFrescura nivel;
  final int diasIngresado;
  final int vidaUtilEstimadaDias;
  final String etiqueta;

  const EstadoFrescuraItem({
    required this.nivel,
    required this.diasIngresado,
    required this.vidaUtilEstimadaDias,
    required this.etiqueta,
  });

  bool get esAlerta => nivel != NivelFrescura.fresco;
  bool get esUrgente => nivel == NivelFrescura.porVencer;
}

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

  /// Estima la vida útil realista en días para anaquel o refrigerador
  /// según la naturaleza y categoría del alimento en el contexto de México.
  static int estimarVidaUtilDias(String nombre) {
    final n = nombre.toLowerCase().trim();

    // 1. Pescados y mariscos frescos (1-2 días)
    if (n.contains('pescado') || n.contains('camar') || n.contains('salmon') ||
        n.contains('salmón') || n.contains('atún fresco') || n.contains('marisco') ||
        n.contains('filete')) {
      return 2;
    }

    // 2. Carnes y aves frescas (3-4 días)
    if (n.contains('pollo') || n.contains('pechuga') || n.contains('carne molida') ||
        n.contains('bistec') || n.contains('costilla') || n.contains('carne de res') ||
        n.contains('cerdo') || n.contains('chuleta') || n.contains('milanesa') ||
        n.contains('arrachera') || RegExp(r'\bres\b').hasMatch(n)) {
      return 4;
    }

    // 3. Lácteos abiertos y embutidos (5-7 días)
    if (n.contains('leche') || n.contains('yogurt') || n.contains('crema') ||
        n.contains('queso panela') || n.contains('queso oaxaca') || n.contains('jamón') ||
        n.contains('jamon') || n.contains('salchicha') || n.contains('tocino')) {
      return 6;
    }

    // 4. Frutas y vegetales tiernos / delicados (4-6 días)
    if (n.contains('aguacate') || n.contains('fresa') || n.contains('espinaca') ||
        n.contains('lechuga') || n.contains('cilantro') || n.contains('perejil') ||
        n.contains('plátano') || n.contains('platano') || n.contains('jitomate') ||
        n.contains('tomate') || n.contains('champiñ') || n.contains('hongo') ||
        n.contains('frambuesa') || n.contains('mora') || n.contains('uva')) {
      return 5;
    }

    // 5. Verduras duras y raíces (14-21 días)
    if (n.contains('papa') || n.contains('cebolla') || n.contains('zanahoria') ||
        n.contains('ajo') || n.contains('calabaza') || n.contains('chayote') ||
        n.contains('manzana') || n.contains('naranja') || n.contains('limón') ||
        n.contains('limon')) {
      return 15;
    }

    // 6. Huevo fresco (21-28 días)
    if (n.contains('huevo')) {
      return 21;
    }

    // 7. Abarrotes, cereales, semillas, aceites, especias, congelados, enlatados (60 - 180 días)
    if (n.contains('arroz') || n.contains('frijol') || n.contains('lenteja') ||
        n.contains('pasta') || n.contains('avena') || n.contains('harina') ||
        n.contains('azúcar') || n.contains('azucar') || n.contains('sal') ||
        n.contains('aceite') || n.contains('atún en lata') || n.contains('atun') ||
        n.contains('lata') || n.contains('canela') || n.contains('orégano') ||
        n.contains('oregano') || n.contains('pimienta') || n.contains('miel') ||
        n.contains('congelad') || n.contains('vainilla')) {
      return 90;
    }

    // Por defecto para productos varios: 10 días
    return 10;
  }

  /// Evalúa el estado de frescura y semáforo de un artículo de la despensa
  static EstadoFrescuraItem evaluarFrescuraItem(Map<String, dynamic> item) {
    final String nombre = (item['nombre'] ?? '').toString();
    final fStr = item['fecha_ingreso']?.toString();
    final dt = fStr != null ? DateTime.tryParse(fStr) : null;
    final int dias = dt != null ? DateTime.now().difference(dt).inDays : 0;
    final int vidaUtil = estimarVidaUtilDias(nombre);

    if (dias >= vidaUtil) {
      return EstadoFrescuraItem(
        nivel: NivelFrescura.porVencer,
        diasIngresado: dias,
        vidaUtilEstimadaDias: vidaUtil,
        etiqueta: '¡Por vencer! (${dias}d) 🔴',
      );
    } else if (dias >= (vidaUtil * 0.6).round()) {
      return EstadoFrescuraItem(
        nivel: NivelFrescura.consumirPronto,
        diasIngresado: dias,
        vidaUtilEstimadaDias: vidaUtil,
        etiqueta: 'Consumir pronto (${dias}d) 🟡',
      );
    } else {
      return EstadoFrescuraItem(
        nivel: NivelFrescura.fresco,
        diasIngresado: dias,
        vidaUtilEstimadaDias: vidaUtil,
        etiqueta: 'Fresco 🟢',
      );
    }
  }
}
