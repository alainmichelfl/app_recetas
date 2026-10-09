import 'package:supabase_flutter/supabase_flutter.dart';
import 'conversor_unidades.dart';

class ItemCotizadoDetalle {
  final int? idItem;
  final String nombre;
  final String cantidadTexto;
  final double precioUnitario;
  final double subtotal;

  const ItemCotizadoDetalle({
    this.idItem,
    required this.nombre,
    required this.cantidadTexto,
    required this.precioUnitario,
    required this.subtotal,
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

      final matchIngrediente = (ingredientes as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((ing) {
            final estandar = (ing['nombre_estandar'] ?? '').toString();
            return ConversorUnidades.nombresCoinciden(nombreItem, estandar);
          }, orElse: () => <String, dynamic>{});

      if (matchIngrediente.isNotEmpty) {
        final int idIng = matchIngrediente['id_ingrediente'];
        for (var s in supers) {
          final int idSuper = s['id_supermercado'];

          final precioRow = (precios as List)
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (p) =>
                    p['id_ingrediente'] == idIng &&
                    p['id_supermercado'] == idSuper,
                orElse: () => <String, dynamic>{},
              );

          if (precioRow.isNotEmpty) {
            final double costoUnitario = extraerNumeroSeguro(
              precioRow['precio'],
              valorPorDefecto: 0.0,
            );

            // Ajuste proporcional para frutas/verduras por kilo y cartones de huevo cuando la unidad es "pza"
            final String u = ConversorUnidades.extraerUnidadSegura(
              item['cantidad'],
              nombreItem,
            );
            double multiplicador = cantidadLimpia;
            if (u == 'pza') {
              if (ConversorUnidades.sinAcentos(nombreItem).contains('huevo')) {
                multiplicador = (cantidadLimpia / 16.0).clamp(0.5, 5.0);
              } else if (ConversorUnidades.esFrutaOVerduraPorKilo(nombreItem)) {
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
              ),
            );
          }
        }
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
}
