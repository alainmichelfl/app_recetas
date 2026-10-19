import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_chef.dart';
import 'perfiles_nutricionales.dart';
import 'servicio_preferencias.dart';
import 'utensilios_cocina.dart';

/// Modal de Onboarding guiado en 4 pasos para nuevos usuarios o acceso desde el menú:
/// 1. Preferencias y Perfil Culinario (Porciones, Dieta, Súper y Alergias)
/// 2. Despensa Express (12 básicos en 1 clic)
/// 3. Arsenal de Electrodomésticos y Utensilios
/// 4. Pilares Disruptivos y Primer Platillo con Chef IA
class DialogoOnboardingBienvenida extends StatefulWidget {
  final VoidCallback? alFinalizar;

  const DialogoOnboardingBienvenida({super.key, this.alFinalizar});

  static const String keyOnboardingCompletado = 'pref_onboarding_completado_v1';

  /// Verifica si el usuario ya vio el onboarding, de lo contrario lo despliega automáticamente
  static Future<void> verificarYMostrar(
    BuildContext context, {
    bool forzar = false,
    VoidCallback? alFinalizar,
  }) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final bool yaVisto = sp.getBool(keyOnboardingCompletado) ?? false;

      if (!yaVisto || forzar) {
        if (context.mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black.withValues(alpha: 0.75),
            builder: (ctx) => DialogoOnboardingBienvenida(alFinalizar: alFinalizar),
          );
        }
      }
    } catch (e) {
      debugPrint('Error verificando onboarding: $e');
    }
  }

  @override
  State<DialogoOnboardingBienvenida> createState() =>
      _DialogoOnboardingBienvenidaState();
}

class _DialogoOnboardingBienvenidaState
    extends State<DialogoOnboardingBienvenida> {
  int _pasoActual = 0; // 0: Preferencias, 1: Despensa, 2: Utensilios, 3: Pilares & Chef
  bool _guardando = false;
  bool _noVolverAMostrar = true;

  // Paso 1: Preferencias Culinarias y del Hogar
  int _porciones = 2;
  String _objetivo = PerfilesNutricionales.mantenimiento;
  final Set<String> _estilosSeleccionados = {PerfilesNutricionales.libre};
  String _superFavorito = 'Walmart';
  final Set<String> _alergiasSeleccionadas = <String>{};

  final List<int> _opcionesPorciones = const [1, 2, 4, 6];

  final List<String> _opcionesSuper = const [
    'Walmart',
    'Soriana',
    'La Comer',
    'Chedraui',
    'Central de Abasto',
  ];

  final List<Map<String, String>> _catalogoAlergiasComunes = const [
    {'nombre': 'Sin mariscos', 'emoji': '🦐'},
    {'nombre': 'Sin lácteos', 'emoji': '🥛'},
    {'nombre': 'Sin gluten', 'emoji': '🌾'},
    {'nombre': 'Sin cacahuate/nueces', 'emoji': '🥜'},
    {'nombre': 'Sin huevo', 'emoji': '🥚'},
  ];

  // Paso 2: Ingredientes básicos frecuentes
  final Set<String> _ingredientesSeleccionados = {
    'Jitomate',
    'Cebolla',
    'Ajo',
    'Huevo',
    'Aceite de oliva',
  };

  final List<Map<String, String>> _catalogoIngredientesBasicos = const [
    {'nombre': 'Jitomate', 'emoji': '🍅'},
    {'nombre': 'Cebolla', 'emoji': '🧅'},
    {'nombre': 'Ajo', 'emoji': '🧄'},
    {'nombre': 'Huevo', 'emoji': '🥚'},
    {'nombre': 'Pechuga de pollo', 'emoji': '🍗'},
    {'nombre': 'Arroz', 'emoji': '🌾'},
    {'nombre': 'Frijoles', 'emoji': '🫘'},
    {'nombre': 'Aceite de oliva', 'emoji': '🫒'},
    {'nombre': 'Queso', 'emoji': '🧀'},
    {'nombre': 'Pasta', 'emoji': '🍝'},
    {'nombre': 'Atún en lata', 'emoji': '🐟'},
    {'nombre': 'Limón', 'emoji': '🍋'},
    {'nombre': 'Aguacate', 'emoji': '🥑'},
    {'nombre': 'Tortillas', 'emoji': '🫓'},
    {'nombre': 'Papas', 'emoji': '🥔'},
  ];

  // Paso 3: Utensilios y electrodomésticos
  final Set<String> _utensiliosSeleccionados = {
    'sarten',
    'licuadora',
  };

  @override
  void initState() {
    super.initState();
    _cargarDatosExistentes();
  }

  Future<void> _cargarDatosExistentes() async {
    try {
      // 1. Cargar preferencias existentes si las hay
      final prefs = await ServicioPreferencias.obtenerPreferencias();
      if (mounted) {
        setState(() {
          _porciones = prefs.porciones.clamp(1, 12);
          _objetivo = prefs.objetivo;
          if (prefs.estilos.isNotEmpty) {
            _estilosSeleccionados.clear();
            _estilosSeleccionados.addAll(prefs.estilos);
          }
          if (_opcionesSuper.contains(prefs.superFavorito)) {
            _superFavorito = prefs.superFavorito;
          }
          if (prefs.alergias.isNotEmpty) {
            final partes = prefs.alergias.split(',').map((e) => e.trim());
            _alergiasSeleccionadas.addAll(partes);
          }
        });
      }

      // 2. Cargar utensilios activos
      final ids = await UtensiliosCocina.cargarUtensiliosActivos();
      if (mounted && ids.isNotEmpty) {
        setState(() {
          _utensiliosSeleccionados.clear();
          _utensiliosSeleccionados.addAll(ids);
        });
      }
    } catch (e) {
      debugPrint('Error cargando preferencias iniciales en onboarding: $e');
    }
  }

  Future<void> _cerrarOmitir() async {
    if (_noVolverAMostrar) {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(DialogoOnboardingBienvenida.keyOnboardingCompletado, true);
    }
    if (mounted) {
      Navigator.pop(context);
      widget.alFinalizar?.call();
    }
  }

  Future<void> _completarOnboarding({bool irAlChef = false}) async {
    setState(() => _guardando = true);
    try {
      if (_noVolverAMostrar) {
        final sp = await SharedPreferences.getInstance();
        await sp.setBool(DialogoOnboardingBienvenida.keyOnboardingCompletado, true);
      }

      // 1. Guardar Preferencias de Perfil
      final prefsActuales = await ServicioPreferencias.obtenerPreferencias();
      final nuevasPrefs = prefsActuales.copyWith(
        porciones: _porciones,
        objetivo: _objetivo,
        estilos: _estilosSeleccionados.toList(),
        superFavorito: _superFavorito,
        alergias: _alergiasSeleccionadas.join(', '),
        utensilios: _utensiliosSeleccionados.toList(),
      );
      await ServicioPreferencias.guardarPreferencias(nuevasPrefs);

      // 2. Guardar utensilios activos en utilería
      await UtensiliosCocina.guardarUtensiliosActivos(
        _utensiliosSeleccionados.toList(),
      );

      // 3. Insertar ingredientes seleccionados en despensa_usuario si no existen
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && _ingredientesSeleccionados.isNotEmpty) {
        final client = Supabase.instance.client;
        for (var ing in _ingredientesSeleccionados) {
          try {
            await client.from('despensa_usuario').upsert({
              'user_id': user.id,
              'nombre': ing,
              'cantidad': 1,
              'unidad_medida': 'pza',
              'fecha_ingreso': DateTime.now().toIso8601String(),
            });
          } catch (_) {
            // Ignorar duplicados o errores individuales de red
          }
        }
      }
    } catch (e) {
      debugPrint('Error finalizando onboarding: $e');
    }

    if (mounted) {
      setState(() => _guardando = false);
      Navigator.pop(context);
      widget.alFinalizar?.call();

      if (irAlChef) {
        final ingredientesPrompt = _ingredientesSeleccionados.join(', ');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaChef(
              ingredientesIniciales: ingredientesPrompt,
              modoExpressInicial: true,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: _guardando
            ? const Padding(
                padding: EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.deepOrange),
                    SizedBox(height: 16),
                    Text(
                      'Configurando tu cocina inteligente...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Encabezado con indicador de pasos
                  _construirHeaderPasos(),

                  const Divider(height: 1),

                  // Contenido interactivo del paso
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _construirCuerpoPaso(),
                    ),
                  ),

                  const Divider(height: 1),

                  // Botonera inferior
                  _construirBotoneraInferior(),
                ],
              ),
      ),
    );
  }

  Widget _construirHeaderPasos() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2022),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.explore_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Tour de Bienvenida 🧭',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Paso ${_pasoActual + 1} de 4',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                    tooltip: 'Cerrar tour',
                    onPressed: _cerrarOmitir,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Barra de progreso de los 4 pasos
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_pasoActual + 1) / 4,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD32F2F)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirCuerpoPaso() {
    switch (_pasoActual) {
      case 0:
        return _construirPaso1Preferencias();
      case 1:
        return _construirPaso2Despensa();
      case 2:
        return _construirPaso3Utensilios();
      case 3:
      default:
        return _construirPaso4ChefIA();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PASO 1: PREFERENCIAS CULINARIAS Y DEL HOGAR
  // ─────────────────────────────────────────────────────────────
  Widget _construirPaso1Preferencias() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Tu Perfil & Preferencias Culinarias 🥗👤',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Personaliza tus porciones, estilo de vida y supermercado para que el Chef IA y el cotizador se adapten a tu realidad desde el primer segundo.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
        ),
        const SizedBox(height: 18),

        // 1. Porciones habituales
        const Text(
          '¿Para cuántas personas cocinas normalmente?',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _opcionesPorciones.map((p) {
            final bool sel = _porciones == p;
            final label = p == 1
                ? '👤 1 persona'
                : p == 2
                    ? '👥 2 personas'
                    : p == 4
                        ? '👨‍👩‍👧‍👦 4 familia'
                        : '🎉 6+ personas';
            return ChoiceChip(
              label: Text(label),
              selected: sel,
              selectedColor: Colors.deepOrange.shade100,
              labelStyle: TextStyle(
                fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                color: sel ? Colors.deepOrange.shade900 : Colors.black87,
                fontSize: 12.5,
              ),
              onSelected: (_) => setState(() => _porciones = p),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // 2. Objetivo Calórico
        const Text(
          'Meta u Objetivo Nutricional:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: PerfilesNutricionales.objetivos.map((obj) {
            final bool sel = _objetivo == obj;
            final emoji = obj.contains('Déficit')
                ? '🏃‍♂️'
                : obj.contains('Volumen')
                    ? '💪'
                    : '⚖️';
            return ChoiceChip(
              avatar: Text(emoji),
              label: Text(obj),
              selected: sel,
              selectedColor: Colors.deepOrange.shade100,
              labelStyle: TextStyle(
                fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                color: sel ? Colors.deepOrange.shade900 : Colors.black87,
                fontSize: 12.5,
              ),
              onSelected: (_) => setState(() => _objetivo = obj),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // 3. Estilos de Dieta
        const Text(
          'Estilos de Alimentación (Elige los que apliquen):',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: PerfilesNutricionales.estilos.map((estilo) {
            final bool sel = _estilosSeleccionados.contains(estilo);
            return FilterChip(
              label: Text(estilo),
              selected: sel,
              selectedColor: Colors.teal.shade100,
              checkmarkColor: Colors.teal.shade900,
              labelStyle: TextStyle(
                fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                color: sel ? Colors.teal.shade900 : Colors.black87,
                fontSize: 12,
              ),
              onSelected: (val) {
                setState(() {
                  if (estilo == PerfilesNutricionales.libre) {
                    _estilosSeleccionados.clear();
                    _estilosSeleccionados.add(PerfilesNutricionales.libre);
                  } else {
                    _estilosSeleccionados.remove(PerfilesNutricionales.libre);
                    if (val) {
                      _estilosSeleccionados.add(estilo);
                    } else {
                      _estilosSeleccionados.remove(estilo);
                    }
                    if (_estilosSeleccionados.isEmpty) {
                      _estilosSeleccionados.add(PerfilesNutricionales.libre);
                    }
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // 4. Supermercado Favorito
        const Text(
          'Tu Supermercado Habitual para Cotizar:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _opcionesSuper.map((sup) {
            final bool sel = _superFavorito == sup;
            final emoji = sup == 'Walmart'
                ? '🛒'
                : sup == 'Soriana'
                    ? '🔴'
                    : sup == 'La Comer'
                        ? '🟠'
                        : sup == 'Chedraui'
                            ? '🟡'
                            : '🏬';
            return ChoiceChip(
              avatar: Text(emoji),
              label: Text(sup),
              selected: sel,
              selectedColor: Colors.indigo.shade100,
              labelStyle: TextStyle(
                fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                color: sel ? Colors.indigo.shade900 : Colors.black87,
                fontSize: 12.5,
              ),
              onSelected: (_) => setState(() => _superFavorito = sup),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // 5. Alergias o Restricciones
        const Text(
          'Alergias o Restricciones Frecuentes:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _catalogoAlergiasComunes.map((a) {
            final nombre = a['nombre']!;
            final emoji = a['emoji']!;
            final bool sel = _alergiasSeleccionadas.contains(nombre);
            return FilterChip(
              avatar: Text(emoji),
              label: Text(nombre),
              selected: sel,
              selectedColor: Colors.red.shade100,
              checkmarkColor: Colors.red.shade900,
              labelStyle: TextStyle(
                fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                color: sel ? Colors.red.shade900 : Colors.black87,
                fontSize: 12,
              ),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _alergiasSeleccionadas.add(nombre);
                  } else {
                    _alergiasSeleccionadas.remove(nombre);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PASO 2: DESPENSA EXPRESS
  // ─────────────────────────────────────────────────────────────
  Widget _construirPaso2Despensa() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. ¿Qué tienes en tu cocina hoy? 🥫',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Toca los alimentos que ya tienes en casa. Los guardaremos en tu Despensa para sugerirte recetas sin que tengas que ir al súper.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _catalogoIngredientesBasicos.map((item) {
            final nombre = item['nombre']!;
            final emoji = item['emoji']!;
            final bool seleccionado = _ingredientesSeleccionados.contains(nombre);

            return FilterChip(
              avatar: Text(emoji, style: const TextStyle(fontSize: 14)),
              label: Text(nombre),
              selected: seleccionado,
              selectedColor: Colors.deepOrange.shade100,
              checkmarkColor: Colors.deepOrange.shade900,
              labelStyle: TextStyle(
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                color: seleccionado ? Colors.deepOrange.shade900 : Colors.black87,
                fontSize: 13,
              ),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _ingredientesSeleccionados.add(nombre);
                  } else {
                    _ingredientesSeleccionados.remove(nombre);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_ingredientesSeleccionados.length} ingredientes seleccionados. Podrás añadir más en cualquier momento.',
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PASO 3: ARSENAL DE UTENSILIOS Y ELECTRODOMÉSTICOS
  // ─────────────────────────────────────────────────────────────
  Widget _construirPaso3Utensilios() {
    final catalogo = UtensiliosCocina.catalogo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. ¿Qué equipo tienes en tu cocina? 🍳',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'El Chef IA solo te sugerirá recetas que puedas preparar con tu equipo disponible (evitando pedirte aparatos que no tengas).',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: catalogo.map((u) {
            final bool activo = _utensiliosSeleccionados.contains(u.id);

            return FilterChip(
              avatar: Text(u.icono, style: const TextStyle(fontSize: 14)),
              label: Text(u.nombre),
              selected: activo,
              selectedColor: Colors.teal.shade100,
              checkmarkColor: Colors.teal.shade900,
              labelStyle: TextStyle(
                fontWeight: activo ? FontWeight.bold : FontWeight.w500,
                color: activo ? Colors.teal.shade900 : Colors.black87,
                fontSize: 13,
              ),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _utensiliosSeleccionados.add(u.id);
                  } else {
                    _utensiliosSeleccionados.remove(u.id);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.teal, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_utensiliosSeleccionados.length} utensilios activos. Ajustables en Mis Preferencias.',
                  style: TextStyle(fontSize: 12, color: Colors.teal.shade900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PASO 4: PILARES Y CHEF IA
  // ─────────────────────────────────────────────────────────────
  Widget _construirPaso4ChefIA() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '4. ¡Todo listo para cocinar como un Chef! 🚀',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Tus preferencias, despensa y equipo quedaron configurados. Mira los 5 pilares que resuelven tu comida y tus finanzas:',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        _tarjetaPilar(
          icono: Icons.bolt_rounded,
          color: Colors.deepOrange,
          titulo: '⚡ Cocina Express (≤ 15 min)',
          descripcion:
              'Recetas ultra rápidas, modo Cero Trastes (1 sartén) y ensamble en frío para no perder tiempo.',
        ),
        const SizedBox(height: 10),
        _tarjetaPilar(
          icono: Icons.auto_awesome,
          color: Colors.purple,
          titulo: '🤖 Chef IA Personalizado',
          descripcion:
              'Inventa platillos combinando exactamente tu despensa con tu meta de $_objetivo y porciones para $_porciones personas.',
        ),
        const SizedBox(height: 10),
        _tarjetaPilar(
          icono: Icons.wine_bar_rounded,
          color: const Color(0xFF6A1B9A),
          titulo: '🍷 Sommelier & Maridaje',
          descripcion:
              'Recomienda vinos, destilados y mocktails 0.0% alcohol para elevar tus cenas en casa.',
        ),
        const SizedBox(height: 10),
        _tarjetaPilar(
          icono: Icons.store_mall_directory_rounded,
          color: Colors.amber.shade900,
          titulo: '🛒 Modo Supermercado Focus',
          descripcion:
              'Pasillos ordenados por categorías físicas y botones táctiles gigantes para cotizar en $_superFavorito con una sola mano.',
        ),
      ],
    );
  }

  Widget _tarjetaPilar({
    required IconData icono,
    required Color color,
    required String titulo,
    required String descripcion,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: color is MaterialColor ? color.shade900 : color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  descripcion,
                  style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBotoneraInferior() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Checkbox(
                value: _noVolverAMostrar,
                activeColor: const Color(0xFFD32F2F),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (val) {
                  setState(() => _noVolverAMostrar = val ?? true);
                },
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'No volver a mostrar al iniciar sesión',
                  style: TextStyle(fontSize: 11.5, color: Colors.black54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_pasoActual > 0)
                OutlinedButton(
                  onPressed: () => setState(() => _pasoActual--),
                  child: const Text('Anterior'),
                )
              else
                TextButton(
                  onPressed: _cerrarOmitir,
                  child: const Text('Omitir Tour', style: TextStyle(color: Colors.grey)),
                ),
              if (_pasoActual < 3)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Siguiente'),
                  onPressed: () => setState(() => _pasoActual++),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: const Text('¡Cocinar con Chef IA!'),
                  onPressed: () => _completarOnboarding(irAlChef: true),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
