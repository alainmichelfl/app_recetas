import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversor_unidades.dart';
import 'pantalla_despensa.dart';
import 'pantalla_carrito.dart';
import 'pantalla_finanzas.dart';
import 'menu_lateral.dart';
import 'servicio_historial_cocina.dart';

class PantallaCotizador extends StatefulWidget {
  final int? idReceta;
  final String? titulo;
  final double multiplicador;

  const PantallaCotizador({
    super.key,
    this.idReceta,
    this.titulo,
    this.multiplicador = 1.0,
  });

  @override
  State<PantallaCotizador> createState() => _PantallaCotizadorState();
}

class _PantallaCotizadorState extends State<PantallaCotizador> {
  List<Map<String, dynamic>> ingredientesDinamicos = [];
  bool cargando = true;

  bool seleccionandoReceta = false;
  List<Map<String, dynamic>> todasLasRecetas = [];
  int? recetaActualId;
  String? recetaActualTitulo;
  Set<int> _idsCocinadas = {};
  Set<String> _titulosCocinados = {};

  int porcionesBase = 1;
  int porcionesActuales = 1;

  double get multiplicadorActual {
    if (recetaActualId == -1) {
      return porcionesActuales.toDouble();
    }
    return porcionesActuales / (porcionesBase > 0 ? porcionesBase : 1);
  }

  final List<String> listaSupermercados = [
    'Walmart',
    'Soriana',
    'La Comer',
    'Central de Abasto',
  ];

  @override
  void initState() {
    super.initState();
    porcionesActuales = (widget.multiplicador > 0 ? widget.multiplicador : 1.0).round().clamp(1, 20);
    _cargarHistorial();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mostrarInfoCotizador();
    });

    if (widget.idReceta != null && widget.idReceta != 0) {
      recetaActualId = widget.idReceta;
      recetaActualTitulo = widget.titulo;
      cargarPreciosDetallados();
    } else {
      seleccionandoReceta = true;
      cargarListaDeRecetas();
    }
  }

  Future<void> _cargarHistorial() async {
    try {
      final ids = await ServicioHistorialCocina.obtenerIdsCocinadas();
      final tits = await ServicioHistorialCocina.obtenerTitulosCocinadas();
      if (mounted) {
        setState(() {
          _idsCocinadas = ids;
          _titulosCocinados = tits;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar historial en cotizador: $e');
    }
  }

  Future<void> cargarListaDeRecetas() async {
    try {
      await _cargarHistorial();
      final respuesta = await Supabase.instance.client
          .from('recetas')
          .select('id_receta, titulo')
          .order('id_receta', ascending: false);
      if (!mounted) return;
      final List<Map<String, dynamic>> listaTotal = [
        {
          'id_receta': -1,
          'titulo': '🛒 Mi Lista de Compras Actual',
        },
        ...List<Map<String, dynamic>>.from(respuesta),
      ];
      setState(() {
        todasLasRecetas = listaTotal;
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar lista de recetas: $e');
      if (mounted) setState(() => cargando = false);
    }
  }

  void _extraerIngredientesDeTexto(
    String desc,
    Map<String, double> ingredientes,
    Map<String, String> unidades,
  ) {
    final lower = desc.toLowerCase();
    if (!lower.contains('ingredientes')) return;

    final partes = desc.split(
      RegExp(r'📝?\s*INGREDIENTES:?', caseSensitive: false),
    );
    if (partes.length < 2) return;

    final bloque = partes[1].split(
      RegExp(r'🍳?\s*INSTRUCCIONES:?', caseSensitive: false),
    )[0];
    final lineas = bloque.split('\n');

    for (var l in lineas) {
      String texto = l.trim();
      if (!texto.startsWith('-') &&
          !texto.startsWith('•') &&
          !texto.startsWith('*')) {
        continue;
      }
      final item = ConversorUnidades.parsearLineaIngrediente(texto);
      if (item.nombre.isNotEmpty) {
        ingredientes[item.nombre] = (ingredientes[item.nombre] ?? 0) + item.cantidad;
        unidades[item.nombre] = item.unidad;
      }
    }
  }

  String _normalizarSupermercado(String nombreDB) {
    final n = nombreDB.toLowerCase();
    if (n.contains('walmart')) return 'Walmart';
    if (n.contains('soriana')) return 'Soriana';
    if (n.contains('comer')) return 'La Comer';
    if (n.contains('abasto') || n.contains('central')) return 'Central de Abasto';
    return 'Walmart';
  }

  Future<void> cargarPreciosDetallados() async {
    setState(() => cargando = true);
    try {
      final supabase = Supabase.instance.client;
      List<Map<String, dynamic>> itemsTemp = [];

      if (recetaActualId == -1) {
        porcionesBase = 1;
        porcionesActuales = 1;
        final resCompras = await supabase
            .from('lista_compras')
            .select('id, nombre, cantidad')
            .eq('comprado', false);
        for (var fila in resCompras) {
          final String nomRaw = (fila['nombre'] ?? '').toString().trim();
          final String cantRaw = (fila['cantidad'] ?? '1').toString().trim();
          final parsed = ConversorUnidades.parsearLineaIngrediente('$cantRaw $nomRaw');
          itemsTemp.add({
            'id_ingrediente': null,
            'nombre': parsed.nombre.isNotEmpty ? parsed.nombre : nomRaw,
            'cantidad': parsed.cantidad,
            'unidad': parsed.unidad,
          });
        }
      } else {
        if (recetaActualId != null && recetaActualId! > 0) {
          try {
            final recetaInfo = await supabase
                .from('recetas')
                .select('porciones, descripcion')
                .eq('id_receta', recetaActualId!)
                .maybeSingle();
            if (recetaInfo != null) {
              int pBase = 1;
              if (recetaInfo['porciones'] != null && recetaInfo['porciones'] is int) {
                pBase = recetaInfo['porciones'] as int;
              } else {
                final match = RegExp(r'PORCIONES:\s*(\d+)', caseSensitive: false)
                    .firstMatch(recetaInfo['descripcion']?.toString() ?? '');
                if (match != null) {
                  pBase = int.tryParse(match.group(1)!) ?? 1;
                }
              }
              if (pBase <= 0) pBase = 1;
              porcionesBase = pBase;
              porcionesActuales = (pBase * widget.multiplicador).round().clamp(1, 20);
            }
          } catch (_) {}
        }

        final respuesta = await supabase
            .from('receta_detalle')
            .select(
              'id_ingrediente, cantidad, unidad_medida, ingredientes_genericos(id_ingrediente, nombre_estandar)',
            )
            .eq('id_receta', recetaActualId!);

        if (respuesta.isNotEmpty) {
          for (var fila in respuesta) {
            final gen = fila['ingredientes_genericos'];
            final String nombre = gen != null
                ? (gen['nombre_estandar']?.toString() ?? '')
                : '';
            final double cant =
                double.tryParse(fila['cantidad']?.toString() ?? '1') ?? 1.0;
            final String unid = (fila['unidad_medida'] ?? 'pza')
                .toString()
                .trim();
            final int? idGen = fila['id_ingrediente'];

            if (nombre.isNotEmpty) {
              itemsTemp.add({
                'id_ingrediente': idGen,
                'nombre': nombre,
                'cantidad': cant,
                'unidad': unid,
              });
            }
          }
        }

        if (itemsTemp.isEmpty) {
          final recetaRes = await supabase
              .from('recetas')
              .select('descripcion, instrucciones')
              .eq('id_receta', recetaActualId!)
              .maybeSingle();

          if (recetaRes != null) {
            final desc =
                (recetaRes['descripcion'] ?? recetaRes['instrucciones'] ?? '')
                    .toString();
            final Map<String, double> ingsExt = {};
            final Map<String, String> unidsExt = {};
            _extraerIngredientesDeTexto(desc, ingsExt, unidsExt);

            for (var entry in ingsExt.entries) {
              itemsTemp.add({
                'id_ingrediente': null,
                'nombre': entry.key,
                'cantidad': entry.value,
                'unidad': unidsExt[entry.key] ?? 'pza',
              });
            }
          }
        }
      }

      final todosGenericosData = await supabase
          .from('ingredientes_genericos')
          .select('id_ingrediente, nombre_estandar');
      final List todosGenericos = todosGenericosData as List;

      final todosPreciosData = await supabase
          .from('precios_supermercado')
          .select('id_ingrediente, precio, supermercados(nombre)');
      final List todosPrecios = todosPreciosData as List;

      List<Map<String, dynamic>> listaFinal = [];

      for (var item in itemsTemp) {
        final String nombre = item['nombre'];
        int? idGen = item['id_ingrediente'];
        Map<String, double> preciosPorSuper = {};

        if (idGen == null) {
          for (var g in todosGenericos) {
            final nomGen = (g['nombre_estandar'] ?? '').toString();
            if (ConversorUnidades.nombresCoinciden(nombre, nomGen)) {
              idGen = g['id_ingrediente'] as int?;
              break;
            }
          }
        }

        if (idGen != null) {
          for (var p in todosPrecios) {
            if (p['id_ingrediente'] == idGen) {
              final superNombreRaw =
                  p['supermercados']?['nombre']?.toString() ?? '';
              final precioVal =
                  double.tryParse(p['precio']?.toString() ?? '0') ?? 0.0;
              if (superNombreRaw.isNotEmpty && precioVal > 0) {
                final normalizado = _normalizarSupermercado(superNombreRaw);
                preciosPorSuper[normalizado] = precioVal;
              }
            }
          }
        }

        if (preciosPorSuper.isEmpty) {
          final palabras = nombre
              .split(' ')
              .where(
                (w) =>
                    w.length > 3 &&
                    ![
                      'para',
                      'sobre',
                      'fina',
                      'poco',
                      'pizca',
                    ].contains(w.toLowerCase()),
              )
              .toList();

          if (palabras.isNotEmpty) {
            final palabraClave = ConversorUnidades.sinAcentos(
              palabras.first.toLowerCase(),
            );
            for (var p in todosPrecios) {
              final idIng = p['id_ingrediente'];
              final gen = todosGenericos.firstWhere(
                (g) => g['id_ingrediente'] == idIng,
                orElse: () => <String, dynamic>{},
              );
              if (gen.isNotEmpty) {
                final nomG = ConversorUnidades.sinAcentos(
                  (gen['nombre_estandar'] ?? '').toString().toLowerCase(),
                );
                if (nomG.contains(palabraClave)) {
                  final superNombreRaw =
                      p['supermercados']?['nombre']?.toString() ?? '';
                  final precioVal =
                      double.tryParse(p['precio']?.toString() ?? '0') ?? 0.0;
                  if (superNombreRaw.isNotEmpty && precioVal > 0) {
                    final normalizado = _normalizarSupermercado(superNombreRaw);
                    preciosPorSuper.putIfAbsent(normalizado, () => precioVal);
                  }
                }
              }
            }
          }
        }

        double precioBaseReferencia = 28.0;
        final nombreLower = nombre.toLowerCase();
        if (nombreLower.contains('pollo') ||
            nombreLower.contains('carne') ||
            nombreLower.contains('pavo')) {
          precioBaseReferencia = 89.0;
        } else if (nombreLower.contains('queso') ||
            nombreLower.contains('jamon') ||
            nombreLower.contains('mantequilla')) {
          precioBaseReferencia = 54.0;
        } else if (nombreLower.contains('huevo') ||
            nombreLower.contains('leche') ||
            nombreLower.contains('avena')) {
          precioBaseReferencia = 38.0;
        } else if (nombreLower.contains('sal') ||
            nombreLower.contains('pimienta') ||
            nombreLower.contains('vainilla')) {
          precioBaseReferencia = 22.0;
        }

        preciosPorSuper.putIfAbsent('Walmart', () => precioBaseReferencia);
        preciosPorSuper.putIfAbsent(
          'Soriana',
          () => (precioBaseReferencia * 0.96).roundToDouble(),
        );
        preciosPorSuper.putIfAbsent(
          'La Comer',
          () => (precioBaseReferencia * 1.05).roundToDouble(),
        );
        preciosPorSuper.putIfAbsent(
          'Central de Abasto',
          () => (precioBaseReferencia * 0.75).roundToDouble(),
        );

        listaFinal.add({
          'nombre': nombre,
          'cantidad': item['cantidad'],
          'unidad': item['unidad'],
          'precios': preciosPorSuper,
          'incluir': true,
        });
      }

      if (!mounted) return;
      setState(() {
        ingredientesDinamicos = listaFinal;
        seleccionandoReceta = false;
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar cotización: $e');
      if (mounted) setState(() => cargando = false);
    }
  }

  double calcularSubtotalItem(Map<String, dynamic> item, String supermercado) {
    final String nombre = (item['nombre'] ?? '').toString();
    final double cantBase = (item['cantidad'] is num)
        ? (item['cantidad'] as num).toDouble()
        : double.tryParse(item['cantidad']?.toString() ?? '1') ?? 1.0;
    final String unidad = (item['unidad'] ?? 'pza').toString();
    final double cantAjustada = cantBase * multiplicadorActual;

    final Map<String, double> precios = Map<String, double>.from(item['precios'] ?? {});
    double precioUnit = precios[supermercado] ?? 0.0;
    if (precioUnit == 0.0 && precios.isNotEmpty) {
      precioUnit = precios.values.first;
    }
    if (precioUnit <= 0) return 0.0;

    final normNom = ConversorUnidades.sinAcentos(nombre);
    final normUnid = ConversorUnidades.sinAcentos(unidad);

    // 1. Frutas y verduras por kilo vendidas en piezas
    if (normUnid == 'pza' && ConversorUnidades.esFrutaOVerduraPorKilo(nombre)) {
      final pesoKilos = cantAjustada * ConversorUnidades.pesoAproximadoKilosPorPieza(nombre);
      return (precioUnit * pesoKilos * 100).round() / 100.0;
    }

    // 2. Carnes y proteínas o productos por kg
    if (normUnid == 'kg' || normUnid == 'kilo') {
      return (precioUnit * cantAjustada * 100).round() / 100.0;
    }

    // 3. Líquidos por litro
    if (normUnid == 'l' || normUnid == 'lt') {
      return (precioUnit * cantAjustada * 100).round() / 100.0;
    }

    // 4. Huevos (precio por paquete/cartera de 12-18)
    if (normNom.contains('huevo') || normNom.contains('blanquillo')) {
      final int paquetes = (cantAjustada / 12.0).ceil().clamp(1, 10);
      return (precioUnit * paquetes * 100).round() / 100.0;
    }

    // 5. Especias o aceites/botellas que no se multiplican si es poca cantidad (1 frasco basta)
    if (normUnid == 'frasco' || normUnid == 'botella' || ConversorUnidades.esEspecia(nombre)) {
      return precioUnit;
    }

    // 6. Paquetes, latas, manojos, cabezas, o piezas enteras
    final double cantComercial = cantAjustada < 1.0 ? 1.0 : cantAjustada.ceilToDouble();
    return (precioUnit * cantComercial * 100).round() / 100.0;
  }

  double calcularTotalDe(String supermercado) {
    double total = 0;
    for (var item in ingredientesDinamicos) {
      if (item['incluir'] == true) {
        total += calcularSubtotalItem(item, supermercado);
      }
    }
    return (total * 100).round() / 100.0;
  }

  Future<void> guardarSeleccionadosEnCarrito() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    try {
      final supabase = Supabase.instance.client;

      for (var item in ingredientesDinamicos) {
        if (item['incluir'] == true) {
          if (ConversorUnidades.esAgua(item['nombre'] ?? '')) continue;
          final cantidadBase = (item['cantidad'] is int)
              ? (item['cantidad'] as int).toDouble()
              : double.tryParse(item['cantidad'].toString()) ?? 1.0;

          final cantidadCalculada = cantidadBase * multiplicadorActual;
          final itemNorm = ConversorUnidades.normalizarParaSupermercado(
            item['nombre'],
            cantidadCalculada,
            item['unidad'] ?? 'pza',
          );
          if (ConversorUnidades.esAgua(itemNorm.nombre) || itemNorm.cantidad <= 0) continue;

          await ConversorUnidades.agregarOActualizarItemEnCarrito(
            supabase,
            itemNorm,
          );
        }
      }

      if (!mounted) return;
      nav.pop();

      messenger.showSnackBar(
        SnackBar(
          content: const Text('¡Lista guardada con éxito en el carrito! 🛒'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'VER LISTA',
            textColor: Colors.white,
            onPressed: () {
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PantallaCarrito(),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      nav.pop();
      debugPrint('Error al guardar en carrito: $e');
    }
  }

  Future<void> _agendarConEstePrecio() async {
    final messenger = ScaffoldMessenger.of(context);

    final DateTime? fechaElegida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (fechaElegida == null || !mounted) return;

    final String? tipo = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => SimpleDialog(
        title: const Text('¿Para qué comida?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogCtx, 'Desayuno'),
            child: const Text('🍳 Desayuno', style: TextStyle(fontSize: 18)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogCtx, 'Comida'),
            child: const Text('🍲 Comida', style: TextStyle(fontSize: 18)),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(dialogCtx, 'Cena'),
            child: const Text('🌙 Cena', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );

    if (tipo == null || !mounted) return;

    double precioParaGuardar = double.infinity;
    for (var s in listaSupermercados) {
      double t = calcularTotalDe(s);
      if (t < precioParaGuardar && t > 0) {
        precioParaGuardar = t;
      }
    }
    if (precioParaGuardar == double.infinity) {
      precioParaGuardar = 0.0;
    }

    try {
      await Supabase.instance.client.from('planeador').insert({
        'fecha': fechaElegida.toIso8601String().split('T')[0],
        'tipo_comida': tipo,
        'id_receta': recetaActualId,
        'costo_personalizado': precioParaGuardar,
      });

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('¡Agendado con precio personalizado! 📅'),
          backgroundColor: Colors.deepPurple,
        ),
      );
    } catch (e) {
      debugPrint('Error al agendar en planeador: $e');
    }
  }

  void _mostrarInfoCotizador() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (contextDialog) {
        return Container(
          padding: const EdgeInsets.all(25.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lightbulb, color: Colors.amber, size: 30),
                  SizedBox(width: 10),
                  Text(
                    '¿Cómo funciona?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              _crearReglaItem(
                icono: Icons.calculate_outlined,
                color: Colors.deepPurple,
                titulo: '1. Matemática Inteligente',
                descripcion: 'El cotizador lee las porciones exactas que elegiste en tu receta y calcula automáticamente cuánto necesitas comprar de cada cosa.',
              ),
              const SizedBox(height: 20),
              _crearReglaItem(
                icono: Icons.local_offer_outlined,
                color: Colors.orange,
                titulo: '2. Nombres Estándar',
                descripcion: 'Buscamos tus ingredientes por su nombre genérico en anaquel (ej. "Cebolla", "Pechuga de pollo").',
              ),
              const SizedBox(height: 20),
              _crearReglaItem(
                icono: Icons.storefront_outlined,
                color: Colors.teal,
                titulo: '3. Precios de Referencia',
                descripcion: 'Te mostramos el costo estimado basándonos en los precios registrados en las cadenas más populares de supermercados.',
              ),
              const SizedBox(height: 20),
              _crearReglaItem(
                icono: Icons.info_outline,
                color: Colors.blueGrey,
                titulo: '4. Variación de Precios',
                descripcion: 'Los montos son orientativos y aproximados. Pueden variar según la zona geográfica, sucursal física, promociones de temporada y marca elegida.',
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(contextDialog),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    '¡Entendido!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _crearReglaItem({
    required IconData icono,
    required Color color,
    required String titulo,
    required String descripcion,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icono, color: color, size: 26),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                descripcion,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Map<String, double> totales = {};
    double precioMinimo = double.infinity;
    String superMasBarato = '';

    if (!cargando && !seleccionandoReceta) {
      for (var superm in listaSupermercados) {
        double t = calcularTotalDe(superm);
        totales[superm] = t;

        if (t < precioMinimo && t > 0) {
          precioMinimo = t;
          superMasBarato = superm;
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const MenuLateral(rutaActual: 'cotizador'),
      appBar: AppBar(
        leading: (!seleccionandoReceta && widget.idReceta == null)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Elegir otra receta',
                onPressed: () {
                  setState(() {
                    seleccionandoReceta = true;
                    recetaActualId = null;
                    recetaActualTitulo = null;
                  });
                },
              )
            : (widget.idReceta != null && Navigator.canPop(context))
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Volver',
                    onPressed: () => Navigator.pop(context),
                  )
                : Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(Icons.menu),
                      tooltip: 'Menú principal',
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
                  ),
        title: const Text(
          'Cotizador Dinámico 💰',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '¿Cómo funciona?',
            onPressed: _mostrarInfoCotizador,
          ),
          IconButton(
            icon: const Icon(Icons.kitchen),
            tooltip: 'Mi Despensa',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PantallaDespensa()),
            ),
          ),
        ],
      ),
      bottomNavigationBar: seleccionandoReceta || cargando
          ? null
          : Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (recetaActualId == -1) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            double mejorPrecio = double.infinity;
                            String mejorSuper = 'Walmart';
                            for (var s in listaSupermercados) {
                              double t = calcularTotalDe(s);
                              if (t > 0 && t < mejorPrecio) {
                                mejorPrecio = t;
                                mejorSuper = s;
                              }
                            }
                            if (mejorPrecio == double.infinity) mejorPrecio = 0.0;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PantallaFinanzas(
                                  presupuestoSuperExterno: mejorPrecio,
                                  supermercadoElegido: mejorSuper,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Transferir mejor precio ($superMasBarato) a Finanzas',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PantallaCarrito(),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.shopping_cart_outlined,
                            color: Colors.deepOrange,
                          ),
                          label: const Text(
                            'Volver a la Lista de Compras',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.deepOrange),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: _agendarConEstePrecio,
                          icon: const Icon(
                            Icons.calendar_month,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Agendar con este precio',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                          onPressed: guardarSeleccionadosEnCarrito,
                          icon: const Icon(
                            Icons.add_shopping_cart,
                            color: Colors.green,
                          ),
                          label: const Text(
                            'Guardar lo seleccionado en carrito',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.green, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepPurple),
            )
          : seleccionandoReceta
          ? Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calculate,
                    size: 80,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '¿Qué receta quieres cotizar?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Selecciona uno de tus platillos y te diremos dónde sale más barato prepararlo.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  Expanded(
                    child: todasLasRecetas.isEmpty
                        ? const Center(
                            child: Text('Aún no tienes recetas para cotizar.'),
                          )
                        : ListView.builder(
                            itemCount: todasLasRecetas.length,
                            itemBuilder: (context, index) {
                              final r = todasLasRecetas[index];
                              final int idR = r['id_receta'] is int
                                  ? r['id_receta']
                                  : (int.tryParse(r['id_receta']?.toString() ?? '0') ?? 0);
                              final String titR = r['titulo']?.toString() ?? '';
                              final bool fueCocinada = (idR > 0 && _idsCocinadas.contains(idR)) ||
                                  _titulosCocinados.contains(titR.toLowerCase().trim());

                              final bool esCarrito = idR == -1;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                color: esCarrito
                                    ? Colors.orange.shade50.withValues(alpha: 0.6)
                                    : null,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: esCarrito
                                        ? Colors.deepOrange.shade300
                                        : (fueCocinada
                                            ? Colors.green.shade300
                                            : Colors.grey.shade200),
                                    width: (esCarrito || fueCocinada) ? 1.5 : 1.0,
                                  ),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    esCarrito
                                        ? Icons.shopping_cart
                                        : (fueCocinada
                                            ? Icons.soup_kitchen
                                            : Icons.restaurant_menu),
                                    color: esCarrito
                                        ? Colors.deepOrange
                                        : (fueCocinada
                                            ? Colors.green.shade700
                                            : Colors.deepPurple),
                                  ),
                                  title: Text(
                                    titR,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: esCarrito
                                          ? Colors.deepOrange.shade900
                                          : Colors.black87,
                                    ),
                                  ),
                                  subtitle: esCarrito
                                      ? const Text(
                                          'Cotizar en vivo todos los productos de tu lista de compras',
                                          style: TextStyle(fontSize: 12),
                                        )
                                      : (fueCocinada
                                          ? Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  size: 12,
                                                  color: Colors.green.shade800,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '¡Aviso: Ya preparaste esta receta! 👨‍🍳✅',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.green.shade800,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : null),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                  ),
                                  onTap: () {
                                    recetaActualId = r['id_receta'];
                                    recetaActualTitulo = r['titulo'];
                                    cargarPreciosDetallados();
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if ((recetaActualId != null &&
                              _idsCocinadas.contains(recetaActualId)) ||
                          _titulosCocinados.contains(
                            recetaActualTitulo?.toLowerCase().trim(),
                          )) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.green.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.soup_kitchen,
                                size: 16,
                                color: Colors.green.shade800,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Aviso: ¡Ya has cocinado esta receta anteriormente! 👨‍🍳✅',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Text(
                        'Total para: $recetaActualTitulo',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (recetaActualId != -1) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.deepPurple,
                                size: 28,
                              ),
                              tooltip: 'Menos porciones',
                              onPressed: porcionesActuales > 1
                                  ? () => setState(() => porcionesActuales--)
                                  : null,
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.deepPurple.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                '🍽️ $porcionesActuales porciones',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.deepPurple,
                                size: 28,
                              ),
                              tooltip: 'Más porciones',
                              onPressed: porcionesActuales < 20
                                  ? () => setState(() => porcionesActuales++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: listaSupermercados.map((superm) {
                          final bool esElMasBarato = (superm == superMasBarato);
                          final double totalSuper = totales[superm] ?? 0.0;
                          return Column(
                            children: [
                              Icon(
                                Icons.storefront,
                                color: esElMasBarato
                                    ? Colors.green
                                    : Colors.grey,
                                size: esElMasBarato ? 35 : 25,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                superm,
                                style: TextStyle(
                                  fontWeight: esElMasBarato
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: esElMasBarato
                                      ? Colors.green
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                '\$${totalSuper.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: esElMasBarato ? 22 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: esElMasBarato
                                      ? Colors.green
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '* Precios estimados de referencia. Pueden variar según sucursal, promociones y marca.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        color: Colors.blue.shade700,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tip: ¡Mantén tu Despensa actualizada! Así sabrás con exactitud qué ingredientes desmarcar de esta lista para ahorrar más.',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Desmarca lo que ya tienes en casa:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: ingredientesDinamicos.length,
                    itemBuilder: (context, index) {
                      final item = ingredientesDinamicos[index];
                      final double cant = (item['cantidad'] is num)
                          ? (item['cantidad'] as num).toDouble()
                          : 1.0;
                      final double cantCalculada = cant * multiplicadorActual;
                      final String presentacionComercial =
                          ConversorUnidades.normalizarParaSupermercado(
                            item['nombre'],
                            cantCalculada,
                            item['unidad'] ?? 'pza',
                          ).textoCantidad;

                      final double precioRef = calcularSubtotalItem(
                        item,
                        superMasBarato.isNotEmpty ? superMasBarato : 'Walmart',
                      );

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: CheckboxListTile(
                          activeColor: Colors.green,
                          title: Text(
                            item['nombre'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              decoration: item['incluir']
                                  ? null
                                  : TextDecoration.lineThrough,
                              color: item['incluir']
                                  ? Colors.black87
                                  : Colors.grey,
                            ),
                          ),
                          subtitle: Text(
                            item['incluir']
                                ? '$presentacionComercial • ~\$${precioRef.toStringAsFixed(2)} MXN'
                                : 'Ya lo tengo en despensa',
                            style: TextStyle(
                              color: item['incluir']
                                  ? Colors.green[700]
                                  : Colors.grey,
                              fontWeight: item['incluir']
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          value: item['incluir'],
                          onChanged: (bool? valor) =>
                              setState(() => item['incluir'] = valor ?? false),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
