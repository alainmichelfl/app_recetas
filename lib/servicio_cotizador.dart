import 'package:supabase_flutter/supabase_flutter.dart';
import 'conversor_unidades.dart';

class ItemCotizadoDetalle {
  final int? idItem;
  final String nombre;
  final String cantidadTexto;
  final double precioUnitario;
  final double subtotal;
  final bool comprado;

  const ItemCotizadoDetalle({
    this.idItem,
    required this.nombre,
    required this.cantidadTexto,
    required this.precioUnitario,
    required this.subtotal,
    this.comprado = false,
  });
}

class CotizacionSupermercado {
  final int idSupermercado;
  final String nombreSupermercado;
  final double total;
  final int itemsCotizados;
  final int itemsTotales;
  final List<ItemCotizadoDetalle> desglose;

  CotizacionSupermercado({
    required this.idSupermercado,
    required this.nombreSupermercado,
    required this.total,
    required this.itemsCotizados,
    required this.itemsTotales,
    this.desglose = const [],
  });
}

class ServicioCotizador {
  static double extraerNumeroSeguro(dynamic valor, {double valorPorDefecto = 1.0}) {
    if (valor == null) return valorPorDefecto;
    if (valor is num) return valor.toDouble();
    if (valor is String) {
      final match = RegExp(r'[0-9]+(\.[0-9]+)?').firstMatch(valor);
      if (match != null) {
        return double.tryParse(match.group(0)!) ?? valorPorDefecto;
      }
    }
    return valorPorDefecto;
  }

  static Future<List<CotizacionSupermercado>> cotizarListaCompleta(
    SupabaseClient supabase,
  ) async {
    final resLista = await supabase
        .from('lista_compras')
        .select('id, nombre, cantidad, comprado');

    final List itemsTodos = resLista as List;
    if (itemsTodos.isEmpty) {
      return [];
    }

    final int pendientesCount =
        itemsTodos.where((it) => it['comprado'] != true).length;

    final supers = await supabase
        .from('supermercados')
        .select('id_supermercado, nombre');
    final ingredientes = await supabase
        .from('ingredientes_genericos')
        .select('id_ingrediente, nombre_estandar');
    final precios = await supabase
        .from('precios_supermercado')
        .select('id_ingrediente, id_supermercado, precio');

    final Map<int, double> totalesPorSuper = {};
    final Map<int, int> conteoPorSuper = {};
    final Map<int, List<ItemCotizadoDetalle>> desglosesPorSuper = {};

    for (var s in (supers as List)) {
      final int id = s['id_supermercado'] as int;
      totalesPorSuper[id] = 0.0;
      conteoPorSuper[id] = 0;
      desglosesPorSuper[id] = [];
    }

    for (var item in itemsTodos) {
      final String nombreItem = (item['nombre'] ?? '')
          .toString()
          .toLowerCase()
          .trim();

      final double cantidadLimpia = extraerNumeroSeguro(item['cantidad']);

      Map<String, dynamic> matchIngrediente = (ingredientes as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((ing) {
            final estandar = (ing['nombre_estandar'] ?? '').toString();
            return ConversorUnidades.nombresCoinciden(nombreItem, estandar);
          }, orElse: () => <String, dynamic>{});

      // Búsqueda de rescate si no hubo coincidencia exacta
      if (matchIngrediente.isEmpty) {
        final cleanNom = ConversorUnidades.sinAcentos(nombreItem);
        if (cleanNom.contains('choc') || cleanNom.contains('chisp') || cleanNom.contains('cacao')) {
          matchIngrediente = (ingredientes as List)
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (ing) {
                  final est = ConversorUnidades.sinAcentos(
                    (ing['nombre_estandar'] ?? '').toString().toLowerCase(),
                  );
                  return est.contains('chispas') || est.contains('chocolate');
                },
                orElse: () => <String, dynamic>{},
              );
        } else if (cleanNom.contains('huevo') || cleanNom.contains('blanquillo')) {
          matchIngrediente = (ingredientes as List)
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (ing) {
                  final est = ConversorUnidades.sinAcentos(
                    (ing['nombre_estandar'] ?? '').toString().toLowerCase(),
                  );
                  return est == 'huevo';
                },
                orElse: () => <String, dynamic>{},
              );
        }
      }

      for (var s in supers) {
        final int idSuper = s['id_supermercado'];
        double costoUnitario = 0.0;

        if (matchIngrediente.isNotEmpty) {
          final int idIng = matchIngrediente['id_ingrediente'];
          final precioRow = (precios as List)
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (p) =>
                    p['id_ingrediente'] == idIng &&
                    p['id_supermercado'] == idSuper,
                orElse: () => <String, dynamic>{},
              );

          if (precioRow.isNotEmpty) {
            costoUnitario = extraerNumeroSeguro(
              precioRow['precio'],
              valorPorDefecto: 0.0,
            );
          }
        }

        // Si no hay precio en DB para este súper o ingrediente, estimar referencia de anaquel
        if (costoUnitario <= 0.0) {
          final String cat = ConversorUnidades.determinarCategoria(nombreItem);
          double baseRef = 28.0;
          if (cat == 'Carnes y Aves') {
            baseRef = 85.0;
          } else if (cat == 'Pescados y Mariscos') {
            baseRef = 95.0;
          } else if (cat == 'Lácteos y Huevos') {
            baseRef = 38.0;
          } else if (cat == 'Frutas y Verduras') {
            baseRef = 24.0;
          } else if (cat == 'Panadería y Tortillería') {
            baseRef = 22.0;
          } else if (cat == 'Especias y Condimentos') {
            baseRef = 16.0;
          }
          final double factorSuper = idSuper == 4 ? 0.85 : (idSuper == 3 ? 1.08 : (idSuper == 2 ? 0.95 : 1.0));
          costoUnitario = (baseRef * factorSuper * 100).round() / 100.0;
        }

        // Ajuste proporcional para frutas/verduras por kilo y cartones de huevo cuando la unidad es "pza"
        final String u = ConversorUnidades.extraerUnidadSegura(
          item['cantidad'],
          nombreItem,
        );
        double multiplicador = cantidadLimpia;
        if (ConversorUnidades.sinAcentos(nombreItem).contains('huevo')) {
          // De 1 a 18 huevos o hasta 1 cartón, siempre es exactamente 1 cartera / cartón
          if (cantidadLimpia <= 18.0) {
            multiplicador = 1.0;
          } else {
            multiplicador = (cantidadLimpia / 18.0).ceilToDouble().clamp(1.0, 3.0);
          }
        } else if (u == 'pza') {
          if (ConversorUnidades.esFrutaOVerduraPorKilo(nombreItem)) {
            multiplicador = cantidadLimpia *
                ConversorUnidades.pesoAproximadoKilosPorPieza(nombreItem);
          }
        }

        final double subtotal =
            (costoUnitario * multiplicador * 100).round() / 100.0;
        if (item['comprado'] != true) {
          totalesPorSuper[idSuper] =
              (totalesPorSuper[idSuper] ?? 0.0) + subtotal;
          conteoPorSuper[idSuper] = (conteoPorSuper[idSuper] ?? 0) + 1;
        }
        desglosesPorSuper[idSuper]?.add(
          ItemCotizadoDetalle(
            idItem: item['id'] as int?,
            nombre: (item['nombre'] ?? '').toString(),
            cantidadTexto: (item['cantidad'] ?? '1').toString(),
            precioUnitario: costoUnitario,
            subtotal: subtotal,
            comprado: item['comprado'] == true,
          ),
        );
      }
    }

    final List<CotizacionSupermercado> resultados = (supers as List)
        .map<CotizacionSupermercado>((s) {
          final id = s['id_supermercado'] as int;
          return CotizacionSupermercado(
            idSupermercado: id,
            nombreSupermercado: s['nombre'] ?? 'Supermercado',
            total: ((totalesPorSuper[id] ?? 0.0) * 100).round() / 100.0,
            itemsCotizados: conteoPorSuper[id] ?? 0,
            itemsTotales: pendientesCount,
            desglose: desglosesPorSuper[id] ?? [],
          );
        })
        .toList();

    resultados.sort((a, b) => a.total.compareTo(b.total));
    return resultados;
  }

  /// Deduce el ID del supermercado a partir del nombre o texto del ticket
  static int deducirIdSupermercado(String tienda) {
    final tLower = tienda.toLowerCase();
    if (tLower.contains('soriana') || tLower.contains('city club')) return 2;
    if (tLower.contains('comer') ||
        tLower.contains('fresko') ||
        tLower.contains('sumesa') ||
        tLower.contains('city market')) {
      return 3;
    }
    if (tLower.contains('abasto') ||
        tLower.contains('mercado') ||
        tLower.contains('tianguis')) {
      return 4;
    }
    return 1; // Default: Walmart / Bodega Aurrera
  }

  /// Calcula el nuevo precio ponderado (40% histórico + 60% nuevo ticket)
  static double calcularPrecioPonderado(double precioExistente, double precioNuevo) {
    if (precioExistente <= 0) return double.parse(precioNuevo.toStringAsFixed(2));
    if (precioNuevo <= 0) return double.parse(precioExistente.toStringAsFixed(2));
    final ponderado = (precioExistente * 0.4) + (precioNuevo * 0.6);
    return double.parse(ponderado.toStringAsFixed(2));
  }

  /// Retroalimenta y calibra la base de datos de precios en Supabase a partir de
  /// los artículos y precios reales leídos en un ticket de supermercado (Crowdsourcing P22).
  static Future<int> reportarPreciosCrowdsourcing({
    required SupabaseClient supabase,
    required String tienda,
    required List<dynamic> articulos,
  }) async {
    try {
      final int idSupermercado = deducirIdSupermercado(tienda);

      final ingredientesRes = await supabase
          .from('ingredientes_genericos')
          .select('id_ingrediente, nombre_estandar');
      final List ingredientes = (ingredientesRes as List);

      int actualizados = 0;
      for (final art in articulos) {
        final nombreArt = (art['nombre'] ?? '').toString().trim();
        final double precio = extraerNumeroSeguro(art['precio']);
        final double cantidad = extraerNumeroSeguro(art['cantidad']);
        if (nombreArt.isEmpty || precio <= 0) continue;

        // Si la cantidad es > 1, calcular precio unitario estimado
        final double precioUnitario =
            (cantidad > 1.0) ? (precio / cantidad) : precio;

        final match = ingredientes.cast<Map<String, dynamic>>().firstWhere(
          (ing) {
            final est = (ing['nombre_estandar'] ?? '').toString();
            return ConversorUnidades.nombresCoinciden(nombreArt, est);
          },
          orElse: () => <String, dynamic>{},
        );

        if (match.isNotEmpty) {
          final int idIng = match['id_ingrediente'];

          final existe = await supabase
              .from('precios_supermercado')
              .select('precio')
              .eq('id_ingrediente', idIng)
              .eq('id_supermercado', idSupermercado)
              .maybeSingle();

          double precioFinal = precioUnitario;
          if (existe != null && existe['precio'] != null) {
            final double precioExistente =
                extraerNumeroSeguro(existe['precio']);
            precioFinal = calcularPrecioPonderado(precioExistente, precioUnitario);
          } else {
            precioFinal = double.parse(precioFinal.toStringAsFixed(2));
          }

          if (existe != null) {
            await supabase
                .from('precios_supermercado')
                .update({'precio': precioFinal})
                .eq('id_ingrediente', idIng)
                .eq('id_supermercado', idSupermercado);
          } else {
            await supabase.from('precios_supermercado').insert({
              'id_ingrediente': idIng,
              'id_supermercado': idSupermercado,
              'precio': precioFinal,
            });
          }
          actualizados++;
        }
      }
      return actualizados;
    } catch (_) {
      // Manejo silencioso en caso de error de red o permisos para no interrumpir el flujo del usuario
      return 0;
    }
  }
}
