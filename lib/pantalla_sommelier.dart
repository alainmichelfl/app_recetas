import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'menu_lateral.dart';
import 'pantalla_chef.dart';
import 'servicio_sommelier.dart';

class PantallaSommelier extends StatefulWidget {
  const PantallaSommelier({super.key});

  @override
  State<PantallaSommelier> createState() => _PantallaSommelierState();
}

class _PantallaSommelierState extends State<PantallaSommelier>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _consultaCtrl = TextEditingController();

  bool _cargandoConsulta = false;
  RespuestaSommelierEnVivo? _ultimaRespuesta;
  List<String> _botellasEnCava = [];
  bool _cargandoCava = true;

  // Catálogo de recetas del usuario
  List<Map<String, dynamic>> _recetasUsuario = [];
  Map<String, dynamic>? _recetaSeleccionada;
  MaridajeReceta? _maridajeRecetaSeleccionada;
  bool _cargandoRecetas = true;

  // Modo Anfitrión 3 Tiempos
  final TextEditingController _entradaCtrl =
      TextEditingController(text: 'Ensalada tibia de espinaca con queso de cabra');
  final TextEditingController _platoFuerteCtrl =
      TextEditingController(text: 'Salmón sellado en salsa de cítricos y romero');
  final TextEditingController _postreCtrl =
      TextEditingController(text: 'Mousse de chocolate amargo 70%');
  MenuTresTiemposMaridado? _menuTresTiempos;
  bool _generandoMenu = false;

  final Color _colorBurgundy = const Color(0xFF2C0916);
  final Color _colorPlum = const Color(0xFF4E1125);
  final Color _colorGold = const Color(0xFFD4AF37);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarCavaYRecetas();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _consultaCtrl.dispose();
    _entradaCtrl.dispose();
    _platoFuerteCtrl.dispose();
    _postreCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCavaYRecetas() async {
    setState(() {
      _cargandoCava = true;
      _cargandoRecetas = true;
    });

    try {
      final botellas = await ServicioSommelier.obtenerBotellasEnDespensa();
      final resRecetas = await Supabase.instance.client
          .from('recetas')
          .select('id_receta, titulo, descripcion')
          .order('id_receta', ascending: false)
          .limit(30);

      final List<Map<String, dynamic>> lista =
          List<Map<String, dynamic>>.from(resRecetas);

      if (mounted) {
        setState(() {
          _botellasEnCava = botellas;
          _cargandoCava = false;
          _recetasUsuario = lista;
          _cargandoRecetas = false;
          if (lista.isNotEmpty) {
            _recetaSeleccionada = lista.first;
            _maridajeRecetaSeleccionada =
                ServicioSommelier.generarMaridajeHeuristico(
              _recetaSeleccionada!['titulo'] ?? '',
              descripcion: _recetaSeleccionada!['descripcion'] ?? '',
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos de Sommelier: $e');
      if (mounted) {
        setState(() {
          _cargandoCava = false;
          _cargandoRecetas = false;
        });
      }
    }
  }

  Future<void> _consultarEnVivo(String texto) async {
    final consulta = texto.trim();
    if (consulta.isEmpty) return;

    setState(() => _cargandoConsulta = true);
    FocusScope.of(context).unfocus();

    try {
      final res = await ServicioSommelier.consultarSommelierEnVivo(
        consulta: consulta,
        botellasEnCava: _botellasEnCava,
      );
      if (mounted) {
        setState(() {
          _ultimaRespuesta = res;
          _cargandoConsulta = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoConsulta = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al consultar al Sommelier: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generarMenuAnfitrion() async {
    setState(() => _generandoMenu = true);
    try {
      final menu = await ServicioSommelier.generarMenuTresTiempos(
        entrada: _entradaCtrl.text.trim(),
        platoFuerte: _platoFuerteCtrl.text.trim(),
        postre: _postreCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _menuTresTiempos = menu;
          _generandoMenu = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generandoMenu = false);
      }
    }
  }

  Future<void> _comprarBebida(String nombre) async {
    final ok = await ServicioSommelier.agregarBebidaAListaCompras(
      nombre,
      cantidad: '1 botella / porción',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '🛒 "$nombre" agregado a tu Lista de Compras'
              : 'Error al agregar la bebida a tu lista',
        ),
        backgroundColor: ok ? const Color(0xFF004D40) : Colors.red,
      ),
    );
  }

  Future<void> _compartirTexto(String texto) async {
    await SharePlus.instance.share(ShareParams(text: texto));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const MenuLateral(rutaActual: 'sommelier'),
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
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text('🍷', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text(
                'Sommelier IA',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF1E2022),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _colorGold,
          indicatorWeight: 3,
          labelColor: _colorGold,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.forum_outlined), text: 'En Vivo'),
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Mis Recetas'),
            Tab(icon: Icon(Icons.celebration_outlined), text: 'Cena 3 Tiempos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _construirPestanaEnVivo(),
          _construirPestanaMisRecetas(),
          _construirPestanaCenaTresTiempos(),
        ],
      ),
    );
  }

  // ───────────── PESTAÑA 1: EN VIVO & CONSULTA LIBRE ─────────────
  Widget _construirPestanaEnVivo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 📸 Hero Card: Sommelier Vision IA (Escáner de Botellas)
          _construirBannerSommelierVision(),
          const SizedBox(height: 14),

          // Banner Cava en Casa
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_colorBurgundy, _colorPlum],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _colorGold.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🍾', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tu Cava / Bar en Casa',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _cargandoCava
                            ? 'Consultando existencias...'
                            : (_botellasEnCava.isEmpty
                                ? 'No tienes botellas registradas en tu despensa.'
                                : 'Tienes ${_botellasEnCava.length} ${_botellasEnCava.length == 1 ? "bebida" : "bebidas"} registradas: ${_botellasEnCava.take(3).join(", ")}'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Campo de Consulta
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF800020), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Pregunta a tu Sommelier en tiempo real',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cuéntale qué estás cocinando, qué botella tienes abierta o qué ocasión festejas.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _consultaCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText:
                        'Ej: "Estoy haciendo una salsa de chipotle con crema, ¿qué vino o mocktail le va?"',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF800020), width: 1.5),
                    ),
                  ),
                  onSubmitted: _consultarEnVivo,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorPlum,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _cargandoConsulta
                        ? null
                        : () => _consultarEnVivo(_consultaCtrl.text),
                    icon: _cargandoConsulta
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _cargandoConsulta
                          ? 'Consultando Cava IA...'
                          : 'Consultar Sommelier ✨',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Chips de preguntas rápidas
          const Text(
            'Sugerencias rápidas:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chipSugerencia('🥩 Rib Eye a la parrilla'),
              _chipSugerencia('🌶️ Mole o salsas con chile'),
              _chipSugerencia('🍾 Tengo vino Malbec en casa'),
              _chipSugerencia('🍹 Mocktail fresco sin alcohol'),
              _chipSugerencia('🐟 Pescado blanco al sartén'),
              _chipSugerencia('🍝 Pasta Alfredo cremosa'),
            ],
          ),
          const SizedBox(height: 20),

          // Resultado de la consulta
          if (_ultimaRespuesta != null) ...[
            _construirTarjetaResultadoEnVivo(_ultimaRespuesta!),
            const SizedBox(height: 30),
          ],
        ],
      ),
    );
  }

  Widget _chipSugerencia(String texto) {
    return ActionChip(
      label: Text(texto, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        _consultaCtrl.text = texto;
        _consultarEnVivo(texto);
      },
    );
  }

  Widget _construirTarjetaResultadoEnVivo(RespuestaSommelierEnVivo res) {
    final m = res.maridaje;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_colorBurgundy, _colorPlum],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _colorGold.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _colorGold.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Text('✨', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Recomendación del Sommelier',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white70),
                tooltip: 'Compartir maridaje',
                onPressed: () => _compartirTexto(
                  '${res.mensaje}\n\n${m.resumenParaCompartir(_consultaCtrl.text)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            res.mensaje,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          ),
          const Divider(color: Colors.white24, height: 24),

          // Las 3 vertientes
          _renglonBebida('🍷 Vino de Autor:', m.vino, onComprar: () => _comprarBebida(m.vino)),
          const SizedBox(height: 10),
          _renglonBebida('🥃 Cóctel / Destilado:', m.destilado, onComprar: () => _comprarBebida(m.destilado)),
          const SizedBox(height: 10),
          _renglonBebida('🍹 0.0% Sin Alcohol:', m.sinAlcohol, onComprar: () => _comprarBebida(m.sinAlcohol)),

          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _colorGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎯', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m.notasArmonia,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '❄️ Servicio: ${m.temperaturaServicio} | 🥂 Cristalería: ${m.tipoCopa}',
            style: TextStyle(color: _colorGold, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _renglonBebida(String titulo, String descripcion, {required VoidCallback onComprar}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: _colorGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                descripcion,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_shopping_cart, color: Colors.white70, size: 20),
          tooltip: 'Agregar a lista de compras',
          onPressed: onComprar,
        ),
      ],
    );
  }

  // =========================================================================
  // 📸 SOMMELIER VISION IA (ESCÁNER DE BOTELLAS CON CÁMARA / GALERÍA)
  // =========================================================================

  Widget _construirBannerSommelierVision() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF380B17),
            Color(0xFF6B1426),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B1426).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _colorGold.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: _colorGold, width: 1.5),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFFFFD700),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sommelier Vision IA 📸',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Escanea la etiqueta de cualquier botella',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Toma una foto a cualquier vino, destilado o licor. La IA identificará la bodega y uva, te dará notas de cata y te sugerirá platillos ideales cruzados con lo que tienes en tu despensa.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: const Color(0xFF380B17),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  icon: const Icon(Icons.photo_camera, size: 18),
                  label: const Text(
                    'Tomar Foto',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () => _escanearBotella(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white60),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text(
                    'Galería',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  onPressed: () => _escanearBotella(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _escanearBotella(ImageSource origen) async {
    final picker = ImagePicker();
    // Prioridad R2: Compresión y optimización en cliente (ahorro de datos y velocidad 3x)
    final XFile? foto = await picker.pickImage(
      source: origen,
      imageQuality: 80,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (foto == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 15, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF800020)),
              SizedBox(height: 18),
              Text(
                'Analizando etiqueta con IA... 🍷🔍',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6),
              Text(
                'Identificando bodega, variedad, notas de cata y maridajes con tu despensa.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final bytes = await foto.readAsBytes();
      final despensa = await ServicioSommelier.obtenerIngredientesEnDespensa();
      final resultado = await ServicioSommelier.escanearBotellaConIA(
        bytes,
        ingredientesDespensa: despensa,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cerrar diálogo de carga

      if (resultado != null) {
        _mostrarModalResultadoBotella(resultado, bytes);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos identificar la etiqueta con claridad. Intenta con una toma más cercana y con buena iluminación.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      debugPrint('Error al escanear botella: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al analizar la botella: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarModalResultadoBotella(
    ResultadoEscaneoBotella resultado,
    Uint8List fotoBytes,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            controller: scrollCtrl,
            children: [
              // Barra superior arrastrable
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Cabecera: Foto + Título de la Botella
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      fotoBytes,
                      width: 75,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF800020).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            resultado.tipoBebida,
                            style: const TextStyle(
                              color: Color(0xFF800020),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          resultado.nombreBotella,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (resultado.variedadORegion.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            resultado.variedadORegion,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Ficha de servicio: Temperatura & Copa
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.thermostat,
                              color: Colors.blueGrey, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              resultado.temperaturaServicio,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 20, width: 1, color: Colors.grey[300]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.wine_bar,
                              color: Color(0xFF800020), size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              resultado.copaRecomendada,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Notas de Cata
              if (resultado.notasCata.isNotEmpty) ...[
                const Text(
                  'Notas de Cata 📝',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Text(
                    resultado.notasCata,
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Platillos Sugeridos
              if (resultado.platillosSugeridos.isNotEmpty) ...[
                const Text(
                  'Platillos recomendados para acompañar 🍽️',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 8),
                ...resultado.platillosSugeridos.map(
                  (platillo) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant_menu,
                            size: 16, color: Color(0xFF800020)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            platillo,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Insumos compatibles de la Despensa
              if (resultado.ingredientesDespensaCompatibles.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.teal.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.kitchen, color: Colors.teal, size: 18),
                          SizedBox(width: 8),
                          Text(
                            '¡En tu despensa tienes insumos que combinan!',
                            style: TextStyle(
                              color: Colors.teal,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: resultado.ingredientesDespensaCompatibles
                            .map(
                              (ing) => Chip(
                                label: Text(ing,
                                    style: const TextStyle(fontSize: 11)),
                                backgroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Tip del Sommelier
              if (resultado.tipSommelier.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBECEF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color:
                            const Color(0xFFB33951).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          resultado.tipSommelier,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF5B1228),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Botonera de acciones
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF800020),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.wine_bar, size: 18),
                      label: const Text(
                        'Guardar en Mi Cava 🍾',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      onPressed: () async {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(ctx);
                        final guardado =
                            await ServicioSommelier.guardarBotellaEnCava(
                                resultado.nombreBotella);
                        if (guardado) {
                          _cargarCavaYRecetas();
                          if (mounted) {
                            navigator.pop();
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${resultado.nombreBotella} guardada en Mi Cava & Bar 🍾✅'),
                                backgroundColor: const Color(0xFF800020),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.teal.shade800,
                        side: BorderSide(color: Colors.teal.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.soup_kitchen, size: 18),
                      label: const Text(
                        'Cocinar con Chef IA 👨‍🍳',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        final sugerenciaIngredientes = resultado
                                .ingredientesDespensaCompatibles.isNotEmpty
                            ? resultado.ingredientesDespensaCompatibles
                                .take(4)
                                .join(', ')
                            : (resultado.platillosSugeridos.isNotEmpty
                                ? resultado.platillosSugeridos.first
                                : '');
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PantallaChef(
                              ingredientesIniciales: sugerenciaIngredientes,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.share_outlined, size: 20),
                    tooltip: 'Compartir Ficha de Cata',
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(
                          text: resultado.formatoParaCompartir(),
                          subject: 'Ficha de Cata: ${resultado.nombreBotella}',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────── PESTAÑA 2: MARIDAR MIS RECETAS GUARDADAS ─────────────
  Widget _construirPestanaMisRecetas() {
    if (_cargandoRecetas) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF800020)),
      );
    }

    if (_recetasUsuario.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'No encontramos recetas en tu catálogo aún.\n¡Crea una en "Chef IA" o guarda recetas para maridarlas aquí!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final m = _maridajeRecetaSeleccionada;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selecciona una receta de tu catálogo:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: _recetaSeleccionada,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _recetasUsuario.map((receta) {
                    return DropdownMenuItem(
                      value: receta,
                      child: Text(
                        receta['titulo'] ?? 'Sin título',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _recetaSeleccionada = val;
                        _maridajeRecetaSeleccionada =
                            ServicioSommelier.generarMaridajeHeuristico(
                          val['titulo'] ?? '',
                          descripcion: val['descripcion'] ?? '',
                        );
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (m != null) ...[
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_colorBurgundy, _colorPlum],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _colorGold.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🍷', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _recetaSeleccionada?['titulo'] ?? 'Receta',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Perfil: ${m.categoriaPerfil}',
                              style: TextStyle(
                                color: _colorGold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, color: Colors.white70),
                        onPressed: () => _compartirTexto(
                          m.resumenParaCompartir(_recetaSeleccionada?['titulo'] ?? ''),
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  _renglonBebida('🍇 Vino Recomendado:', m.vino,
                      onComprar: () => _comprarBebida(m.vino)),
                  const SizedBox(height: 12),
                  _renglonBebida('🥃 Destilado / Cóctel:', m.destilado,
                      onComprar: () => _comprarBebida(m.destilado)),
                  const SizedBox(height: 12),
                  _renglonBebida('🍹 Sin Alcohol (Mocktail):', m.sinAlcohol,
                      onComprar: () => _comprarBebida(m.sinAlcohol)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _colorGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🎯', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m.notasArmonia,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '❄️ Temperatura: ${m.temperaturaServicio} | 🥂 Cristalería: ${m.tipoCopa}',
                    style: TextStyle(
                      color: _colorGold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ───────────── PESTAÑA 3: CENA 3 TIEMPOS (MODO ANFITRIÓN) ─────────────
  Widget _construirPestanaCenaTresTiempos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('🍽️', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 8),
                    Text(
                      'Diseña tu Menú de Anfitrión',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Organiza una cena memorable con maridaje coordinado para cada tiempo.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 14),

                _campoTiempo('🥗 1er Tiempo (Entrada)', _entradaCtrl),
                const SizedBox(height: 10),
                _campoTiempo('🥩 2do Tiempo (Plato Fuerte)', _platoFuerteCtrl),
                const SizedBox(height: 10),
                _campoTiempo('🍰 3er Tiempo (Postre)', _postreCtrl),
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorPlum,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _generandoMenu ? null : _generarMenuAnfitrion,
                    icon: _generandoMenu
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.menu_book_rounded),
                    label: Text(
                      _generandoMenu
                          ? 'Generando Menú...'
                          : 'Generar Carta con Maridaje 🥂',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_menuTresTiempos != null) ...[
            _construirTarjetaCartaMenu(_menuTresTiempos!),
            const SizedBox(height: 30),
          ],
        ],
      ),
    );
  }

  Widget _campoTiempo(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirTarjetaCartaMenu(MenuTresTiemposMaridado menu) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E060F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _colorGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'CARTA GOURMET',
            style: TextStyle(
              color: _colorGold,
              letterSpacing: 3,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Menú & Maridaje de 3 Tiempos',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const Divider(color: Colors.white24, height: 24),

          _bloqueTiempo(
            '1er Tiempo · Entrada',
            menu.entrada,
            menu.maridajeEntrada.vino,
            menu.maridajeEntrada.sinAlcohol,
          ),
          const Divider(color: Colors.white12, height: 20),

          _bloqueTiempo(
            '2do Tiempo · Plato Fuerte',
            menu.platoFuerte,
            menu.maridajePlatoFuerte.vino,
            menu.maridajePlatoFuerte.destilado,
          ),
          const Divider(color: Colors.white12, height: 20),

          _bloqueTiempo(
            '3er Tiempo · Postre',
            menu.postre,
            menu.maridajePostre.vino,
            menu.maridajePostre.destilado,
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _colorGold,
                foregroundColor: _colorBurgundy,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _compartirTexto(menu.formatoParaCompartir()),
              icon: const Icon(Icons.share, size: 20),
              label: const Text(
                'Compartir Carta con Invitados 📤',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloqueTiempo(
    String tiempo,
    String platillo,
    String vino,
    String alternativa,
  ) {
    return Column(
      children: [
        Text(
          tiempo.toUpperCase(),
          style: TextStyle(
            color: _colorGold,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          platillo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '🍷 Vino: $vino',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          '🍹 Alternativa: $alternativa',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}
