import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'config_api.dart';
import 'perfiles_nutricionales.dart';
import 'servicio_preferencias.dart';
import 'menu_lateral.dart';

class PantallaChef extends StatefulWidget {
  final String? ingredientesIniciales;

  const PantallaChef({super.key, this.ingredientesIniciales});

  @override
  State<PantallaChef> createState() => _PantallaChefState();
}

class _PantallaChefState extends State<PantallaChef> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool _generando = false;
  bool _modoPerruno = false; // 🐾 Interruptor para recetas de perritos

  final TextEditingController _ingredientesCtrl = TextEditingController();

  String _tipoComidaSeleccionado = 'Comida';
  String _objetivoSeleccionado = 'Mantenimiento 2,000 kcal';
  String _alergias = '';
  List<String> _estilos = [PerfilesNutricionales.libre];

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
    bool esPerruno,
  ) {
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
        ? '- Ingredientes principales a usar (prioriza estos pero puedes agregar básicos): $ingredientesBase'
        : '- Ingredientes: ¡Tienes libertad creativa total! Inventa una receta deliciosa y original desde cero.';

    final String instruccionAlergias = _alergias.trim().isNotEmpty
        ? '- ALERGIAS Y RESTRICCIONES (PROHIBIDO USAR): ${_alergias.trim()}.'
        : '';

    final String instruccionEstilos =
        PerfilesNutricionales.instruccionesPrompt(_estilos);

    return '''
    Eres el chef principal y nutriólogo de la app "Jitomate y Cebolla".
    Tu tarea es crear una receta deliciosa, realista y fácil de preparar.
    
    Parámetros obligatorios:
    $instruccionIngredientes
    $instruccionAlergias
    $instruccionEstilos
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
      "instrucciones": "1. Primer paso.\\n2. Segundo paso.\\n3. Tercer paso."
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
        _modoPerruno,
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
                      Row(
                        children: [
                          Chip(
                            label: Text('${receta['calorias'] ?? 0} kcal'),
                            backgroundColor: Colors.red.shade50,
                            labelStyle: TextStyle(
                              color: colorPremium,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              receta['macros'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
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
      sb.writeln('\n📝 INGREDIENTES:');
      for (var ing in ingredientes) {
        sb.writeln('- ${ing['cantidad']} ${ing['unidad']} ${ing['nombre_estandar']}');
      }
      sb.writeln('\n🍳 INSTRUCCIONES:');
      sb.writeln(instrucciones);

      final String descCompleta = sb.toString().trim();

      final resReceta = await supabase
          .from('recetas')
          .insert({
            'titulo': recetaGenerada['titulo'],
            'descripcion': descCompleta.isNotEmpty ? descCompleta : recetaGenerada['descripcion'],
            'tipo_comida': recetaGenerada['tipo_comida'],
            'calorias': recetaGenerada['calorias'],
            'macros': recetaGenerada['macros'],
            'instrucciones': recetaGenerada['instrucciones'],
            'imagen_url': 'https://via.placeholder.com/300',
          })
          .select('id_receta')
          .single();

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
              '¡Receta "${recetaGenerada['titulo']}" guardada con éxito! 🎉',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
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

  @override
  Widget build(BuildContext context) {
    final Color colorPremium = Colors.red.shade800;

    return Scaffold(
      drawer: const MenuLateral(rutaActual: 'chef'),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú principal',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(_modoPerruno ? 'Chef Perruno 🐾' : 'Chef IA 👨‍🍳'),
        backgroundColor: colorPremium,
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
                    : '¿Qué tienes en tu despensa?',
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
                    : 'Ingresa ingredientes, o deja el campo vacío para que la IA te sorprenda.',
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
                      : 'Ej. Pechuga de pollo, espinacas (Opcional)',
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

              // Ocultamos tipos de comida y objetivos si está en modo perruno para simplificar
              if (!_modoPerruno) ...[
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
                const SizedBox(height: 40),
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
                label: Text(
                  _generando
                      ? 'Cocinando...'
                      : (_modoPerruno
                            ? 'Cocinar Snack Perruno 🐾'
                            : 'Cocinar Receta con IA'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _modoPerruno
                      ? Colors.amber.shade800
                      : colorPremium,
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
