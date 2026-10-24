import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'conversor_unidades.dart';
import 'pantalla_chef.dart';
import 'pantalla_detalle_receta.dart';
import 'pantalla_recetas_caninas.dart';
import 'servicio_ia.dart';
import 'servicio_historial_cocina.dart';
import 'menu_lateral.dart';
import 'servicio_admin.dart';
import 'servicio_recetas.dart';
import 'servicio_cocina_express.dart';
import 'servicio_despensa.dart';
import 'perfiles_nutricionales.dart';
import 'pantalla_carga_masiva_recetas.dart';
import 'dialogo_manifiesto_bienvenida.dart';
import 'dialogo_busqueda_spotlight.dart';
import 'dialogo_onboarding_bienvenida.dart';
import 'servicio_recordatorios.dart';
import 'servicio_perfil_usuario.dart';
import 'widget_shimmer_esqueleto.dart';

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
  List<Map<String, dynamic>> recetasCaninas = [];
  List<Map<String, dynamic>> recetasFiltradas = [];
  Set<int> _idsCocinadas = {};
  Set<String> _titulosCocinados = {};
  bool cargando = true;

  FiltroAudienciaReceta _filtroAudiencia = FiltroAudienciaReceta.oficiales;
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

  // 🗂️ Secciones colapsadas en la vista agrupada por tiempos de comida (estilo Planeador)
  final Set<String> _seccionesColapsadas = {};

  // 🧊 Búsqueda por ingredientes disponibles ("¿Qué cocino con lo que tengo?")
  final Set<String> _ingredientesSeleccionados = {};
  List<String> _ingredientesDespensa = [];
  final Map<int, ResultadoMatchDespensa> _cacheMatchDespensa = {};

  Future<void> _cargarDespensaSilenciosa() async {
    try {
      final data = await Supabase.instance.client
          .from('despensa_usuario')
          .select('nombre');
      final List items = data as List;
      final list = items
          .map((e) => (e['nombre'] ?? '').toString().trim())
          .where((n) => n.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _ingredientesDespensa = list;
          _cacheMatchDespensa.clear();
        });
      }
    } catch (_) {}
  }

  ResultadoMatchDespensa _evaluarMatchReceta(Map<String, dynamic> receta) {
    final int id = receta['id_receta'] as int? ?? 0;
    if (_cacheMatchDespensa.containsKey(id)) {
      return _cacheMatchDespensa[id]!;
    }
    final res = ServicioDespensa.evaluarMatchReceta(
      descripcionReceta: "${receta['descripcion'] ?? ''}\n${receta['instrucciones'] ?? ''}",
      nombresEnDespensa: _ingredientesDespensa,
    );
    if (id > 0) {
      _cacheMatchDespensa[id] = res;
    }
    return res;
  }

  List<SelloNutricional> _obtenerSellosReceta(Map<String, dynamic> receta) {
    final desc = "${receta['descripcion'] ?? ''} ${receta['macros'] ?? ''}";
    final matchCal = RegExp(r'calor[ií]as\s*:\s*(\d+)', caseSensitive: false).firstMatch(desc);
    final matchProt = RegExp(r'prote[ií]nas?\s*:\s*(\d+)', caseSensitive: false).firstMatch(desc);
    final matchCarb = RegExp(r'carbohidratos?\s*:\s*(\d+)', caseSensitive: false).firstMatch(desc);
    final matchGras = RegExp(r'grasas?\s*:\s*(\d+)', caseSensitive: false).firstMatch(desc);

    final int cals = matchCal != null
        ? int.tryParse(matchCal.group(1) ?? '0') ?? 0
        : (receta['calorias'] is num ? (receta['calorias'] as num).toInt() : 0);
    final int prots = matchProt != null ? int.tryParse(matchProt.group(1) ?? '0') ?? 0 : 0;
    final int carbs = matchCarb != null ? int.tryParse(matchCarb.group(1) ?? '0') ?? 0 : 0;
    final int gras = matchGras != null ? int.tryParse(matchGras.group(1) ?? '0') ?? 0 : 0;

    return PerfilesNutricionales.calcularSellosNutricionales(
      calorias: cals,
      proteinas: prots,
      carbs: carbs,
      grasas: gras,
      titulo: receta['titulo']?.toString(),
    );
  }

  // 💡 Tarjeta explicativa de inicio (4 Pilares)
  bool _mostrarBannerInicioExplicativo = true;

  @override
  void initState() {
    super.initState();
    if (widget.filtroInicial != null) {
      _filtroAudiencia = widget.filtroInicial!;
    }
    _cargarDespensaSilenciosa();
    cargarRecetas();
    _cargarPreferenciaBannerInicio();
    _searchController.addListener(_filtrarRecetas);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _verificarYMostrarAgradecimiento();
      if (mounted) {
        DialogoOnboardingBienvenida.verificarYMostrar(context, alFinalizar: () {
          DialogoManifiestoBienvenida.verificarYMostrar(context);
        });
      }
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
      await _mostrarDialogoAgradecimiento();
    }
  }

  Future<void> _mostrarDialogoAgradecimiento() async {
    await showDialog(
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
      final todas = List<Map<String, dynamic>>.from(respuesta);
      final caninas = todas.where(ServicioRecetas.esRecetaCanina).toList();
      final recetasHumanas = todas.where((r) => !ServicioRecetas.esRecetaCanina(r)).toList();

      // Garantizar visibilidad comunitaria para receta 101 seleccionada por el usuario
      for (final r in recetasHumanas) {
        if (r['id_receta'] == 101) {
          r['es_publica'] = true;
        }
      }
      ServicioRecetas.contadorCaninas = caninas.length;

      setState(() {
        todasLasRecetas = recetasHumanas;
        recetasCaninas = caninas;
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
      final bool esFiltroCanino = _filtroAudiencia == FiltroAudienciaReceta.caninas;
      final List<Map<String, dynamic>> listaBase =
          esFiltroCanino ? recetasCaninas : todasLasRecetas;

      final base = listaBase.where((receta) {
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

        // Filtro por Audiencia (Oficiales vs Recién Salidas vs Puedo Cocinar Hoy vs Mis Recetas vs Comunidad vs Todas)
        final bool coincideAudiencia;
        switch (_filtroAudiencia) {
          case FiltroAudienciaReceta.oficiales:
            coincideAudiencia = ServicioRecetas.esOficial(receta);
            break;
          case FiltroAudienciaReceta.recienSalidas:
            coincideAudiencia = ServicioRecetas.esNovedad(receta);
            break;
          case FiltroAudienciaReceta.escolares:
            coincideAudiencia = ServicioRecetas.esRecetaEscolar(receta);
            break;
          case FiltroAudienciaReceta.puedoCocinarHoy:
            final match = _evaluarMatchReceta(receta);
            coincideAudiencia = match.listoParaCocinar || match.faltaUno;
            break;
          case FiltroAudienciaReceta.misRecetas:
            coincideAudiencia = ServicioRecetas.esMiReceta(receta);
            break;
          case FiltroAudienciaReceta.comunidad:
            coincideAudiencia = ServicioRecetas.esComunidad(receta);
            break;
          case FiltroAudienciaReceta.caninas:
            coincideAudiencia = true;
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

      if (_filtroAudiencia == FiltroAudienciaReceta.puedoCocinarHoy) {
        base.sort((a, b) {
          final mA = _evaluarMatchReceta(a);
          final mB = _evaluarMatchReceta(b);
          // Priorizar 100% disponibles sobre falta 1
          if (mA.listoParaCocinar && !mB.listoParaCocinar) return -1;
          if (!mA.listoParaCocinar && mB.listoParaCocinar) return 1;
          return mB.porcentaje.compareTo(mA.porcentaje);
        });
      } else if (_ingredientesSeleccionados.isNotEmpty) {
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

  // ==========================================================
  // 📸 AUDITORÍA AUTOMATIZADA DE IMÁGENES CON IA (1-CLIC)
  // ==========================================================
  void _confirmarAuditoriaImagenesConIA() {
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
            Icon(Icons.camera_enhance_rounded, color: Color(0xFFE65100)),
            SizedBox(width: 10),
            Expanded(child: Text('Auditar Imágenes con IA 📸')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El robot de IA revisará automáticamente todas las recetas oficiales del catálogo en Supabase:\n',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text('• Detecta fotos discordantes (ej. vinilos o platos no relacionados).'),
            SizedBox(height: 4),
            Text('• Erradica enlaces caídos (404) y cargas interminables.'),
            SizedBox(height: 4),
            Text('• Asigna y actualiza en Supabase fotos gastronómicas auténticas verificadas (HTTP 200).'),
            SizedBox(height: 12),
            Text(
              '¿Deseas comenzar la auditoría automática?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _ejecutarAuditoriaImagenes();
            },
            icon: const Icon(Icons.rocket_launch, size: 16),
            label: const Text('Comenzar Auditoría 📸'),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarAuditoriaImagenes() async {
    final supabase = Supabase.instance.client;

    final listaRes = await supabase
        .from('recetas')
        .select('id_receta, titulo, tipo_comida, imagen_url')
        .order('id_receta', ascending: true);

    final List<Map<String, dynamic>> recetasParaAuditar =
        List<Map<String, dynamic>>.from(listaRes);

    if (recetasParaAuditar.isEmpty || !mounted) return;

    int actual = 0;
    int corregidas = 0;
    String nombreActual = '';
    String estadoActual = 'Iniciando escaneo...';
    bool cancelado = false;
    bool procesoIniciado = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progresoCtx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            void iniciarProceso() async {
              try {
                for (var i = 0; i < recetasParaAuditar.length; i++) {
                  if (cancelado) break;

                  final r = recetasParaAuditar[i];
                  final dynamic rawId = r['id_receta'];
                  final int id = rawId is int ? rawId : (int.tryParse(rawId?.toString() ?? '0') ?? 0);
                  final String titulo = r['titulo'] ?? '';
                  final String tipoComida = r['tipo_comida'] ?? 'Comida';
                  final String? urlActual = r['imagen_url']?.toString();

                  setStateModal(() {
                    actual = i + 1;
                    nombreActual = titulo;
                    estadoActual = 'Analizando: $titulo...';
                  });

                  if (id > 0) {
                    final resultado = ServicioRecetas.auditarImagenReceta(
                      idReceta: id,
                      titulo: titulo,
                      tipoComida: tipoComida,
                      urlActual: urlActual,
                    );

                    if (resultado['cambiada'] == true) {
                      final String nuevaUrl = resultado['url'];
                      try {
                        await supabase
                            .from('recetas')
                            .update({'imagen_url': nuevaUrl})
                            .eq('id_receta', id);
                        corregidas++;
                        setStateModal(() {
                          estadoActual = 'Saneada: ${resultado['motivo']}';
                        });
                      } catch (e) {
                        debugPrint('Error al actualizar imagen de receta $id: $e');
                      }
                    }
                  }

                  // Pausa prudente para actualización reactiva fluida
                  await Future.delayed(const Duration(milliseconds: 60));
                }
              } catch (e) {
                debugPrint('Excepción en proceso de auditoría: $e');
              } finally {
                if (context.mounted) Navigator.pop(progresoCtx);
              }
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!procesoIniciado) {
                procesoIniciado = true;
                iniciarProceso();
              }
            });

            final double progreso = recetasParaAuditar.isEmpty
                ? 0.0
                : (actual / recetasParaAuditar.length);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.camera_enhance_rounded, color: Color(0xFFE65100)),
                  SizedBox(width: 10),
                  Expanded(child: Text('Auditando Imágenes con IA')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progreso,
                    color: const Color(0xFFE65100),
                    backgroundColor: const Color(0xFFE65100).withValues(alpha: 0.15),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progreso: $actual de ${recetasParaAuditar.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade300, width: 0.8),
                        ),
                        child: Text(
                          '$corregidas saneadas',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nombreActual,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    estadoActual,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                  child: const Text('Detener', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) {
      cargarRecetas();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡Auditoría finalizada! 🎉 Se revisaron $actual recetas y se sanearon $corregidas imágenes.',
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 5),
        ),
      );
    }
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
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final bool esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isLandscape ? 5 : 10),
      decoration: BoxDecoration(
        color: esOscuro ? const Color(0xFF16171D) : const Color(0xFFD32F2F),
        border: Border(
          bottom: BorderSide(
            color: esOscuro ? const Color(0xFF262833) : const Color(0xFFB71C1C),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              saludo,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: isLandscape ? 13 : 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: isLandscape ? 10.5 : 11.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirPildoraFiltro({
    required String etiqueta,
    required bool seleccionado,
    required VoidCallback onTap,
    required Color colorActivo,
    required Color fondoActivo,
    Color? colorInactivo,
    Color? fondoInactivo,
    Widget? icono,
  }) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: isLandscape ? 6 : 10),
            constraints: BoxConstraints(minHeight: isLandscape ? 36 : 44),
            decoration: BoxDecoration(
              color: seleccionado ? fondoActivo : (fondoInactivo ?? Colors.grey[100]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: seleccionado ? colorActivo : Colors.grey.shade300,
                width: seleccionado ? 1.8 : 1.0,
              ),
              boxShadow: seleccionado
                  ? [
                      BoxShadow(
                        color: colorActivo.withValues(alpha: 0.15),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (seleccionado) ...[
                  Icon(Icons.check_circle_rounded, size: 15, color: colorActivo),
                  const SizedBox(width: 6),
                ] else if (icono != null) ...[
                  icono,
                  const SizedBox(width: 6),
                ],
                Text(
                  etiqueta,
                  style: TextStyle(
                    color: seleccionado ? colorActivo : (colorInactivo ?? Colors.black87),
                    fontWeight: seleccionado ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
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
            : (widget.filtroInicial == FiltroAudienciaReceta.recienSalidas
                ? 'recetas_novedades'
                : (widget.filtroInicial == FiltroAudienciaReceta.escolares
                    ? 'recetas_escolares'
                    : (widget.filtroInicial == FiltroAudienciaReceta.caninas
                        ? 'caninas'
                        : (widget.filtroInicial == FiltroAudienciaReceta.oficiales
                            ? 'recetas_oficiales'
                            : 'recetas')))));

    final String tituloAppBar = widget.filtroInicial == FiltroAudienciaReceta.misRecetas
        ? 'Mis Creaciones 👨‍🍳'
        : (widget.filtroInicial == FiltroAudienciaReceta.recienSalidas
            ? 'Recién Salidas 🔥'
            : (widget.filtroInicial == FiltroAudienciaReceta.escolares
                ? 'Lunches y Snacks 🎒🍎'
                : (widget.filtroInicial == FiltroAudienciaReceta.caninas
                    ? 'Recetas Caninas 🐾'
                    : (widget.filtroInicial == FiltroAudienciaReceta.oficiales
                        ? 'Catálogo Oficial 🌟'
                        : 'Mis Recetas 📖'))));

    final bool esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: esOscuro ? const Color(0xFF121416) : Colors.grey[100],
      drawer: MenuLateral(rutaActual: rutaActualMenu),
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
            tituloAppBar,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: const Color(0xFF1E2022),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Búsqueda Global Spotlight 🔍',
            splashRadius: 24,
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
            splashRadius: 24,
            onPressed: () {
              ServicioRecordatorios.mostrarModalCentroRecordatorios(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.tips_and_updates_outlined, color: Colors.amberAccent),
            tooltip: '💡 Tour, Preferencias y Cómo Funciona',
            splashRadius: 24,
            onPressed: _mostrarCentroDeAyudaYBienvenida,
          ),
          if (ServicioAdmin.esAdmin())
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 28),
              tooltip: 'Herramientas de Administrador',
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 56),
              onSelected: (val) {
                if (val == 'sanitizar') {
                  _confirmarSaneamientoConIA();
                } else if (val == 'auditar_imagenes') {
                  _confirmarAuditoriaImagenesConIA();
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
                      Text('Carga Masiva Mensual (25 IA) 🚀'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'auditar_imagenes',
                  child: Row(
                    children: [
                      Icon(Icons.camera_enhance_rounded, color: Color(0xFFE65100)),
                      SizedBox(width: 10),
                      Text('Auditar Imágenes con IA 📸'),
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
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
            )
          : RefreshIndicator(
              color: const Color(0xFFD32F2F),
              onRefresh: cargarRecetas,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _construirBannerSaludo(),
          Container(
            padding: const EdgeInsets.all(15),
            color: esOscuro ? const Color(0xFF1E2022) : Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar receta por nombre...',
                    hintStyle: TextStyle(
                      color: esOscuro ? Colors.white38 : Colors.grey.shade600,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: esOscuro ? Colors.white70 : const Color(0xFF1E2022),
                    ),
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
                    fillColor: esOscuro ? const Color(0xFF16181A) : Colors.grey[100],
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
                // 🌟 Filtro de Audiencia y Origen (Oficiales, Recién Salidas, Mis Recetas, Comunidad, Todas)
                Builder(
                  builder: (context) {
                    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                    final double alturaFiltro = isLandscape ? 40 : 48;

                    final int countOficiales = todasLasRecetas.where(ServicioRecetas.esOficial).length;
                    final int countNovedades = todasLasRecetas.where(ServicioRecetas.esNovedad).length;
                    final int countEscolares = todasLasRecetas.where(ServicioRecetas.esRecetaEscolar).length;
                    final int countMisRecetas = todasLasRecetas.where(ServicioRecetas.esMiReceta).length;
                    final int countComunidad = todasLasRecetas.where(ServicioRecetas.esComunidad).length;
                    final int countCaninas = recetasCaninas.length;
                    final int countPuedoCocinar = todasLasRecetas.where((r) {
                      final m = _evaluarMatchReceta(r);
                      return m.listoParaCocinar || m.faltaUno;
                    }).length;
                    final int countMenos20 = todasLasRecetas.where(ServicioCocinaExpress.esExpress20).length;
                    final int countUnSarten = todasLasRecetas.where(ServicioCocinaExpress.esCeroTrastes).length;
                    final int countFacil5 = todasLasRecetas.where(ServicioCocinaExpress.esFacil5).length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🌟 Única Fila Unificada y Deslizable de Filtros de Decisión
                        SizedBox(
                          height: alturaFiltro,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              // 1. Oficiales
                              _construirPildoraFiltro(
                                etiqueta: '🌟 Oficiales ($countOficiales)',
                                seleccionado: _filtroAudiencia == FiltroAudienciaReceta.oficiales &&
                                    _filtroExpress == FiltroExpress.todos,
                                colorActivo: const Color(0xFFD32F2F),
                                fondoActivo: const Color(0xFFFBECEF),
                                onTap: () {
                                  setState(() {
                                    _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                    _filtroExpress = FiltroExpress.todos;
                                    categoriaSeleccionada = 'Todos';
                                    _filtrarRecetas();
                                  });
                                },
                              ),
                              // 2. Recién Salidas
                              _construirPildoraFiltro(
                                etiqueta: '🔥 Recién Salidas ($countNovedades)',
                                seleccionado: _filtroAudiencia == FiltroAudienciaReceta.recienSalidas,
                                colorActivo: const Color(0xFFE65100),
                                fondoActivo: const Color(0xFFFFF3E0),
                                onTap: () {
                                  setState(() {
                                    if (_filtroAudiencia == FiltroAudienciaReceta.recienSalidas) {
                                      _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                    } else {
                                      _filtroAudiencia = FiltroAudienciaReceta.recienSalidas;
                                      _filtroExpress = FiltroExpress.todos;
                                    }
                                    categoriaSeleccionada = 'Todos';
                                    _filtrarRecetas();
                                  });
                                },
                              ),
                              // 2.5 Lunch Escolar
                              _construirPildoraFiltro(
                                etiqueta: '🎒 Lunch Escolar ($countEscolares)',
                                seleccionado: _filtroAudiencia == FiltroAudienciaReceta.escolares,
                                colorActivo: const Color(0xFF00897B),
                                fondoActivo: const Color(0xFFE0F2F1),
                                onTap: () {
                                  setState(() {
                                    if (_filtroAudiencia == FiltroAudienciaReceta.escolares) {
                                      _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                    } else {
                                      _filtroAudiencia = FiltroAudienciaReceta.escolares;
                                      _filtroExpress = FiltroExpress.todos;
                                    }
                                    categoriaSeleccionada = 'Todos';
                                    _filtrarRecetas();
                                  });
                                },
                              ),
                              // 3. Puedo cocinar hoy
                              _construirPildoraFiltro(
                                etiqueta: '🟢 Puedo cocinar hoy ($countPuedoCocinar)',
                                seleccionado: _filtroAudiencia == FiltroAudienciaReceta.puedoCocinarHoy,
                                colorActivo: const Color(0xFF2E7D32),
                                fondoActivo: const Color(0xFFE8F5E9),
                                onTap: () {
                                  setState(() {
                                    if (_filtroAudiencia == FiltroAudienciaReceta.puedoCocinarHoy) {
                                      _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                    } else {
                                      _filtroAudiencia = FiltroAudienciaReceta.puedoCocinarHoy;
                                      _filtroExpress = FiltroExpress.todos;
                                    }
                                    categoriaSeleccionada = 'Todos';
                                    _filtrarRecetas();
                                  });
                                },
                              ),
                              // 4. Rápidas < 20 min
                              _construirPildoraFiltro(
                                etiqueta: '⚡ <20 min ($countMenos20)',
                                icono: const Text('⚡', style: TextStyle(fontSize: 14)),
                                seleccionado: _filtroExpress == FiltroExpress.express20,
                                colorActivo: const Color(0xFFE65100),
                                fondoActivo: const Color(0xFFFFF3E0),
                                onTap: () {
                                  setState(() {
                                    if (_filtroExpress == FiltroExpress.express20) {
                                      _filtroExpress = FiltroExpress.todos;
                                      _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                    } else {
                                      _filtroExpress = FiltroExpress.express20;
                                      _filtroAudiencia = FiltroAudienciaReceta.todas;
                                    }
                                    categoriaSeleccionada = 'Todos';
                                    _filtrarRecetas();
                                  });
                                },
                              ),
                              // 5. 1 Sartén
                              _construirPildoraFiltro(
                                etiqueta: '🍳 1 Sartén ($countUnSarten)',
                                icono: const Text('🍳', style: TextStyle(fontSize: 14)),
                                seleccionado: _filtroExpress == FiltroExpress.ceroTrastes,
                                colorActivo: const Color(0xFF00695C),
                                fondoActivo: const Color(0xFFE0F2F1),
                                onTap: () {
                                  setState(() {
                                    if (_filtroExpress == FiltroExpress.ceroTrastes) {
                                      _filtroExpress = FiltroExpress.todos;
                                      _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                    } else {
                                      _filtroExpress = FiltroExpress.ceroTrastes;
                                      _filtroAudiencia = FiltroAudienciaReceta.todas;
                                    }
                                    categoriaSeleccionada = 'Todos';
                                    _filtrarRecetas();
                                  });
                                },
                              ),
                              // 6. 5 Ingredientes
                              _construirPildoraFiltro(
                                etiqueta: '✨ 5 Ingredientes ($countFacil5)',
                                icono: const Text('✨', style: TextStyle(fontSize: 14)),
                                seleccionado: _filtroExpress == FiltroExpress.faciles5,
                                colorActivo: const Color(0xFF6A1B9A),
                                fondoActivo: const Color(0xFFF3E5F5),
                                onTap: () {
                                  setState(() {
                                    if (_filtroExpress == FiltroExpress.faciles5) {
                                      _filtroExpress = FiltroExpress.todos;
                                      _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                    } else {
                                      _filtroExpress = FiltroExpress.faciles5;
                                      _filtroAudiencia = FiltroAudienciaReceta.todas;
                                    }
                                    categoriaSeleccionada = 'Todos';
                                    _filtrarRecetas();
                                  });
                                },
                              ),
                              // 7. Mis Creaciones
                              _construirPildoraFiltro(
                                etiqueta: '👨‍🍳 Mis Creaciones ($countMisRecetas)',
                                seleccionado: _filtroAudiencia == FiltroAudienciaReceta.misRecetas,
                                colorActivo: const Color(0xFF1E2022),
                                fondoActivo: Colors.grey.shade200,
                                onTap: () {
                                  setState(() {
                                    if (_filtroAudiencia == FiltroAudienciaReceta.misRecetas) {
                                      _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                    } else {
                                      _filtroAudiencia = FiltroAudienciaReceta.misRecetas;
                                      _filtroExpress = FiltroExpress.todos;
                                    }
                                    categoriaSeleccionada = 'Todos';
                                    _filtrarRecetas();
                                  });
                                },
                              ),
                              // 8. Comunidad
                              _construirPildoraFiltro(
                                etiqueta: '🌎 Comunidad ($countComunidad)',
                                seleccionado: _filtroAudiencia == FiltroAudienciaReceta.comunidad,
                                colorActivo: Colors.indigo.shade800,
                                fondoActivo: Colors.indigo.shade50,
                                onTap: () {
                                  setState(() {
                                    if (_filtroAudiencia == FiltroAudienciaReceta.comunidad) {
                                      _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                    } else {
                                      _filtroAudiencia = FiltroAudienciaReceta.comunidad;
                                      _filtroExpress = FiltroExpress.todos;
                                    }
                                    categoriaSeleccionada = 'Todos';
                                    _filtrarRecetas();
                                  });
                                },
                              ),
                              // 9. Caninas
                              _construirPildoraFiltro(
                                etiqueta: '🐾 Caninas ($countCaninas)',
                                seleccionado: _filtroAudiencia == FiltroAudienciaReceta.caninas,
                                colorActivo: const Color(0xFF6D4C41),
                                fondoActivo: const Color(0xFFEFEBE9),
                                onTap: () {
                                  setState(() {
                                    if (_filtroAudiencia == FiltroAudienciaReceta.caninas) {
                                      _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                    } else {
                                      _filtroAudiencia = FiltroAudienciaReceta.caninas;
                                      _filtroExpress = FiltroExpress.todos;
                                    }
                                    categoriaSeleccionada = 'Todos';
                                    _filtrarRecetas();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        // Banners informativos ubicados DEBAJO de todos los selectores para evitar saltos de altura
                        if (_filtroAudiencia == FiltroAudienciaReceta.escolares) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2F1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF80CBC4), width: 0.8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.backpack_rounded, size: 18, color: Color(0xFF00897B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Lunches y snacks saludables para niños ($countEscolares). Fáciles de empacar y preparar con amor.',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF004D40),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const PantallaChef(
                                          modoEscolarInicial: true,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF004D40),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          'Chef IA 🎒',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () => ServicioRecordatorios.mostrarModalCentroRecordatorios(context),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00897B),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.alarm_add_rounded, size: 12, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text(
                                          'Alerta ⏰',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
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
                        if (_filtroAudiencia == FiltroAudienciaReceta.recienSalidas) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                _filtrarRecetas();
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFFB74D), width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFE65100)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Viendo recetas recién salidas ($countNovedades). Toca aquí para ver todo el Catálogo Oficial ($countOficiales).',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFFBF360C),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_filtroAudiencia == FiltroAudienciaReceta.misRecetas) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                                _filtrarRecetas();
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade300, width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: Colors.amber),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Viendo solo tus creaciones ($countMisRecetas). Toca aquí para ver el Catálogo Oficial completo ($countOficiales).',
                                      style: TextStyle(
                                        fontSize: 11.5,
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
                        if (_filtroAudiencia == FiltroAudienciaReceta.caninas) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PantallaRecetasCaninas(),
                                ),
                              ).then((_) => cargarRecetas());
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFEBE9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBCAAA4), width: 0.8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.pets, size: 16, color: Color(0xFF5D4037)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Viendo recetas caninas ($countCaninas). Nutrición y snacks para lomitos. Toca aquí para el Recetario Canino completo 🐾.',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF4E342E),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF5D4037)),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_filtroExpress != FiltroExpress.todos) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _filtroExpress.fondoColor,
                              borderRadius: BorderRadius.circular(10),
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
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    ),
                  if (_mostrarBannerInicioExplicativo &&
                      _searchController.text.trim().isEmpty &&
                      _ingredientesSeleccionados.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(15, 12, 15, 0),
                        child: _construirTarjetaExplicativaInicio(),
                      ),
                    ),
                  if (recetasFiltradas.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _construirEstadoVacioRecetas(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(15),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(
                          _construirListaRecetasAgrupadas(recetasFiltradas),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // ==========================================================
  // 📭 ESTADO VACÍO CUANDO NO HAY RECETAS QUE COINCIDAN
  // ==========================================================
  Widget _construirEstadoVacioRecetas() {
    final String terminoBusqueda = _searchController.text.trim();
    final bool esBusqueda = terminoBusqueda.isNotEmpty;

    if (esBusqueda) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 54,
                  color: Color(0xFFE65100),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No encontramos «$terminoBusqueda» en el catálogo',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E2022),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¿Quieres que el Chef IA invente una receta de «$terminoBusqueda» con lo que tienes en tu cocina?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700, height: 1.3),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => PantallaChef(
                        ingredientesIniciales: 'Quiero preparar $terminoBusqueda',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.psychology_alt_rounded, size: 20),
                label: Text('Crear «$terminoBusqueda» con Chef IA 🤖✨'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _filtrarRecetas();
                },
                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                label: const Text('Limpiar búsqueda', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _filtroAudiencia == FiltroAudienciaReceta.recienSalidas
                  ? Icons.local_fire_department_outlined
                  : (_filtroAudiencia == FiltroAudienciaReceta.escolares
                      ? Icons.backpack_outlined
                      : (_filtroAudiencia == FiltroAudienciaReceta.puedoCocinarHoy
                          ? Icons.kitchen_outlined
                          : (_filtroAudiencia == FiltroAudienciaReceta.caninas
                              ? Icons.pets
                              : Icons.search_off))),
              size: 70,
              color: _filtroAudiencia == FiltroAudienciaReceta.recienSalidas
                  ? Colors.orange.shade400
                  : (_filtroAudiencia == FiltroAudienciaReceta.escolares
                      ? const Color(0xFF00897B)
                      : (_filtroAudiencia == FiltroAudienciaReceta.puedoCocinarHoy
                          ? Colors.teal.shade400
                          : (_filtroAudiencia == FiltroAudienciaReceta.caninas
                              ? Colors.brown.shade400
                              : Colors.grey[400]))),
            ),
            const SizedBox(height: 10),
            Text(
              _filtroAudiencia == FiltroAudienciaReceta.recienSalidas
                  ? '¡Muy pronto nuevas recetas recién salidas del sartén!'
                  : (_filtroAudiencia == FiltroAudienciaReceta.escolares
                      ? 'No hay snacks o recetas de lunch escolar con los filtros actuales'
                      : (_filtroAudiencia == FiltroAudienciaReceta.puedoCocinarHoy
                          ? 'No hay recetas completas con tu despensa actual'
                          : (_filtroAudiencia == FiltroAudienciaReceta.caninas
                              ? 'Aún no hay recetas caninas con estos filtros'
                              : 'No se encontraron recetas con los filtros aplicados'))),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: (_filtroAudiencia == FiltroAudienciaReceta.recienSalidas ||
                        _filtroAudiencia == FiltroAudienciaReceta.escolares ||
                        _filtroAudiencia == FiltroAudienciaReceta.puedoCocinarHoy ||
                        _filtroAudiencia == FiltroAudienciaReceta.caninas)
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _filtroAudiencia == FiltroAudienciaReceta.recienSalidas
                    ? Colors.brown.shade800
                    : (_filtroAudiencia == FiltroAudienciaReceta.escolares
                        ? const Color(0xFF00695C)
                        : (_filtroAudiencia == FiltroAudienciaReceta.puedoCocinarHoy
                            ? Colors.teal.shade900
                            : (_filtroAudiencia == FiltroAudienciaReceta.caninas
                                ? Colors.brown.shade900
                                : Colors.grey))),
              ),
            ),
            if (_filtroAudiencia == FiltroAudienciaReceta.escolares) ...[
              const SizedBox(height: 6),
              Text(
                'Descubre snacks fáciles, brochetas, wraps y loncheras nutritivas para los peques.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PantallaChef(
                            modoEscolarInicial: true,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Crear con Chef Escolar 🎒✨'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                        _filtrarRecetas();
                      });
                    },
                    icon: const Icon(Icons.star_rounded, size: 18),
                    label: const Text('Ver Todo el Catálogo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00897B),
                      side: const BorderSide(color: Color(0xFF00897B)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (_filtroAudiencia == FiltroAudienciaReceta.recienSalidas) ...[
              const SizedBox(height: 6),
              Text(
                'El Chef está preparando el próximo lote de temporada.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                    _filtrarRecetas();
                  });
                },
                icon: const Icon(Icons.star_rounded, size: 18),
                label: const Text('Explorar Catálogo Oficial'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ] else if (_filtroAudiencia == FiltroAudienciaReceta.puedoCocinarHoy) ...[
              const SizedBox(height: 6),
              Text(
                'Registra tus alimentos en "Mi Despensa" o explora el catálogo para ver recetas faltantes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                    _filtrarRecetas();
                  });
                },
                icon: const Icon(Icons.star_rounded, size: 18),
                label: const Text('Ver Catálogo Oficial'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD32F2F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ] else if (_filtroAudiencia == FiltroAudienciaReceta.caninas) ...[
              const SizedBox(height: 6),
              Text(
                'Visita el Recetario Canino para consultar y preparar premios caseros.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PantallaRecetasCaninas(),
                    ),
                  ).then((_) => cargarRecetas());
                },
                icon: const Icon(Icons.pets, size: 18),
                label: const Text('Abrir Recetario Canino 🐾'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D4C41),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _filtroAudiencia = FiltroAudienciaReceta.oficiales;
                    categoriaSeleccionada = 'Todos';
                    _filtroExpress = FiltroExpress.todos;
                    _ingredientesSeleccionados.clear();
                    _searchController.clear();
                    _filtrarRecetas();
                  });
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Restablecer todos los filtros'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD32F2F),
                  side: const BorderSide(color: Color(0xFFD32F2F)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // 🍲 LISTA DE RECETAS AGRUPADAS POR TIEMPO DE COMIDA (ACORDEÓN)
  // ==========================================================
  List<Widget> _construirListaRecetasAgrupadas(List<Map<String, dynamic>> recetas) {
    // Clasificar recetas por tipo de comida
    final List<Map<String, dynamic>> desayunos = [];
    final List<Map<String, dynamic>> comidas = [];
    final List<Map<String, dynamic>> snacks = [];
    final List<Map<String, dynamic>> cenas = [];
    final List<Map<String, dynamic>> otras = [];

    for (final r in recetas) {
      final tipo = (r['tipo_comida'] ?? '').toString().toLowerCase().trim();
      if (tipo.contains('desayuno')) {
        desayunos.add(r);
      } else if (tipo.contains('comida')) {
        comidas.add(r);
      } else if (tipo.contains('snack')) {
        snacks.add(r);
      } else if (tipo.contains('cena')) {
        cenas.add(r);
      } else {
        otras.add(r);
      }
    }

    final List<String> categoriasActivas = [
      if (desayunos.isNotEmpty) 'desayunos',
      if (comidas.isNotEmpty) 'comidas',
      if (snacks.isNotEmpty) 'snacks',
      if (cenas.isNotEmpty) 'cenas',
      if (otras.isNotEmpty) 'otras',
    ];

    final widgets = <Widget>[];

    // Si hay más de una categoría activa, botón para Expandir/Colapsar todas
    if (categoriasActivas.length > 1) {
      final bool todasColapsadas =
          categoriasActivas.every((c) => _seccionesColapsadas.contains(c));
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.teal.shade800,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                ),
                onPressed: () {
                  setState(() {
                    if (todasColapsadas) {
                      _seccionesColapsadas.clear();
                    } else {
                      _seccionesColapsadas.addAll(categoriasActivas);
                    }
                  });
                },
                icon: Icon(
                  todasColapsadas
                      ? Icons.unfold_more_rounded
                      : Icons.unfold_less_rounded,
                  size: 18,
                ),
                label: Text(
                  todasColapsadas
                      ? 'Expandir todas las comidas'
                      : 'Colapsar todas las comidas',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (desayunos.isNotEmpty) {
      widgets.add(
        _crearSeccionCategoriaRecetas(
          clave: 'desayunos',
          titulo: '🍳 Desayunos',
          items: desayunos,
          colorTema: const Color(0xFFD97706),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    if (comidas.isNotEmpty) {
      widgets.add(
        _crearSeccionCategoriaRecetas(
          clave: 'comidas',
          titulo: '🍲 Comidas',
          items: comidas,
          colorTema: const Color(0xFF2E7D32),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    if (snacks.isNotEmpty) {
      widgets.add(
        _crearSeccionCategoriaRecetas(
          clave: 'snacks',
          titulo: '🍎 Snacks',
          items: snacks,
          colorTema: const Color(0xFFBE185D),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    if (cenas.isNotEmpty) {
      widgets.add(
        _crearSeccionCategoriaRecetas(
          clave: 'cenas',
          titulo: '🌙 Cenas',
          items: cenas,
          colorTema: const Color(0xFF4338CA),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    if (otras.isNotEmpty) {
      widgets.add(
        _crearSeccionCategoriaRecetas(
          clave: 'otras',
          titulo: '🍽️ Otras Recetas',
          items: otras,
          colorTema: const Color(0xFF6B7280),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  // ==========================================================
  // 🗂️ SECCIÓN DE CATEGORÍA COLAPSABLE
  // ==========================================================
  Widget _crearSeccionCategoriaRecetas({
    required String clave,
    required String titulo,
    required List<Map<String, dynamic>> items,
    required Color colorTema,
  }) {
    final bool estaColapsada = _seccionesColapsadas.contains(clave);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              if (estaColapsada) {
                _seccionesColapsadas.remove(clave);
              } else {
                _seccionesColapsadas.add(clave);
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: estaColapsada
                  ? colorTema.withValues(alpha: 0.08)
                  : colorTema.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorTema.withValues(alpha: estaColapsada ? 0.3 : 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  estaColapsada
                      ? Icons.arrow_right_rounded
                      : Icons.arrow_drop_down_rounded,
                  color: colorTema,
                  size: 26,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colorTema,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorTema.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorTema,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  estaColapsada
                      ? Icons.expand_more_rounded
                      : Icons.expand_less_rounded,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (!estaColapsada)
          ...items.map((receta) => _construirTarjetaReceta(receta)),
      ],
    );
  }

  // ==========================================================
  // 🎴 TARJETA INDIVIDUAL DE RECETA
  // ==========================================================
  Widget _construirTarjetaReceta(Map<String, dynamic> receta) {
    final titulo = receta['titulo'] ?? 'Sin título';
    final String? imagen = ServicioRecetas.obtenerImagenOptimizada(
      idReceta: receta['id_receta'],
      titulo: titulo.toString(),
      rawUrl: receta['imagen_url']?.toString(),
    );
    final tipo = receta['tipo_comida'] ?? 'General';
    final descripcion =
        receta['descripcion'] ?? receta['instrucciones'] ?? '';
    final id = receta['id_receta'];
    final int idInt = id is int
        ? id
        : (int.tryParse(id?.toString() ?? '0') ?? 0);
    final bool fueCocinada = (idInt > 0 &&
            _idsCocinadas.contains(idInt)) ||
        _titulosCocinados
            .contains(titulo.toString().toLowerCase().trim());

    // 🏷️ Curaduría Minimalista: Máximo 3 o 4 píldoras clave en 1 sola fila
    final List<Widget> pildoras = [];

    // 1. Origen / Identidad (Oficial, Mi Receta, Comunidad, o Tipo)
    if (ServicioRecetas.esOficial(receta)) {
      pildoras.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 2.5,
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
        ),
      );
    } else if (ServicioRecetas.esMiReceta(receta)) {
      pildoras.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 2.5,
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
        ),
      );
    } else if (ServicioRecetas.esComunidad(receta)) {
      pildoras.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 2.5,
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
      );
    } else {
      pildoras.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 2.5,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFD32F2F).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            tipo,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFFD32F2F),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // 2. Match de Despensa (Prioridad máxima de decisión culinaria)
    final m = _evaluarMatchReceta(receta);
    if (_ingredientesDespensa.isNotEmpty && m.totalPrincipales > 0) {
      if (m.listoParaCocinar) {
        pildoras.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF81C784), width: 0.8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, size: 10.5, color: Color(0xFF2E7D32)),
                SizedBox(width: 3),
                Text(
                  '🟢 ¡Tienes todo!',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (m.faltaUno) {
        pildoras.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFD54F), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_basket_outlined, size: 10.5, color: Color(0xFFF57F17)),
                const SizedBox(width: 3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    '🟡 Falta 1: ${m.faltantes.first}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 3. Novedad (si aplica)
    if (ServicioRecetas.esNovedad(receta)) {
      pildoras.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 2.5,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE65100).withValues(alpha: 0.25),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 11,
                color: Colors.white,
              ),
              SizedBox(width: 3),
              Text(
                'Recién salida 🔥',
                style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Tiempo de Preparación Express
    DesgloseTiempoCocina desglose;
    try {
      desglose = ServicioCocinaExpress.calcularDesglose(receta);
    } catch (_) {
      desglose = const DesgloseTiempoCocina(
        totalMinutos: 15,
        activoMinutos: 10,
        pasivoMinutos: 5,
      );
    }
    pildoras.add(
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 2.5,
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
                fontSize: 10.5,
                color: desglose.totalMinutos <= 20
                    ? const Color(0xFFE65100)
                    : Colors.grey.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    // 5. Calorías (kcal)
    if (receta['calorias'] != null && (receta['calorias'] as num) > 0) {
      pildoras.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 2.5,
          ),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${receta['calorias']} kcal',
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.teal[800],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else {
      // Si no tiene calorías numéricas, muestra el primer sello nutricional destacado
      final sellos = _obtenerSellosReceta(receta);
      if (sellos.isNotEmpty) {
        final s = sellos.first;
        pildoras.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: BoxDecoration(
              color: s.colorFondo,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: s.colorTexto.withValues(alpha: 0.3), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.emoji, style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 3),
                Text(
                  s.etiqueta,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: s.colorTexto,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // 6. Preparada (si fue cocinada y queda espacio)
    if (fueCocinada) {
      pildoras.add(
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
            vertical: 2.5,
          ),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
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
              const SizedBox(width: 3),
              Text(
                'Preparada',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 🌟 Curaduría Minimalista: exactamente hasta 4 píldoras clave en 1 sola fila
    final pildorasVisibles = pildoras.take(4).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: fueCocinada
              ? Colors.green.shade300
              : Colors.grey.shade200,
          width: fueCocinada ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () async {
          final eliminada = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaDetalleReceta(
                idReceta: idInt,
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. FILA PRINCIPAL: IMAGEN + TÍTULO + ACCIONES RÁPIDAS
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: imagen != null && imagen.toString().isNotEmpty
                        ? Image.network(
                            imagen,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const WidgetShimmerEsqueleto(
                                width: 60,
                                height: 60,
                                borderRadius: 10,
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      titulo,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.0,
                        height: 1.22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.event_available,
                          color: Colors.teal,
                          size: 22,
                        ),
                        tooltip: 'Programar en Planeador',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        visualDensity: VisualDensity.compact,
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
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
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
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),

              // 2. SECCIÓN DE PÍLDORAS CURADAS (1 SOLA FILA LIMPIA)
              if (pildorasVisibles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: pildorasVisibles,
                ),
              ],
            ],
          ),
        ),
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
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Los 5 Pilares de Jitomate y Cebolla',
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
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
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Mis Preferencias ⚙️',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
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
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Ver Manifiesto 🔥',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
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
