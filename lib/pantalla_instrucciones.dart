import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pantalla moderna tipo Tarjetas Deslizables (Swipe Cards) que explica con total claridad
/// qué es, qué hace y cómo funciona la aplicación Jitomate y Cebolla en el día a día.
/// Utiliza la paleta Haute-Cuisine Bistro (Gourmet Red, Verde Laurel, Ámbar, Índigo, Frambuesa).
class PantallaInstrucciones extends StatefulWidget {
  const PantallaInstrucciones({super.key});

  @override
  State<PantallaInstrucciones> createState() => _PantallaInstruccionesState();
}

class _PantallaInstruccionesState extends State<PantallaInstrucciones> {
  final PageController _controladorPagina = PageController();
  int _paginaActual = 0;

  static const Color _colorRuby = Color(0xFFD32F2F);
  static const Color _colorVerdeLaurel = Color(0xFF2E7D32);
  static const Color _colorAmbar = Color(0xFFD97706);
  static const Color _colorIndigo = Color(0xFF4338CA);
  static const Color _colorFrambuesa = Color(0xFFBE185D);

  final List<Map<String, dynamic>> _tarjetasGuia = [
    {
      'pilar': '01',
      'etiqueta': 'VISIÓN & FILOSOFÍA DISRUPTIVA',
      'titulo': '¿Qué es Jitomate y Cebolla?',
      'subtitulo': 'Tu Asistente Integral de Cocina, Nutrición y Ahorro Doméstico',
      'icono': Icons.restaurant_menu_rounded,
      'colorTema': _colorRuby,
      'destacado': 'Mucho más que un recetario: un ecosistema que resuelve el "¿qué cocino hoy?", optimiza tu despensa y cuida tu dinero.',
      'puntos': [
        '🍽️ Menús a tu medida calórica (Déficit, Volumen, Keto o Mantenimiento).',
        '⏱️ Modo Cocina Express en ≤ 15 min y técnica Cero Trastes.',
        '💰 Ahorro real de más de \$3,000 MXN al mes vs delivery o restaurantes.',
      ],
      'insignia': 'Ecosistema Culinario Inteligente',
    },
    {
      'pilar': '02',
      'etiqueta': 'FLUJO MAESTRO EN 4 PASOS',
      'titulo': '¿Cómo Funciona la App?',
      'subtitulo': 'El Circuito Diario: De tu Supermercado a tu Mesa',
      'icono': Icons.all_inclusive_rounded,
      'colorTema': _colorAmbar,
      'destacado': 'Un sistema sin fricción pensado para personas reales con poco tiempo libre:',
      'puntos': [
        '1️⃣ Despensa: Escaneas tu ticket con IA o agregas tus 15 básicos.',
        '2️⃣ Planificación: El Chef IA arma tus 28 comidas en 1 clic sin repetir.',
        '3️⃣ Cocina: Platillos en ≤15 min (1 sartén) o adelanta el domingo en 2h.',
        '4️⃣ Ahorro: Cotizas Walmart vs Soriana vs La Comer y evitas desperdicios.',
      ],
      'insignia': 'Circuito 100% Automatizado',
    },
    {
      'pilar': '03',
      'etiqueta': 'DESPENSA POR ZONAS & ESCÁNER IA',
      'titulo': 'Despensa por 4 Zonas',
      'subtitulo': 'Tu Refrigerador, Congelador y Alacena Bajo Control',
      'icono': Icons.kitchen_rounded,
      'colorTema': _colorVerdeLaurel,
      'destacado': 'Se acabó olvidar ingredientes que caducan en el fondo del estante:',
      'puntos': [
        '🧊 4 Zonas Inteligentes: Refri, Congelador, Alacena Seca y Cava & Bar.',
        '📸 Escáner con Gemini Visión: Foto de tu ticket y captura artículos y precios.',
        '❄️ Alertas de Descongelado: Te avisa qué proteína bajar la noche previa.',
      ],
      'insignia': 'Cero Merma & Frescura Garantizada',
    },
    {
      'pilar': '04',
      'etiqueta': 'COCINA EXPRESS & COMANDOS POR VOZ',
      'titulo': 'Chef IA y Cocina Express',
      'subtitulo': 'Cocina en ≤ 15 Minutos, 1 Solo Sartén y Manos Libres',
      'icono': Icons.bolt_rounded,
      'colorTema': _colorAmbar,
      'destacado': 'El Chef IA inventa platillos usando ÚNICAMENTE lo que tienes en casa:',
      'puntos': [
        '⚡ Recetas Express: Platillos deliciosos listos en 15 minutos o menos.',
        '🍳 Cero Trastes: Todo se resuelve en 1 sartén, air fryer o ensamble en frío.',
        '🎙️ Comandos por Voz: Di "Siguiente", "Anterior" o "Terminar" sin manchar el cel.',
      ],
      'insignia': 'Cero Trastes & Manos Libres',
    },
    {
      'pilar': '05',
      'etiqueta': 'ORGANIZACIÓN SEMANAL COMPLETA',
      'titulo': 'Planeador & Batch Cooking',
      'subtitulo': 'Tu Semana Completa Resuelta en 1 Clic y 2 Horas',
      'icono': Icons.calendar_month_rounded,
      'colorTema': _colorIndigo,
      'destacado': 'Planifica tus 28 turnos semanales respetando porciones y electrodomésticos:',
      'puntos': [
        '🪄 Planeador en 1 Clic: Rellena turnos vacíos sin repetir alimentos.',
        '🍱 Batch Cooking Dominical: Guía en 4 fases para cocinar toda la semana en 2 horas.',
        '📆 Exportación Directa: Sincroniza tus comidas con Google o Apple Calendar.',
      ],
      'insignia': '28 Comidas Resueltas en 2h',
    },
    {
      'pilar': '06',
      'etiqueta': 'ECONOMÍA & HOGAR COMPARTIDO',
      'titulo': 'Club del Súper & Finanzas',
      'subtitulo': 'Cotizador Multicadena y Despensa Familiar Compartida',
      'icono': Icons.shopping_cart_checkout_rounded,
      'colorTema': _colorFrambuesa,
      'destacado': 'Convierte tu alimentación en la inversión más rentable de tu hogar:',
      'puntos': [
        '🛒 Comparativa en Vivo: Walmart vs Soriana vs La Comer vs Central de Abasto.',
        '🏡 Código Familiar CASA-XXXX: Sincroniza despensa y lista de súper con tu familia.',
        '🏆 Racha Antidesperdicio: Gana insignias por semanas con cero comida tirada.',
      ],
      'insignia': 'Ahorro de +\$3,000 MXN al Mes',
    },
  ];

  @override
  void dispose() {
    _controladorPagina.dispose();
    super.dispose();
  }

  void _avanzarOFinalizar() {
    if (_paginaActual == _tarjetasGuia.length - 1) {
      Navigator.pop(context);
    } else {
      _controladorPagina.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121316),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16171D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          tooltip: 'Cerrar guía',
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _colorRuby.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _colorRuby.withValues(alpha: 0.4)),
              ),
              child: const Text('🍅🧅', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿CÓMO FUNCIONA LA APP?',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFFB300),
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Guía Oficial y Pilares Clave',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Saltar',
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Carrusel de Tarjetas Modernas Deslizables
            Expanded(
              child: PageView.builder(
                controller: _controladorPagina,
                onPageChanged: (index) => setState(() => _paginaActual = index),
                itemCount: _tarjetasGuia.length,
                itemBuilder: (context, index) {
                  final item = _tarjetasGuia[index];
                  final Color itemColor = item['colorTema'] as Color;
                  final List<String> puntos = List<String>.from(item['puntos']);

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 480),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF23252E),
                              Color(0xFF16171D),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: itemColor.withValues(alpha: 0.45),
                            width: 1.6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: itemColor.withValues(alpha: 0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Cabecera de la tarjeta: Etiqueta y Número de Pilar
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: itemColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: itemColor.withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Text(
                                        item['etiqueta'],
                                        style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: itemColor,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '#${item['pilar']}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white24,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // Ícono ilustrativo en círculo luminoso
                                Center(
                                  child: Container(
                                    width: 82,
                                    height: 82,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          itemColor.withValues(alpha: 0.35),
                                          itemColor.withValues(alpha: 0.08),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: itemColor.withValues(alpha: 0.5),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: itemColor.withValues(alpha: 0.25),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      item['icono'] as IconData,
                                      size: 44,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Título principal
                                Text(
                                  item['titulo'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Subtítulo
                                Text(
                                  item['subtitulo'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: itemColor,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Párrafo destacado
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Text(
                                    item['destacado'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      color: Colors.white.withValues(alpha: 0.88),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Bullets con viñetas temáticas
                                ...puntos.map(
                                  (punto) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.only(top: 3, right: 8),
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: itemColor.withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.check_rounded,
                                            size: 11,
                                            color: itemColor,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            punto,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.white70,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Insignia de Valor en la base de la tarjeta
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: itemColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: itemColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.verified_rounded,
                                          size: 12,
                                          color: itemColor,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          item['insignia'],
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: itemColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Indicador de Progreso por Pasos (Pills animados)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _tarjetasGuia.length,
                  (index) {
                    final bool activo = _paginaActual == index;
                    final Color dotColor = _tarjetasGuia[index]['colorTema'] as Color;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: activo ? 28 : 8,
                      decoration: BoxDecoration(
                        color: activo ? dotColor : Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: activo
                            ? [
                                BoxShadow(
                                  color: dotColor.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Botonera de Navegación Inferior
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Row(
                  children: [
                    if (_paginaActual > 0)
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: () {
                            _controladorPagina.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Anterior',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    if (_paginaActual > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: _avanzarOFinalizar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _colorRuby,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 4,
                          shadowColor: _colorRuby.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Icon(
                          _paginaActual == _tarjetasGuia.length - 1
                              ? Icons.rocket_launch_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18,
                          color: const Color(0xFFFFD54F),
                        ),
                        label: Text(
                          _paginaActual == _tarjetasGuia.length - 1
                              ? '¡Comenzar ahora!'
                              : 'Siguiente',
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
