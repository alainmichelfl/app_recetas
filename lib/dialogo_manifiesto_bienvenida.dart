import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modal interactivo tipo tarjeta deslizable (Swipe Cards) que presenta
/// el manifiesto disruptivo de "Jitomate y Cebolla".
class DialogoManifiestoBienvenida extends StatefulWidget {
  final VoidCallback? onCerrar;

  const DialogoManifiestoBienvenida({
    super.key,
    this.onCerrar,
  });

  static const String prefClaveVisto = 'manifiesto_bienvenida_visto_v1';

  /// Muestra el diálogo si no ha sido visto o si se fuerza su visualización.
  static Future<void> verificarYMostrar(
    BuildContext context, {
    bool forzar = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final yaVisto = prefs.getBool(prefClaveVisto) ?? false;

    if ((forzar || !yaVisto) && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => const DialogoManifiestoBienvenida(),
      );
    }
  }

  @override
  State<DialogoManifiestoBienvenida> createState() =>
      _DialogoManifiestoBienvenidaState();
}

class _DialogoManifiestoBienvenidaState
    extends State<DialogoManifiestoBienvenida> {
  final PageController _pageController = PageController();
  int _paginaActual = 0;
  bool _noVolverAMostrar = true;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _marcarComoVistoYCerrar() async {
    if (_noVolverAMostrar) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(DialogoManifiestoBienvenida.prefClaveVisto, true);
    }
    if (mounted) {
      Navigator.of(context).pop();
      widget.onCerrar?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final anchoDialogo = (size.width * 0.92).clamp(320.0, 520.0);
    final altoDialogo = (size.height * 0.82).clamp(520.0, 640.0);

    const colorRuby = Color(0xFFD32F2F);
    const colorDorado = Color(0xFFFFB300);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Container(
          width: anchoDialogo,
          height: altoDialogo,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF23252E),
                Color(0xFF16171D),
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: colorRuby.withValues(alpha: 0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorRuby.withValues(alpha: 0.25),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              children: [
                // 💡 Fondo con halo sutil
                Positioned(
                  top: -80,
                  right: -80,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorRuby.withValues(alpha: 0.18),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -60,
                  left: -60,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorDorado.withValues(alpha: 0.12),
                    ),
                  ),
                ),

                // 💡 Contenido principal en tarjetas deslizables
                Column(
                  children: [
                    // Barra superior: Indicador de paso + Botón Saltar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              'MANIFIESTO • ${_paginaActual + 1} de 3',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: colorDorado,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 22,
                            ),
                            tooltip: 'Cerrar',
                            onPressed: _marcarComoVistoYCerrar,
                          ),
                        ],
                      ),
                    ),

                    // Tarjetas Deslizables (PageView)
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (idx) {
                          setState(() => _paginaActual = idx);
                        },
                        children: [
                          _construirTarjeta1Manifiesto(context),
                          _construirTarjeta2ChefIA(context),
                          _construirTarjeta3WellnessYFinanzas(context),
                        ],
                      ),
                    ),

                    // Indicadores de puntos (Dots) y botones de navegación
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (index) {
                              final bool activa = _paginaActual == index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: activa ? 26 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: activa
                                      ? colorRuby
                                      : Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (_paginaActual > 0)
                                TextButton(
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  child: Text(
                                    'Atrás',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(width: 60),
                              const Spacer(),
                              ElevatedButton(
                                onPressed: () {
                                  if (_paginaActual < 2) {
                                    _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  } else {
                                    _marcarComoVistoYCerrar();
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorRuby,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 6,
                                  shadowColor:
                                      colorRuby.withValues(alpha: 0.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _paginaActual == 2
                                          ? '¡A Cocinar! 🚀'
                                          : 'Siguiente',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      _paginaActual == 2
                                          ? Icons.check_circle_outline
                                          : Icons.arrow_forward_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Checkbox discreto "No volver a mostrar al inicio"
                          InkWell(
                            onTap: () {
                              setState(() {
                                _noVolverAMostrar = !_noVolverAMostrar;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _noVolverAMostrar
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    size: 16,
                                    color: Colors.white54,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'No volver a mostrar al iniciar',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.white54,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // 🎴 TARJETA 1: EL MANIFIESTO REBELDE (PROPUESTA A)
  // ==========================================================
  Widget _construirTarjeta1Manifiesto(BuildContext context) {
    const colorRuby = Color(0xFFE53935);
    const colorDorado = Color(0xFFFFB300);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo oficial con resplandor
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colorRuby.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(50),
              child: Image.asset(
                'assets/icon_3a_ruby_glow.png',
                width: 78,
                height: 78,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorRuby,
                  ),
                  child: const Center(
                    child: Text('🍅', style: TextStyle(fontSize: 38)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Título de la App
          Text(
            'JITOMATE Y CEBOLLA',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.white70,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 14),

          // ⚡ EL GANCHO REBELDE (Propuesta A)
          Text(
            '«¡Olvídate de las típicas apps de cocina aburridas!»',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colorDorado,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),

          // 🚀 EL ESCRITO DEL MANIFIESTO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              'No somos un recetario más:\nsomos tu asistente culinario inteligente, wellness & fitness tracker.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Pistas de swipe
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Desliza para ver la diferencia',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.swipe_left_rounded,
                color: colorDorado,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 🎴 TARJETA 2: EL ASISTENTE CULINARIO IA & MANOS LIBRES
  // ==========================================================
  Widget _construirTarjeta2ChefIA(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              '🍳 PILAR 1: ASISTENCIA CULINARIA',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFB300),
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Cocina sin estrés ni manos sucias',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),

          _construirFilaBeneficio(
            icono: Icons.smart_toy_outlined,
            colorIcono: Colors.amber,
            titulo: 'Chef IA con tu Despensa',
            descripcion:
                '¿Qué tienes hoy? Inventa platillos deliciosos al instante con lo que ya compraste, sin tirar comida.',
          ),
          const SizedBox(height: 12),

          _construirFilaBeneficio(
            icono: Icons.air_outlined,
            colorIcono: Colors.tealAccent,
            titulo: 'Copiloto Thermomix & Air Fryer',
            descripcion:
                'Traduce cualquier receta a parámetros exactos de tiempo, temperatura Varoma, velocidad y giro inverso ↺.',
          ),
          const SizedBox(height: 12),

          _construirFilaBeneficio(
            icono: Icons.mic_rounded,
            colorIcono: Colors.redAccent,
            titulo: 'Modo Manos Libres por Voz',
            descripcion:
                'Di "Siguiente", "Atrás" o "Terminar" sin tocar el teléfono con las manos llenas de masa o aceite.',
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // 🎴 TARJETA 3: WELLNESS, FITNESS TRACKER & BOLSILLO
  // ==========================================================
  Widget _construirTarjeta3WellnessYFinanzas(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              '🥗 PILAR 2: WELLNESS & BOLSILLO',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFB300),
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Salud a tu medida y ahorro real',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),

          _construirFilaBeneficio(
            icono: Icons.fitness_center_rounded,
            colorIcono: Colors.greenAccent,
            titulo: 'Fitness & Nutrición Personalizada',
            descripcion:
                'Metas en calorías y macros (proteína, carbos, grasas). Planes Keto, Déficit calórico o Apto para diabetes.',
          ),
          const SizedBox(height: 12),

          _construirFilaBeneficio(
            icono: Icons.compare_arrows_rounded,
            colorIcono: Colors.lightBlueAccent,
            titulo: 'Cotizador Multi-Supermercado',
            descripcion:
                'Compara tu lista en Walmart, Soriana y La Comer para ahorrar \$300-\$600 MXN en cada súper.',
          ),
          const SizedBox(height: 12),

          _construirFilaBeneficio(
            icono: Icons.family_restroom_rounded,
            colorIcono: Colors.purpleAccent,
            titulo: 'Hogar Familiar Compartido',
            descripcion:
                'Conecta a tu pareja y familia con el código CASA-XXXX para sincronizar despensa y compras en tiempo real.',
          ),
        ],
      ),
    );
  }

  Widget _construirFilaBeneficio({
    required IconData icono,
    required Color colorIcono,
    required String titulo,
    required String descripcion,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorIcono.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: colorIcono, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descripcion,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
