import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'conversor_unidades.dart';
import 'pantalla_cotizador.dart';
import 'pantalla_finanzas.dart';
import 'servicio_preferencias.dart';
import 'servicio_hogar.dart';
import 'servicio_carrito_offline.dart';
import 'menu_lateral.dart';

export 'servicio_cotizador.dart';
import 'servicio_cotizador.dart';

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
  List<Map<String, dynamic>> _cacheOffline = [];
  int _ultimoTotalItems = -1;
  final Set<String> _categoriasColapsadas = {};
  bool _modoSuperFocus = false;
  String _filtroFocus = 'todos'; // 'todos', 'pendientes', 'comprados'

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
    _consolidarYRecalcular();
    _inicializarResilienciaOffline();
  }

  Future<void> _inicializarResilienciaOffline() async {
    final cache = await ServicioCarritoOffline.obtenerCacheLocal();
    if (mounted && cache.isNotEmpty && _ultimosItems.isEmpty) {
      setState(() => _cacheOffline = cache);
    }
    await ServicioCarritoOffline.obtenerConteoPendientes();
    final sincronizados = await ServicioCarritoOffline.sincronizarPendientes(supabase);
    if (sincronizados > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('☁️ $sincronizados cambios del súper sincronizados con la nube.'),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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

  static const List<Map<String, dynamic>> _ordenCategorias = [
    {'nombre': 'Frutas y Verduras', 'icono': Icons.eco_outlined, 'color': Colors.green, 'pasillo': 'Pasillo 1 (Entrada)'},
    {'nombre': 'Panadería y Tortillería', 'icono': Icons.bakery_dining_outlined, 'color': Colors.orange, 'pasillo': 'Pasillo 2 (Horno)'},
    {'nombre': 'Abarrotes y Alacena', 'icono': Icons.shelves, 'color': Colors.indigo, 'pasillo': 'Pasillo 3 (Alacena)'},
    {'nombre': 'Especias y Condimentos', 'icono': Icons.grain_outlined, 'color': Colors.brown, 'pasillo': 'Pasillo 3 (Condimentos)'},
    {'nombre': 'Carnes y Aves', 'icono': Icons.kebab_dining_outlined, 'color': Colors.red, 'pasillo': 'Pasillo 4 (Carnicería)'},
    {'nombre': 'Pescados y Mariscos', 'icono': Icons.set_meal_outlined, 'color': Colors.teal, 'pasillo': 'Pasillo 4 (Pescadería)'},
    {'nombre': 'Lácteos y Huevos', 'icono': Icons.egg_outlined, 'color': Colors.amber, 'pasillo': 'Pasillo 5 (Refrigerados)'},
    {'nombre': 'Congelados', 'icono': Icons.ac_unit_outlined, 'color': Colors.cyan, 'pasillo': 'Pasillo 6 (Congeladores)'},
    {'nombre': 'Otros', 'icono': Icons.shopping_basket_outlined, 'color': Colors.blueGrey, 'pasillo': 'Pasillo General'},
  ];

  String _generarTextoTicketSuper(List<Map<String, dynamic>> items) {
    final pendientes = items.where((i) => !(i['comprado'] ?? false)).toList();
    final comprados = items.where((i) => i['comprado'] ?? false).toList();

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('🧾 *TICKET DE SÚPER INTELIGENTE*');
    buffer.writeln('🍅🧅 *Jitomate y Cebolla*');
    final now = DateTime.now();
    buffer.writeln('📅 ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}');
    if (_nombreSuperDestacado.isNotEmpty) {
      buffer.writeln('🏪 Supermercado: $_nombreSuperDestacado');
    }
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');

    if (pendientes.isNotEmpty) {
      buffer.writeln('*POR COMPRAR (${pendientes.length} artículos):*');

      final Map<String, List<Map<String, dynamic>>> pendientesPorCat = {};
      for (var p in pendientes) {
        final cat = ConversorUnidades.determinarCategoria(p['nombre'] ?? '');
        pendientesPorCat.putIfAbsent(cat, () => []).add(p);
      }

      for (var c in _ordenCategorias) {
        final nombreCat = c['nombre'] as String;
        final listCat = pendientesPorCat[nombreCat] ?? [];
        if (listCat.isNotEmpty) {
          listCat.sort((a, b) => (a['nombre'] ?? '').toString().toLowerCase().compareTo(
                (b['nombre'] ?? '').toString().toLowerCase(),
              ));
          buffer.writeln('\n📍 *${nombreCat.toUpperCase()}*');
          for (var p in listCat) {
            final cant = (p['cantidad'] != null && p['cantidad'].toString().isNotEmpty)
                ? ' (${p['cantidad']})'
                : '';
            final id = p['id'] as int?;
            final double? precioEst = id != null ? _preciosEstimadosPorItem[id] : null;
            final String precioStr = (precioEst != null && precioEst > 0)
                ? ' — ~\$${precioEst.toStringAsFixed(2)} MXN'
                : '';
            buffer.writeln('  [ ] ${p['nombre']}$cant$precioStr');
          }
        }
      }
      buffer.writeln('');
    }

    if (comprados.isNotEmpty) {
      buffer.writeln('*YA EN EL CARRITO (${comprados.length}):*');
      for (var c in comprados) {
        buffer.writeln('  [x] ~${c['nombre']}~');
      }
      buffer.writeln('');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━');
    if (_mejorCotizacion != null && _mejorCotizacion!.total > 0) {
      buffer.writeln(
        '💰 *TOTAL PRESUPUESTO:* \$${_mejorCotizacion!.total.toStringAsFixed(2)} MXN',
      );
      buffer.writeln('🏷️ Estimado en: ${_mejorCotizacion!.nombreSupermercado}');
    } else {
      buffer.writeln('💰 Total de artículos: ${items.length}');
    }

    buffer.writeln('\n_Generado automáticamente con Jitomate y Cebolla_ 🍅🧅');
    buffer.writeln('👉 https://www.jitomateycebolla.com/');
    return buffer.toString();
  }

  void _mostrarMenuExportarTicket(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu lista de compras está vacía.')),
      );
      return;
    }

    final texto = _generarTextoTicketSuper(items);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E2022),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_rounded, color: Colors.greenAccent, size: 24),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exportar Ticket de Súper',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    Text(
                      'Formato con casillas [ ] y precios estimados',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.white.withValues(alpha: 0.06),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF25D366),
                child: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
              ),
              title: const Text('Enviar por WhatsApp 📲', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Comparte la lista ordenada con casillas para tu familia', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}');
                try {
                  final lanzado = await launchUrl(uri, mode: LaunchMode.externalApplication);
                  if (!lanzado) {
                    await SharePlus.instance.share(ShareParams(text: texto, subject: 'Lista de compras Jitomate y Cebolla'));
                  }
                } catch (_) {
                  await SharePlus.instance.share(ShareParams(text: texto, subject: 'Lista de compras Jitomate y Cebolla'));
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.white.withValues(alpha: 0.06),
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.copy_rounded, color: Colors.white, size: 20),
              ),
              title: const Text('Copiar Ticket al Portapapeles 📋', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Pega la lista en cualquier app de notas o mensajería', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              onTap: () async {
                Navigator.pop(ctx);
                await Clipboard.setData(ClipboardData(text: texto));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.greenAccent),
                          SizedBox(width: 8),
                          Text('¡Ticket copiado al portapapeles! 📋'),
                        ],
                      ),
                      backgroundColor: Color(0xFF1E2022),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.white.withValues(alpha: 0.06),
              leading: const CircleAvatar(
                backgroundColor: Colors.deepOrange,
                child: Icon(Icons.share_rounded, color: Colors.white, size: 20),
              ),
              title: const Text('Compartir con otra Aplicación 📤', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Telegram, Correo, Slack o imprimir', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              onTap: () async {
                Navigator.pop(ctx);
                await SharePlus.instance.share(ShareParams(text: texto, subject: 'Ticket de compras Jitomate y Cebolla'));
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.white.withValues(alpha: 0.06),
              leading: const CircleAvatar(
                backgroundColor: Colors.teal,
                child: Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
              ),
              title: const Text('Comprar Súper en Línea 🌐', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Abre Walmart, Soriana o La Comer para surtir tu súper', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              onTap: () {
                Navigator.pop(ctx);
                _mostrarModalElegirSupermercadoOnline();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarModalElegirSupermercadoOnline() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2022),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.storefront_rounded, color: Colors.tealAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Comprar Súper (App o Web) 🛒',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        Text(
                          'Abre su app oficial en tu teléfono o la tienda web:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...[
                {'nombre': 'Walmart', 'url': 'super.walmart.com.mx', 'icono': Icons.shopping_cart, 'color': Colors.blue},
                {'nombre': 'Soriana', 'url': 'soriana.com', 'icono': Icons.store, 'color': Colors.red},
                {'nombre': 'La Comer', 'url': 'lacomer.com.mx', 'icono': Icons.local_grocery_store, 'color': Colors.orange},
                {'nombre': 'Chedraui', 'url': 'chedraui.com.mx', 'icono': Icons.shopping_basket, 'color': Colors.teal},
                {'nombre': 'Costco', 'url': 'costco.com.mx', 'icono': Icons.card_membership, 'color': Colors.indigo},
                {'nombre': 'Sam\'s Club', 'url': 'sams.com.mx', 'icono': Icons.loyalty, 'color': Colors.cyan},
              ].map((s) {
                final String nombre = s['nombre'] as String;
                final String url = s['url'] as String;
                final IconData icono = s['icono'] as IconData;
                final Color color = s['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: Colors.white.withValues(alpha: 0.06),
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Icon(icono, color: color, size: 20),
                    ),
                    title: Row(
                      children: [
                        Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('📱 App / 🌐 Web', style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ),
                      ],
                    ),
                    subtitle: Text(url, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
                    onTap: () {
                      Navigator.pop(ctx);
                      PantallaCotizador.abrirTiendaSupermercado(context, nombre);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirBarraPresupuesto(List<Map<String, dynamic>> items) {
    final double presupuesto = _preferencias?.presupuestoSemanal ?? 1500.0;
    final double estimado = _mejorCotizacion?.total ?? 0.0;
    final double restante = presupuesto - estimado;
    final double porcentaje = presupuesto > 0
        ? (estimado / presupuesto).clamp(0.0, 1.0)
        : 0.0;
    final bool excedido = restante < 0;
    final int total = items.length;
    final int pendientes =
        items.where((i) => !(i['comprado'] ?? false)).length;
    final int comprados =
        items.where((i) => i['comprado'] ?? false).length;
    final double progresoArticulos =
        total > 0 ? (comprados / total) : 0.0;

    Color barraColor = Colors.green;
    if (porcentaje > 0.7 && porcentaje <= 0.9) {
      barraColor = Colors.orange;
    } else if (porcentaje > 0.9 || excedido) {
      barraColor = Colors.red.shade700;
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      margin: EdgeInsets.fromLTRB(12, isLandscape ? 4 : 10, 12, isLandscape ? 3 : 6),
      padding: EdgeInsets.all(isLandscape ? 8 : 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: excedido ? Colors.red.shade300 : Colors.grey.withValues(alpha: 0.25),
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isLandscape ? 4 : 6),
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
                        size: isLandscape ? 16 : 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Presupuesto Semanal',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isLandscape ? 13 : 14,
                            color: excedido ? Colors.red.shade900 : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '\$${presupuesto.toStringAsFixed(0)} MXN',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isLandscape ? 13 : 14,
                            color: Colors.deepOrange,
                          ),
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
          SizedBox(height: isLandscape ? 6 : 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: isLandscape ? 6 : 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barraColor),
            ),
          ),
          SizedBox(height: isLandscape ? 6 : 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _mejorCotizacion != null && _mejorCotizacion!.total > 0
                            ? 'Estimado: \$${estimado.toStringAsFixed(2)} (${_mejorCotizacion!.nombreSupermercado})'
                            : (items.isEmpty
                                ? 'Lista vacía (\$0.00)'
                                : 'Estimado: Calculando...'),
                        style: TextStyle(
                          fontSize: isLandscape ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$pendientes pendientes · $comprados en carrito',
                        style:
                            TextStyle(fontSize: isLandscape ? 10 : 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 8 : 10,
                    vertical: isLandscape ? 3 : 5,
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
                      fontSize: isLandscape ? 10 : 11,
                      fontWeight: FontWeight.bold,
                      color: excedido
                          ? Colors.red.shade900
                          : Colors.green.shade800,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 🛒 Barra de Progreso de Artículos en el Carrito ("¡Faltan X cosas!")
          if (total > 0) ...[
            SizedBox(height: isLandscape ? 6 : 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: isLandscape ? 6 : 10),
              decoration: BoxDecoration(
                color: progresoArticulos == 1.0
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.amber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: progresoArticulos == 1.0
                      ? Colors.green.shade400
                      : Colors.amber.shade400,
                  width: 1,
                ),
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
                            Icon(
                              progresoArticulos == 1.0
                                  ? Icons.check_circle_rounded
                                  : Icons.shopping_basket_rounded,
                              size: isLandscape ? 15 : 17,
                              color: progresoArticulos == 1.0
                                  ? Colors.green.shade800
                                  : Colors.amber.shade900,
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                progresoArticulos == 1.0
                                    ? '🎉 ¡Carrito 100% Completo!'
                                    : '🛒 $comprados de $total en el carrito (${(progresoArticulos * 100).toInt()}%)',
                                style: TextStyle(
                                  fontSize: isLandscape ? 11.5 : 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: progresoArticulos == 1.0
                                      ? Colors.green.shade900
                                      : Colors.brown.shade900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          progresoArticulos == 1.0
                              ? '¡Listo para pagar!'
                              : (pendientes == 1
                                  ? '¡Falta solo 1!'
                                  : '¡Faltan solo $pendientes!'),
                          style: TextStyle(
                            fontSize: isLandscape ? 11 : 12,
                            fontWeight: FontWeight.bold,
                            color: progresoArticulos == 1.0
                                ? Colors.green.shade800
                                : Colors.deepOrange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isLandscape ? 4 : 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progresoArticulos,
                      minHeight: isLandscape ? 5 : 7,
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progresoArticulos == 1.0
                            ? Colors.green.shade700
                            : Colors.deepOrange,
                      ),
                    ),
                  ),
                  if (progresoArticulos == 1.0) ...[
                    SizedBox(height: isLandscape ? 6 : 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade800,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isLandscape ? 6 : 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.inventory_2_outlined, size: 17),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Mover comprados a mi Despensa 🥫✨',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        onPressed: transferirCompradosADespensa,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
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
          // Huevos: 1 cartón (cartera de 12-18 pzas) cubre típicamente la semana (máx 2 si es consumo muy alto)
          if (ConversorUnidades.sinAcentos(existente.nombre).contains('huevo')) {
            final double nuevoTotal = (existente.cantidad + 0.15).clamp(1.0, 3.0);
            final int cartonesInt = nuevoTotal.floor().clamp(1, 3);
            requerimientos[key] = ItemSupermercado(
              nombre: 'Huevo',
              cantidad: cartonesInt.toDouble(),
              unidad: 'cartón',
              textoCantidad: '$cartonesInt cartón${cartonesInt > 1 ? 'es' : ''} (cartera 12-18 pzas)',
            );
            return;
          }
          // Unidades sumables (kg, L, pza, cabeza, lata, paquete)
          final nuevaCantidad =
              ((existente.cantidad + item.cantidad) * 100).round() / 100.0;
          String texto = '$nuevaCantidad ${existente.unidad}';
          if (existente.unidad == 'cartón') {
            final int cantInt = nuevaCantidad.ceil();
            texto = '$cantInt cartón${cantInt > 1 ? 'es' : ''} (cartera 12-18 pzas)';
          } else if (existente.unidad == 'pza' ||
              existente.unidad == 'cabeza' ||
              existente.unidad == 'lata' ||
              existente.unidad == 'paquete') {
            final int cantInt = nuevaCantidad.ceil();
            texto =
                '$cantInt ${existente.unidad}${cantInt > 1 ? 's' : ''}';
          } else if (existente.unidad == 'kg' && ConversorUnidades.esFrutaOVerduraPorKilo(canNombre)) {
            texto = ConversorUnidades.textoKgConPiezas(
              canNombre,
              ConversorUnidades.redondearKg(nuevaCantidad),
            );
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
                } else if (reqItem.unidad == 'kg' &&
                    ConversorUnidades.esFrutaOVerduraPorKilo(reqItem.nombre)) {
                  texto = ConversorUnidades.textoKgConPiezas(
                    reqItem.nombre,
                    ConversorUnidades.redondearKg(rLimpio),
                  );
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
  Future<List<CotizacionSupermercado>> cotizarListaCompleta() =>
      ServicioCotizador.cotizarListaCompleta(supabase);

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
                        Expanded(
                          child: Row(
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
                              const Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Cotización Consolidada',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                      final itemsPendientes =
                          c.desglose.where((d) => !d.comprado).toList();
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
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      c.nombreSupermercado == 'Central de Abasto' ? 'CEDA CDMX' : c.nombreSupermercado,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
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
                              if (itemsPendientes.isNotEmpty) ...[
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
                                    itemCount: itemsPendientes.length,
                                    separatorBuilder: (_, _) => Divider(
                                      height: 1,
                                      color: Colors.grey.shade200,
                                    ),
                                    itemBuilder: (_, i) {
                                      final d = itemsPendientes[i];
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
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Usar \$${c.total.toStringAsFixed(2)} en Finanzas',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Abrir en Cotizador Interactivo detallado',
                            style: TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
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
    final nuevoEstado = !estadoActual;
    // 1. Reflejo optimista inmediato en memoria
    if (mounted) {
      setState(() {
        for (var item in _ultimosItems) {
          if (item['id'] == id) {
            item['comprado'] = nuevoEstado;
            break;
          }
        }
      });
    }

    // 2. Resiliencia offline y sincronización diferida (Prioridad R3)
    await ServicioCarritoOffline.actualizarEstadoComprado(
      idItem: id,
      comprado: nuevoEstado,
      supabaseClient: supabase,
    );
    _recalcularPresupuesto();
  }

  Future<void> eliminarItem(int id) async {
    if (mounted) {
      setState(() {
        _ultimosItems.removeWhere((item) => item['id'] == id);
      });
    }

    await ServicioCarritoOffline.eliminarItem(
      idItem: id,
      supabaseClient: supabase,
    );
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

  void mostrarModalDictadoRapido() {
    final textoCtrl = TextEditingController();
    bool parseando = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2022) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPadding),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.playlist_add_rounded, color: Colors.deepOrange, size: 24),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dictado Rápido & Multilista 🎙️📝',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Escribe o pega varios artículos separados por coma o renglón',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: textoCtrl,
                    maxLines: 4,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Ej:\n2 aguacates\n1 kg de jitomate\nmedio kilo de queso panela\ntortillas de maíz',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF121416) : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  () {
                    final raw = textoCtrl.text.trim();
                    if (raw.isEmpty) return const SizedBox.shrink();
                    final lineas = raw
                        .split(RegExp(r'[\n,;]'))
                        .map((l) => l.trim())
                        .where((l) => l.isNotEmpty && !ConversorUnidades.esAgua(l))
                        .toList();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Text(
                            '${lineas.length} insumos listos para clasificar y agregar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: parseando || textoCtrl.text.trim().isEmpty
                        ? null
                        : () async {
                            setModalState(() => parseando = true);
                            final raw = textoCtrl.text.trim();
                            final articulos = raw
                                .split(RegExp(r'[\n,;]'))
                                .map((l) => l.trim())
                                .where((l) => l.isNotEmpty && !ConversorUnidades.esAgua(l))
                                .toList();

                            int agregados = 0;
                            for (var art in articulos) {
                              final item = ConversorUnidades.parsearLineaIngrediente(art);
                              if (item.nombre.isNotEmpty && !ConversorUnidades.esAgua(item.nombre)) {
                                await ConversorUnidades.agregarOActualizarItemEnCarrito(
                                  supabase,
                                  item,
                                );
                                agregados++;
                              }
                            }

                            _recalcularPresupuesto();
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('🛒 ¡Se agregaron $agregados insumos a tu carrito de compras!'),
                                  backgroundColor: Colors.green.shade800,
                                ),
                              );
                            }
                          },
                    icon: parseando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.playlist_add_check_rounded, size: 20),
                    label: Text(parseando ? 'Agregando insumos...' : 'Agregar Insumos al Carrito'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const MenuLateral(rutaActual: 'carrito'),
      appBar: AppBar(
        leadingWidth: 56,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28, color: Colors.white),
            tooltip: 'Menú principal',
            splashRadius: 26,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Lista de Compras 🛒',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: const Color(0xFF1E2022),
        foregroundColor: Colors.white,
        actions: [
          // 📶 Indicador de Resiliencia Offline y Sincronización (Prioridad R3)
          ValueListenableBuilder<int>(
            valueListenable: ServicioCarritoOffline.pendientesNotifier,
            builder: (context, pendientes, _) {
              if (pendientes > 0) {
                return IconButton(
                  tooltip: '📶 $pendientes cambios offline guardados. Toca para sincronizar con la nube.',
                  icon: Badge(
                    label: Text('$pendientes'),
                    backgroundColor: Colors.amber.shade900,
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      color: Colors.amberAccent,
                      size: 22,
                    ),
                  ),
                  onPressed: () async {
                    final syncCount =
                        await ServicioCarritoOffline.sincronizarPendientes(supabase);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            syncCount > 0
                                ? '☁️ ¡$syncCount cambios sincronizados con éxito!'
                                : '📶 Sigues sin conexión estable en el supermercado.',
                          ),
                          backgroundColor:
                              syncCount > 0 ? Colors.teal : Colors.brown,
                        ),
                      );
                    }
                  },
                );
              }
              return const Tooltip(
                message: '☁️ Lista protegida contra caídas de red en el súper',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.cloud_done_rounded,
                    color: Colors.greenAccent,
                    size: 20,
                  ),
                ),
              );
            },
          ),
          // ⚡ Modo Supermercado Focus (Una Sola Mano)
          IconButton(
            tooltip: _modoSuperFocus
                ? 'Salir de Modo Focus'
                : 'Modo Supermercado Focus (1 Mano)',
            icon: Icon(
              _modoSuperFocus ? Icons.flash_on : Icons.flash_on_outlined,
              color: _modoSuperFocus ? Colors.amberAccent : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _modoSuperFocus = !_modoSuperFocus;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _modoSuperFocus
                        ? '🛒 Modo Supermercado Focus Activado: Pasillos ordenados y botones gigantes para 1 sola mano.'
                        : 'Modo Estándar restaurado.',
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: _modoSuperFocus ? Colors.deepOrange : Colors.black87,
                ),
              );
            },
          ),
          // 🧾 Exportar Ticket / Compartir Lista Inteligente (Mejora 4)
          IconButton(
            tooltip: 'Exportar Ticket / Compartir Lista',
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () => _mostrarMenuExportarTicket(_ultimosItems),
          ),
          // ⋯ Menú de opciones secundarias (Autollenar, Mover a Despensa, Vaciar lista)
          PopupMenuButton<String>(
            tooltip: 'Más opciones de lista',
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'autollenar') {
                if (!_estaCargando) autollenarListaDesdePlaneador();
              } else if (value == 'transferir') {
                if (!_estaCargando) transferirCompradosADespensa();
              } else if (value == 'vaciar') {
                _confirmarBorrarListaCompleta();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'autollenar',
                child: Row(
                  children: [
                    Icon(Icons.sync_alt, color: Colors.deepOrange, size: 20),
                    SizedBox(width: 10),
                    Text('Autollenar desde Planeador'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'transferir',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Colors.teal, size: 20),
                    SizedBox(width: 10),
                    Text('Mover comprados a Despensa'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'vaciar',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Text('Vaciar toda la lista', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
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
                List<Map<String, dynamic>> items;
                if (snapshot.hasData && snapshot.data != null) {
                  items = snapshot.data!;
                  _ultimosItems = items;
                  ServicioCarritoOffline.guardarCacheLocal(items);
                } else if (snapshot.hasError ||
                    (snapshot.connectionState == ConnectionState.waiting &&
                        _cacheOffline.isNotEmpty)) {
                  // Resiliencia Offline (R3): en sótanos de súper usamos la caché local
                  items = _cacheOffline.isNotEmpty ? _cacheOffline : _ultimosItems;
                } else {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  items = snapshot.data ?? [];
                }
                _ultimosItems = items;
                _verificarYRecalcular(items.length);

                if (_modoSuperFocus && items.isNotEmpty) {
                  return _construirModoSuperFocus(items);
                }

                return Column(
                  children: [
                    _construirBarraPresupuesto(items),
                    BannerHogarFamiliar(
                      onHogarActualizado: () {
                        if (mounted) {
                          setState(() {});
                          _recalcularPresupuesto();
                        }
                      },
                    ),
                    if (items.isEmpty)
                      Expanded(
                        child: RefreshIndicator(
                          color: Colors.red.shade800,
                          onRefresh: () async {
                            if (mounted) setState(() {});
                            await _recalcularPresupuesto();
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.5,
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
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: RefreshIndicator(
                          color: Colors.red.shade800,
                          onRefresh: () async {
                            if (mounted) setState(() {});
                            await _recalcularPresupuesto();
                          },
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 90, top: 4),
                            children: _construirSeccionesPorCategoria(items),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
      bottomNavigationBar: _modoSuperFocus
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFF1E2328),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.fullscreen_exit_rounded),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Salir de Focus'),
                      ),
                      onPressed: () => setState(() => _modoSuperFocus = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'A Despensa',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      onPressed: _estaCargando ? null : transferirCompradosADespensa,
                    ),
                  ),
                ],
              ),
            )
          : Container(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -3),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Agregar insumo individual',
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                      ),
                      onPressed: mostrarModalAgregarManual,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.playlist_add_rounded, size: 20),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Multilista / Dictado'),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.deepOrange,
                          side: const BorderSide(color: Colors.deepOrange),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: mostrarModalDictadoRapido,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.storefront, size: 20),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Cotizar Súper'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _construirModoSuperFocus(List<Map<String, dynamic>> items) {
    final int total = items.length;
    final int comprados = items.where((i) => i['comprado'] == true).length;
    final int pendientes = total - comprados;
    final double progreso = total > 0 ? comprados / total : 0.0;

    List<Map<String, dynamic>> itemsFiltrados = items;
    if (_filtroFocus == 'pendientes') {
      itemsFiltrados = items.where((i) => !(i['comprado'] ?? false)).toList();
    } else if (_filtroFocus == 'comprados') {
      itemsFiltrados = items.where((i) => i['comprado'] ?? false).toList();
    }

    final Map<String, List<Map<String, dynamic>>> itemsPorCategoria = {};
    for (var c in _ordenCategorias) {
      itemsPorCategoria[c['nombre'] as String] = [];
    }
    for (var item in itemsFiltrados) {
      final cat = ConversorUnidades.determinarCategoria(item['nombre'] ?? '');
      itemsPorCategoria.putIfAbsent(cat, () => []).add(item);
    }

    return Container(
      color: const Color(0xFF14171A),
      child: Column(
        children: [
          // Banner de progreso y control para una sola mano
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2328),
              border: Border(
                bottom: BorderSide(
                  color: Colors.amber.shade700.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
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
                            color: Colors.amber.shade900.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.flash_on_rounded,
                            color: Colors.amberAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MODO SUPERMERCADO FOCUS',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              '$comprados de $total en el carrito',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '${(progreso * 100).toInt()}%',
                      style: TextStyle(
                        color: progreso == 1.0 ? Colors.greenAccent : Colors.white70,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progreso == 1.0 ? Colors.greenAccent : Colors.deepOrangeAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      progreso == 1.0
                          ? '🎉 ¡Completaste todos tus artículos en tienda!'
                          : (pendientes == 1
                              ? '⚡ ¡Falta solo 1 producto!'
                              : '⚡ ¡Faltan solo $pendientes productos!'),
                      style: TextStyle(
                        color: progreso == 1.0 ? Colors.greenAccent : Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (progreso == 1.0)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.greenAccent.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.inventory_2_outlined, size: 14),
                        label: const Text('Mover a Despensa', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: transferirCompradosADespensa,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Chips de filtro para cambiar de vista con el pulgar
                Row(
                  children: [
                    _construirChipFiltroFocus('pendientes', 'Por Comprar ($pendientes)'),
                    const SizedBox(width: 8),
                    _construirChipFiltroFocus('todos', 'Todos ($total)'),
                    const SizedBox(width: 8),
                    _construirChipFiltroFocus('comprados', 'En Carrito ($comprados)'),
                  ],
                ),
              ],
            ),
          ),

          // Lista de Pasillos y Productos Gigantes
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100, top: 8),
              children: _construirSeccionesSupermercadoFocus(itemsPorCategoria),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirChipFiltroFocus(String clave, String texto) {
    final bool activo = _filtroFocus == clave;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filtroFocus = clave),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo ? Colors.amberAccent : Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: activo ? Colors.black : Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  List<Widget> _construirSeccionesSupermercadoFocus(
    Map<String, List<Map<String, dynamic>>> itemsPorCategoria,
  ) {
    final List<Widget> widgets = [];
    int pasilloNum = 1;

    for (var catConfig in _ordenCategorias) {
      final String nombreCat = catConfig['nombre'] as String;
      final List<Map<String, dynamic>> itemsDeEstaCat =
          itemsPorCategoria[nombreCat] ?? [];

      if (itemsDeEstaCat.isEmpty) continue;

      final String pasillo = catConfig['pasillo'] as String? ?? 'Pasillo $pasilloNum';
      final IconData iconoCat = catConfig['icono'] as IconData;
      final Color colorCat = catConfig['color'] as Color;
      final int comprados = itemsDeEstaCat.where((i) => i['comprado'] == true).length;
      final int total = itemsDeEstaCat.length;

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorCat.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconoCat, color: colorCat, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pasillo.toUpperCase(),
                      style: TextStyle(
                        color: colorCat,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      nombreCat,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: comprados == total
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$comprados/$total',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: comprados == total ? Colors.greenAccent : Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      for (var item in itemsDeEstaCat) {
        widgets.add(_construirItemFocusGigante(item));
      }

      pasilloNum++;
    }

    if (widgets.isEmpty) {
      widgets.add(
        const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
            child: Text(
              'No hay productos en esta vista.',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _construirItemFocusGigante(Map<String, dynamic> item) {
    final bool comprado = item['comprado'] ?? false;
    final String nombre = item['nombre'] ?? '';
    final cant = item['cantidad'];
    final unidad = item['unidad_medida'] ?? '';
    final int? idItem = item['id'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: comprado
            ? const Color(0xFF1E2328).withValues(alpha: 0.5)
            : const Color(0xFF222831),
        borderRadius: BorderRadius.circular(14),
        elevation: comprado ? 0 : 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (idItem != null) {
              alternarComprado(idItem, comprado);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Checkbox gigante táctil de 38px
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: comprado ? Colors.greenAccent.shade700 : Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: comprado ? Colors.greenAccent : Colors.white38,
                      width: 2.2,
                    ),
                  ),
                  child: comprado
                      ? const Icon(Icons.check, color: Colors.white, size: 26)
                      : null,
                ),
                const SizedBox(width: 14),
                // Nombre del producto en letra grande y legible
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: comprado ? Colors.white38 : Colors.white,
                          decoration: comprado ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.white38,
                          decorationThickness: 2,
                        ),
                      ),
                      if (cant != null || unidad.toString().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          '${cant ?? ''} $unidad'.trim(),
                          style: TextStyle(
                            fontSize: 13,
                            color: comprado ? Colors.white30 : Colors.amberAccent.shade100,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Botón visual rápido "1-TAP"
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: comprado
                        ? Colors.transparent
                        : Colors.deepOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: comprado
                          ? Colors.white10
                          : Colors.deepOrange.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    comprado ? 'LISTO ✓' : 'TOCAR 👆',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: comprado ? Colors.white38 : Colors.deepOrangeAccent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _construirSeccionesPorCategoria(List<Map<String, dynamic>> items) {
    final Map<String, List<Map<String, dynamic>>> itemsPorCategoria = {};
    for (var c in _ordenCategorias) {
      itemsPorCategoria[c['nombre'] as String] = [];
    }

    for (var item in items) {
      final cat = ConversorUnidades.determinarCategoria(item['nombre'] ?? '');
      itemsPorCategoria.putIfAbsent(cat, () => []).add(item);
    }

    // Identificar categorías activas con productos
    final List<String> categoriasPresentes = [];
    for (var catConfig in _ordenCategorias) {
      final String nombreCat = catConfig['nombre'] as String;
      if ((itemsPorCategoria[nombreCat] ?? []).isNotEmpty) {
        categoriasPresentes.add(nombreCat);
      }
    }

    final List<Widget> widgets = [];

    // Si hay más de una categoría activa, barra rápida de "Colapsar / Expandir todas"
    if (categoriasPresentes.length > 1) {
      final bool todasColapsadas =
          categoriasPresentes.every((cat) => _categoriasColapsadas.contains(cat));

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${categoriasPresentes.length} categorías • ${items.length} productos',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  setState(() {
                    if (todasColapsadas) {
                      _categoriasColapsadas.clear();
                    } else {
                      _categoriasColapsadas.addAll(categoriasPresentes);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        todasColapsadas
                            ? Icons.unfold_more_rounded
                            : Icons.unfold_less_rounded,
                        size: 15,
                        color: Colors.deepOrange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        todasColapsadas ? 'Expandir todas' : 'Colapsar todas',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (var catConfig in _ordenCategorias) {
      final String nombreCat = catConfig['nombre'] as String;
      final List<Map<String, dynamic>> itemsDeEstaCat =
          itemsPorCategoria[nombreCat] ?? [];

      if (itemsDeEstaCat.isEmpty) continue;

      // Ordenar alfabéticamente dentro de la categoría
      itemsDeEstaCat.sort((a, b) {
        final nomA = (a['nombre'] ?? '').toString().toLowerCase();
        final nomB = (b['nombre'] ?? '').toString().toLowerCase();
        return nomA.compareTo(nomB);
      });

      final IconData iconoCat = catConfig['icono'] as IconData;
      final Color colorCat = catConfig['color'] as Color;
      final bool estaColapsada = _categoriasColapsadas.contains(nombreCat);
      final int compradosCount =
          itemsDeEstaCat.where((i) => i['comprado'] == true).length;
      final int totalCount = itemsDeEstaCat.length;

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                setState(() {
                  if (estaColapsada) {
                    _categoriasColapsadas.remove(nombreCat);
                  } else {
                    _categoriasColapsadas.add(nombreCat);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: colorCat.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(iconoCat, size: 16, color: colorCat),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              nombreCat,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: compradosCount == totalCount
                                  ? Colors.green.shade50
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              compradosCount > 0
                                  ? '$compradosCount/$totalCount'
                                  : '$totalCount',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: compradosCount == totalCount
                                    ? Colors.green.shade800
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      estaColapsada
                          ? Icons.expand_more_rounded
                          : Icons.expand_less_rounded,
                      size: 22,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      if (!estaColapsada) {
        for (var item in itemsDeEstaCat) {
          widgets.add(_construirItemCard(item));
        }
      }
    }

    return widgets;
  }

  Widget _construirItemCard(Map<String, dynamic> item) {
    final bool comprado = item['comprado'] ?? false;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 3.5,
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
