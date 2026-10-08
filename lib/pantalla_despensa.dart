import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversor_unidades.dart';
import 'pantalla_chef.dart';
import 'servicio_ia.dart';
import 'menu_lateral.dart';

class PantallaDespensa extends StatefulWidget {
  const PantallaDespensa({super.key});

  @override
  State<PantallaDespensa> createState() => _PantallaDespensaState();
}

class _PantallaDespensaState extends State<PantallaDespensa> {
  final TextEditingController _itemController = TextEditingController();
  bool procesandoTicket = false;

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _agregarManual() async {
    final texto = _itemController.text.trim();
    if (texto.isEmpty) return;

    try {
      final parsed = ConversorUnidades.parsearLineaIngrediente(texto);
      await Supabase.instance.client.from('despensa_usuario').insert({
        'nombre': parsed.nombre,
        'cantidad': parsed.cantidad,
        'fecha_ingreso': DateTime.now().toIso8601String().split('T')[0],
      });

      _itemController.clear();
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
    final XFile? foto = await picker.pickImage(
      source: origen,
      imageQuality: 85,
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
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú principal',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Mi Despensa 🥫',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
        actions: [
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
        label: const Text(
          'Escanear Ticket',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
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
          ),
          const Divider(height: 1),
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

                final despensa = snapshot.data ?? [];

                if (despensa.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.kitchen_outlined,
                          size: 70,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Tu despensa está vacía',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Agrega ingredientes o escanea tu ticket de compra',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final List despensaItems = despensa;
                final porVencer = despensaItems.where((item) {
                  final fStr = item['fecha_ingreso']?.toString();
                  if (fStr == null) return false;
                  final dt = DateTime.tryParse(fStr);
                  if (dt == null) return false;
                  return DateTime.now().difference(dt).inDays >= 4;
                }).toList();

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
                                    '🚨 ${porVencer.length} ingrediente(s) por vencer',
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
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                        itemCount: despensaItems.length,
                        itemBuilder: (context, index) {
                          final item = despensaItems[index];
                          final idItem = item['id_item'];
                          final nombre = item['nombre'] ?? '';
                          final cant = item['cantidad'];
                          final cantidadTexto =
                              ConversorUnidades.formatearParaDespensa(nombre, cant);

                          final fStr = item['fecha_ingreso']?.toString();
                          final dt = fStr != null ? DateTime.tryParse(fStr) : null;
                          final int dias = dt != null ? DateTime.now().difference(dt).inDays : 0;

                          Color semaforoColor = Colors.green;
                          String semaforoTexto = 'Fresco 🟢';
                          if (dias >= 7) {
                            semaforoColor = Colors.red.shade700;
                            semaforoTexto = '¡Por vencer! (${dias}d) 🔴';
                          } else if (dias >= 4) {
                            semaforoColor = Colors.orange.shade800;
                            semaforoTexto = 'Consumir pronto (${dias}d) 🟡';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: semaforoColor.withValues(alpha: 0.1),
                                child: Icon(Icons.inventory_2, color: semaforoColor),
                              ),
                              title: Text(
                                nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Row(
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
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => _eliminarItem(idItem),
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
          ),
        ],
      ),
    );
  }
}
