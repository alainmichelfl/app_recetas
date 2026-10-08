import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pantalla_cotizador.dart';
import 'pantalla_carrito.dart';
import 'pantalla_planeador.dart';
import 'conversor_unidades.dart';

class PantallaDetalle extends StatefulWidget {
  final int idReceta;
  final String titulo;
  final String imagenUrl;
  final String instrucciones;
  final int porcionesOriginales;

  const PantallaDetalle({
    super.key,
    required this.idReceta,
    required this.titulo,
    required this.imagenUrl,
    required this.instrucciones,
    required this.porcionesOriginales,
  });

  @override
  State<PantallaDetalle> createState() => _PantallaDetalleState();
}

class _PantallaDetalleState extends State<PantallaDetalle> {
  List<dynamic> ingredientes = [];
  bool cargando = true;
  late int porcionesDeseadas;

  @override
  void initState() {
    super.initState();
    porcionesDeseadas = widget.porcionesOriginales > 0
        ? widget.porcionesOriginales
        : 1;
    cargarIngredientes();
  }

  Future<void> cargarIngredientes() async {
    try {
      final respuesta = await Supabase.instance.client
          .from('receta_detalle')
          .select(
            'cantidad, unidad_medida, ingredientes_genericos (nombre_estandar)',
          )
          .eq('id_receta', widget.idReceta);
      setState(() {
        ingredientes = respuesta;
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar ingredientes: $e');
      setState(() => cargando = false);
    }
  }

  Future<void> guardarEnCarrito(double multiplicador) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.deepOrange),
      ),
    );
    try {
      for (var ing in ingredientes) {
        final nombre = ing['ingredientes_genericos']?['nombre_estandar'] ?? 'Ingrediente';
        if (ConversorUnidades.esAgua(nombre)) continue;
        final unidad = ing['unidad_medida'] ?? 'pza';
        final cantidadBase = (ing['cantidad'] is int)
            ? (ing['cantidad'] as int).toDouble()
            : double.tryParse(ing['cantidad'].toString()) ?? 1.0;
        final cantidadCalculada = cantidadBase * multiplicador;
        final itemNorm = ConversorUnidades.normalizarParaSupermercado(
          nombre,
          cantidadCalculada,
          unidad,
        );
        if (ConversorUnidades.esAgua(itemNorm.nombre) || itemNorm.cantidad <= 0) continue;
        await ConversorUnidades.agregarOActualizarItemEnCarrito(
          Supabase.instance.client,
          itemNorm,
        );
      }
      // Aquí SÍ va !mounted porque estamos en las funciones del State
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Ingredientes guardados!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'VER LISTA',
            textColor: Colors.white,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PantallaCarrito()),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      debugPrint('Error al guardar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final multiplicador =
        porcionesDeseadas /
        (widget.porcionesOriginales > 0 ? widget.porcionesOriginales : 1);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.titulo),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Mi Planeador',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PantallaPlaneador(),
              ),
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.imagenUrl.isNotEmpty)
              Image.network(
                widget.imagenUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.restaurant,
                          color: Colors.deepOrange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Porciones:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                        const SizedBox(width: 15),
                        InkWell(
                          onTap: () {
                            if (porcionesDeseadas > 1) {
                              setState(() => porcionesDeseadas--);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Text(
                          '$porcionesDeseadas',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 15),
                        InkWell(
                          onTap: () => setState(() => porcionesDeseadas++),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    '🛒 Ingredientes',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (cargando)
                    const Center(child: CircularProgressIndicator())
                  else if (ingredientes.isEmpty)
                    const Text(
                      'No hay ingredientes registrados.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ingredientes.length,
                      itemBuilder: (context, index) {
                        final ing = ingredientes[index];
                        final nombre =
                            ing['ingredientes_genericos']['nombre_estandar'];
                        final unidad = ing['unidad_medida'];
                        final cantidadBase = (ing['cantidad'] is int)
                            ? (ing['cantidad'] as int).toDouble()
                            : double.tryParse(ing['cantidad'].toString()) ??
                                  1.0;
                        final cantidadCalculada = cantidadBase * multiplicador;
                        final cantidadMostrar =
                            cantidadCalculada ==
                                cantidadCalculada.roundToDouble()
                            ? cantidadCalculada.toInt().toString()
                            : cantidadCalculada.toStringAsFixed(1);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          title: Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Text(
                            '$cantidadMostrar $unidad',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  const Divider(height: 40, thickness: 1),
                  const Text(
                    '👨‍🍳 Procedimiento',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  ...widget.instrucciones
                      .split(RegExp(r'(?=\d+\.)'))
                      .where((paso) => paso.trim().isNotEmpty)
                      .map((paso) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.outdoor_grill,
                                color: Colors.deepOrange,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  paso.trim(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                  const SizedBox(height: 40),
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PantallaCotizador(
                                idReceta: widget.idReceta,
                                titulo: widget.titulo,
                                multiplicador: multiplicador,
                              ),
                            ),
                          ),
                          icon: const Icon(
                            Icons.calculate,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Cotizar esta receta',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final DateTime? fechaElegida = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (fechaElegida != null) {
                              // 🚨 CORRECCIÓN: Aquí regresamos a !context.mounted
                              if (!context.mounted) return;
                              final String? tipo = await showDialog<String>(
                                context: context,
                                builder: (context) => SimpleDialog(
                                  title: const Text('¿Para qué comida?'),
                                  children: [
                                    SimpleDialogOption(
                                      onPressed: () =>
                                          Navigator.pop(context, 'Desayuno'),
                                      child: const Text(
                                        '🍳 Desayuno',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ),
                                    SimpleDialogOption(
                                      onPressed: () =>
                                          Navigator.pop(context, 'Comida'),
                                      child: const Text(
                                        '🍲 Comida',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ),
                                    SimpleDialogOption(
                                      onPressed: () =>
                                          Navigator.pop(context, 'Cena'),
                                      child: const Text(
                                        '🌙 Cena',
                                        style: TextStyle(fontSize: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              if (tipo != null) {
                                await Supabase.instance.client
                                    .from('planeador')
                                    .insert({
                                      'fecha': fechaElegida
                                          .toIso8601String()
                                          .split('T')[0],
                                      'tipo_comida': tipo,
                                      'id_receta': widget.idReceta,
                                    });
                                // 🚨 CORRECCIÓN: Aquí también usamos !context.mounted
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '¡Agendado en tu planeador! 📅',
                                    ),
                                    backgroundColor: Colors.deepPurple,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.calendar_month,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Agendar en Planeador',
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
                          onPressed: () => guardarEnCarrito(multiplicador),
                          icon: const Icon(
                            Icons.add_shopping_cart,
                            color: Colors.deepOrange,
                          ),
                          label: const Text(
                            'Guardar ingredientes en mi lista',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Colors.deepOrange,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
