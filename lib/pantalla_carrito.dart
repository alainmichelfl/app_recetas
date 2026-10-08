import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'conversor_unidades.dart';
import 'pantalla_cotizador.dart';
import 'pantalla_finanzas.dart';
import 'servicio_preferencias.dart';
import 'menu_lateral.dart';

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

class PantallaCarrito extends StatefulWidget {
  const PantallaCarrito({super.key});

  @override
  State<PantallaCarrito> createState() => _PantallaCarritoState();
}

class _PantallaCarritoState extends State<PantallaCarrito> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _estaCargando = false;
  PreferenciasUsuario? _preferencias;
  CotizacionSupermercado? _mejorCotizacion;
  Map<int, double> _preciosEstimadosPorItem = {};
  String _nombreSuperDestacado = 'Walmart';
  bool _esSuperFavoritoActivo = false;
  List<Map<String, dynamic>> _ultimosItems = [];
  int _ultimoTotalItems = -1;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
    _consolidarYRecalcular();
  }

  Future<void> _consolidarYRecalcular() async {
    try {
      await ConversorUnidades.consolidarCarritoEnBaseDeDatos(supabase);
    } catch (e) {
      debugPrint('Error al consolidar carrito: $e');
    }
    _recalcularPresupuesto();
  }

  Future<void> _cargarPreferencias() async {
    final prefs = await ServicioPreferencias.obtenerPreferencias();
    if (mounted) {
      setState(() => _preferencias = prefs);
      _recalcularPresupuesto();
    }
  }

  Future<void> _recalcularPresupuesto() async {
    try {
      final cotizaciones = await cotizarListaCompleta();
      if (mounted && cotizaciones.isNotEmpty) {
        final String favPref =
            (_preferencias?.superFavorito ?? '').trim().toLowerCase();

        CotizacionSupermercado cotizacionElegida;
        bool esFavorito = false;

        final matchFavorito = cotizaciones.where((c) {
          final n = c.nombreSupermercado.toLowerCase();
          return favPref.isNotEmpty &&
              favPref != 'ninguno' &&
              (n.contains(favPref) || favPref.contains(n));
        }).toList();

        if (matchFavorito.isNotEmpty) {
          cotizacionElegida = matchFavorito.first;
          esFavorito = true;
        } else {
          cotizacionElegida = cotizaciones.firstWhere(
            (c) => c.total > 0,
            orElse: () => cotizaciones.first,
          );
        }

        final Map<int, double> preciosMap = {};
        for (var d in cotizacionElegida.desglose) {
          if (d.idItem != null) {
            preciosMap[d.idItem!] = d.subtotal;
          }
        }

        setState(() {
          _mejorCotizacion = cotizacionElegida;
          _preciosEstimadosPorItem = preciosMap;
          _nombreSuperDestacado = cotizacionElegida.nombreSupermercado;
          _esSuperFavoritoActivo = esFavorito;
        });
      }
    } catch (e) {
      debugPrint('Error al recalcular presupuesto: $e');
    }
  }

  void _verificarYRecalcular(int totalItems) {
    if (totalItems != _ultimoTotalItems) {
      _ultimoTotalItems = totalItems;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _recalcularPresupuesto();
      });
    }
  }

  void _abrirAjustePresupuesto() {
    final ctrl = TextEditingController(
      text: (_preferencias?.presupuestoSemanal ?? 1500.0).toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Presupuesto semanal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajusta tu presupuesto para compras semanales:',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                suffixText: 'MXN',
                labelText: 'Monto semanal',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nuevo = double.tryParse(ctrl.text.trim());
              if (nuevo != null && nuevo > 0) {
                final prefsActuales =
                    _preferencias ?? const PreferenciasUsuario();
                final actualizadas = PreferenciasUsuario(
                  objetivo: prefsActuales.objetivo,
                  estilos: prefsActuales.estilos,
                  alergias: prefsActuales.alergias,
                  superFavorito: prefsActuales.superFavorito,
                  porciones: prefsActuales.porciones,
                  presupuestoSemanal: nuevo,
                  notificaciones: prefsActuales.notificaciones,
                );
                try {
                  await ServicioPreferencias.guardarPreferencias(actualizadas);
                  if (mounted) {
                    setState(() => _preferencias = actualizadas);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Error al guardar presupuesto: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _compartirListaPorWhatsApp(
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu lista de compras está vacía.')),
      );
      return;
    }

    final pendientes = items.where((i) => !(i['comprado'] ?? false)).toList();
    final comprados = items.where((i) => i['comprado'] ?? false).toList();

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('🛒 *Lista de Compras - Jitomate y Cebolla*');
    buffer.writeln(
      '📅 ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
    );
    buffer.writeln('');

    if (pendientes.isNotEmpty) {
      buffer.writeln('*Por comprar (${pendientes.length}):*');
      for (var p in pendientes) {
        final cant = p['cantidad'] != null ? ' (${p['cantidad']})' : '';
        buffer.writeln('  ▫️ ${p['nombre']}$cant');
      }
      buffer.writeln('');
    }

    if (comprados.isNotEmpty) {
      buffer.writeln('*Ya en el carrito (${comprados.length}):*');
      for (var c in comprados) {
        buffer.writeln('  ✅ ~${c['nombre']}~');
      }
      buffer.writeln('');
    }

    if (_mejorCotizacion != null && _mejorCotizacion!.total > 0) {
      buffer.writeln(
        '💰 *Total estimado:* \$${_mejorCotizacion!.total.toStringAsFixed(2)} MXN (${_mejorCotizacion!.nombreSupermercado})',
      );
    }

    buffer.writeln('\n_Generado con Jitomate y Cebolla_ 🍅🧅');

    final texto = buffer.toString();
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}');

    try {
      final bool lanzado = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!lanzado) {
        await SharePlus.instance.share(ShareParams(text: texto));
      }
    } catch (_) {
      try {
        await SharePlus.instance.share(ShareParams(text: texto));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo compartir la lista: $e')),
          );
        }
      }
    }
  }

  Widget _construirBarraPresupuesto(List<Map<String, dynamic>> items) {
    final double presupuesto = _preferencias?.presupuestoSemanal ?? 1500.0;
    final double estimado = _mejorCotizacion?.total ?? 0.0;
    final double restante = presupuesto - estimado;
    final double porcentaje = presupuesto > 0
        ? (estimado / presupuesto).clamp(0.0, 1.0)
        : 0.0;
    final bool excedido = restante < 0;
    final int pendientes =
        items.where((i) => !(i['comprado'] ?? false)).length;
    final int comprados =
        items.where((i) => i['comprado'] ?? false).length;

    Color barraColor = Colors.green;
    if (porcentaje > 0.7 && porcentaje <= 0.9) {
      barraColor = Colors.orange;
    } else if (porcentaje > 0.9 || excedido) {
      barraColor = Colors.red.shade700;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: excedido ? Colors.red.shade300 : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (excedido ? Colors.red : Colors.orange)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      excedido
                          ? Icons.warning_amber_rounded
                          : Icons.account_balance_wallet_outlined,
                      color:
                          excedido ? Colors.red.shade700 : Colors.deepOrange,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Presupuesto Semanal',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: excedido ? Colors.red.shade900 : Colors.black87,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _abrirAjustePresupuesto,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${presupuesto.toStringAsFixed(0)} MXN',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: Colors.deepOrange,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barraColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: mostrarModalCotizaciones,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _mejorCotizacion != null && _mejorCotizacion!.total > 0
                                ? 'Estimado: \$${estimado.toStringAsFixed(2)} (${_mejorCotizacion!.nombreSupermercado})'
                                : (items.isEmpty
                                    ? 'Lista vacía (\$0.00)'
                                    : 'Estimado: Calculando...'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.touch_app_outlined,
                            size: 13,
                            color: Colors.deepOrange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$pendientes pendientes · $comprados en carrito',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: excedido ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        excedido ? Colors.red.shade300 : Colors.green.shade200,
                  ),
                ),
                child: Text(
                  excedido
                      ? 'Excedido: +\$${(-restante).toStringAsFixed(2)}'
                      : 'Disponible: \$${restante.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: excedido
                        ? Colors.red.shade900
                        : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: mostrarModalCotizaciones,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.deepOrange.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront, size: 16, color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Comparar precios en Walmart, Soriana y La Comer',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepOrange.shade900,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: Colors.deepOrange),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // FUNCIÓN SALVAVIDAS: Extrae números puros incluso si vienen con letras (ej. "3pzas" -> 3.0)
  double _extraerNumeroSeguro(dynamic valor, {double valorPorDefecto = 1.0}) {
    if (valor == null) {
      return valorPorDefecto;
    }
    if (valor is num) {
      return valor.toDouble();
    }
    if (valor is String) {
      final match = RegExp(r'[0-9]+(\.[0-9]+)?').firstMatch(valor);
      if (match != null) {
        return double.tryParse(match.group(0)!) ?? valorPorDefecto;
      }
    }
    return valorPorDefecto;
  }

  // 🗑️ FUNCIÓN PARA BORRAR TODA LA LISTA DESDE EL APPBAR
  Future<void> _confirmarBorrarListaCompleta() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar lista de compras'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar todos los elementos de tu lista?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Borrar todo',
              style: TextStyle(
                color: Colors.red.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await supabase.from('lista_compras').delete().neq('id', -1);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lista de compras vaciada por completo 🗑️'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      } catch (e) {
        debugPrint('Error al vaciar la lista: $e');
      }
    }
  }

  // 1. AUTOLLENADO: Cruza Planeador vs Despensa (alcance semanal inteligente)
  Future<void> autollenarListaDesdePlaneador() async {
    setState(() => _estaCargando = true);
    try {
      final String hoy = DateTime.now().toIso8601String().split('T').first;
      final String finSemana = DateTime.now()
          .add(const Duration(days: 7))
          .toIso8601String()
          .split('T')
          .first;

      var planeadorData = await supabase
          .from('planeador')
          .select('id_receta, fecha')
          .gte('fecha', hoy)
          .lte('fecha', finSemana);

      // Si no hay recetas registradas en los próximos 7 días, buscar fechas planeadas a futuro o las más recientes
      if ((planeadorData as List).isEmpty) {
        planeadorData = await supabase
            .from('planeador')
            .select('id_receta, fecha')
            .gte('fecha', hoy)
            .limit(28);
      }
      if ((planeadorData as List).isEmpty) {
        planeadorData = await supabase
            .from('planeador')
            .select('id_receta, fecha')
            .order('fecha', ascending: false)
            .limit(28);
      }

      final List planeador = planeadorData as List;

      if (planeador.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay recetas programadas en el planeador.'),
            ),
          );
        }
        setState(() => _estaCargando = false);
        return;
      }

      final despensaData = await supabase
          .from('despensa_usuario')
          .select('nombre, cantidad');
      final List despensa = despensaData as List;

      final List<int> idsRecetas = planeador
          .where((p) => p['id_receta'] != null)
          .map<int>((p) => p['id_receta'] as int)
          .toList();

      if (idsRecetas.isEmpty) {
        setState(() => _estaCargando = false);
        return;
      }

      final recetasData = await supabase
          .from('recetas')
          .select(
            'id_receta, descripcion, receta_detalle(cantidad, unidad_medida, ingredientes_genericos(nombre_estandar))',
          )
          .inFilter('id_receta', idsRecetas);

      Map<String, ItemSupermercado> requerimientos = {};

      void acumular(ItemSupermercado item) {
        if (ConversorUnidades.esAgua(item.nombre) || item.cantidad <= 0) return;
        final String canNombre = ConversorUnidades.canonicalizarNombre(item.nombre);
        final key = ConversorUnidades.sinAcentos(canNombre).trim();
        if (requerimientos.containsKey(key)) {
          final existente = requerimientos[key]!;
          // Especias, aceites o frascos: no duplicar para la misma semana (1 frasco basta)
          if (existente.unidad == 'frasco' || existente.unidad == 'botella') {
            return;
          }
          // Hierbas frescas: máximo 2 manojos por semana
          if (existente.unidad == 'manojo') {
            final nuevoTotal = (existente.cantidad + 1.0).clamp(1.0, 2.0);
            requerimientos[key] = ItemSupermercado(
              nombre: canNombre,
              cantidad: nuevoTotal,
              unidad: 'manojo',
              textoCantidad:
                  '${nuevoTotal.toInt()} manojo${nuevoTotal > 1 ? 's' : ''}',
            );
            return;
          }
          // Tostadas, tortillas, pan: 1 paquete suele bastar para la semana (máx 2 si son muchas porciones)
          if (existente.unidad == 'paquete' && ConversorUnidades.sinAcentos(existente.nombre).contains(RegExp(r'(tostada|tortilla|pan|totopo)'))) {
            final double nuevoTotal = (existente.cantidad + 0.25).clamp(1.0, 2.0);
            final int paquetesInt = nuevoTotal.ceil();
            requerimientos[key] = ItemSupermercado(
              nombre: canNombre,
              cantidad: paquetesInt.toDouble(),
              unidad: 'paquete',
              textoCantidad: '$paquetesInt paquete${paquetesInt > 1 ? 's' : ''}',
            );
            return;
          }
          // Avena, granos, pastas, frutos secos, chía, semillas en paquete: 1 a 2 paquetes por semana
          if (existente.unidad == 'paquete' && ConversorUnidades.sinAcentos(existente.nombre).contains(RegExp(r'(avena|harina|arroz|frijol|lenteja|quinoa|amaranto|almendra|nuez|cacahuate|arandano|chia|linaza|ajonjoli|semilla|maiz palomero)'))) {
            final double nuevoTotal = (existente.cantidad + 0.25).clamp(1.0, 2.0);
            final int paquetesInt = nuevoTotal.ceil();
            requerimientos[key] = ItemSupermercado(
              nombre: canNombre,
              cantidad: paquetesInt.toDouble(),
              unidad: 'paquete',
              textoCantidad: '$paquetesInt paquete${paquetesInt > 1 ? 's' : ''}',
            );
            return;
          }
          // Unidades sumables (kg, L, pza, cabeza, lata, paquete)
          final nuevaCantidad =
              ((existente.cantidad + item.cantidad) * 100).round() / 100.0;
          String texto = '$nuevaCantidad ${existente.unidad}';
          if (existente.unidad == 'pza' ||
              existente.unidad == 'cabeza' ||
              existente.unidad == 'lata' ||
              existente.unidad == 'paquete') {
            final int cantInt = nuevaCantidad.ceil();
            texto =
                '$cantInt ${existente.unidad}${cantInt > 1 ? 's' : ''}';
          } else if (existente.unidad == 'kg' || existente.unidad == 'L') {
            texto = nuevaCantidad == nuevaCantidad.toInt()
                ? '${nuevaCantidad.toInt()} ${existente.unidad}'
                : '${nuevaCantidad.toStringAsFixed(2)} ${existente.unidad}';
          }
          requerimientos[key] = ItemSupermercado(
            nombre: canNombre,
            cantidad: nuevaCantidad,
            unidad: existente.unidad,
            textoCantidad: texto,
          );
        } else {
          requerimientos[key] = ItemSupermercado(
            nombre: canNombre,
            cantidad: item.cantidad,
            unidad: item.unidad,
            textoCantidad: item.textoCantidad,
          );
        }
      }

      for (var r in (recetasData as List)) {
        final detalles = r['receta_detalle'] as List?;
        if (detalles != null && detalles.isNotEmpty) {
          for (var d in detalles) {
            final gen = d['ingredientes_genericos'];
            final String nombreIng = gen != null
                ? (gen['nombre_estandar'] ?? '')
                : '';
            final double cant = _extraerNumeroSeguro(
              d['cantidad'],
              valorPorDefecto: 1.0,
            );
            final String unidad = (d['unidad_medida'] ?? '').toString();

            if (nombreIng.isNotEmpty) {
              final normalizado = ConversorUnidades.normalizarParaSupermercado(
                nombreIng,
                cant,
                unidad,
              );
              acumular(normalizado);
            }
          }
        } else {
          final String desc = r['descripcion'] ?? '';
          final lineas = desc.split('\n');
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
            if ((enIngredientes &&
                    (l.startsWith('-') ||
                        l.startsWith('*') ||
                        l.startsWith('•'))) ||
                (!enIngredientes && l.startsWith('-') && l.length > 3)) {
              final normalizado = ConversorUnidades.parsearLineaIngrediente(l);
              acumular(normalizado);
            }
          }
        }
      }

      // Descontar existencias de la despensa
      for (var d in despensa) {
        final String nombreDisp = (d['nombre'] ?? '')
            .toString()
            .trim();
        final double cantDisp = _extraerNumeroSeguro(
          d['cantidad'],
          valorPorDefecto: 0.0,
        );

        for (var reqKey in requerimientos.keys.toList()) {
          final reqItem = requerimientos[reqKey]!;
          if (ConversorUnidades.nombresCoinciden(reqItem.nombre, nombreDisp)) {
            if (reqItem.unidad == 'frasco' ||
                reqItem.unidad == 'botella' ||
                reqItem.unidad == 'manojo') {
              // Si ya tiene en despensa, se asume cubierto
              requerimientos.remove(reqKey);
            } else {
              final double restante = reqItem.cantidad - cantDisp;
              if (restante <= 0.05) {
                requerimientos.remove(reqKey);
              } else {
                final double rLimpio =
                    (restante * 100).round() / 100.0;
                String texto = '$rLimpio ${reqItem.unidad}';
                if (reqItem.unidad == 'pza' ||
                    reqItem.unidad == 'cabeza' ||
                    reqItem.unidad == 'lata' ||
                    reqItem.unidad == 'paquete') {
                  final int cantInt = rLimpio.ceil();
                  texto =
                      '$cantInt ${reqItem.unidad}${cantInt > 1 ? 's' : ''}';
                } else if (reqItem.unidad == 'kg' || reqItem.unidad == 'L') {
                  texto = rLimpio == rLimpio.toInt()
                      ? '${rLimpio.toInt()} ${reqItem.unidad}'
                      : '${rLimpio.toStringAsFixed(2)} ${reqItem.unidad}';
                }
                requerimientos[reqKey] = ItemSupermercado(
                  nombre: reqItem.nombre,
                  cantidad: rLimpio,
                  unidad: reqItem.unidad,
                  textoCantidad: texto,
                );
              }
            }
          }
        }
      }

      List<Map<String, dynamic>> itemsParaInsertar = [];
      requerimientos.forEach((_, item) {
        itemsParaInsertar.add({
          'nombre': item.nombre,
          'cantidad': item.textoCantidad,
          'comprado': false,
        });
      });

      if (itemsParaInsertar.isNotEmpty) {
        final existentesData = await supabase
            .from('lista_compras')
            .select('id')
            .eq('comprado', false);
        final List existentes = existentesData as List;

        bool reemplazar = false;
        if (existentes.isNotEmpty && mounted) {
          final bool? decision = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Actualizar lista semanal'),
              content: Text(
                'Actualmente tienes ${existentes.length} artículos en tu lista.\n\n'
                '¿Deseas reemplazar los productos anteriores con los de esta semana planeada, o sumarlos a la lista existente?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Sumar a la lista'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Reemplazar por esta semana'),
                ),
              ],
            ),
          );
          if (decision == null) {
            setState(() => _estaCargando = false);
            return;
          }
          reemplazar = decision;
        }

        if (reemplazar) {
          await supabase.from('lista_compras').delete().eq('comprado', false);
        }

        await supabase.from('lista_compras').insert(itemsParaInsertar);
        await ConversorUnidades.consolidarCarritoEnBaseDeDatos(supabase);
        _recalcularPresupuesto();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Se agregaron ${itemsParaInsertar.length} insumos a la lista.',
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tu despensa ya cubre todo lo planeado.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al autollenar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _estaCargando = false);
      }
    }
  }

  // 2. TRANSFERENCIA A DESPENSA
  Future<void> transferirCompradosADespensa() async {
    setState(() => _estaCargando = true);
    try {
      final compradosData = await supabase
          .from('lista_compras')
          .select('id, nombre, cantidad')
          .eq('comprado', true);

      final List comprados = compradosData as List;
      if (comprados.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay productos marcados como comprados.'),
            ),
          );
        }
        setState(() => _estaCargando = false);
        return;
      }

      final String hoy = DateTime.now().toIso8601String().split('T').first;
      List<Map<String, dynamic>> articulosDespensa = [];
      List<int> idsEliminar = [];

      for (var item in comprados) {
        final double cantidadLimpia = _extraerNumeroSeguro(item['cantidad']);

        articulosDespensa.add({
          'nombre': item['nombre'],
          'cantidad': cantidadLimpia,
          'precio': 0.0,
          'fecha_ingreso': hoy,
        });
        idsEliminar.add(item['id'] as int);
      }

      await supabase.from('despensa_usuario').insert(articulosDespensa);
      await supabase.from('lista_compras').delete().inFilter('id', idsEliminar);
      _recalcularPresupuesto();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${articulosDespensa.length} artículos transferidos a tu despensa.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al transferir: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _estaCargando = false);
      }
    }
  }

  // 3. COTIZADOR SEGURO
  Future<List<CotizacionSupermercado>> cotizarListaCompleta() async {
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

    Map<int, double> totalesPorSuper = {};
    Map<int, int> conteoPorSuper = {};
    Map<int, List<ItemCotizadoDetalle>> desglosesPorSuper = {};

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

      final double cantidadLimpia = _extraerNumeroSeguro(item['cantidad']);

      final matchIngrediente = (ingredientes as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((ing) {
            final estandar = (ing['nombre_estandar'] ?? '')
                .toString();
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
            final double costoUnitario = _extraerNumeroSeguro(
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

    List<CotizacionSupermercado> resultados = (supers as List)
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

  void mostrarModalCotizaciones() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.deepOrange),
      ),
    );

    try {
      final cotizaciones = await cotizarListaCompleta();

      if (mounted) {
        Navigator.pop(context);
      }

      if (!mounted) {
        return;
      }

      if (cotizaciones.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No hay productos pendientes o registrados para cotizar.',
            ),
          ),
        );
        return;
      }

      if (mounted) {
        setState(() {
          _mejorCotizacion = cotizaciones.firstWhere(
            (c) => c.total > 0,
            orElse: () => cotizaciones.first,
          );
        });
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          final double presSemanal = _preferencias?.presupuestoSemanal ?? 1500.0;
          return DraggableScrollableSheet(
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (_, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: ListView(
                  controller: scrollController,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.deepOrange.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.storefront,
                                color: Colors.deepOrange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Cotización Consolidada',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    Text(
                      'Comparativa en vivo para ${cotizaciones.first.itemsTotales} productos de tu lista.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tu presupuesto semanal:',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
                          ),
                          Text(
                            '\$${presSemanal.toStringAsFixed(0)} MXN',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...cotizaciones.map((c) {
                      final bool esMejorOpcion =
                          c == cotizaciones.first && c.total > 0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: esMejorOpcion ? 2 : 1,
                        color: esMejorOpcion
                            ? Colors.green.shade50.withValues(alpha: 0.6)
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: esMejorOpcion
                                ? Colors.green
                                : Colors.grey.shade300,
                            width: esMejorOpcion ? 1.5 : 1.0,
                          ),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (esMejorOpcion
                                        ? Colors.green
                                        : Colors.deepOrange)
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shopping_basket_outlined,
                                color: esMejorOpcion
                                    ? Colors.green.shade700
                                    : Colors.deepOrange,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  c.nombreSupermercado,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (esMejorOpcion) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Mejor precio',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '${c.itemsCotizados} de ${c.itemsTotales} productos cotizados',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${c.total.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: esMejorOpcion
                                        ? Colors.green.shade800
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Ver desglose ▼',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            children: [
                              if (c.desglose.isNotEmpty) ...[
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: c.desglose.length,
                                    separatorBuilder: (_, _) => Divider(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                    itemBuilder: (_, i) {
                                      final d = c.desglose[i];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '${d.nombre} (${d.cantidadTexto})',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '\$${d.subtotal.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    'Usar \$${c.total.toStringAsFixed(2)} en Finanzas',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: esMejorOpcion
                                        ? Colors.green.shade700
                                        : Colors.deepOrange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PantallaFinanzas(
                                          presupuestoSuperExterno: c.total,
                                          supermercadoElegido: c.nombreSupermercado,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.tune, color: Colors.deepPurple, size: 18),
                        label: const Text(
                          'Abrir en Cotizador Interactivo detallado',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.deepPurple),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PantallaCotizador(
                                idReceta: -1,
                                titulo: '🛒 Mi Lista de Compras Actual',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cotizar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> alternarComprado(int id, bool estadoActual) async {
    await supabase
        .from('lista_compras')
        .update({'comprado': !estadoActual})
        .eq('id', id);
    _recalcularPresupuesto();
  }

  Future<void> eliminarItem(int id) async {
    await supabase.from('lista_compras').delete().eq('id', id);
    _recalcularPresupuesto();
  }

  void mostrarModalAgregarManual() {
    final nombreCtrl = TextEditingController();
    final cantCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar a la lista'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Ingrediente o producto',
              ),
            ),
            TextField(
              controller: cantCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final rawNombre = nombreCtrl.text.trim();
              if (rawNombre.isNotEmpty) {
                if (ConversorUnidades.esAgua(rawNombre)) {
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'El agua para cocinar no es necesaria en tu lista de compras.',
                        ),
                      ),
                    );
                  }
                  return;
                }
                final rawCant = cantCtrl.text.trim();
                final parsed = ConversorUnidades.parsearLineaIngrediente(
                  rawCant.isEmpty ? rawNombre : '$rawCant $rawNombre',
                );
                await ConversorUnidades.agregarOActualizarItemEnCarrito(
                  supabase,
                  parsed,
                );
                _recalcularPresupuesto();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MenuLateral(rutaActual: 'carrito'),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú principal',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Lista de Compras'),
        actions: [
          // 🛒 Cotizar en Supermercados
          IconButton(
            tooltip: 'Cotizar en supermercados',
            icon: const Icon(Icons.storefront, color: Colors.white),
            onPressed: _estaCargando ? null : mostrarModalCotizaciones,
          ),
          // 💬 Compartir por WhatsApp
          IconButton(
            tooltip: 'Compartir por WhatsApp',
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _compartirListaPorWhatsApp(_ultimosItems),
          ),
          // 🗑️ Botón para vaciar toda la lista
          IconButton(
            tooltip: 'Vaciar toda la lista',
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: _confirmarBorrarListaCompleta,
          ),
          // Botón para autollenar
          IconButton(
            tooltip: 'Autollenar desde Planeador',
            icon: const Icon(Icons.sync_alt, color: Colors.white),
            onPressed: _estaCargando ? null : autollenarListaDesdePlaneador,
          ),
          // Botón para transferir a despensa
          IconButton(
            tooltip: 'Mover comprados a Despensa',
            icon: const Icon(Icons.inventory_2_outlined, color: Colors.white),
            onPressed: _estaCargando ? null : transferirCompradosADespensa,
          ),
        ],
      ),
      body: _estaCargando
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('lista_compras')
                  .stream(primaryKey: ['id'])
                  .order('comprado', ascending: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                _ultimosItems = items;
                _verificarYRecalcular(items.length);

                return Column(
                  children: [
                    _construirBarraPresupuesto(items),
                    if (items.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.shopping_cart_outlined,
                                size: 70,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Tu lista de compras está vacía.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.sync),
                                label: const Text('Autollenar con Planeador'),
                                onPressed: autollenarListaDesdePlaneador,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90, top: 4),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final bool comprado = item['comprado'] ?? false;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Checkbox(
                                  value: comprado,
                                  activeColor: Colors.deepOrange,
                                  onChanged: (_) =>
                                      alternarComprado(item['id'], comprado),
                                ),
                                title: Text(
                                  item['nombre'] ?? '',
                                  style: TextStyle(
                                    decoration: comprado
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: comprado
                                        ? Colors.grey
                                        : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      'Cantidad: ${item['cantidad'] ?? 1}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: comprado
                                            ? Colors.grey
                                            : Colors.black54,
                                      ),
                                    ),
                                    _construirBadgePrecioItem(
                                      item['id'] as int?,
                                      comprado,
                                    ),
                                  ],
                                ),
                                // 🗑️ Botón individual para borrar elemento por elemento
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Eliminar ingrediente',
                                  onPressed: () => eliminarItem(item['id']),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(bottom: 12, top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -3),
              blurRadius: 6,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Insumo'),
                  onPressed: mostrarModalAgregarManual,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.storefront),
                  label: const Text('Cotizar Súper'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _estaCargando ? null : mostrarModalCotizaciones,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirBadgePrecioItem(int? idItem, bool comprado) {
    final double? precio =
        idItem != null ? _preciosEstimadosPorItem[idItem] : null;
    final String superNombre = _nombreSuperDestacado;
    final bool esFavorito = _esSuperFavoritoActivo;

    if (precio == null || precio <= 0) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Cotización pendiente',
          style: TextStyle(
            fontSize: 10.5,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final Color badgeBg =
        esFavorito ? const Color(0xFFFFF9C4) : const Color(0xFFF1F8E9);
    final Color borderColor =
        esFavorito ? const Color(0xFFFFCA28) : const Color(0xFFAED581);
    final Color textColor =
        esFavorito ? const Color(0xFFE65100) : const Color(0xFF33691E);
    final Color precioColor =
        esFavorito ? const Color(0xFFBF360C) : const Color(0xFF1B5E20);

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: comprado ? Colors.grey.shade100 : badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: comprado ? Colors.grey.shade300 : borderColor,
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            esFavorito ? Icons.star_rounded : Icons.storefront_outlined,
            size: 14,
            color: comprado
                ? Colors.grey
                : (esFavorito
                    ? Colors.amber.shade900
                    : Colors.green.shade700),
          ),
          const SizedBox(width: 4),
          Text(
            esFavorito ? '⭐ $superNombre (Favorito): ' : '$superNombre: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: esFavorito ? FontWeight.bold : FontWeight.w600,
              color: comprado ? Colors.grey : textColor,
            ),
          ),
          Text(
            '\$${precio.toStringAsFixed(2)} MXN',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: comprado ? Colors.grey : precioColor,
            ),
          ),
        ],
      ),
    );
  }
}
