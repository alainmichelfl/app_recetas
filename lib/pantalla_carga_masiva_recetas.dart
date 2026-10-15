import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config_api.dart';
import 'servicio_admin.dart';
import 'servicio_recetas.dart';

class PantallaCargaMasivaRecetas extends StatefulWidget {
  const PantallaCargaMasivaRecetas({super.key});

  @override
  State<PantallaCargaMasivaRecetas> createState() =>
      _PantallaCargaMasivaRecetasState();
}

class _PantallaCargaMasivaRecetasState
    extends State<PantallaCargaMasivaRecetas> {
  final TextEditingController _temaController = TextEditingController(
    text: 'Especial Sabores de Temporada y Cocina Práctica',
  );

  bool _generandoIA = false;
  bool _insertandoEnBd = false;
  double _progresoInsercion = 0.0;
  String _estadoInsercion = '';

  List<Map<String, dynamic>> _recetasGeneradas = [];
  String _filtroCategoria = 'Todos';

  @override
  void initState() {
    super.initState();
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
      
      RESPONDE ÚNICAMENTE con un arreglo JSON de 20 objetos con esta estructura exacta:
      [
        {
          "titulo": "Huevos a la Mexicana con Frijoles de la Olla",
          "descripcion": "Desayuno clásico balanceado, alto en proteína y fibra.",
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
        setState(() {
          _recetasGeneradas = List<Map<String, dynamic>>.from(decoded);
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

    try {
      for (int i = 0; i < _recetasGeneradas.length; i++) {
        final r = _recetasGeneradas[i];
        final String titulo = r['titulo']?.toString().trim() ?? 'Receta Oficial';
        final String tipoComida = r['tipo_comida']?.toString().trim() ?? 'Comida';
        final String instrucciones = r['instrucciones']?.toString().trim() ?? '';
        final String imagenUrl = r['imagen_url']?.toString().trim() ??
            'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=500';
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

        // 2. Insertar en tabla recetas usando ServicioRecetas
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
        backgroundColor: Colors.orange.shade800,
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
