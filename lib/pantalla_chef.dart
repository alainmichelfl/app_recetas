import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'config_api.dart';
import 'perfiles_nutricionales.dart';
import 'tipos_cocina.dart';
import 'servicio_preferencias.dart';
import 'servicio_recetas.dart';
import 'servicio_admin.dart';
import 'menu_lateral.dart';
import 'pantalla_recetas_caninas.dart';
import 'servicio_copiloto_cocina.dart';
import 'utensilios_cocina.dart';
import 'servicio_cocina_express.dart';

class PantallaChef extends StatefulWidget {
  final String? ingredientesIniciales;
  final bool modoPerrunoInicial;
  final bool modoExpressInicial;
  final bool modoCeroTrastesInicial;
  final bool modoSinFuegoInicial;

  const PantallaChef({
    super.key,
    this.ingredientesIniciales,
    this.modoPerrunoInicial = false,
    this.modoExpressInicial = false,
    this.modoCeroTrastesInicial = false,
    this.modoSinFuegoInicial = false,
  });

  @override
  State<PantallaChef> createState() => _PantallaChefState();
}

class _PantallaChefState extends State<PantallaChef> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _generando = false;
  bool _modoPerruno = false; // 🐾 Interruptor para recetas de perritos
  bool _modoExpress = false; // ⚡ Modo Express (≤ 15 min)
  bool _modoCeroTrastes = false; // 🍳 Modo One-Pan (1 sola sartén)
  bool _modoSinFuego = false; // 🥗 Modo Sin Fuego / Frío (5-10 min)
  ModoElectrodomestico _electrodomesticoSeleccionado = ModoElectrodomestico.tradicional;

  final TextEditingController _ingredientesCtrl = TextEditingController();

  String _tipoComidaSeleccionado = 'Comida';
  String _objetivoSeleccionado = 'Mantenimiento 2,000 kcal';
  String _tipoCocinaSeleccionado = TiposCocina.mexicana;
  String _alergias = '';
  List<String> _estilos = [PerfilesNutricionales.libre];
  List<String> _utensiliosDisponibles = UtensiliosCocina.porDefecto;

  final List<String> _tiposComida = ['Desayuno', 'Comida', 'Cena', 'Snack'];
  final List<String> _objetivosSalud = [
    'Déficit 1,500 kcal',
    'Mantenimiento 2,000 kcal',
    'Volumen 2,500 kcal',
    'Keto 1,700 kcal',
    'Personalizada',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.modoPerrunoInicial) {
      _modoPerruno = true;
    }
    if (widget.modoExpressInicial) {
      _modoExpress = true;
    }
    if (widget.modoCeroTrastesInicial) {
      _modoCeroTrastes = true;
    }
    if (widget.modoSinFuegoInicial) {
      _modoSinFuego = true;
    }
    if (widget.ingredientesIniciales != null && widget.ingredientesIniciales!.isNotEmpty) {
      _ingredientesCtrl.text = widget.ingredientesIniciales!;
    }
    _cargarPreferenciasParaChef();
  }

  Future<void> _cargarPreferenciasParaChef() async {
    try {
      final prefs = await ServicioPreferencias.obtenerPreferencias();
      if (!mounted) return;
      setState(() {
        _alergias = prefs.alergias;
        _estilos = prefs.estilos;
        _utensiliosDisponibles = prefs.utensilios;
        if (prefs.tiposCocina.isNotEmpty &&
            prefs.tiposCocina.first != TiposCocina.todas) {
          _tipoCocinaSeleccionado = prefs.tiposCocina.first;
        } else {
          _tipoCocinaSeleccionado = TiposCocina.mexicana;
        }
        if (prefs.estilos.contains(PerfilesNutricionales.keto)) {
          _objetivoSeleccionado = 'Keto 1,700 kcal';
        } else if (prefs.objetivo == PerfilesNutricionales.deficit) {
          _objetivoSeleccionado = 'Déficit 1,500 kcal';
        } else if (prefs.objetivo == PerfilesNutricionales.volumen) {
          _objetivoSeleccionado = 'Volumen 2,500 kcal';
        } else {
          _objetivoSeleccionado = 'Mantenimiento 2,000 kcal';
        }
      });
    } catch (e) {
      debugPrint('Error cargando preferencias en PantallaChef: $e');
    }
  }

  String construirPromptChef(
    String ingredientesBase,
    String tipoComida,
    String objetivoSalud,
    String tipoCocina,
    bool esPerruno, [
    ModoElectrodomestico electrodomestico = ModoElectrodomestico.tradicional,
  ]) {
    if (esPerruno) {
      final String insPerruno = ingredientesBase.isNotEmpty
          ? '- Ingredientes base a incluir: $ingredientesBase'
          : '- Ingredientes: Libertad creativa con alimentos 100% seguros para perros.';

      return '''
      Eres un Veterinario Nutricionista y Chef experto en comida para mascotas. 
      Tu tarea es crear una receta de premios caseros o comida saludable para perritos.
      
      Parámetros obligatorios:
      $insPerruno
      
      REGLA DE ORO ABSOLUTA (SEGURIDAD CANINA):
      - EXCLUYE estrictamente ingredientes tóxicos para perros (cebolla, ajo, chocolate, uvas, aguacate, macadamias, xilitol, sal agregada, azúcares).
      
      REGLA DE UNIDADES:
      - Usa gramos (g), kilos (kg) o piezas (pzas) para la lista de ingredientes.
      
      REGLA CRÍTICA: DEBES responder ÚNICAMENTE con un objeto JSON válido y minificado. 
      NO incluyas saludos, explicaciones, ni bloques de código markdown (como ```json).
      
      El JSON debe tener EXACTAMENTE esta estructura:
      {
        "titulo": "Galletas de avena y pollo para perro",
        "descripcion": "Premios caseros muy nutritivos y seguros para consentir a tu mascota",
        "tipo_comida": "Snack Canino",
        "calorias": 250,
        "macros": "Proteína: 25g | Grasas: 6g | Fibra: 4g",
        "ingredientes": [
          {
            "nombre_estandar": "pechuga de pollo",
            "cantidad": 0.2,
            "unidad": "kg"
          },
          {
            "nombre_estandar": "hojuelas de avena",
            "cantidad": 1.0,
            "unidad": "paquete"
          }
        ],
        "instrucciones": "1. Hervir la pechuga de pollo sin sal.\\n2. Mezclar el pollo deshebrado con la avena.\\n3. Formar pequeñas galletas y hornear a 180°C por 15 minutos."
      }
      ''';
    }

    final String instruccionIngredientes = ingredientesBase.isNotEmpty
        ? '- Ingredientes principales o antojo del usuario (prioriza estos y combínalos con básicos): $ingredientesBase'
        : '- Ingredientes: ¡Tienes libertad creativa total! Inventa una receta deliciosa y original desde cero.';

    final String instruccionCocina =
        (tipoCocina.isNotEmpty && tipoCocina != TiposCocina.todas)
            ? '- GASTRONOMÍA / ESTILO DE COCINA OBLIGATORIO: Cocina $tipoCocina (${TiposCocina.iconos[tipoCocina] ?? ""}). La receta DEBE ser 100% representativa de la tradición culinaria $tipoCocina (${TiposCocina.descripciones[tipoCocina] ?? ""}), usando técnicas, sazón y sabores típicos.'
            : '- GASTRONOMÍA: Cocina libre, internacional o fusión según los ingredientes y antojos provistos.';

    final String instruccionAlergias = _alergias.trim().isNotEmpty
        ? '- ALERGIAS Y RESTRICCIONES (PROHIBIDO USAR): ${_alergias.trim()}.'
        : '';

    final String instruccionEstilos =
        PerfilesNutricionales.instruccionesPrompt(_estilos);

    final String instruccionUtensilios =
        UtensiliosCocina.instruccionesPrompt(_utensiliosDisponibles);

    final String instruccionElectrodomestico =
        electrodomestico == ModoElectrodomestico.thermomix
            ? '''
    - ELECTRODOMÉSTICO OBLIGATORIO: THERMOMIX (TM5 / TM6 / TM7).
    Toda la receta DEBE estar redactada específicamente para Thermomix.
    CADA PASO en "instrucciones" DEBE iniciar obligatoriamente con el formato de corchetes:
    [Tiempo | Temperatura | Velocidad | Giro inverso (si aplica) | Accesorio (si aplica)]
    Ejemplo: "1. [5 seg | Sin temp | Vel 5] Picar la cebolla en el vaso con el cubilete puesto.\\n2. [7 min | 120°C | Vel 1] Sofreír con aceite.\\n3. [20 min | 100°C | Giro inverso ↺ | Vel cuchara 🥄 | Mariposa 🦋] Cocinar guisado."
    '''
            : electrodomestico == ModoElectrodomestico.airFryer
                ? '''
    - ELECTRODOMÉSTICO OBLIGATORIO: FREIDORA DE AIRE (AIR FRYER).
    Toda la receta DEBE estar redactada específicamente para freidora de aire.
    CADA PASO en "instrucciones" DEBE iniciar obligatoriamente con el formato de corchetes:
    [Temperatura | Tiempo | Acción clave]
    Ejemplo: "1. [200°C | 3 min] Precalentar la freidora de aire.\\n2. [180°C | 15 min | Agitar a la mitad] Cocinar en la canastilla en una sola capa."
    '''
                : '';

    final String instruccionExpress = (_modoExpress || _modoCeroTrastes || _modoSinFuego)
        ? ServicioCocinaExpress.construirInstruccionesPromptExpress(
            modoCeroTrastes: _modoCeroTrastes,
            modoSinFuego: _modoSinFuego,
            tiempoMaximoMinutos: _modoSinFuego ? 10 : 15,
          )
        : '';

    return '''
    Eres el chef principal y nutriólogo de la app "Jitomate y Cebolla".
    Tu tarea es crear una receta deliciosa, realista y fácil de preparar.
    
    Parámetros obligatorios:
    $instruccionIngredientes
    $instruccionCocina
    $instruccionAlergias
    $instruccionEstilos
    $instruccionUtensilios
    $instruccionElectrodomestico
    $instruccionExpress
    - Tipo de comida: $tipoComida
    - Objetivo de salud: $objetivoSalud
    
    REGLAS DE UNIDADES DE MEDIDA (MUY IMPORTANTE):
    - NO uses gramos (g) ni mililitros (ml) en la lista de ingredientes.
    - Usa SIEMPRE fracciones de Kilo (kg) o Litro (L). Ejemplo: en lugar de 500g, usa 0.5 kg. En lugar de 250ml, usa 0.25 L.
    - Para vegetales, frutas o huevos, usa "piezas" o "pzas".
    - Para condimentos, semillas, quesos o enlatados, usa "paquete", "lata" o "frasco".
    
    REGLA CRÍTICA: DEBES responder ÚNICAMENTE con un objeto JSON válido y minificado. 
    NO incluyas saludos, explicaciones, ni bloques de código markdown (como ```json).
    
    El JSON debe tener EXACTAMENTE esta estructura:
    {
      "titulo": "Nombre atractivo del platillo",
      "descripcion": "Breve descripción de la receta",
      "tipo_comida": "$tipoComida",
      "calorias": 450,
      "macros": "Proteína: 30g | Carbos: 40g | Grasas: 15g",
      "ingredientes": [
        {
          "nombre_estandar": "pechuga de pollo",
          "cantidad": 0.25,
          "unidad": "kg"
        },
        {
          "nombre_estandar": "jitomate",
          "cantidad": 2,
          "unidad": "piezas"
        }
      ],
      "instrucciones": "1. Primer paso.\\n2. Segundo paso.\\n3. Tercer paso."${!esPerruno ? ',\n      "maridaje": {\n        "vino": "Nombre y estilo de vino sugerido",\n        "destilado": "Destilado o cóctel sugerido",\n        "sinAlcohol": "Mocktail artesanal sin alcohol sugerido"\n      }' : ''}
    }
    
    Nota: En "nombre_estandar" usa SIEMPRE minúsculas y el nombre base del ingrediente (ej. "cebolla blanca", no "media cebolla blanca picada").
    ''';
  }

  // 1. GENERA Y MUESTRA LA TARJETA DE VISTA PREVIA
  Future<void> generarRecetaPreview() async {
    setState(() => _generando = true);

    try {
      final model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: ConfigApi.geminiKey,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.6,
        ),
      );

      final prompt = construirPromptChef(
        _ingredientesCtrl.text.trim(),
        _tipoComidaSeleccionado,
        _objetivoSeleccionado,
        _tipoCocinaSeleccionado,
        _modoPerruno,
        _electrodomesticoSeleccionado,
      );

      final response = await model.generateContent([Content.text(prompt)]);
      String jsonString = response.text ?? '{}';

      jsonString = jsonString
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final Map<String, dynamic> recetaGenerada = jsonDecode(jsonString);

      if (mounted) {
        _mostrarTarjetaVistaPrevia(recetaGenerada);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar receta: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _generando = false);
      }
    }
  }

  // 2. MUESTRA EL MODAL/TARJETA CON LA RECETA CREADA
  void _mostrarTarjetaVistaPrevia(Map<String, dynamic> receta) {
    final Color colorPremium = Colors.red.shade800;
    List<dynamic> ingredientes = receta['ingredientes'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (contextDialog) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
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
                    _modoPerruno ? Icons.pets : Icons.auto_awesome,
                    color: colorPremium,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _modoPerruno
                        ? '¡Receta Canina Creada!'
                        : '¡Receta Creada por el Chef!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: 25),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receta['titulo'] ?? '',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: colorPremium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        receta['descripcion'] ?? '',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            label: Text('${receta['calorias'] ?? 0} kcal'),
                            backgroundColor: Colors.red.shade50,
                            labelStyle: TextStyle(
                              color: colorPremium,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!_modoPerruno) ...[
                            Chip(
                              avatar: Text(
                                TiposCocina.iconos[_tipoCocinaSeleccionado] ??
                                    '🍽️',
                                style: const TextStyle(fontSize: 14),
                              ),
                              label: Text(_tipoCocinaSeleccionado),
                              backgroundColor: Colors.orange.shade50,
                              labelStyle: TextStyle(
                                color: Colors.deepOrange.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_electrodomesticoSeleccionado !=
                                ModoElectrodomestico.tradicional)
                              Chip(
                                avatar: Text(
                                  _electrodomesticoSeleccionado.icono,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                label: Text(
                                  _electrodomesticoSeleccionado ==
                                          ModoElectrodomestico.thermomix
                                      ? 'Thermomix'
                                      : 'Air Fryer',
                                ),
                                backgroundColor: _electrodomesticoSeleccionado
                                    .colorPrimario
                                    .withValues(alpha: 0.12),
                                labelStyle: TextStyle(
                                  color: _electrodomesticoSeleccionado
                                      .colorPrimario,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                          if (receta['macros'] != null &&
                              receta['macros'].toString().isNotEmpty)
                            Text(
                              receta['macros'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Ingredientes:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...ingredientes.map(
                        (ing) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '• ${ing['cantidad']} ${ing['unidad']} de ${ing['nombre_estandar']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Instrucciones:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        receta['instrucciones'] ?? '',
                        style: const TextStyle(fontSize: 14, height: 1.4),
                      ),
                      if (receta['maridaje'] != null && !_modoPerruno) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF230611).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF800020).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Text('🍷', style: TextStyle(fontSize: 16)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Maridaje del Sommelier:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF800020),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              if (receta['maridaje']['vino'] != null)
                                Text('• Vino: ${receta['maridaje']['vino']}',
                                    style: const TextStyle(fontSize: 13)),
                              if (receta['maridaje']['destilado'] != null)
                                Text('• Destilado: ${receta['maridaje']['destilado']}',
                                    style: const TextStyle(fontSize: 13)),
                              if (receta['maridaje']['sinAlcohol'] != null)
                                Text('• Sin alcohol: ${receta['maridaje']['sinAlcohol']}',
                                    style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () => Navigator.pop(contextDialog),
                      child: const Text('Descartar'),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorPremium,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(contextDialog);
                        await _guardarRecetaEnSupabase(receta);
                      },
                      child: const Text(
                        'Guardar Receta 💾',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. GUARDA EN SUPABASE SÓLO AL DAR CLIC EN "GUARDAR"
  Future<void> _guardarRecetaEnSupabase(
    Map<String, dynamic> recetaGenerada,
  ) async {
    try {
      List<dynamic> ingredientes = recetaGenerada['ingredientes'] ?? [];
      final String porciones = recetaGenerada['porciones']?.toString() ?? '2';
      final String calorias = recetaGenerada['calorias']?.toString() ?? '450';
      final String macros = recetaGenerada['macros']?.toString() ?? '';
      final String tipo = recetaGenerada['tipo_comida']?.toString() ?? 'Comida';
      final String instrucciones = recetaGenerada['instrucciones']?.toString() ?? '';

      final sb = StringBuffer();
      sb.writeln('PORCIONES: $porciones');
      sb.writeln('CALORÍAS: $calorias kcal');
      if (macros.isNotEmpty) sb.writeln('MACROS: $macros');
      sb.writeln('TIPO: $tipo');
      if (!_modoPerruno && _tipoCocinaSeleccionado.isNotEmpty) {
        sb.writeln(
          'COCINA: ${TiposCocina.iconos[_tipoCocinaSeleccionado] ?? ""} $_tipoCocinaSeleccionado',
        );
      }
      sb.writeln('\n📝 INGREDIENTES:');
      for (var ing in ingredientes) {
        sb.writeln('- ${ing['cantidad']} ${ing['unidad']} ${ing['nombre_estandar']}');
      }
      sb.writeln('\n🍳 INSTRUCCIONES:');
      sb.writeln(instrucciones);

      if (!_modoPerruno && recetaGenerada['maridaje'] is Map) {
        final m = recetaGenerada['maridaje'] as Map;
        sb.writeln('\n🍷 MARIDAJE SUGERIDO:');
        if (m['vino'] != null) sb.writeln('- Vino: ${m['vino']}');
        if (m['destilado'] != null) sb.writeln('- Destilado / Cóctel: ${m['destilado']}');
        if (m['sinAlcohol'] != null) sb.writeln('- Sin Alcohol: ${m['sinAlcohol']}');
      }

      final String descCompleta = sb.toString().trim();
      final bool esPerruna = _modoPerruno;
      final String tipoComidaFinal =
          esPerruna ? 'Snack Canino' : (recetaGenerada['tipo_comida'] ?? 'Comida');

      final resReceta = await ServicioRecetas.insertarReceta(
        titulo: recetaGenerada['titulo'] ??
            (esPerruna ? 'Snack Canino Chef' : 'Receta Chef IA'),
        descripcion: descCompleta.isNotEmpty
            ? descCompleta
            : (recetaGenerada['descripcion'] ?? ''),
        instrucciones: recetaGenerada['instrucciones'] ?? '',
        tipoComida: tipoComidaFinal,
        calorias: recetaGenerada['calorias'] is num
            ? (recetaGenerada['calorias'] as num).toInt()
            : int.tryParse(
                recetaGenerada['calorias']?.toString() ??
                    (esPerruna ? '250' : '450'),
              ),
        macros: recetaGenerada['macros']?.toString(),
        imagenUrl: esPerruna
            ? 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=500'
            : 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=500',
        esOficial: esPerruna ? false : ServicioAdmin.esAdmin(),
        esPublica: true,
      );

      final int idRecetaNueva = resReceta['id_receta'];

      for (var ing in ingredientes) {
        String nombreEstandar = ing['nombre_estandar']
            .toString()
            .trim()
            .toLowerCase();
        double cantidad = (ing['cantidad'] as num).toDouble();
        String unidad = ing['unidad'].toString().trim().toLowerCase();

        final matchIngrediente = await supabase
            .from('ingredientes_genericos')
            .select('id_ingrediente')
            .eq('nombre_estandar', nombreEstandar)
            .maybeSingle();

        int idIngrediente;

        if (matchIngrediente != null) {
          idIngrediente = matchIngrediente['id_ingrediente'];
        } else {
          final nuevoIngrediente = await supabase
              .from('ingredientes_genericos')
              .insert({'nombre_estandar': nombreEstandar})
              .select('id_ingrediente')
              .single();

          idIngrediente = nuevoIngrediente['id_ingrediente'];
        }

        await supabase.from('receta_detalle').insert({
          'id_receta': idRecetaNueva,
          'id_ingrediente': idIngrediente,
          'cantidad': cantidad,
          'unidad_medida': unidad,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              esPerruna
                  ? '¡Receta canina guardada en el Recetario Canino 🐾 y compartida con la comunidad!'
                  : '¡Receta "${recetaGenerada['titulo']}" guardada con éxito! 🎉',
            ),
            backgroundColor: esPerruna ? Colors.brown.shade700 : Colors.green,
            duration: const Duration(seconds: 4),
            action: esPerruna
                ? SnackBarAction(
                    label: 'Ver Recetario 🐾',
                    textColor: Colors.amberAccent,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PantallaRecetasCaninas(),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
        _ingredientesCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar en base de datos: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ingredientesCtrl.dispose();
    super.dispose();
  }

  LinearGradient _obtenerGradienteCocina(String tipo) {
    switch (tipo) {
      case TiposCocina.mexicana:
        return LinearGradient(
          colors: [Colors.green.shade800, Colors.red.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case TiposCocina.italiana:
        return LinearGradient(
          colors: [Colors.green.shade700, Colors.red.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case TiposCocina.japonesa:
        return LinearGradient(
          colors: [Colors.red.shade900, Colors.grey.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case TiposCocina.thai:
        return LinearGradient(
          colors: [Colors.deepOrange.shade600, Colors.amber.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case TiposCocina.francesa:
        return LinearGradient(
          colors: [Colors.blue.shade900, Colors.red.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case TiposCocina.espanola:
        return LinearGradient(
          colors: [Colors.amber.shade800, Colors.red.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case TiposCocina.mediterranea:
        return LinearGradient(
          colors: [Colors.teal.shade700, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case TiposCocina.china:
        return LinearGradient(
          colors: [Colors.red.shade900, Colors.amber.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case TiposCocina.india:
        return LinearGradient(
          colors: [Colors.orange.shade800, Colors.deepPurple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case TiposCocina.americana:
        return LinearGradient(
          colors: [Colors.indigo.shade800, Colors.red.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case TiposCocina.todas:
      default:
        return LinearGradient(
          colors: [Colors.blueGrey.shade800, Colors.teal.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Widget _construirSelectorTarjetasCocina(Color colorTema) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.public, color: Colors.deepOrange, size: 20),
                SizedBox(width: 8),
                Text(
                  'Tipo de Cocina / Gastronomía 🎴',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${TiposCocina.iconos[_tipoCocinaSeleccionado] ?? "🍽️"} $_tipoCocinaSeleccionado',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorTema,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Desliza y selecciona la gastronomía que se te antoja para inspirar al Chef IA:',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 145,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: TiposCocina.lista.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final cocina = TiposCocina.lista[index];
              final bool isSelected = _tipoCocinaSeleccionado == cocina;
              final String icono = TiposCocina.iconos[cocina] ?? '🍽️';
              final String desc = TiposCocina.descripciones[cocina] ?? '';
              final String ejemplo =
                  (TiposCocina.platillosEmblematicos[cocina]?.take(2).join(', ')) ??
                      '';

              return GestureDetector(
                onTap: () {
                  setState(() => _tipoCocinaSeleccionado = cocina);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 140,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: _obtenerGradienteCocina(cocina),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.25),
                      width: isSelected ? 2.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  icono,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: colorTema,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            cocina,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ejemplo.isNotEmpty ? ejemplo : desc,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 10.5,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      if (!isSelected)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color colorPremium = Colors.red.shade800;

    return Scaffold(
      drawer: const MenuLateral(rutaActual: 'chef'),
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
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            _modoPerruno ? 'Chef Perruno 🐾' : 'Chef IA 👨‍🍳',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: const Color(0xFF1E2022),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🐾 TARJETA / INTERRUPTOR DE MODO PERRUNO
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _modoPerruno
                      ? Colors.amber.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _modoPerruno
                        ? Colors.amber.shade700
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    _modoPerruno
                        ? 'Modo Chef Perruno Activado 🐾'
                        : 'Activar Recetas para Perritos 🐶',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _modoPerruno
                          ? Colors.amber.shade900
                          : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    _modoPerruno
                        ? 'Generando snacks y comida segura para mascotas'
                        : 'Cambia para inventar comida apta para tus perros',
                    style: const TextStyle(fontSize: 12),
                  ),
                  secondary: Icon(
                    _modoPerruno ? Icons.pets : Icons.restaurant,
                    color: _modoPerruno ? Colors.amber.shade800 : Colors.grey,
                    size: 30,
                  ),
                  activeThumbColor:
                      Colors.amber.shade800, // Actualizado a activeThumbColor
                  value: _modoPerruno,
                  onChanged: (val) {
                    setState(() => _modoPerruno = val);
                  },
                ),
              ),
              const SizedBox(height: 24),

              Icon(
                _modoPerruno ? Icons.pets : Icons.auto_awesome,
                size: 60,
                color: colorPremium,
              ),
              const SizedBox(height: 16),
              Text(
                _modoPerruno
                    ? '¿Qué ingredientes seguros tienes para tu perrito?'
                    : '¿Qué tienes en tu despensa o qué se te antoja?',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _modoPerruno
                    ? 'Ingresa pollo, avena, zanahoria, o déjalo vacío para sugerencia veterinaria.'
                    : 'Ingresa ingredientes disponibles, el antojo del día, o déjalo vacío para que el Chef IA te sorprenda.',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              TextField(
                controller: _ingredientesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: _modoPerruno
                      ? 'Ej. Pollo hervido, zanahoria (Opcional)'
                      : 'Ej. Pechuga de pollo, espinacas, o algo picante y caldoso (Opcional)',
                  floatingLabelStyle: TextStyle(
                    color: colorPremium,
                    fontWeight: FontWeight.bold,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colorPremium, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 24),

              // Ocultamos tipos de comida, objetivos y gastronomía si está en modo perruno
              if (!_modoPerruno) ...[
                // ⏱️ ATAJOS EXPRESS Y CERO TRASTES
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFF3E0),
                        Colors.orange.shade50,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.orange.shade300,
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFFE65100), size: 22),
                          const SizedBox(width: 8),
                          Text(
                            '¿Poco tiempo o cansancio hoy? ⏱️',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.brown.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Activa modos rápidos para que el Chef IA diseñe recetas de fuego vivo, ensamble y mínimo desorden:',
                        style: TextStyle(fontSize: 12, color: Colors.brown.shade700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            avatar: const Text('⚡', style: TextStyle(fontSize: 14)),
                            label: const Text('Modo Express (≤ 15 min)'),
                            selected: _modoExpress,
                            selectedColor: const Color(0xFFE65100),
                            backgroundColor: Colors.white,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _modoExpress ? Colors.white : const Color(0xFFE65100),
                              fontWeight: _modoExpress ? FontWeight.bold : FontWeight.w600,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: _modoExpress
                                    ? Colors.transparent
                                    : const Color(0xFFE65100).withValues(alpha: 0.4),
                              ),
                            ),
                            onSelected: (val) => setState(() => _modoExpress = val),
                          ),
                          FilterChip(
                            avatar: const Text('🍳', style: TextStyle(fontSize: 14)),
                            label: const Text('Cero Trastes (1 Sartén)'),
                            selected: _modoCeroTrastes,
                            selectedColor: const Color(0xFF00695C),
                            backgroundColor: Colors.white,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _modoCeroTrastes ? Colors.white : const Color(0xFF00695C),
                              fontWeight: _modoCeroTrastes ? FontWeight.bold : FontWeight.w600,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: _modoCeroTrastes
                                    ? Colors.transparent
                                    : const Color(0xFF00695C).withValues(alpha: 0.4),
                              ),
                            ),
                            onSelected: (val) => setState(() => _modoCeroTrastes = val),
                          ),
                          FilterChip(
                            avatar: const Text('🥗', style: TextStyle(fontSize: 14)),
                            label: const Text('Sin Estufa / Frío (5-10 min)'),
                            selected: _modoSinFuego,
                            selectedColor: const Color(0xFF2E7D32),
                            backgroundColor: Colors.white,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _modoSinFuego ? Colors.white : const Color(0xFF2E7D32),
                              fontWeight: _modoSinFuego ? FontWeight.bold : FontWeight.w600,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: _modoSinFuego
                                    ? Colors.transparent
                                    : const Color(0xFF2E7D32).withValues(alpha: 0.4),
                              ),
                            ),
                            onSelected: (val) => setState(() => _modoSinFuego = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tipo de Platillo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _tiposComida.map((tipo) {
                    final bool isSelected = _tipoComidaSeleccionado == tipo;
                    return ChoiceChip(
                      label: Text(tipo),
                      selected: isSelected,
                      selectedColor: colorPremium,
                      backgroundColor: Colors.grey.shade200,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _tipoComidaSeleccionado = tipo);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Perfil Calórico / Objetivo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _objetivosSalud.map((objetivo) {
                    final bool isSelected = _objetivoSeleccionado == objetivo;
                    return ChoiceChip(
                      label: Text(objetivo),
                      selected: isSelected,
                      selectedColor: colorPremium,
                      backgroundColor: Colors.grey.shade200,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _objetivoSeleccionado = objetivo);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // 🎴 BARRA DE TARJETAS DE TIPO DE COCINA / GASTRONOMÍA
                _construirSelectorTarjetasCocina(colorPremium),
                const SizedBox(height: 24),

                const Text(
                  'Equipo / Robot de Cocina 🤖',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: ModoElectrodomestico.values.map((modo) {
                    final bool isSelected =
                        _electrodomesticoSeleccionado == modo;
                    final Color chipColor =
                        modo == ModoElectrodomestico.thermomix
                            ? const Color(0xFF00897B)
                            : modo == ModoElectrodomestico.airFryer
                                ? const Color(0xFFF57C00)
                                : colorPremium;

                    return ChoiceChip(
                      avatar: Text(
                        modo.icono,
                        style: const TextStyle(fontSize: 14),
                      ),
                      label: Text(
                        modo == ModoElectrodomestico.thermomix
                            ? 'Thermomix (TM5/TM6/TM7)'
                            : modo == ModoElectrodomestico.airFryer
                                ? 'Air Fryer'
                                : 'Tradicional (Estufa)',
                      ),
                      selected: isSelected,
                      selectedColor: chipColor,
                      backgroundColor: Colors.grey.shade200,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _electrodomesticoSeleccionado = modo);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
              ] else ...[
                const SizedBox(height: 20),
              ],

              ElevatedButton.icon(
                onPressed: _generando ? null : generarRecetaPreview,
                icon: _generando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(_modoPerruno ? Icons.pets : Icons.restaurant_menu),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _generando
                        ? 'Cocinando...'
                        : (_modoPerruno
                              ? 'Cocinar Snack Perruno 🐾'
                              : (_electrodomesticoSeleccionado ==
                                      ModoElectrodomestico.thermomix
                                  ? 'Cocinar con Thermomix 🤖'
                                  : (_electrodomesticoSeleccionado ==
                                          ModoElectrodomestico.airFryer
                                      ? 'Cocinar con Air Fryer 🍟'
                                      : (_tipoCocinaSeleccionado ==
                                              TiposCocina.todas
                                          ? 'Cocinar Receta con IA 👨‍🍳'
                                          : 'Cocinar Receta $_tipoCocinaSeleccionado con IA 👨‍🍳')))),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _modoPerruno
                      ? Colors.amber.shade800
                      : (_electrodomesticoSeleccionado ==
                              ModoElectrodomestico.thermomix
                          ? const Color(0xFF00897B)
                          : (_electrodomesticoSeleccionado ==
                                  ModoElectrodomestico.airFryer
                              ? const Color(0xFFF57C00)
                              : colorPremium)),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
