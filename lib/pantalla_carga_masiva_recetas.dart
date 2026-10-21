import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config_api.dart';
import 'servicio_admin.dart';
import 'servicio_recetas.dart';
import 'servicio_temas_lote.dart';

class PantallaCargaMasivaRecetas extends StatefulWidget {
  const PantallaCargaMasivaRecetas({super.key});

  @override
  State<PantallaCargaMasivaRecetas> createState() =>
      _PantallaCargaMasivaRecetasState();
}

class _PantallaCargaMasivaRecetasState
    extends State<PantallaCargaMasivaRecetas> {
  late OpcionTemaLote _temaSeleccionado;
  late GrupoTemaLote _grupoActivo;
  late final TextEditingController _temaController;

  bool _generandoIA = false;
  bool _insertandoEnBd = false;
  double _progresoInsercion = 0.0;
  String _estadoInsercion = '';

  List<Map<String, dynamic>> _recetasGeneradas = [];
  String _filtroCategoria = 'Todos';
  bool _panelConfiguracionExpandido = true;

  @override
  void initState() {
    super.initState();
    _temaSeleccionado = ServicioTemasLote.obtenerTemporadaActual();
    _grupoActivo = _temaSeleccionado.grupo;
    _temaController = TextEditingController(
      text: _temaSeleccionado.temaCompleto,
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
    String tipoComida, [
    String? urlSugerida,
  ]) {
    // Si la URL sugerida es válida y no está en la lista negra, respetarla prioritariamente
    if (urlSugerida != null && urlSugerida.trim().isNotEmpty) {
      final trimmed = urlSugerida.trim();
      if (!ServicioRecetas.urlsNegras.any((negra) => trimmed.contains(negra))) {
        return trimmed;
      }
    }
    // Asignar fotografía gastronómica curada por semántica
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
      
      TEMA / ENFOQUE DEL LOTE: "$tema"
      
      ${_temaSeleccionado.directrizPrompt}
      
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
      5. ENFOQUE CULINARIO: Recetas auténticas, apetitosas y bien equilibradas según el tema.
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
          );
        }
        setState(() {
          _recetasGeneradas = list;
          _panelConfiguracionExpandido = false;
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

  void _mostrarDetallePrevisualizacion(Map<String, dynamic> r, int index) {
    final String tit = r['titulo'] ?? 'Sin título';
    final String cat = r['tipo_comida'] ?? 'Comida';
    final int cal = r['calorias'] is int
        ? r['calorias']
        : int.tryParse(r['calorias']?.toString() ?? '0') ?? 0;
    final String macros = r['macros']?.toString() ?? '';
    final String desc = r['descripcion']?.toString() ?? '';
    final String inst = r['instrucciones']?.toString() ?? '';
    final List ings = r['ingredientes'] is List ? r['ingredientes'] as List : [];
    final String img = r['imagen_url']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Barra superior de arrastre
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      children: [
                        // Imagen de alta resolución
                        if (img.isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              img,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.restaurant_rounded,
                                    size: 52,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _mostrarSelectorFotosAlternativas(r);
                              },
                              icon: const Icon(Icons.camera_alt_outlined, size: 16, color: Color(0xFFD32F2F)),
                              label: const Text(
                                'Cambiar foto de este platillo 📸',
                                style: TextStyle(
                                  color: Color(0xFFD32F2F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        // Badges tipo de comida y calorías
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '🔥 $cal kcal',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tit,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2022),
                          ),
                        ),
                        if (macros.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              macros,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        // Sección Ingredientes
                        Row(
                          children: [
                            const Icon(Icons.shopping_basket_outlined, size: 20, color: Color(0xFFD32F2F)),
                            const SizedBox(width: 8),
                            Text(
                              'Ingredientes (${ings.length}):',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E2022),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: ings.map((ing) {
                              final nom = ing['nombre_estandar']?.toString() ?? '';
                              final cant = ing['cantidad']?.toString() ?? '';
                              final uni = ing['unidad']?.toString() ?? '';
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '$cant $uni de $nom',
                                        style: const TextStyle(fontSize: 13.5),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Sección Instrucciones
                        const Row(
                          children: [
                            Icon(Icons.restaurant_outlined, size: 20, color: Color(0xFFD32F2F)),
                            SizedBox(width: 8),
                            Text(
                              'Preparación Paso a Paso:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E2022),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            inst.isNotEmpty ? inst : 'Instrucciones en desarrollo...',
                            style: const TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Botones de acción
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade300),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _recetasGeneradas.removeAt(index);
                                  });
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Receta descartada del lote.'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.delete_outline, size: 18),
                                label: const Text('Descartar receta'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E2022),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text('Listo ✅'),
                              ),
                            ),
                          ],
                        ),
                      ],
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

  /// Despliega selector visual interactivo con 4 fotografías culinarias alternativas
  /// verificadas y opción de URL personalizada antes de guardar en Supabase.
  void _mostrarSelectorFotosAlternativas(Map<String, dynamic> r) {
    final String titulo = r['titulo']?.toString() ?? 'Receta';
    final String tipo = r['tipo_comida']?.toString() ?? 'Comida';
    final String urlActual = r['imagen_url']?.toString() ?? '';
    final List<String> opciones = ServicioRecetas.obtenerOpcionesAlternativas(titulo, tipo);
    final ctrlUrl = TextEditingController(text: urlActual);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.photo_camera_back_rounded, color: Color(0xFFD32F2F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cambiar Foto: $titulo',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Toca cualquiera de las opciones verificadas o ingresa una URL personalizada:',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.45,
                ),
                itemCount: opciones.length,
                itemBuilder: (context, idx) {
                  final optUrl = opciones[idx];
                  final bool seleccionada = (r['imagen_url'] ?? '') == optUrl;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        r['imagen_url'] = optUrl;
                      });
                      setModalState(() {});
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Fotografía actualizada para esta receta! 📸✨'),
                          backgroundColor: Colors.teal,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: seleccionada ? const Color(0xFFD32F2F) : Colors.grey.shade300,
                          width: seleccionada ? 3 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(optUrl, fit: BoxFit.cover),
                            if (seleccionada)
                              Container(
                                color: Colors.black38,
                                child: const Center(
                                  child: Icon(Icons.check_circle, color: Colors.white, size: 28),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrlUrl,
                decoration: InputDecoration(
                  labelText: 'O ingresa una URL personalizada de imagen',
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_circle, color: Color(0xFFD32F2F)),
                    onPressed: () {
                      final custom = ctrlUrl.text.trim();
                      if (custom.isNotEmpty) {
                        setState(() {
                          r['imagen_url'] = custom;
                        });
                        Navigator.pop(ctx);
                      }
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          // Panel Superior de Configuración del Lote (Colapsable)
          if (_recetasGeneradas.isNotEmpty && !_panelConfiguracionExpandido)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      _temaSeleccionado.icono,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_temaSeleccionado.tituloCorto} • ${_recetasGeneradas.length} recetas listas',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E2022),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Toca cualquier tarjeta para revisar detalle y pasos',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      backgroundColor: Colors.orange.shade50,
                      foregroundColor: Colors.orange.shade900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.orange.shade200),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _panelConfiguracionExpandido = true;
                      });
                    },
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text(
                      'Cambiar tema',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_recetasGeneradas.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Configuración del Lote (${_recetasGeneradas.length} generadas)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Colors.orange.shade900,
                              backgroundColor: Colors.orange.shade50,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _panelConfiguracionExpandido = false;
                              });
                            },
                            icon: const Icon(Icons.expand_less, size: 16),
                            label: const Text(
                              'Ocultar panel',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.orange.shade800),
                          const SizedBox(width: 8),
                          const Text(
                            'Lote de 20 Recetas Oficiales',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    // Botón Ruleta Sorpresa
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.purple.shade50,
                        foregroundColor: Colors.purple.shade800,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.purple.shade200),
                        ),
                      ),
                      onPressed: () {
                        final aleatorio = ServicioTemasLote.obtenerAleatorio();
                        setState(() {
                          _temaSeleccionado = aleatorio;
                          _grupoActivo = aleatorio.grupo;
                          _temaController.text = aleatorio.temaCompleto;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '¡La Ruleta Culinaria eligió: ${aleatorio.icono} ${aleatorio.tituloCorto}! 🪄✨',
                            ),
                            backgroundColor: Colors.purple.shade800,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                      icon: const Text('🎲', style: TextStyle(fontSize: 14)),
                      label: const Text(
                        '¡Sorpréndeme!',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Nivel 1: Selector de Universos / Grupos Temáticos
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: GrupoTemaLote.values.map((grupo) {
                      final esActivo = _grupoActivo == grupo;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 4),
                        child: ChoiceChip(
                          selected: esActivo,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _grupoActivo = grupo;
                                final opciones = ServicioTemasLote.obtenerPorGrupo(grupo);
                                if (!opciones.any((o) => o.id == _temaSeleccionado.id)) {
                                  _temaSeleccionado = opciones.first;
                                  _temaController.text = _temaSeleccionado.temaCompleto;
                                }
                              });
                            }
                          },
                          label: Text(
                            grupo.etiqueta,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: esActivo ? FontWeight.bold : FontWeight.w500,
                              color: esActivo ? Colors.white : Colors.black87,
                            ),
                          ),
                          selectedColor: const Color(0xFF1E2022),
                          backgroundColor: Colors.grey.shade100,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                // Nivel 2: Píldoras específicas del grupo activo
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: ServicioTemasLote.obtenerPorGrupo(_grupoActivo).map((opcion) {
                      final esSeleccionada = _temaSeleccionado.id == opcion.id;
                      final esMesActual = opcion.grupo == GrupoTemaLote.temporada &&
                          opcion.id == 'temp_${DateTime.now().month}';
                      return Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 6),
                        child: FilterChip(
                          showCheckmark: false,
                          selected: esSeleccionada,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _temaSeleccionado = opcion;
                                _temaController.text = opcion.temaCompleto;
                              });
                            }
                          },
                          avatar: Text(opcion.icono, style: const TextStyle(fontSize: 14)),
                          label: Text(
                            '${opcion.tituloCorto}${esMesActual ? ' (Hoy)' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: esSeleccionada ? FontWeight.bold : FontWeight.w500,
                              color: esSeleccionada ? Colors.white : Colors.black87,
                            ),
                          ),
                          selectedColor: Colors.orange.shade800,
                          backgroundColor: Colors.grey.shade100,
                          side: BorderSide(
                            color: esSeleccionada
                                ? Colors.orange.shade900
                                : Colors.grey.shade300,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _temaController,
                  decoration: InputDecoration(
                    labelText: 'Tema, Enfoque o Especial del Lote',
                    hintText: 'Ej. Especial Italia, Cero Trastes, High-Protein...',
                    prefixIcon: const Icon(Icons.palette_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Tarjeta informativa del enfoque activo
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
                        _temaSeleccionado.icono,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_temaSeleccionado.grupo.etiqueta} • ${_temaSeleccionado.tituloCorto}:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _temaSeleccionado.resumenEnfoque,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.brown.shade800,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '💡 Directriz Activa: La IA adaptará las 20 recetas a este especial respetando sus ingredientes y técnicas.',
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _mostrarDetallePrevisualizacion(r, index),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => _mostrarSelectorFotosAlternativas(r),
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          r['imagen_url'] ?? '',
                                          width: 65,
                                          height: 65,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 65,
                                            height: 65,
                                            color: Colors.orange.shade100,
                                            child: Icon(
                                              Icons.restaurant_rounded,
                                              color: Colors.orange.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.camera_alt_rounded,
                                            size: 11,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
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
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              tit,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14.5,
                                                color: Color(0xFF1E2022),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '🔥 $cal kcal  •  ${ings.length} ingredientes\n${r['descripcion'] ?? ''}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                          height: 1.25,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.touch_app_outlined,
                                            size: 13,
                                            color: Colors.teal.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Toca para revisar ingredientes y pasos',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.teal.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      tooltip: 'Quitar de este lote',
                                      onPressed: () {
                                        setState(() {
                                          _recetasGeneradas.remove(r);
                                        });
                                      },
                                    ),
                                    const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                  ],
                                ),
                              ],
                            ),
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
