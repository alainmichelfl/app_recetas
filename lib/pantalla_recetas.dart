import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'conversor_unidades.dart';
import 'pantalla_chef.dart';
import 'pantalla_detalle_receta.dart';
import 'pantalla_planeador.dart';
import 'pantalla_recetas_caninas.dart';
import 'servicio_ia.dart';
import 'servicio_historial_cocina.dart';
import 'menu_lateral.dart';
import 'servicio_admin.dart';
import 'servicio_recetas.dart';
import 'servicio_cocina_express.dart';
import 'pantalla_carga_masiva_recetas.dart';
import 'dialogo_manifiesto_bienvenida.dart';
import 'dialogo_busqueda_spotlight.dart';
import 'dialogo_onboarding_bienvenida.dart';
import 'servicio_recordatorios.dart';
import 'servicio_perfil_usuario.dart';

class PantallaRecetas extends StatefulWidget {
  final FiltroAudienciaReceta? filtroInicial;
  final String? rutaMenu;

  const PantallaRecetas({
    super.key,
    this.filtroInicial,
    this.rutaMenu,
  });

  @override
  State<PantallaRecetas> createState() => _PantallaRecetasState();
}

class _PantallaRecetasState extends State<PantallaRecetas> {
  List<Map<String, dynamic>> todasLasRecetas = [];
  List<Map<String, dynamic>> recetasFiltradas = [];
  Set<int> _idsCocinadas = {};
  Set<String> _titulosCocinados = {};
  bool cargando = true;

  FiltroAudienciaReceta _filtroAudiencia = FiltroAudienciaReceta.todas;
  FiltroExpress _filtroExpress = FiltroExpress.todos;

  final TextEditingController _searchController = TextEditingController();
  String categoriaSeleccionada = 'Todos';
  final List<String> categorias = [
    'Todos',
    'Desayuno',
    'Comida',
    'Cena',
    'Snack',
  ];

  // 🧊 Búsqueda por ingredientes disponibles ("¿Qué cocino con lo que tengo?")
  final Set<String> _ingredientesSeleccionados = {};
  List<String> _ingredientesDespensa = [];

  // 💡 Tarjeta explicativa de inicio (4 Pilares)
  bool _mostrarBannerInicioExplicativo = true;

  @override
  void initState() {
    super.initState();
    if (widget.filtroInicial != null) {
      _filtroAudiencia = widget.filtroInicial!;
    }
    cargarRecetas();
    _cargarPreferenciaBannerInicio();
    _searchController.addListener(_filtrarRecetas);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarYMostrarAgradecimiento();
      DialogoOnboardingBienvenida.verificarYMostrar(context, alFinalizar: () {
        DialogoManifiestoBienvenida.verificarYMostrar(context);
      });
    });
  }

  Future<void> _cargarPreferenciaBannerInicio() async {
    final prefs = await SharedPreferences.getInstance();
    final oculto = prefs.getBool('banner_inicio_explicativo_oculto_v2') ?? false;
    if (mounted) {
      setState(() => _mostrarBannerInicioExplicativo = !oculto);
    }
  }

  Future<void> _ocultarBannerInicioExplicativo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('banner_inicio_explicativo_oculto_v2', true);
    if (mounted) {
      setState(() => _mostrarBannerInicioExplicativo = false);
    }
  }

  Future<void> _reactivarBannerInicioExplicativo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('banner_inicio_explicativo_oculto_v2', false);
    if (mounted) {
      setState(() => _mostrarBannerInicioExplicativo = true);
    }
  }

  void _mostrarCentroDeAyudaYBienvenida() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E2022),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lightbulb, color: Colors.amberAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Centro de Bienvenida y Ayuda',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Jitomate y Cebolla • Guía rápida y preferencias',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.white.withValues(alpha: 0.05),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFD32F2F),
                child: Icon(Icons.tune_rounded, color: Colors.white, size: 20),
              ),
              title: const Text(
                'Tour de Inicio & Mis Preferencias 🧭',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Configura porciones, dieta, súper favorito, alergias y electrodomésticos.',
                style: TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
              onTap: () {
                Navigator.pop(ctx);
                DialogoOnboardingBienvenida.verificarYMostrar(context, forzar: true);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.white.withValues(alpha: 0.05),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF2D3238),
                child: Icon(Icons.rocket_launch_rounded, color: Color(0xFFFFB300), size: 20),
              ),
              title: const Text(
                'Cómo Funciona la App & Manifiesto Rebelde 🔥',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Conoce los 5 pilares: IA, Batch Cooking, Modo Express y Cero Merma.',
                style: TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
              onTap: () {
                Navigator.pop(ctx);
                DialogoManifiestoBienvenida.verificarYMostrar(context, forzar: true);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: Colors.white.withValues(alpha: 0.05),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF2D3238),
                child: Icon(Icons.view_carousel_rounded, color: Colors.tealAccent, size: 20),
              ),
              title: const Text(
                'Reactivar Tarjeta Explicativa de Inicio 🎴',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Vuelve a mostrar la tarjeta de 5 pilares al inicio del catálogo.',
                style: TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _reactivarBannerInicioExplicativo();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('💡 Tarjeta de los 5 pilares reactivada en el catálogo'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _verificarYMostrarAgradecimiento() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'agradecimiento_registro_mostrado_${user.id}';
    final yaMostrado = prefs.getBool(key) ?? false;

    bool debeMostrar = !yaMostrado;
    if (kIsWeb) {
      final fragment = Uri.base.fragment;
      final query = Uri.base.queryParameters;
      if (fragment.contains('type=signup') || query['type'] == 'signup') {
        debeMostrar = true;
      }
    }

    if (debeMostrar && mounted) {
      await prefs.setBool(key, true);
      _mostrarDialogoAgradecimiento();
    }
  }

  void _mostrarDialogoAgradecimiento() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Text('🎉', style: TextStyle(fontSize: 42)),
            ),
            const SizedBox(height: 14),
            const Text(
              '¡Gracias por registrarte y autenticarte! 🍅🧅',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 21,
                color: Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Tu cuenta ya está activa y verificada!',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Nos emociona darte la bienvenida a Jitomate y Cebolla. Todo está listo para que disfrutes de:',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.3),
            ),
            const SizedBox(height: 14),
            _construirBeneficioItem(
              Icons.smart_toy_outlined,
              Colors.redAccent,
              'Asistente Culinario IA & Batch Cooking (2h)',
              'Chef con tu despensa, Copiloto Thermomix & Air Fryer, voz manos libres y menú semanal en 2 horas.',
            ),
            const SizedBox(height: 10),
            _construirBeneficioItem(
              Icons.fitness_center_outlined,
              Colors.teal,
              'Wellness, Macros & Ayuno Intermitente',
              'Cálculo metabólico TDEE, déficit calórico, keto, apto diabetes y fases biológicas en tiempo real.',
            ),
            const SizedBox(height: 10),
            _construirBeneficioItem(
              Icons.savings_outlined,
              Colors.green,
              'Finanzas, Club del Súper & Cero Merma',
              'Cotiza en Walmart, Soriana y La Comer, gana insignias antidesperdicio y ahorra +\$3,000 MXN/mes vs delivery.',
            ),
            const SizedBox(height: 10),
            _construirBeneficioItem(
              Icons.family_restroom_outlined,
              Colors.deepPurpleAccent,
              'Despensa Inteligente & Hogar Compartido',
              'Sincroniza despensa y compras en vivo con tu pareja y familia mediante el código CASA-XXXX.',
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                '¡Comenzar a cocinar! 🚀',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirBeneficioItem(IconData icono, Color color, String titulo, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              Text(
                desc,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> cargarRecetas() async {
    setState(() => cargando = true);
    try {
      final ids = await ServicioHistorialCocina.obtenerIdsCocinadas();
      final tits = await ServicioHistorialCocina.obtenerTitulosCocinadas();
      final respuesta = await Supabase.instance.client
          .from('recetas')
          .select()
          .order('id_receta', ascending: false);

      if (!mounted) return;
      final recetasHumanas = List<Map<String, dynamic>>.from(respuesta)
          .where((r) => !ServicioRecetas.esRecetaCanina(r))
          .toList();

      setState(() {
        todasLasRecetas = recetasHumanas;
        _idsCocinadas = ids;
        _titulosCocinados = tits;
        cargando = false;
      });
      _filtrarRecetas();
    } catch (e) {
      debugPrint('Error al cargar recetas: $e');
      if (mounted) setState(() => cargando = false);
    }
  }

  int _contarCoincidenciasIngredientes(Map<String, dynamic> receta) {
    if (_ingredientesSeleccionados.isEmpty) return 0;
    final texto = ConversorUnidades.sinAcentos(
      "${receta['titulo'] ?? ''} ${receta['descripcion'] ?? ''} ${receta['instrucciones'] ?? ''}",
    ).toLowerCase();

    int cuenta = 0;
    for (var ing in _ingredientesSeleccionados) {
      final ingLimpio = ConversorUnidades.sinAcentos(ing.trim().toLowerCase());
      if (ingLimpio.isNotEmpty && texto.contains(ingLimpio)) {
        cuenta++;
      }
    }
    return cuenta;
  }

  void _filtrarRecetas() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      final base = todasLasRecetas.where((receta) {
        final titulo = receta['titulo']?.toString().toLowerCase() ?? '';
        final descripcion =
            receta['descripcion']?.toString().toLowerCase() ?? '';
        final tipo = receta['tipo_comida']?.toString() ?? '';

        final coincideTexto = query.isEmpty ||
            titulo.contains(query) ||
            descripcion.contains(query);
        final coincideCategoria =
            categoriaSeleccionada == 'Todos' || tipo == categoriaSeleccionada;

        if (!coincideTexto || !coincideCategoria) return false;

        // Filtro por Cocina Express / Poco Tiempo
        if (!ServicioCocinaExpress.cumpleFiltroExpress(receta, _filtroExpress)) {
          return false;
        }

        // Filtro por Audiencia (Oficiales vs Mis Recetas vs Comunidad vs Todas)
        final bool coincideAudiencia;
        switch (_filtroAudiencia) {
          case FiltroAudienciaReceta.oficiales:
            coincideAudiencia = ServicioRecetas.esOficial(receta);
            break;
          case FiltroAudienciaReceta.misRecetas:
            coincideAudiencia = ServicioRecetas.esMiReceta(receta);
            break;
          case FiltroAudienciaReceta.comunidad:
            coincideAudiencia = ServicioRecetas.esComunidad(receta);
            break;
          case FiltroAudienciaReceta.todas:
            coincideAudiencia = true;
            break;
        }

        if (!coincideAudiencia) return false;

        if (_ingredientesSeleccionados.isNotEmpty) {
          final coincidencias = _contarCoincidenciasIngredientes(receta);
          return coincidencias > 0;
        }

        return true;
      }).toList();

      if (_ingredientesSeleccionados.isNotEmpty) {
        base.sort((a, b) {
          final cA = _contarCoincidenciasIngredientes(a);
          final cB = _contarCoincidenciasIngredientes(b);
          return cB.compareTo(cA); // Primero las que tienen más ingredientes que tienes
        });
      }

      recetasFiltradas = base;
    });
  }

  // 🧊 MODAL INTERACTIVO: "¿QUÉ COCINO CON LO QUE TENGO?"
  Future<void> _abrirModalQueCocinoConLoQueTengo() async {
    if (_ingredientesDespensa.isEmpty) {
      try {
        final data = await Supabase.instance.client
            .from('despensa_usuario')
            .select('nombre');
        final List items = data as List;
        final list = items
            .map((e) => (e['nombre'] ?? '').toString().trim())
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList();
        list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _ingredientesDespensa = list;
      } catch (e) {
        debugPrint('Error al leer despensa: $e');
      }
    }

    final sugerenciasComunes = [
      'Pollo',
      'Huevo',
      'Atún',
      'Jitomate',
      'Cebolla',
      'Aguacate',
      'Avena',
      'Arroz',
      'Frijoles',
      'Queso',
      'Papa',
      'Espinaca',
      'Limón',
      'Pasta',
      'Tortillas',
      'Carne de res',
    ];

    final customCtrl = TextEditingController();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(Icons.kitchen_rounded,
                            color: Color(0xFFD32F2F), size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '¿Qué cocino con lo que tengo? 🧊',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Marca los ingredientes que tienes a la mano y te mostraremos qué recetas puedes preparar de inmediato:',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 14),

                    // Botón para usar toda la despensa registrada
                    if (_ingredientesDespensa.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.teal),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.inventory_2,
                              color: Colors.teal, size: 18),
                          label: Text(
                            'Usar mi despensa (${_ingredientesDespensa.length} insumos)',
                            style: const TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            setModalState(() {
                              _ingredientesSeleccionados
                                  .addAll(_ingredientesDespensa);
                            });
                            setState(() => _filtrarRecetas());
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Input para agregar cualquier ingrediente extra
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customCtrl,
                            decoration: InputDecoration(
                              hintText: 'Escribir otro ingrediente...',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onSubmitted: (val) {
                              final txt = val.trim();
                              if (txt.isNotEmpty) {
                                setModalState(() {
                                  _ingredientesSeleccionados.add(txt);
                                });
                                customCtrl.clear();
                                setState(() => _filtrarRecetas());
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: () {
                            final txt = customCtrl.text.trim();
                            if (txt.isNotEmpty) {
                              setModalState(() {
                                _ingredientesSeleccionados.add(txt);
                              });
                              customCtrl.clear();
                              setState(() => _filtrarRecetas());
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Ingredientes seleccionados actualmente
                    if (_ingredientesSeleccionados.isNotEmpty) ...[
                      const Text(
                        'Ingredientes seleccionados:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _ingredientesSeleccionados.map((ing) {
                          return Chip(
                            backgroundColor: Colors.teal.shade50,
                            side: BorderSide(color: Colors.teal.shade300),
                            label: Text(
                              ing,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade900,
                              ),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            deleteIconColor: Colors.teal.shade800,
                            onDeleted: () {
                              setModalState(() {
                                _ingredientesSeleccionados.remove(ing);
                              });
                              setState(() => _filtrarRecetas());
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Sugerencias comunes rápidas
                    const Text(
                      'Básicos comunes para marcar:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: sugerenciasComunes.map((sug) {
                        final bool activa =
                            _ingredientesSeleccionados.contains(sug);
                        return FilterChip(
                          selected: activa,
                          selectedColor: Colors.teal.shade100,
                          backgroundColor: Colors.grey.shade100,
                          label: Text(sug),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                activa ? FontWeight.bold : FontWeight.normal,
                            color: activa ? Colors.teal.shade900 : Colors.black87,
                          ),
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                _ingredientesSeleccionados.add(sug);
                              } else {
                                _ingredientesSeleccionados.remove(sug);
                              }
                            });
                            setState(() => _filtrarRecetas());
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Botones de acción inferior
                    Row(
                      children: [
                        if (_ingredientesSeleccionados.isNotEmpty)
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () {
                                setModalState(() {
                                  _ingredientesSeleccionados.clear();
                                });
                                setState(() => _filtrarRecetas());
                              },
                              child: const Text('Limpiar'),
                            ),
                          ),
                        if (_ingredientesSeleccionados.isNotEmpty)
                          const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD32F2F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() => _filtrarRecetas());
                            },
                            child: Text(
                              _ingredientesSeleccionados.isEmpty
                                  ? 'Cerrar'
                                  : 'Ver recetas (${recetasFiltradas.length}) 🍳',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 📅 AGREGAR RECETA DIRECTO AL PLANEADOR SEMANAL
  Future<void> _programarEnPlaneador(
    int idReceta,
    String titulo,
    String tipoReceta,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ahora = DateTime.now();

    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: ahora,
      firstDate: ahora.subtract(const Duration(days: 1)),
      lastDate: ahora.add(const Duration(days: 30)),
      helpText: 'PROGRAMAR PARA ESTE DÍA',
      confirmText: 'AGREGAR',
      cancelText: 'CANCELAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD32F2F),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaSeleccionada == null) return;

    final fechaTexto = fechaSeleccionada.toIso8601String().split('T')[0];

    // Asegurar un tipo válido para evitar restricciones NOT NULL
    final String tipoValido =
        ['Desayuno', 'Comida', 'Cena', 'Snack'].contains(tipoReceta)
        ? tipoReceta
        : 'Comida';

    try {
      await Supabase.instance.client.from('planeador').insert({
        'id_receta': idReceta,
        'fecha': fechaTexto,
        'tipo_comida': tipoValido,
      });

      final bool yaCocino =
          (idReceta > 0 && _idsCocinadas.contains(idReceta)) ||
          _titulosCocinados.contains(titulo.toLowerCase().trim());

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            yaCocino
                ? '¡Aviso: "$titulo" (ya preparada anteriormente) agendada para el $fechaTexto ($tipoValido)! 👨‍🍳📅'
                : '¡"$titulo" agendada para el $fechaTexto ($tipoValido)! 📅✨',
          ),
          backgroundColor: yaCocino ? Colors.green.shade800 : Colors.teal,
        ),
      );
    } catch (e) {
      debugPrint('Error al agendar en planeador: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo programar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmarSaneamientoConIA() {
    if (!ServicioAdmin.esAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acción reservada al administrador')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high, color: Color(0xFFD32F2F)),
            SizedBox(width: 10),
            Expanded(child: Text('Pulir con IA ✨')),
          ],
        ),
        content: const Text(
          'Gemini revisará una por una las descripciones para corregir ortografía y formato.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _ejecutarSaneamiento();
            },
            child: const Text('Comenzar'),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarSaneamiento() async {
    final supabase = Supabase.instance.client;
    final messenger = ScaffoldMessenger.of(context);

    final listaRes = await supabase
        .from('recetas')
        .select('id_receta, titulo, descripcion')
        .order('id_receta', ascending: true);

    final List<Map<String, dynamic>> recetasParaLimpiar =
        List<Map<String, dynamic>>.from(listaRes);

    if (recetasParaLimpiar.isEmpty || !mounted) return;

    int actual = 0;
    String nombreActual = '';
    bool cancelado = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progresoCtx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            void iniciarProceso() async {
              for (var i = 0; i < recetasParaLimpiar.length; i++) {
                if (cancelado) break;

                final r = recetasParaLimpiar[i];
                final int id = r['id_receta'];
                final String titulo = r['titulo'] ?? '';
                final String desc = r['descripcion'] ?? '';

                setStateModal(() {
                  actual = i + 1;
                  nombreActual = titulo;
                });

                if (desc.trim().isNotEmpty) {
                  final descPulida =
                      await ServicioIA.pulirOrtografiaYFormatoReceta(desc);

                  if (descPulida != null && descPulida.isNotEmpty) {
                    await supabase
                        .from('recetas')
                        .update({'descripcion': descPulida})
                        .eq('id_receta', id);

                    try {
                      await ConversorUnidades.sincronizarIngredientesDeTexto(
                        supabase,
                        id,
                        descPulida,
                      );
                    } catch (e) {
                      debugPrint('Error al auto-sincronizar ingredientes: $e');
                    }
                  }
                }

                await Future.delayed(const Duration(milliseconds: 4100));
              }

              if (context.mounted) Navigator.pop(progresoCtx);
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (actual == 0) iniciarProceso();
            });

            final double progreso = recetasParaLimpiar.isEmpty
                ? 0.0
                : (actual / recetasParaLimpiar.length);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.auto_fix_high, color: Color(0xFFD32F2F)),
                  SizedBox(width: 10),
                  Expanded(child: Text('Perfeccionando Recetas')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progreso,
                    color: const Color(0xFFD32F2F),
                    backgroundColor: const Color(0xFFD32F2F).withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Receta $actual de ${recetasParaLimpiar.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    nombreActual.isNotEmpty
                        ? 'Procesando: $nombreActual'
                        : 'Preparando...',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelado = true;
                    Navigator.pop(progresoCtx);
                  },
                  child: const Text(
                    'Detener',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    await cargarRecetas();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('¡Recetas pulidas y sincronizadas con éxito! ✨📦'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmarMigracionRelacional() {
    if (!ServicioAdmin.esAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acción reservada al administrador')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.teal),
            SizedBox(width: 10),
            Expanded(child: Text('Sincronizar Ingredientes 📦')),
          ],
        ),
        content: const Text(
          'Estructurará y asegurará que todos los ingredientes de todas tus recetas estén registrados en "ingredientes_genericos" y vinculados en "receta_detalle" con sus cantidades y precios comerciales.\n\n'
          '⚡ Proceso automático y ultrarrápido con el conversor inteligente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _ejecutarMigracionRelacional();
            },
            child: const Text('Iniciar Sincronización'),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarMigracionRelacional() async {
    final supabase = Supabase.instance.client;
    final messenger = ScaffoldMessenger.of(context);

    final listaRes = await supabase
        .from('recetas')
        .select('id_receta, titulo, descripcion')
        .order('id_receta', ascending: true);

    final List<Map<String, dynamic>> recetas = List<Map<String, dynamic>>.from(
      listaRes,
    );

    if (recetas.isEmpty || !mounted) return;

    int actual = 0;
    String nombreActual = '';
    int totalIngredientesInsertados = 0;
    int totalRecetasExitosas = 0;
    bool cancelado = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progresoCtx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            void iniciarProceso() async {
              for (var i = 0; i < recetas.length; i++) {
                if (cancelado) break;

                final r = recetas[i];
                final int id = r['id_receta'];
                final String titulo = r['titulo'] ?? '';
                final String desc = r['descripcion'] ?? '';

                setStateModal(() {
                  actual = i + 1;
                  nombreActual = titulo;
                });

                if (desc.trim().isNotEmpty) {
                  try {
                    final insertados =
                        await ConversorUnidades.sincronizarIngredientesDeTexto(
                      supabase,
                      id,
                      desc,
                    );
                    totalIngredientesInsertados += insertados;
                    totalRecetasExitosas++;
                  } catch (e) {
                    debugPrint('Error sincronizando receta $id: $e');
                  }
                }

                await Future.delayed(const Duration(milliseconds: 30));
              }

              if (context.mounted) Navigator.pop(progresoCtx);
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (actual == 0) iniciarProceso();
            });

            final double progreso = recetas.isEmpty
                ? 0.0
                : (actual / recetas.length);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: Colors.teal),
                  SizedBox(width: 10),
                  Expanded(child: Text('Sincronizando Ingredientes')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progreso,
                    color: Colors.teal,
                    backgroundColor: Colors.teal.shade100,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Receta $actual de ${recetas.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    nombreActual.isNotEmpty
                        ? 'Procesando: $nombreActual'
                        : 'Preparando...',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelado = true;
                    Navigator.pop(progresoCtx);
                  },
                  child: const Text(
                    'Detener',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '¡Sincronización completa! $totalRecetasExitosas recetas verificadas con $totalIngredientesInsertados nuevos ingredientes vinculados. 📦✨',
        ),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _mostrarOpcionesAgregar() {
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
                  'Agregar Receta 🍳',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                    child: const Icon(Icons.camera_alt, color: Color(0xFFD32F2F)),
                  ),
                  title: const Text(
                    'Tomar foto con la cámara',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Escanea una página de libro o libreta'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _procesarFotoReceta(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.photo_library,
                      color: Colors.purple,
                    ),
                  ),
                  title: const Text(
                    'Elegir foto de la galería',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Selecciona una captura o foto guardada',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _procesarFotoReceta(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withValues(alpha: 0.15),
                    child: const Icon(Icons.edit_note, color: Colors.teal),
                  ),
                  title: const Text(
                    'Escribir manualmente',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Ingresa título, tipo y pasos tú mismo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _mostrarDialogoAgregarReceta();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _procesarFotoReceta(ImageSource origen) async {
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
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(25.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFFD32F2F)),
                SizedBox(height: 15),
                Text(
                  'Digitalizando receta con IA... 🔍✨',
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
      final resultado = await ServicioIA.escanearRecetaDeFoto(bytes);

      if (!mounted) return;
      Navigator.pop(context);

      if (resultado != null) {
        _mostrarDialogoAgregarReceta(
          tituloInicial: resultado['titulo']?.toString() ?? '',
          tipoInicial: resultado['tipo_comida']?.toString() ?? 'Comida',
          descInicial: resultado['descripcion']?.toString() ?? '',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos leer la receta de la imagen.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      debugPrint('Error procesando imagen: $e');
    }
  }

  void _mostrarDialogoAgregarReceta({
    String tituloInicial = '',
    String tipoInicial = 'Comida',
    String descInicial = '',
  }) {
    final titleController = TextEditingController(text: tituloInicial);
    String tipoSeleccionado =
        ['Desayuno', 'Comida', 'Cena', 'Snack'].contains(tipoInicial)
        ? tipoInicial
        : 'Comida';
    final descController = TextEditingController(text: descInicial);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            tituloInicial.isEmpty
                ? 'Nueva Receta 🍳'
                : 'Revisar Receta Escaneada 📖',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título de la receta',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipoSeleccionado,
                  items: ['Desayuno', 'Comida', 'Cena', 'Snack']
                      .map(
                        (tipo) =>
                            DropdownMenuItem(value: tipo, child: Text(tipo)),
                      )
                      .toList(),
                  onChanged: (val) => tipoSeleccionado = val ?? 'Comida',
                  decoration: const InputDecoration(
                    labelText: 'Tipo de comida',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Instrucciones / Descripción',
                    hintText: 'PORCIONES: 2\n\n📝 INGREDIENTES:\n- ...\n\n🍳 INSTRUCCIONES:\n1. ...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;

                Navigator.pop(dialogContext);

                final descripcionLimpia = descController.text
                    .replaceFirst(
                      RegExp(
                        r'^\s*TÍTULO:[^\r\n]*[\r\n]*',
                        caseSensitive: false,
                      ),
                      '',
                    )
                    .trim();

                try {
                  await Supabase.instance.client.from('recetas').insert({
                    'titulo': titleController.text.trim(),
                    'tipo_comida': tipoSeleccionado,
                    'descripcion': descripcionLimpia,
                  });

                  if (!mounted) return;
                  cargarRecetas();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Receta agregada con éxito! ✨'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  debugPrint('Error al guardar receta: $e');
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Widget _construirBannerSaludo() {
    final String saludo = ServicioPerfilUsuario.obtenerSaludoHorario();
    final String subtitulo = ServicioPerfilUsuario.obtenerSubtituloHorario();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF16171D),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF262833),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  saludo,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              ServicioPerfilUsuario.mostrarDialogoEditarNombre(
                context,
                alGuardar: () => setState(() {}),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD32F2F), width: 0.8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 11, color: Color(0xFFEF5350)),
                  SizedBox(width: 4),
                  Text(
                    'Apodo',
                    style: TextStyle(
                      color: Color(0xFFEF5350),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirChipAudiencia({
    required String etiqueta,
    required FiltroAudienciaReceta filtro,
    required Color colorActivo,
    required Color fondoActivo,
  }) {
    final bool seleccionado = _filtroAudiencia == filtro;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(etiqueta),
        selected: seleccionado,
        selectedColor: fondoActivo,
        backgroundColor: Colors.grey[100],
        checkmarkColor: colorActivo,
        side: BorderSide(
          color: seleccionado ? colorActivo : Colors.grey.shade300,
          width: seleccionado ? 1.4 : 0.8,
        ),
        labelStyle: TextStyle(
          color: seleccionado ? colorActivo : Colors.black87,
          fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
          fontSize: 12,
        ),
        onSelected: (bool valor) {
          setState(() {
            _filtroAudiencia = valor ? filtro : FiltroAudienciaReceta.todas;
            _filtrarRecetas();
          });
        },
      ),
    );
  }

  Future<void> _confirmarEliminarReceta(int idReceta, String titulo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar Receta'),
          ],
        ),
        content: Text('¿Estás seguro de eliminar "$titulo"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final ok = await ServicioRecetas.eliminarReceta(idReceta);
      if (ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Receta "$titulo" eliminada correctamente.'),
              backgroundColor: Colors.black87,
            ),
          );
        }
        cargarRecetas();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String rutaActualMenu = widget.rutaMenu ??
        (widget.filtroInicial == FiltroAudienciaReceta.misRecetas
            ? 'recetas_mias'
            : (widget.filtroInicial == FiltroAudienciaReceta.oficiales
                ? 'recetas_oficiales'
                : 'recetas'));

    final String tituloAppBar = widget.filtroInicial == FiltroAudienciaReceta.misRecetas
        ? 'Mis Creaciones 👨‍🍳'
        : (widget.filtroInicial == FiltroAudienciaReceta.oficiales
            ? 'Catálogo Oficial 🌟'
            : 'Mis Recetas 📖');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: MenuLateral(rutaActual: rutaActualMenu),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú principal',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          tituloAppBar,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E2022),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Búsqueda Global Spotlight 🔍',
            onPressed: () {
              DialogoBusquedaSpotlight.mostrar(
                context,
                recetas: todasLasRecetas,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Centro de Recordatorios 🔔',
            onPressed: () {
              ServicioRecordatorios.mostrarModalCentroRecordatorios(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Planeador Semanal 📅',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PantallaPlaneador(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.pets),
            tooltip: 'Recetario Canino 🐾',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PantallaRecetasCaninas(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tips_and_updates_outlined, color: Colors.amberAccent),
            tooltip: '💡 Tour, Preferencias y Cómo Funciona',
            onPressed: _mostrarCentroDeAyudaYBienvenida,
          ),
          if (ServicioAdmin.esAdmin())
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Herramientas de Administrador',
              onSelected: (val) {
              if (val == 'sanitizar') {
                _confirmarSaneamientoConIA();
              } else if (val == 'migrar_relacional') {
                _confirmarMigracionRelacional();
              } else if (val == 'carga_mensual') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PantallaCargaMasivaRecetas(),
                  ),
                ).then((guardado) {
                  if (guardado == true) cargarRecetas();
                });
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'carga_mensual',
                child: Row(
                  children: [
                    Icon(Icons.rocket_launch, color: Color(0xFFD32F2F)),
                    SizedBox(width: 10),
                    Text('Carga Masiva Mensual (20 IA) 🚀'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sanitizar',
                child: Row(
                  children: [
                    Icon(Icons.auto_fix_high, color: Color(0xFFD32F2F)),
                    SizedBox(width: 10),
                    Text('Pulir ortografía y formato ✨'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'migrar_relacional',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Colors.teal),
                    SizedBox(width: 10),
                    Text('Sincronizar Ingredientes en BD 📦'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarOpcionesAgregar,
        backgroundColor: const Color(0xFFD32F2F),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          _construirBannerSaludo(),
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar receta por nombre...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF1E2022)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filtrarRecetas();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _abrirModalQueCocinoConLoQueTengo,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _ingredientesSeleccionados.isNotEmpty
                          ? Colors.teal.shade50
                          : const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _ingredientesSeleccionados.isNotEmpty
                            ? Colors.teal.shade300
                            : const Color(0xFF1E2022).withValues(alpha: 0.15),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _ingredientesSeleccionados.isNotEmpty
                              ? Icons.kitchen_rounded
                              : Icons.restaurant_menu_rounded,
                          color: _ingredientesSeleccionados.isNotEmpty
                              ? Colors.teal.shade700
                              : const Color(0xFF1E2022),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _ingredientesSeleccionados.isNotEmpty
                                ? 'Filtrando con ${_ingredientesSeleccionados.length} ingredientes (${_ingredientesSeleccionados.take(3).join(', ')}${_ingredientesSeleccionados.length > 3 ? "..." : ""})'
                                : '¿Qué cocino con lo que tengo? 🧊',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _ingredientesSeleccionados.isNotEmpty
                                  ? Colors.teal.shade800
                                  : const Color(0xFF1E2022),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_ingredientesSeleccionados.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _ingredientesSeleccionados.clear();
                                _filtrarRecetas();
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.teal.shade800,
                              ),
                            ),
                          )
                        else
                          const Icon(
                            Icons.tune,
                            size: 16,
                            color: Color(0xFF1E2022),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // 🌟 Filtro de Audiencia y Origen (Oficiales, Mis Recetas, Comunidad, Todas)
                Builder(
                  builder: (context) {
                    final int countOficiales = todasLasRecetas.where(ServicioRecetas.esOficial).length;
                    final int countMisRecetas = todasLasRecetas.where(ServicioRecetas.esMiReceta).length;
                    final int countComunidad = todasLasRecetas.where(ServicioRecetas.esComunidad).length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _construirChipAudiencia(
                                etiqueta: '🌟 Oficiales ($countOficiales)',
                                filtro: FiltroAudienciaReceta.oficiales,
                                colorActivo: const Color(0xFFD32F2F),
                                fondoActivo: const Color(0xFFFBECEF),
                              ),
                              _construirChipAudiencia(
                                etiqueta: '👨‍🍳 Mis Creaciones ($countMisRecetas)',
                                filtro: FiltroAudienciaReceta.misRecetas,
                                colorActivo: const Color(0xFF1E2022),
                                fondoActivo: Colors.grey.shade200,
                              ),
                              _construirChipAudiencia(
                                etiqueta: '🌎 Comunidad ($countComunidad)',
                                filtro: FiltroAudienciaReceta.comunidad,
                                colorActivo: Colors.indigo.shade800,
                                fondoActivo: Colors.indigo.shade50,
                              ),
                              _construirChipAudiencia(
                                etiqueta: 'Todas (${todasLasRecetas.length})',
                                filtro: FiltroAudienciaReceta.todas,
                                colorActivo: Colors.grey.shade900,
                                fondoActivo: Colors.grey.shade200,
                              ),
                            ],
                          ),
                        ),
                        if (_filtroAudiencia == FiltroAudienciaReceta.misRecetas) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                _filtrarRecetas();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.shade300, width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Viendo solo tus creaciones ($countMisRecetas). Toca aquí para ver el Catálogo Oficial completo ($countOficiales recetas).',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.brown.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: categorias.map((cat) {
                      final bool seleccionado = categoriaSeleccionada == cat;
                      final int countCat = cat == 'Todos'
                          ? todasLasRecetas.length
                          : todasLasRecetas.where((r) => (r['tipo_comida'] ?? '') == cat).length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat == 'Todos' ? 'Todos ($countCat)' : '$cat ($countCat)'),
                          selected: seleccionado,
                          selectedColor: const Color(0xFF1E2022),
                          backgroundColor: Colors.grey[200],
                          labelStyle: TextStyle(
                            color: seleccionado
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: seleccionado
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (bool valor) {
                            if (valor) {
                              setState(() => categoriaSeleccionada = cat);
                              _filtrarRecetas();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // ⏱️ FILTROS DE COCINA EXPRESS Y CERO TRASTES
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: FiltroExpress.values.map((f) {
                      final bool seleccionado = _filtroExpress == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Text(f.emoji, style: const TextStyle(fontSize: 13)),
                          label: Text(f.etiqueta),
                          selected: seleccionado,
                          selectedColor: f == FiltroExpress.todos
                              ? const Color(0xFF1E2022)
                              : f.color,
                          backgroundColor: f.fondoColor,
                          labelStyle: TextStyle(
                            color: seleccionado
                                ? Colors.white
                                : (f == FiltroExpress.todos ? Colors.black87 : f.color),
                            fontWeight: seleccionado
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: seleccionado
                                  ? Colors.transparent
                                  : f.color.withValues(alpha: 0.3),
                            ),
                          ),
                          onSelected: (bool valor) {
                            if (valor) {
                              setState(() => _filtroExpress = f);
                              _filtrarRecetas();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (_filtroExpress != FiltroExpress.todos) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _filtroExpress.fondoColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _filtroExpress.color.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(_filtroExpress.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _filtroExpress.descripcionCorta,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _filtroExpress.color,
                            ),
                          ),
                        ),
                        if (_filtroExpress == FiltroExpress.express20)
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PantallaChef(
                                    modoExpressInicial: true,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE65100),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt, size: 12, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'Chef 15 min ➔',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cargando
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
                  )
                : RefreshIndicator(
                    color: const Color(0xFFD32F2F),
                    onRefresh: cargarRecetas,
                    child: recetasFiltradas.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(15),
                            children: [
                              if (_mostrarBannerInicioExplicativo &&
                                  _searchController.text.trim().isEmpty &&
                                  _ingredientesSeleccionados.isEmpty)
                                _construirTarjetaExplicativaInicio(),
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.45,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 70,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'No se encontraron recetas',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Builder(
                            builder: (context) {
                              final bool mostrarBanner =
                                  _mostrarBannerInicioExplicativo &&
                                  _searchController.text.trim().isEmpty &&
                                  _ingredientesSeleccionados.isEmpty;
                              final int totalItems = recetasFiltradas.length +
                                  (mostrarBanner ? 1 : 0);

                              return ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(15),
                                itemCount: totalItems,
                                itemBuilder: (context, index) {
                                  if (mostrarBanner && index == 0) {
                                    return _construirTarjetaExplicativaInicio();
                                  }
                                  final int indiceReceta =
                                      mostrarBanner ? index - 1 : index;
                                  final receta = recetasFiltradas[indiceReceta];
                                  final titulo = receta['titulo'] ?? 'Sin título';
                                  final String? imagen =
                                      ServicioRecetas.obtenerImagenOptimizada(
                                        idReceta: receta['id_receta'],
                                        titulo: titulo.toString(),
                                        rawUrl: receta['imagen_url']?.toString(),
                                      );
                      final tipo = receta['tipo_comida'] ?? 'General';
                      final descripcion =
                          receta['descripcion'] ??
                          receta['instrucciones'] ??
                          '';
                      final id = receta['id_receta'];
                      final int idInt = id is int
                          ? id
                          : (int.tryParse(id?.toString() ?? '0') ?? 0);
                      final bool fueCocinada = (idInt > 0 &&
                              _idsCocinadas.contains(idInt)) ||
                          _titulosCocinados
                              .contains(titulo.toString().toLowerCase().trim());

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: fueCocinada
                                ? Colors.green.shade300
                                : Colors.grey.shade200,
                            width: fueCocinada ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child:
                                imagen != null && imagen.toString().isNotEmpty
                                ? Image.network(
                                    imagen,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 60,
                                        height: 60,
                                        color: const Color(0xFFD32F2F).withValues(alpha: 0.08),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFFD32F2F),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 60,
                                        height: 60,
                                        color: const Color(0xFFD32F2F).withValues(
                                          alpha: 0.08,
                                        ),
                                        child: const Icon(
                                          Icons.restaurant,
                                          color: Color(0xFFD32F2F),
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 60,
                                    height: 60,
                                    color: const Color(0xFFD32F2F).withValues(alpha: 0.08),
                                    child: const Icon(
                                      Icons.restaurant,
                                      color: Color(0xFFD32F2F),
                                    ),
                                  ),
                          ),
                          title: Text(
                            titulo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD32F2F).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tipo,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFD32F2F),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // Distintivo de Origen / Oficial / Personal / Comunidad
                                  if (ServicioRecetas.esOficial(receta))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.red.shade200, width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.star, size: 10, color: Colors.red.shade800),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Oficial',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (ServicioRecetas.esMiReceta(receta))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.teal.shade300, width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.person, size: 10, color: Colors.teal.shade800),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Mi Receta',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.teal.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (ServicioRecetas.esComunidad(receta))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.indigo.shade200, width: 0.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.groups, size: 10, color: Colors.indigo.shade800),
                                          const SizedBox(width: 3),
                                          Text(
                                            'Comunidad',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_ingredientesSeleccionados.isNotEmpty)
                                    Builder(
                                      builder: (context) {
                                        final count =
                                            _contarCoincidenciasIngredientes(
                                          receta,
                                        );
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade50,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.teal.shade300,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.kitchen_rounded,
                                                size: 11,
                                                color: Colors.teal.shade800,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Tienes $count ingrediente${count > 1 ? "s" : ""}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.teal.shade800,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  if (fueCocinada)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.shade400,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.soup_kitchen,
                                            size: 11,
                                            color: Colors.green.shade800,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Preparada',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green.shade800,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (receta['calorias'] != null &&
                                      (receta['calorias'] as num) > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${receta['calorias']} kcal',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.teal[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Builder(
                                    builder: (context) {
                                      final desglose = ServicioCocinaExpress.calcularDesglose(receta);
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: desglose.totalMinutos <= 20
                                              ? const Color(0xFFFFF3E0)
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: desglose.totalMinutos <= 20
                                                ? const Color(0xFFFFB74D)
                                                : Colors.grey.shade300,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              desglose.totalMinutos <= 20
                                                  ? Icons.bolt_rounded
                                                  : Icons.schedule_rounded,
                                              size: 11,
                                              color: desglose.totalMinutos <= 20
                                                  ? const Color(0xFFE65100)
                                                  : Colors.grey.shade700,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              desglose.insigniaCorta,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: desglose.totalMinutos <= 20
                                                    ? const Color(0xFFE65100)
                                                    : Colors.grey.shade800,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  if (ServicioCocinaExpress.esCeroTrastes(receta))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2F1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        '🍳 1 Sartén',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF00695C),
                                        ),
                                      ),
                                    ),
                                  if (ServicioCocinaExpress.esFacil5(receta))
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3E5F5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '✨ ${ServicioCocinaExpress.contarIngredientes(receta)} ing',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF6A1B9A),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.event_available,
                                  color: Colors.teal,
                                ),
                                tooltip: 'Programar en Planeador',
                                onPressed: () =>
                                    _programarEnPlaneador(id, titulo, tipo),
                              ),
                              if (ServicioRecetas.puedeModificar(receta))
                                PopupMenuButton<String>(
                                  icon: const Icon(
                                    Icons.more_vert,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  tooltip: 'Opciones de receta',
                                  onSelected: (accion) async {
                                    if (accion == 'eliminar') {
                                      _confirmarEliminarReceta(idInt, titulo);
                                    } else if (accion == 'toggle_publica') {
                                      final messenger = ScaffoldMessenger.of(context);
                                      final bool esPub = receta['es_publica'] == true;
                                      final exito = await ServicioRecetas.cambiarVisibilidadPublica(
                                        idReceta: idInt,
                                        nuevaVisibilidad: !esPub,
                                      );
                                      if (exito && mounted) {
                                        setState(() {
                                          receta['es_publica'] = !esPub;
                                        });
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(!esPub
                                                ? '¡Receta compartida con la comunidad! 🌎'
                                                : 'Receta guardada como privada 🔒'),
                                            backgroundColor: Colors.teal,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    if (ServicioRecetas.esMiReceta(receta))
                                      PopupMenuItem(
                                        value: 'toggle_publica',
                                        child: Row(
                                          children: [
                                            Icon(
                                              receta['es_publica'] == true
                                                  ? Icons.lock_outline
                                                  : Icons.public,
                                              size: 18,
                                              color: Colors.indigo,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(receta['es_publica'] == true
                                                ? 'Hacer Privada 🔒'
                                                : 'Compartir en Comunidad 🌎'),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuItem(
                                      value: 'eliminar',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Eliminar Receta', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                          onTap: () async {
                            final eliminada = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PantallaDetalleReceta(
                                  idReceta: id,
                                  titulo: titulo,
                                  descripcion: descripcion,
                                  imagenUrl: imagen,
                                ),
                              ),
                            );
                            if (eliminada == true) {
                              cargarRecetas();
                              return;
                            }
                            final ids =
                                await ServicioHistorialCocina.obtenerIdsCocinadas();
                            final tits =
                                await ServicioHistorialCocina.obtenerTitulosCocinadas();
                            if (mounted) {
                              setState(() {
                                _idsCocinadas = ids;
                                _titulosCocinados = tits;
                              });
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 🎴 TARJETA EXPLICATIVA DE INICIO: LOS 4 PILARES DE LA APP
  // ==========================================================
  Widget _construirTarjetaExplicativaInicio() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF23252E), Color(0xFF16171D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFD32F2F).withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD32F2F).withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera con título e ícono de cierre
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFD32F2F).withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: const Text('🍅🧅', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¿CÓMO FUNCIONA LA APP?',
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFB300),
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'Los 5 Pilares de Jitomate y Cebolla',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                  tooltip: 'Ocultar tarjeta',
                  onPressed: _ocultarBannerInicioExplicativo,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Mucho más que un recetario: tu asistente culinario con IA, wellness y finanzas del hogar.',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: Colors.white70,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Carrusel horizontal de las 5 tarjetas explicativas
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _construirMiniTarjetaPilar(
                  icono: Icons.smart_toy_outlined,
                  colorIcono: Colors.amber,
                  numero: '01',
                  titulo: 'Asistencia IA & Batch',
                  descripcion:
                      'Chef con tu refri, Copiloto Thermomix/Air Fryer y cocina semanal en 2h.',
                  etiqueta: 'Chef & Batch Cooking',
                ),
                _construirMiniTarjetaPilar(
                  icono: Icons.bolt_rounded,
                  colorIcono: Colors.orangeAccent,
                  numero: '02',
                  titulo: 'Cocina Express & Zonas',
                  descripcion:
                      'Recetas en ≤ 15 min, Cero Trastes (1 sartén) y despensa por zonas (refri, congelador, alacena y cava).',
                  etiqueta: 'Express & Cero Trastes',
                ),
                _construirMiniTarjetaPilar(
                  icono: Icons.fitness_center_rounded,
                  colorIcono: Colors.greenAccent,
                  numero: '03',
                  titulo: 'Wellness & Macros',
                  descripcion:
                      'Metas TDEE, déficit calórico, keto y reloj de ayuno en tiempo real.',
                  etiqueta: 'Salud & Nutrición',
                ),
                _construirMiniTarjetaPilar(
                  icono: Icons.compare_arrows_rounded,
                  colorIcono: Colors.lightBlueAccent,
                  numero: '04',
                  titulo: 'Cotizador de Súper',
                  descripcion:
                      'Walmart vs Soriana vs La Comer. Ahorra +\$3,000 MXN/mes vs delivery.',
                  etiqueta: 'Club del Súper',
                ),
                _construirMiniTarjetaPilar(
                  icono: Icons.eco_rounded,
                  colorIcono: Colors.tealAccent,
                  numero: '05',
                  titulo: 'Cero Merma & Hogar',
                  descripcion:
                      'Racha antidesperdicio con insignias y despensa sincronizada (CASA-XXXX).',
                  etiqueta: 'Desperdicio Cero',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Botones inferiores de acción
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      DialogoOnboardingBienvenida.verificarYMostrar(
                        context,
                        forzar: true,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 3,
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(
                      'Mis Preferencias ⚙️',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      DialogoManifiestoBienvenida.verificarYMostrar(
                        context,
                        forzar: true,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.rocket_launch_rounded, size: 15, color: Color(0xFFFFB300)),
                    label: Text(
                      'Ver Manifiesto 🔥',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Ocultar tarjeta',
                  icon: const Icon(Icons.visibility_off_outlined, color: Colors.white54, size: 18),
                  onPressed: _ocultarBannerInicioExplicativo,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirMiniTarjetaPilar({
    required IconData icono,
    required Color colorIcono,
    required String numero,
    required String titulo,
    required String descripcion,
    required String etiqueta,
  }) {
    return Container(
      width: 205,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorIcono.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: colorIcono, size: 16),
              ),
              const Spacer(),
              Text(
                numero,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              descripcion,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                color: Colors.white70,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
