import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversor_unidades.dart';
import 'pantalla_chef.dart';
import 'pantalla_sommelier.dart';
import 'servicio_ia.dart';
import 'servicio_hogar.dart';
import 'servicio_recordatorios.dart';
import 'servicio_zonas_despensa.dart';
import 'servicio_despensa.dart';
import 'menu_lateral.dart';

class PantallaDespensa extends StatefulWidget {
  const PantallaDespensa({super.key});

  @override
  State<PantallaDespensa> createState() => _PantallaDespensaState();
}

class _PantallaDespensaState extends State<PantallaDespensa> {
  final TextEditingController _itemController = TextEditingController();
  bool procesandoTicket = false;
  int _cantidadNueva = 1;
  String _filtroZona = 'Todos';
  bool _filtrarSoloPorVencer = false;
  ZonaDespensa? _zonaParaAgregarManual;
  Map<String, String> _overridesZonas = {};

  @override
  void initState() {
    super.initState();
    _cargarOverridesZonas();
  }

  Future<void> _cargarOverridesZonas() async {
    final ov = await ServicioZonasDespensa.obtenerOverrides();
    if (mounted) setState(() => _overridesZonas = ov);
  }

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _agregarManual() async {
    final texto = _itemController.text.trim();
    if (texto.isEmpty) return;

    try {
      // Si el usuario ya escribió una cantidad ("6 plátanos") se respeta;
      // de lo contrario se usa el selector de cantidad.
      final bool tieneNumeroInicial =
          RegExp(r'^\s*[-*•]?\s*\d').hasMatch(texto);
      final String textoFinal = (!tieneNumeroInicial && _cantidadNueva > 1)
          ? '$_cantidadNueva $texto'
          : texto;

      final parsed = ConversorUnidades.parsearLineaIngrediente(textoFinal);
      final res = await Supabase.instance.client.from('despensa_usuario').insert({
        'nombre': parsed.nombre,
        'cantidad': parsed.cantidad,
        'fecha_ingreso': DateTime.now().toIso8601String().split('T')[0],
      }).select();

      if (_zonaParaAgregarManual != null) {
        final itemGuardado = res.isNotEmpty ? res.first : {'nombre': parsed.nombre};
        await ServicioZonasDespensa.asignarZona(
          item: itemGuardado,
          nuevaZona: _zonaParaAgregarManual!,
        );
        await _cargarOverridesZonas();
      }

      _itemController.clear();
      if (mounted) {
        setState(() {
          _cantidadNueva = 1;
          _zonaParaAgregarManual = null;
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${parsed.textoCantidad} de ${parsed.nombre} agregado a la despensa ✅'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } catch (e) {
      debugPrint('Error al agregar ingrediente: $e');
    }
  }

  Future<void> _cambiarZonaItem(dynamic item, ZonaDespensa nuevaZona) async {
    await ServicioZonasDespensa.asignarZona(
      item: item,
      nuevaZona: nuevaZona,
    );
    await _cargarOverridesZonas();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${item['nombre']} guardado en ${nuevaZona.emoji} ${nuevaZona.nombre} 📍',
        ),
        backgroundColor: nuevaZona.color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _mostrarModalCambiarZona(dynamic item) {
    final zonaActual = ServicioZonasDespensa.resolverZona(item, _overridesZonas);
    final String nombre = item['nombre']?.toString() ?? 'Ingrediente';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: zonaActual.fondoColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(zonaActual.icono, color: zonaActual.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ubicación en tu Hogar 📍',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Elige la zona física donde guardas este alimento:',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                ...ZonaDespensa.values.map((zona) {
                  final bool esActual = zona == zonaActual;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: esActual ? zona.fondoColor : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: esActual ? zona.color : Colors.grey.shade200,
                        width: esActual ? 1.5 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Text(zona.emoji, style: const TextStyle(fontSize: 22)),
                      title: Text(
                        zona.nombre,
                        style: TextStyle(
                          fontWeight: esActual ? FontWeight.bold : FontWeight.w600,
                          color: esActual ? zona.color : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        zona.descripcionCorta,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      trailing: esActual
                          ? Icon(Icons.check_circle_rounded, color: zona.color)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _cambiarZonaItem(item, zona);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _botonCantidad({
    required IconData icono,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red.shade800,
          shape: const CircleBorder(),
        ),
        icon: Icon(icono, size: 18),
        onPressed: onPressed,
      ),
    );
  }

  double _aDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 1.0;
  }

  Future<void> _guardarCantidad(dynamic idItem, double cantidad) async {
    try {
      await Supabase.instance.client
          .from('despensa_usuario')
          .update({'cantidad': cantidad})
          .eq('id_item', idItem);
    } catch (e) {
      debugPrint('Error al actualizar cantidad: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar la cantidad: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Aumenta o disminuye la cantidad *mostrada* de un ingrediente (piezas, kg, L...).
  /// Como la cantidad guardada se normaliza al mostrarse (ej. ajo → cabezas),
  /// se avanza el valor guardado hasta que la cantidad visible cambie.
  Future<void> _ajustarCantidad(dynamic item, int delta) async {
    final String nombre = (item['nombre'] ?? '').toString();
    final double guardada = _aDouble(item['cantidad']);
    final actual = ConversorUnidades.normalizarItemDespensa(nombre, guardada);
    // Frutas y verduras: un paso = peso de 1 pieza (múltiplo de 0.05 kg).
    final double paso = ConversorUnidades.esFrutaOVerduraPorKilo(nombre)
        ? ConversorUnidades.pasoKgFrutaVerdura(nombre)
        : ((actual.unidad == 'kg' || actual.unidad == 'L') ? 0.25 : 1.0);

    double candidata = guardada;
    bool cambio = false;
    for (int i = 0; i < 80; i++) {
      candidata = ((candidata + delta * paso) * 100).round() / 100.0;
      if (candidata <= 0) break;
      final nueva = ConversorUnidades.normalizarItemDespensa(nombre, candidata);
      if ((delta > 0 && nueva.cantidad > actual.cantidad) ||
          (delta < 0 && nueva.cantidad < actual.cantidad)) {
        cambio = true;
        break;
      }
    }

    if (!cambio) {
      if (delta < 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Es la cantidad mínima. Usa el bote 🗑️ para quitarlo.'),
          ),
        );
      }
      return;
    }
    await _guardarCantidad(item['id_item'], candidata);
  }

  /// Permite escribir una cantidad exacta (ej. 6 plátanos, 1.5 kg).
  Future<void> _editarCantidadManual(dynamic item) async {
    final String nombre = (item['nombre'] ?? '').toString();
    final double guardada = _aDouble(item['cantidad']);
    final actual = ConversorUnidades.normalizarItemDespensa(nombre, guardada);
    final String sugerido = actual.cantidad == actual.cantidad.toInt()
        ? actual.cantidad.toInt().toString()
        : actual.cantidad.toString();
    final ctrl = TextEditingController(text: sugerido);

    final String? resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cantidad de $nombre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actual: ${ConversorUnidades.formatearParaDespensa(nombre, guardada)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Nueva cantidad (${actual.unidad.isEmpty ? 'pzas' : actual.unidad})',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (resultado == null) return;
    final double? n = double.tryParse(resultado.trim().replaceAll(',', '.'));
    if (n == null || n <= 0) return;

    // Se re-parsea con la misma lógica que la captura manual para que cada
    // tipo de ingrediente guarde la cantidad en su propia unidad.
    final String unidadTexto =
        (actual.unidad == 'kg' || actual.unidad == 'L') ? '${actual.unidad} ' : '';
    final parsed = ConversorUnidades.parsearLineaIngrediente(
      '$n $unidadTexto$nombre',
    );
    await _guardarCantidad(item['id_item'], parsed.cantidad);
  }

  Future<void> _eliminarItem(dynamic idItem) async {
    try {
      await Supabase.instance.client
          .from('despensa_usuario')
          .delete()
          .eq('id_item', idItem);
    } catch (e) {
      debugPrint('Error al eliminar ingrediente: $e');
    }
  }

  Future<void> _escanearTicket(ImageSource origen) async {
    final picker = ImagePicker();
    // Prioridad R2: Compresión y optimización en cliente (ahorro de datos y velocidad 3x)
    final XFile? foto = await picker.pickImage(
      source: origen,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (foto == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.red.shade800),
                const SizedBox(height: 15),
                const Text(
                  'Extrayendo alimentos y precios... 🧾🔍',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final bytes = await foto.readAsBytes();
      final resultado = await ServicioIA.leerTicketSupermercado(bytes);

      if (!mounted) return;
      Navigator.pop(context);

      if (resultado != null &&
          resultado['articulos'] != null &&
          (resultado['articulos'] as List).isNotEmpty) {
        _mostrarBandejaConfirmacionTicket(resultado);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No encontramos alimentos en el ticket. Intenta con una toma más cercana.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      debugPrint('Error al procesar ticket: $e');
    }
  }

  void _mostrarOpcionesOrigenTicket() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Escanear Ticket de Compra 🧾',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade800,
                    child: const Icon(Icons.camera_alt, color: Colors.white),
                  ),
                  title: const Text(
                    'Tomar foto al ticket con la cámara',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Walmart, Soriana, La Comer, Chedraui...',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _escanearTicket(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade50,
                    child: Icon(
                      Icons.photo_library,
                      color: Colors.red.shade800,
                    ),
                  ),
                  title: const Text(
                    'Elegir foto de la galería',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Sube un comprobante o foto guardada'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _escanearTicket(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarBandejaConfirmacionTicket(Map<String, dynamic> datosTicket) {
    String superDetectado =
        datosTicket['supermercado']?.toString() ?? 'Walmart';
    final List articulos = List.from(datosTicket['articulos'] ?? []);
    final Map<int, bool> seleccionados = {};

    for (int i = 0; i < articulos.length; i++) {
      seleccionados[i] = true;
    }

    final listaCadenas = [
      'Walmart',
      'Soriana',
      'La Comer',
      'Chedraui',
      'Costco',
      "Sam's Club",
    ];
    if (!listaCadenas.contains(superDetectado)) {
      superDetectado = 'Walmart';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (contextDialog) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: Colors.red.shade800,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Ticket Digitalizado',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Supermercado:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: DropdownButton<String>(
                            value: superDetectado,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: listaCadenas.map((cadena) {
                              return DropdownMenuItem(
                                value: cadena,
                                child: Text(cadena),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setStateModal(() => superDetectado = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Desmarca lo que no desees ingresar:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: articulos.length,
                      itemBuilder: (context, index) {
                        final art = articulos[index];
                        final nombre = art['nombre']?.toString() ?? 'Artículo';
                        final double precio =
                            double.tryParse(art['precio'].toString()) ?? 0.0;
                        final bool check = seleccionados[index] ?? true;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CheckboxListTile(
                            activeColor: Colors.red.shade800,
                            value: check,
                            title: Text(
                              nombre,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '\$${precio.toStringAsFixed(2)} MXN',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onChanged: (val) {
                              setStateModal(() {
                                seleccionados[index] = val ?? false;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(contextDialog);
                        await _guardarTicketEnDespensaYPrecios(
                          superDetectado,
                          articulos,
                          seleccionados,
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text(
                        'Guardar en Despensa y Cotizador 💾',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _guardarTicketEnDespensaYPrecios(
    String nombreSuper,
    List articulos,
    Map<int, bool> seleccionados,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final supabase = Supabase.instance.client;
    int guardados = 0;

    try {
      final resSuper = await supabase
          .from('supermercados')
          .select('id_supermercado')
          .ilike('nombre', '%$nombreSuper%')
          .limit(1);

      int? idSuper;
      if (resSuper.isNotEmpty) {
        idSuper = resSuper[0]['id_supermercado'];
      }

      for (int i = 0; i < articulos.length; i++) {
        if (seleccionados[i] != true) continue;

        final art = articulos[i];
        final String nombre = art['nombre'].toString().trim();
        final double precio = double.tryParse(art['precio'].toString()) ?? 0.0;
        final itemNorm = ConversorUnidades.parsearLineaIngrediente(nombre);

        await supabase.from('despensa_usuario').insert({
          'nombre': itemNorm.nombre,
          'cantidad': itemNorm.cantidad,
          'precio': precio,
          'fecha_ingreso': DateTime.now().toIso8601String().split('T')[0],
        });

        if (idSuper != null) {
          final resGen = await supabase
              .from('ingredientes_genericos')
              .select('id_ingrediente')
              .ilike('nombre_estandar', '%$nombre%')
              .limit(1);

          int? idGen;
          if (resGen.isNotEmpty) {
            idGen = resGen[0]['id_ingrediente'];
          } else {
            final nuevoGen = await supabase
                .from('ingredientes_genericos')
                .insert({'nombre_estandar': nombre})
                .select('id_ingrediente')
                .single();
            idGen = nuevoGen['id_ingrediente'];
          }

          if (idGen != null && precio > 0) {
            final precioExistente = await supabase
                .from('precios_supermercado')
                .select('id_precio')
                .eq('id_ingrediente', idGen)
                .eq('id_supermercado', idSuper)
                .limit(1);

            if (precioExistente.isNotEmpty) {
              await supabase
                  .from('precios_supermercado')
                  .update({'precio': precio})
                  .eq('id_precio', precioExistente[0]['id_precio']);
            } else {
              await supabase.from('precios_supermercado').insert({
                'id_ingrediente': idGen,
                'id_supermercado': idSuper,
                'precio': precio,
              });
            }
          }
        }
        guardados++;
      }

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '¡$guardados artículos guardados en Despensa y actualizados en $nombreSuper! 🎉',
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } catch (e) {
      debugPrint('Error guardando ticket: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al guardar datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const MenuLateral(rutaActual: 'despensa'),
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
            'Mi Despensa 🥫',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: const Color(0xFF1E2022),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.family_restroom_rounded),
            tooltip: 'Hogar Familiar Compartido',
            onPressed: () => ModalHogarFamiliar.mostrar(
              context,
              onHogarCambiado: () {
                if (mounted) setState(() {});
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.ac_unit_rounded),
            tooltip: 'Guía de Descongelado Seguro 🧊',
            onPressed: () =>
                ServicioRecordatorios.mostrarModalTipsDescongelado(context),
          ),
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Escanear ticket de compra',
            onPressed: _mostrarOpcionesOrigenTicket,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarOpcionesOrigenTicket,
        backgroundColor: Colors.red.shade800,
        icon: const Icon(Icons.receipt_long, color: Colors.white),
        label: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Escanear Ticket',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: Column(
        children: [
          Builder(
            builder: (context) {
              final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
              return Container(
                padding: EdgeInsets.fromLTRB(16, isLandscape ? 8 : 16, 16, isLandscape ? 4 : 8),
                color: Colors.white,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _itemController,
                            decoration: InputDecoration(
                              hintText: 'Agregar ingrediente a mano...',
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(15),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _agregarManual(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _agregarManual,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                          ),
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Cantidad a agregar:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _botonCantidad(
                          icono: Icons.remove,
                          tooltip: 'Menos',
                          onPressed: () {
                            if (_cantidadNueva > 1) {
                              setState(() => _cantidadNueva--);
                            }
                          },
                        ),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '$_cantidadNueva',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _botonCantidad(
                          icono: Icons.add,
                          tooltip: 'Más',
                          onPressed: () => setState(() => _cantidadNueva++),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'o escribe "6 plátanos"',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Zona:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('Auto ⚡', style: TextStyle(fontSize: 11)),
                              selected: _zonaParaAgregarManual == null,
                              selectedColor: Colors.grey.shade800,
                              labelStyle: TextStyle(
                                color: _zonaParaAgregarManual == null
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: _zonaParaAgregarManual == null
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _zonaParaAgregarManual = null);
                              },
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('❄️ Refri', style: TextStyle(fontSize: 11)),
                              selected:
                                  _zonaParaAgregarManual == ZonaDespensa.refrigerador,
                              selectedColor: ZonaDespensa.refrigerador.color,
                              labelStyle: TextStyle(
                                color: _zonaParaAgregarManual ==
                                        ZonaDespensa.refrigerador
                                    ? Colors.white
                                    : Colors.blue.shade900,
                                fontWeight: _zonaParaAgregarManual ==
                                        ZonaDespensa.refrigerador
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _zonaParaAgregarManual =
                                      ZonaDespensa.refrigerador);
                                }
                              },
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label:
                                  const Text('🧊 Congelador', style: TextStyle(fontSize: 11)),
                              selected:
                                  _zonaParaAgregarManual == ZonaDespensa.congelador,
                              selectedColor: ZonaDespensa.congelador.color,
                              labelStyle: TextStyle(
                                color: _zonaParaAgregarManual ==
                                        ZonaDespensa.congelador
                                    ? Colors.white
                                    : Colors.cyan.shade900,
                                fontWeight: _zonaParaAgregarManual ==
                                        ZonaDespensa.congelador
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _zonaParaAgregarManual =
                                      ZonaDespensa.congelador);
                                }
                              },
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              visualDensity: VisualDensity.compact,
                              label: const Text('🥫 Alacena', style: TextStyle(fontSize: 11)),
                              selected: _zonaParaAgregarManual == ZonaDespensa.alacena,
                              selectedColor: ZonaDespensa.alacena.color,
                              labelStyle: TextStyle(
                                color: _zonaParaAgregarManual == ZonaDespensa.alacena
                                    ? Colors.white
                                    : Colors.amber.shade900,
                                fontWeight: _zonaParaAgregarManual ==
                                        ZonaDespensa.alacena
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setState(() =>
                                      _zonaParaAgregarManual = ZonaDespensa.alacena);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      const Divider(height: 1),
          BannerHogarFamiliar(
            onHogarActualizado: () {
              if (mounted) setState(() {});
            },
          ),
          Expanded(
            child: StreamBuilder(
              stream: Supabase.instance.client
                  .from('despensa_usuario')
                  .stream(primaryKey: ['id_item'])
                  .order('id_item', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.red.shade800,
                    ),
                  );
                }

                final despensaRaw = snapshot.data ?? [];
                final Map<ZonaDespensa, int> conteos =
                    ServicioZonasDespensa.contarPorZonas(
                        despensaRaw, _overridesZonas);
                final despensa = despensaRaw
                    .where((item) => _pasaFiltro(item))
                    .toList();

                return Column(
                  children: [
                    _construirFiltrosZonas(conteos, despensaRaw.length),
                    if (_filtroZona == 'Todos' && despensaRaw.isNotEmpty)
                      _construirBarraResumenZonas(conteos, despensaRaw.length),
                    _construirBannerZona(
                      _filtroZona,
                      _filtroZona == 'congelador'
                          ? (conteos[ZonaDespensa.congelador] ?? 0)
                          : (_filtroZona == 'refrigerador'
                              ? (conteos[ZonaDespensa.refrigerador] ?? 0)
                              : (_filtroZona == 'cava'
                                  ? (conteos[ZonaDespensa.cava] ?? 0)
                                  : (conteos[ZonaDespensa.alacena] ?? 0))),
                    ),
                    Expanded(
                      child: despensa.isEmpty
                          ? RefreshIndicator(
                              color: Colors.red.shade800,
                              onRefresh: () async {
                                if (mounted) setState(() {});
                                await Future.delayed(
                                    const Duration(milliseconds: 300));
                              },
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height * 0.45,
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _filtroZona == 'cava'
                                                ? Icons.wine_bar
                                                : (_filtroZona == 'congelador'
                                                    ? Icons.ac_unit_rounded
                                                    : (_filtroZona == 'refrigerador'
                                                        ? Icons.kitchen_rounded
                                                        : Icons.inventory_2_outlined)),
                                            size: 70,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 15),
                                          Text(
                                            _obtenerTituloVacioZona(_filtroZona),
                                            style: const TextStyle(
                                              fontSize: 17,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            _obtenerSubtituloVacioZona(_filtroZona),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _construirListaDespensa(despensa),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _pasaFiltro(dynamic item) {
    if (_filtroZona == 'Todos') return true;
    final zona = ServicioZonasDespensa.resolverZona(item, _overridesZonas);
    return zona.id == _filtroZona;
  }

  Widget _construirFiltrosZonas(Map<ZonaDespensa, int> conteos, int total) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          ChoiceChip(
            label: Text(
              'Todos ($total)',
              style: TextStyle(
                fontWeight: _filtroZona == 'Todos' ? FontWeight.bold : FontWeight.normal,
                color: _filtroZona == 'Todos' ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
            ),
            selected: _filtroZona == 'Todos',
            selectedColor: Colors.red.shade700,
            backgroundColor: Colors.grey.shade100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: _filtroZona == 'Todos' ? Colors.transparent : Colors.grey.shade300,
              ),
            ),
            onSelected: (val) {
              if (val) setState(() => _filtroZona = 'Todos');
            },
          ),
          const SizedBox(width: 8),
          ...ZonaDespensa.values.map((zona) {
            final bool seleccionada = _filtroZona == zona.id;
            final int count = conteos[zona] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Text(zona.emoji, style: const TextStyle(fontSize: 14)),
                label: Text(
                  '${zona.nombre} ($count)',
                  style: TextStyle(
                    fontWeight: seleccionada ? FontWeight.bold : FontWeight.w600,
                    color: seleccionada ? Colors.white : zona.color,
                    fontSize: 12,
                  ),
                ),
                selected: seleccionada,
                selectedColor: zona.color,
                backgroundColor: zona.fondoColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: seleccionada
                        ? Colors.transparent
                        : zona.color.withValues(alpha: 0.35),
                  ),
                ),
                onSelected: (val) {
                  if (val) setState(() => _filtroZona = zona.id);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _construirBarraResumenZonas(Map<ZonaDespensa, int> conteos, int total) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ZonaDespensa.values.map((zona) {
          final int count = conteos[zona] ?? 0;
          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _filtroZona = zona.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                children: [
                  Text(zona.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    zona.nombre,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: zona.fondoColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: zona.color.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: zona.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _construirBannerZona(String filtro, int cantidad) {
    if (filtro == 'cava') {
      return _construirBannerCavaBar();
    }
    if (filtro == 'congelador') {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.cyan.shade900, Colors.teal.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.cyan.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.ac_unit_rounded, color: Colors.cyanAccent, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '🧊 Congelador Inteligente ($cantidad items)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Text(
                    'Porciones de Batch Cooking, carnes y verduras listas para semanas futuras.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (filtro == 'refrigerador') {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade900, Colors.indigo.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.kitchen_rounded, color: Colors.lightBlueAccent, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '❄️ Refrigerador ($cantidad items)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Text(
                    'Perecederos, lácteos y verduras frescas en monitoreo activo de vida útil.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    if (filtro == 'alacena') {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade900, Colors.brown.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inventory_2_rounded, color: Colors.amberAccent, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '🥫 Alacena Seca ($cantidad items)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Text(
                    'Granos, pastas, especias y enlatados de larga conservación.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  String _obtenerTituloVacioZona(String filtro) {
    switch (filtro) {
      case 'cava':
        return 'Tu Cava & Bar está vacía 🍾';
      case 'congelador':
        return 'Tu Congelador está vacío 🧊';
      case 'refrigerador':
        return 'Tu Refrigerador está vacío ❄️';
      case 'alacena':
        return 'Tu Alacena Seca está vacía 🥫';
      default:
        return 'Tu despensa está vacía 🧺';
    }
  }

  String _obtenerSubtituloVacioZona(String filtro) {
    switch (filtro) {
      case 'cava':
        return 'Agrega botellas de vino, cerveza o licores para recibir maridajes inteligentes.';
      case 'congelador':
        return 'Guarda tus porciones de batch cooking, carnes o verduras congeladas.';
      case 'refrigerador':
        return 'Agrega tus alimentos frescos y perecederos para monitorear su frescura.';
      case 'alacena':
        return 'Agrega granos, pastas, especias o enlatados de larga duración.';
      default:
        return 'Agrega tus primeros ingredientes arriba o escanea un ticket de compra.';
    }
  }

  Widget _construirListaDespensa(List despensaItems) {
    final porVencer = despensaItems.where((item) {
      final frescura = ServicioDespensa.evaluarFrescuraItem(Map<String, dynamic>.from(item));
      return frescura.esAlerta;
    }).toList();

    final itemsFiltrados = _filtrarSoloPorVencer
        ? despensaItems.where((item) {
            final frescura = ServicioDespensa.evaluarFrescuraItem(Map<String, dynamic>.from(item));
            return frescura.esAlerta;
          }).toList()
        : despensaItems;

    return Column(
      children: [
        if (porVencer.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amber.shade400,
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.deepOrange,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🚨 ${porVencer.length} ingrediente(s) por vencer / consumir pronto',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.brown.shade900,
                        ),
                      ),
                      Text(
                        porVencer.map((i) => i['nombre']).take(3).join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.brown.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() => _filtrarSoloPorVencer = !_filtrarSoloPorVencer),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      color: _filtrarSoloPorVencer ? Colors.brown.shade800 : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade600),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _filtrarSoloPorVencer ? Icons.check : Icons.filter_alt_outlined,
                          size: 14,
                          color: _filtrarSoloPorVencer ? Colors.white : Colors.brown.shade900,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _filtrarSoloPorVencer ? 'Ver todos' : 'Filtrar',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _filtrarSoloPorVencer ? Colors.white : Colors.brown.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final listaNombres = porVencer
                        .map((i) => i['nombre'])
                        .join(', ');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PantallaChef(
                          ingredientesIniciales: listaNombres,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text(
                    'Rescatar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: Colors.red.shade800,
            onRefresh: () async {
              if (mounted) setState(() {});
              await Future.delayed(const Duration(milliseconds: 300));
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              itemCount: itemsFiltrados.length,
              itemBuilder: (context, index) {
                final item = itemsFiltrados[index];
                final idItem = item['id_item'];
                final nombre = item['nombre'] ?? '';
                final cant = item['cantidad'];
                final cantidadTexto =
                    ConversorUnidades.formatearParaDespensa(nombre, cant);

                final frescura = ServicioDespensa.evaluarFrescuraItem(Map<String, dynamic>.from(item));
                Color semaforoColor = Colors.green;
                if (frescura.nivel == NivelFrescura.porVencer) {
                  semaforoColor = Colors.red.shade700;
                } else if (frescura.nivel == NivelFrescura.consumirPronto) {
                  semaforoColor = Colors.orange.shade800;
                }
                final semaforoTexto = frescura.etiqueta;

                final zona = ServicioZonasDespensa.resolverZona(item, _overridesZonas);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: zona.fondoColor,
                      child: Icon(zona.icono, color: zona.color, size: 22),
                    ),
                    title: Text(
                      nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              cantidadTexto,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '• $semaforoTexto',
                              style: TextStyle(
                                color: semaforoColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _mostrarModalCambiarZona(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: zona.fondoColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: zona.color.withValues(alpha: 0.35),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(zona.emoji, style: const TextStyle(fontSize: 11)),
                                const SizedBox(width: 4),
                                Text(
                                  zona.nombre,
                                  style: TextStyle(
                                    color: zona.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.arrow_drop_down, size: 14, color: zona.color),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _botonCantidad(
                          icono: Icons.remove,
                          tooltip: 'Disminuir cantidad',
                          onPressed: () =>
                              _ajustarCantidad(item, -1),
                        ),
                        _botonCantidad(
                          icono: Icons.add,
                          tooltip: 'Aumentar cantidad',
                          onPressed: () =>
                              _ajustarCantidad(item, 1),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _eliminarItem(idItem),
                        ),
                      ],
                    ),
                    onTap: () => _editarCantidadManual(item),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }


  Widget _construirBannerCavaBar() {
    final botellasComunes = [
      'Vino Tinto',
      'Vino Blanco',
      'Cerveza',
      'Tequila',
      'Mezcal',
      'Ginebra',
      'Agua Tónica',
      'Ron',
      'Whisky',
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF380B17),
            Color(0xFF5B1228),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5B1228).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wine_bar,
                  color: Color(0xFFFFD700),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Mi Cava & Bar en Casa',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const Text(
                      'Sincronizado con el Sommelier IA para maridar tus platillos',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: const Color(0xFF380B17),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Sommelier',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PantallaSommelier(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Agregar botella rápida a tu cava:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: botellasComunes.map((botella) {
              return ActionChip(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                avatar: const Icon(
                  Icons.add,
                  size: 14,
                  color: Color(0xFFFFD700),
                ),
                label: Text(
                  botella,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
                onPressed: () => _agregarBotellaCava(botella),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _agregarBotellaCava(String nombre) async {
    try {
      await Supabase.instance.client.from('despensa_usuario').insert({
        'nombre': nombre,
        'cantidad': 1,
        'fecha_ingreso': DateTime.now().toIso8601String().split('T')[0],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$nombre agregado a tu Cava & Bar 🍾🍷'),
          backgroundColor: const Color(0xFF5B1228),
        ),
      );
    } catch (e) {
      debugPrint('Error al agregar botella: $e');
    }
  }
}

