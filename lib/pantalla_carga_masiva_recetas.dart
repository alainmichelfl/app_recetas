import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config_api.dart';
import 'servicio_admin.dart';
import 'servicio_recetas.dart';
import 'servicio_temporadas_mexico.dart';

class PantallaCargaMasivaRecetas extends StatefulWidget {
  const PantallaCargaMasivaRecetas({super.key});

  @override
  State<PantallaCargaMasivaRecetas> createState() =>
      _PantallaCargaMasivaRecetasState();
}

class _PantallaCargaMasivaRecetasState
    extends State<PantallaCargaMasivaRecetas> {
  late TemporadaMes _temporadaSeleccionada;
  late final TextEditingController _temaController;

  bool _generandoIA = false;
  bool _insertandoEnBd = false;
  double _progresoInsercion = 0.0;
  String _estadoInsercion = '';

  List<Map<String, dynamic>> _recetasGeneradas = [];
  String _filtroCategoria = 'Todos';

  @override
  void initState() {
    super.initState();
    _temporadaSeleccionada = ServicioTemporadasMexico.obtenerTemporadaActual();
    _temaController = TextEditingController(
      text: _temporadaSeleccionada.temaSugerido,
    );
    if (!ServicioAdmin.esAdmin()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Acceso denegado: solo para administradores.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  void dispose() {
    _temaController.dispose();
    super.dispose();
  }

  /// Asigna imágenes directas y verificadas de alta resolución de Unsplash según el platillo,
  /// evitando fotos no correspondientes (ej. hotcakes para guacamole) o placeholders rotos.
  static String _resolverImagenOptimizada(
    String titulo,
    String tipoComida,
    String? urlSugerida,
  ) {
    final t = titulo.toLowerCase();

    // 1. Detección específica por platillos tradicionales
    if (t.contains('picadillo') ||
        t.contains('carne molida') ||
        t.contains('bistec') ||
        t.contains('res')) {
      return 'https://images.unsplash.com/photo-1590655367923-fa80b7e61b6c?w=800';
    }
    if (t.contains('guacamole')) {
      return 'https://images.unsplash.com/photo-1680992071073-cb1696ba8d3e?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('chilaquil')) {
      return 'https://plus.unsplash.com/premium_photo-1661776841313-1bd2be380a64?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('avena') || t.contains('oatmeal') || t.contains('porridge')) {
      return 'https://plus.unsplash.com/premium_photo-1669559809547-6e4c4fe41371?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('pan francés') || t.contains('pan frances')) {
      return 'https://images.unsplash.com/photo-1584776296944-ab6fb57b0bdd?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('mollete')) {
      return 'https://images.unsplash.com/photo-1588137378633-dea1336ce1e2?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('pochado') || t.contains('poche') || (t.contains('huevo') && t.contains('aguacate'))) {
      return 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('omelette') || t.contains('huevo')) {
      return 'https://plus.unsplash.com/premium_photo-1667807521536-bc35c8d8b64b?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('pescado') ||
        t.contains('salmón') ||
        t.contains('salmon') ||
        t.contains('atún') ||
        t.contains('atun')) {
      return 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('tinga')) {
      return 'https://images.unsplash.com/photo-1552332386-f8dd00dc2f85?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('pollo') || t.contains('pechuga')) {
      return 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('lenteja')) {
      return 'https://plus.unsplash.com/premium_photo-1699030868880-d8970ccc146e?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('sopa') ||
        t.contains('crema') ||
        t.contains('caldo')) {
      return 'https://images.unsplash.com/photo-1603105037880-880cd4edfb0d?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('ensalada') || t.contains('caprese') || t.contains('quinoa')) {
      return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=600&q=80';
    }
    if (t.contains('perro') || t.contains('canin') || t.contains('lomito')) {
      return 'https://images.unsplash.com/photo-1678554500191-3885a6fbf8c2?auto=format&fit=crop&w=600&q=80';
    }

    // 2. Si la URL sugerida está explícitamente en nuestro catálogo verificado y no es un vinilo ni placeholder
    if (urlSugerida != null &&
        urlSugerida.trim().isNotEmpty &&
        !urlSugerida.contains('placeholder') &&
        !urlSugerida.contains('photo-1539185441755') &&
        !urlSugerida.contains('photo-1541288097308-7b8e3f58c4c6') &&
        (urlSugerida.contains('auto=format') || urlSugerida.contains('images.unsplash.com'))) {
      // Validar si concuerda con la semántica
      return ServicioRecetas.resolverImagenPorSemantica(titulo, tipoComida);
    }

    // 3. Fallback semántico determinista del banco gastronómico oficial
    return ServicioRecetas.resolverImagenPorSemantica(titulo, tipoComida);
  }

  Future<void> _generarLoteConGemini() async {
    final tema = _temaController.text.trim();
    if (tema.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, indica un tema o mes para el lote.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _generandoIA = true;
      _recetasGeneradas.clear();
    });

    try {
      final model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: ConfigApi.geminiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.7,
        ),
      );

      final prompt = '''
      Eres el chef ejecutivo y nutriólogo principal de la app "Jitomate y Cebolla".
      Tu objetivo es generar exactamente 20 recetas oficiales de alta calidad para el catálogo de la app.
      
      TEMA / ENFOQUE DEL MES: "$tema"
      
      ${ServicioTemporadasMexico.generarDirectrizEstacionalPrompt(_temporadaSeleccionada)}
      
      DISTRIBUCIÓN ESTRICTA (5 recetas por categoría):
      - Exactamente 5 recetas de "Desayuno"
      - Exactamente 5 recetas de "Comida"
      - Exactamente 5 recetas de "Cena"
      - Exactamente 5 recetas de "Snack"
      
      REGLAS DE FORMATO Y CONTENIDO:
      1. Títulos atractivos y variados (evita repeticiones).
      2. Ingredientes accesibles en supermercados mexicanos (Walmart, Soriana, La Comer, Central de Abasto).
      3. En "nombre_estandar" usa SIEMPRE minúsculas y el nombre base del ingrediente (ej. "huevo", "jitomate", "cebolla blanca", "aceite de oliva", "pechuga de pollo", "frijoles negros", "aguacate", "queso panela", "avena").
      4. UNIDADES: Usa "piezas", "kg", "L", "paquete", "lata" o "frasco". (NO uses gramos g ni mililitros ml).
      5. En "imagen_url", usa URLs directas y válidas de fotos de comida de Unsplash con formato WebP o jpg optimizado.
      6. CALORÍAS Y MACROS: Calcula valores nutricionales realistas para cada porción.
      7. DESGLOSE DE TIEMPO Y COCINA PRÁCTICA:
      - En "descripcion" incluye SIEMPRE al inicio el desglose: "Tiempo activo: X min | Cocción: Y min. Breve descripción apetitosa..."
      - Al menos 2 de las 5 recetas por categoría DEBEN ser Express (tiempo total ≤ 20 min) o técnicas Cero Trastes (1 sartén, air fryer o ensamble en frío).
      
      RESPONDE ÚNICAMENTE con un arreglo JSON de 20 objetos con esta estructura exacta:
      [
        {
          "titulo": "Huevos a la Mexicana con Frijoles de la Olla",
          "descripcion": "Tiempo activo: 5 min | Cocción: 8 min. Desayuno clásico balanceado, alto en proteína y fibra.",
          "tipo_comida": "Desayuno",
          "calorias": 380,
          "macros": "Proteína: 22g | Carbos: 28g | Grasas: 14g",
          "imagen_url": "https://images.unsplash.com/photo-1525351484163-7529414344d8?w=600",
          "ingredientes": [
            { "nombre_estandar": "huevo", "cantidad": 2.0, "unidad": "piezas" },
            { "nombre_estandar": "jitomate", "cantidad": 1.0, "unidad": "piezas" },
            { "nombre_estandar": "cebolla blanca", "cantidad": 0.5, "unidad": "piezas" },
            { "nombre_estandar": "chile serrano", "cantidad": 1.0, "unidad": "piezas" },
            { "nombre_estandar": "aceite de oliva", "cantidad": 0.02, "unidad": "L" }
          ],
          "instrucciones": "1. Picar finamente el jitomate, la cebolla y el chile serrano.\\n2. Calentar el aceite en un sartén y sofreír los vegetales por 3 minutos.\\n3. Batir los huevos con una pizca de sal y verter al sartén.\\n4. Cocinar a fuego medio revolviendo suavemente hasta que cuajen."
        }
      ]
      ''';

      final response = await model.generateContent([Content.text(prompt)]);
      String jsonStr = response.text ?? '[]';
      jsonStr = jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();

      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        final list = List<Map<String, dynamic>>.from(decoded);
        for (var item in list) {
          item['imagen_url'] = _resolverImagenOptimizada(
            item['titulo']?.toString() ?? '',
            item['tipo_comida']?.toString() ?? 'Comida',
            item['imagen_url']?.toString(),
          );
        }
        setState(() {
          _recetasGeneradas = list;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '¡Se generaron ${_recetasGeneradas.length} recetas oficiales listas para revisión! 🎉',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('La respuesta no fue una lista de recetas.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar con IA: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoIA = false);
    }
  }

  Future<void> _insertarRecetasEnCatalogoOficial() async {
    if (_recetasGeneradas.isEmpty) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.rocket_launch, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirmar Carga Masiva'),
          ],
        ),
        content: Text(
          '¿Deseas insertar ${_recetasGeneradas.length} recetas en el Catálogo Oficial de Jitomate y Cebolla?\n\n'
          '• Se marcarán como oficiales y públicas.\n'
          '• Sus ingredientes quedarán vinculados al Cotizador Dinámico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, Publicar Lote 🚀'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() {
      _insertandoEnBd = true;
      _progresoInsercion = 0.0;
      _estadoInsercion = 'Iniciando inserción...';
    });

    final supabase = Supabase.instance.client;
    int guardadas = 0;

    // 0. Rotación automática de "Recién Salidas del Sartén":
    // El lote anterior se archiva permanentemente en el Catálogo Oficial general (es_novedad = false)
    try {
      await supabase
          .from('recetas')
          .update({'es_novedad': false})
          .eq('es_novedad', true);
    } catch (e) {
      debugPrint('Aviso al archivar novedades previas en base de datos: $e');
    }

    try {
      for (int i = 0; i < _recetasGeneradas.length; i++) {
        final r = _recetasGeneradas[i];
        final String titulo = r['titulo']?.toString().trim() ?? 'Receta Oficial';
        final String tipoComida = r['tipo_comida']?.toString().trim() ?? 'Comida';
        final String instrucciones = r['instrucciones']?.toString().trim() ?? '';
        final String imagenUrl = _resolverImagenOptimizada(
          titulo,
          tipoComida,
          r['imagen_url']?.toString(),
        );
        final int calorias = r['calorias'] is num
            ? (r['calorias'] as num).toInt()
            : int.tryParse(r['calorias']?.toString() ?? '450') ?? 450;
        final String macros = r['macros']?.toString().trim() ?? '';
        final List<dynamic> ingredientes = r['ingredientes'] ?? [];

        setState(() {
          _estadoInsercion = 'Insertando ($i/${_recetasGeneradas.length}): $titulo';
          _progresoInsercion = (i + 1) / _recetasGeneradas.length;
        });

        // 1. Reconstruir descripción canónica con ingredientes e instrucciones
        final sb = StringBuffer();
        sb.writeln('CALORÍAS: $calorias kcal');
        if (macros.isNotEmpty) sb.writeln('MACROS: $macros');
        sb.writeln('TIPO: $tipoComida');
        sb.writeln('\n📝 INGREDIENTES:');
        for (var ing in ingredientes) {
          final nom = ing['nombre_estandar']?.toString() ?? '';
          final cant = ing['cantidad']?.toString() ?? '1';
          final uni = ing['unidad']?.toString() ?? 'piezas';
          if (nom.isNotEmpty) sb.writeln('- $cant $uni $nom');
        }
        sb.writeln('\n🍳 INSTRUCCIONES:');
        sb.writeln(instrucciones);
        final String descCompleta = sb.toString().trim();

        // 2. Insertar en tabla recetas usando ServicioRecetas como Catálogo Oficial y Novedad Activa
        final resReceta = await ServicioRecetas.insertarReceta(
          titulo: titulo,
          descripcion: descCompleta,
          instrucciones: instrucciones,
          tipoComida: tipoComida,
          calorias: calorias,
          macros: macros,
          imagenUrl: imagenUrl,
          esOficial: true,
          esPublica: true,
          esNovedad: true,
          userIdOverride: 'none',
        );

        final int idNueva = resReceta['id_receta'];

        // 3. Vincular ingredientes detallados a catalogo e ingredientes_genericos
        for (var ing in ingredientes) {
          try {
            final String nomIng =
                ing['nombre_estandar']?.toString().trim().toLowerCase() ?? '';
            if (nomIng.isEmpty) continue;
            final double cant = (ing['cantidad'] is num)
                ? (ing['cantidad'] as num).toDouble()
                : double.tryParse(ing['cantidad']?.toString() ?? '1.0') ?? 1.0;
            final String uni =
                ing['unidad']?.toString().trim().toLowerCase() ?? 'piezas';

            final match = await supabase
                .from('ingredientes_genericos')
                .select('id_ingrediente')
                .eq('nombre_estandar', nomIng)
                .maybeSingle();

            int idIngrediente;
            if (match != null) {
              idIngrediente = match['id_ingrediente'];
            } else {
              final nuevo = await supabase
                  .from('ingredientes_genericos')
                  .insert({'nombre_estandar': nomIng})
                  .select('id_ingrediente')
                  .single();
              idIngrediente = nuevo['id_ingrediente'];
            }

            await supabase.from('receta_detalle').insert({
              'id_receta': idNueva,
              'id_ingrediente': idIngrediente,
              'cantidad': cant,
              'unidad_medida': uni,
            });
          } catch (_) {}
        }

        guardadas++;
      }

      if (mounted) {
        setState(() {
          _estadoInsercion = '¡Completado! $guardadas recetas oficiales registradas.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Éxito total! Se agregaron $guardadas recetas oficiales al catálogo. 🌟🎉',
            ),
            backgroundColor: Colors.green.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error durante la inserción: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _insertandoEnBd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> recetasFiltradas = _recetasGeneradas.where((r) {
      if (_filtroCategoria == 'Todos') return true;
      return (r['tipo_comida']?.toString().toLowerCase() ?? '') ==
          _filtroCategoria.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Carga Masiva de Recetas (IA)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E2022),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Panel Superior de Configuración del Lote
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    const Text(
                      'Lote Mensual de 20 Recetas Oficiales',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Selector rápido de meses y temporadas mexicanas
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: ServicioTemporadasMexico.obtenerTodosLosMeses().map((temp) {
                      final esSeleccionado = _temporadaSeleccionada.mesNumero == temp.mesNumero;
                      final esMesActual = DateTime.now().month == temp.mesNumero;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 6),
                        child: FilterChip(
                          showCheckmark: false,
                          selected: esSeleccionado,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _temporadaSeleccionada = temp;
                                _temaController.text = temp.temaSugerido;
                              });
                            }
                          },
                          avatar: Text(temp.icono, style: const TextStyle(fontSize: 14)),
                          label: Text(
                            '${temp.nombreMes}${esMesActual ? ' (Hoy)' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: esSeleccionado ? FontWeight.bold : FontWeight.w500,
                              color: esSeleccionado ? Colors.white : Colors.black87,
                            ),
                          ),
                          selectedColor: Colors.orange.shade800,
                          backgroundColor: Colors.grey.shade100,
                          side: BorderSide(
                            color: esSeleccionado
                                ? Colors.orange.shade900
                                : Colors.grey.shade300,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _temaController,
                  decoration: InputDecoration(
                    labelText: 'Tema, Enfoque o Mes del Lote',
                    hintText: 'Ej. Noviembre 2026 - Especial Cítricos y Otoño',
                    prefixIcon: const Icon(Icons.palette_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Tarjeta informativa de la cosecha estacional de México
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _temporadaSeleccionada.icono,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cosecha de ${_temporadaSeleccionada.nombreMes} en México (${_temporadaSeleccionada.nombreTemporada}):',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _temporadaSeleccionada.resumenIngredientes,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.brown.shade800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '🌱 Directriz Estacional: Las recetas generadas usarán estos ingredientes reales y no se generarán al azar.',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _generandoIA || _insertandoEnBd
                        ? null
                        : _generarLoteConGemini,
                    icon: _generandoIA
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.flash_on),
                    label: Text(
                      _generandoIA
                          ? 'Generando 20 recetas con Gemini...'
                          : 'Generar Lote del Mes con IA (20 recetas) 🪄',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Barra de progreso durante inserción en Supabase
          if (_insertandoEnBd) ...[
            LinearProgressIndicator(
              value: _progresoInsercion,
              backgroundColor: Colors.grey[300],
              color: Colors.green,
              minHeight: 6,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _estadoInsercion,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade900,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Barra de Filtros de Categoría si hay recetas generadas
          if (_recetasGeneradas.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Text(
                    'Total: ${_recetasGeneradas.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          'Todos',
                          'Desayuno',
                          'Comida',
                          'Cena',
                          'Snack',
                        ].map((cat) {
                          final bool sel = _filtroCategoria == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: sel,
                              selectedColor: Colors.orange.shade200,
                              labelStyle: TextStyle(
                                color: sel ? Colors.orange.shade900 : Colors.black87,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (_) => setState(() => _filtroCategoria = cat),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Lista de Recetas Generadas
          Expanded(
            child: _recetasGeneradas.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_motion_outlined,
                            size: 64,
                            color: Colors.orange.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Genera o previsualiza aquí el lote mensual de 20 recetas oficiales.\n'
                            'Podrás revisarlas y publicarlas con un solo clic.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: recetasFiltradas.length,
                    itemBuilder: (ctx, index) {
                      final r = recetasFiltradas[index];
                      final String cat = r['tipo_comida'] ?? 'Comida';
                      final String tit = r['titulo'] ?? 'Sin título';
                      final int cal = r['calorias'] ?? 0;
                      final List ings = r['ingredientes'] ?? [];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              r['imagen_url'] ?? '',
                              width: 55,
                              height: 55,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 55,
                                height: 55,
                                color: Colors.orange.shade100,
                                child: Icon(
                                  Icons.restaurant,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  tit,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '🔥 $cal kcal  •  ${ings.length} ingredientes\n${r['descripcion'] ?? ''}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Quitar de este lote',
                            onPressed: () {
                              setState(() {
                                _recetasGeneradas.remove(r);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Botón Inferior para Publicar en Supabase
          if (_recetasGeneradas.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _insertandoEnBd ? null : _insertarRecetasEnCatalogoOficial,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    'Publicar ${_recetasGeneradas.length} Recetas en Catálogo Oficial 🚀',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
