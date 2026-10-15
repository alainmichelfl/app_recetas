import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'tipos_cocina.dart';

/// Widget interactivo de baraja deslizable (estilo Tinder culinario).
/// Permite al usuario deslizar a la derecha si le gusta un tipo de cocina,
/// o a la izquierda si prefiere pasar / omitirla.
class WidgetDeslizadorCocinas extends StatefulWidget {
  final List<String> seleccionInicial;
  final ValueChanged<List<String>> onSeleccionCambiada;

  const WidgetDeslizadorCocinas({
    super.key,
    required this.seleccionInicial,
    required this.onSeleccionCambiada,
  });

  @override
  State<WidgetDeslizadorCocinas> createState() => _WidgetDeslizadorCocinasState();
}

class _WidgetDeslizadorCocinasState extends State<WidgetDeslizadorCocinas>
    with SingleTickerProviderStateMixin {
  late final List<String> _baraja;
  late List<String> _seleccionadas;

  int _indiceActual = 0;
  Offset _dragOffset = Offset.zero;
  final List<Map<String, dynamic>> _historial = [];

  late AnimationController _animController;
  Animation<Offset>? _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _baraja = List<String>.from(TiposCocina.listaDeslizables);
    _seleccionadas = List<String>.from(
      widget.seleccionInicial.where((c) => c != TiposCocina.todas),
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _animController.addListener(() {
      if (_offsetAnimation != null) {
        setState(() => _dragOffset = _offsetAnimation!.value);
      }
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animController.reset();
        _dragOffset = Offset.zero;
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _notificarCambio() {
    final normalizadas = TiposCocina.normalizar(_seleccionadas);
    widget.onSeleccionCambiada(normalizadas);
  }

  void _deslizar(bool leGusta) {
    if (_indiceActual >= _baraja.length || _animController.isAnimating) return;

    final cocinaActual = _baraja[_indiceActual];
    final bool estabaAntes = _seleccionadas.contains(cocinaActual);

    // Guardar para deshacer
    _historial.add({
      'cocina': cocinaActual,
      'gusto': leGusta,
      'estabaAntes': estabaAntes,
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final targetX = leGusta ? screenWidth * 1.3 : -screenWidth * 1.3;

    _offsetAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset(targetX, _dragOffset.dy),
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward().then((_) {
      setState(() {
        if (leGusta) {
          if (!_seleccionadas.contains(cocinaActual)) {
            _seleccionadas.add(cocinaActual);
          }
        } else {
          _seleccionadas.remove(cocinaActual);
        }
        _indiceActual++;
      });
      _notificarCambio();
    });
  }

  void _deshacer() {
    if (_historial.isEmpty || _animController.isAnimating) return;

    final ultimo = _historial.removeLast();
    final String cocina = ultimo['cocina'] as String;
    final bool estabaAntes = ultimo['estabaAntes'] as bool;

    setState(() {
      _indiceActual = math.max(0, _indiceActual - 1);
      if (estabaAntes) {
        if (!_seleccionadas.contains(cocina)) _seleccionadas.add(cocina);
      } else {
        _seleccionadas.remove(cocina);
      }
    });
    _notificarCambio();
  }

  void _reiniciarBaraja() {
    setState(() {
      _indiceActual = 0;
      _dragOffset = Offset.zero;
      _historial.clear();
    });
  }

  LinearGradient _gradientePorCocina(String cocina) {
    switch (cocina) {
      case TiposCocina.mexicana:
        return LinearGradient(
          colors: [Colors.green.shade800, Colors.red.shade700],
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
          colors: [Colors.red.shade800, Colors.grey.shade900],
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
      default:
        return LinearGradient(
          colors: [Colors.blueGrey.shade800, Colors.teal.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool terminadas = _indiceActual >= _baraja.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicador de progreso
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                terminadas
                    ? '🎉 ¡Completaste la baraja!'
                    : 'Cocina ${_indiceActual + 1} de ${_baraja.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              Text(
                '❤️ ${_seleccionadas.length} seleccionadas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Área de tarjetas
        SizedBox(
          height: 320,
          child: terminadas ? _construirPantallaFin() : _construirPilaTarjetas(),
        ),

        const SizedBox(height: 14),

        // Botones de acción inferiores
        if (!terminadas)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botón PASO / NO ME GUSTA
              _botonCircular(
                icono: Icons.close_rounded,
                colorFondo: Colors.red.shade50,
                colorIcono: Colors.red.shade700,
                borde: Colors.red.shade200,
                tooltip: 'Paso (Deslizar izquierda)',
                size: 54,
                iconoSize: 28,
                onTap: () => _deslizar(false),
              ),
              const SizedBox(width: 20),

              // Botón DESHACER
              _botonCircular(
                icono: Icons.undo_rounded,
                colorFondo: Colors.grey.shade100,
                colorIcono: _historial.isNotEmpty ? Colors.blueGrey.shade700 : Colors.grey.shade400,
                borde: Colors.grey.shade300,
                tooltip: 'Deshacer anterior',
                size: 44,
                iconoSize: 22,
                onTap: _historial.isNotEmpty ? _deshacer : null,
              ),
              const SizedBox(width: 20),

              // Botón ME GUSTA
              _botonCircular(
                icono: Icons.favorite_rounded,
                colorFondo: Colors.green.shade50,
                colorIcono: Colors.green.shade700,
                borde: Colors.green.shade200,
                tooltip: '¡Me encanta! (Deslizar derecha)',
                size: 54,
                iconoSize: 28,
                onTap: () => _deslizar(true),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _reiniciarBaraja,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Volver a deslizar tarjetas'),
                style: TextButton.styleFrom(foregroundColor: Colors.teal.shade800),
              ),
            ],
          ),
      ],
    );
  }

  Widget _construirPilaTarjetas() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Tarjeta siguiente (debajo, efecto de profundidad 3D)
        if (_indiceActual + 1 < _baraja.length)
          Transform.scale(
            scale: 0.94,
            child: Transform.translate(
              offset: const Offset(0, 10),
              child: Opacity(
                opacity: 0.85,
                child: _construirTarjetaContenido(_baraja[_indiceActual + 1]),
              ),
            ),
          ),

        // Tarjeta actual superior interactiva
        GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _dragOffset += details.delta;
            });
          },
          onPanEnd: (details) {
            final dx = _dragOffset.dx;
            final vx = details.velocity.pixelsPerSecond.dx;

            if (dx > 90 || vx > 400) {
              _deslizar(true);
            } else if (dx < -90 || vx < -400) {
              _deslizar(false);
            } else {
              // Resorte de regreso al centro
              _offsetAnimation = Tween<Offset>(
                begin: _dragOffset,
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: _animController, curve: Curves.elasticOut));
              _animController.forward(from: 0.0);
            }
          },
          child: Transform.translate(
            offset: _dragOffset,
            child: Transform.rotate(
              angle: (_dragOffset.dx / 300) * 0.25,
              child: Stack(
                children: [
                  _construirTarjetaContenido(_baraja[_indiceActual]),
                  // Estampilla ME GUSTA
                  if (_dragOffset.dx > 25)
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Transform.rotate(
                        angle: -0.2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600.withValues(
                              alpha: (_dragOffset.dx / 100).clamp(0.0, 0.95),
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite, color: Colors.white, size: 20),
                              SizedBox(width: 6),
                              Text(
                                '¡ME GUSTA!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Estampilla PASO
                  if (_dragOffset.dx < -25)
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Transform.rotate(
                        angle: 0.2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600.withValues(
                              alpha: (-_dragOffset.dx / 100).clamp(0.0, 0.95),
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'PASO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.close, color: Colors.white, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirTarjetaContenido(String cocina) {
    final icono = TiposCocina.iconos[cocina] ?? '🍽️';
    final descripcion = TiposCocina.descripciones[cocina] ?? '';
    final platillos = TiposCocina.platillosEmblematicos[cocina] ?? [];
    final bool yaGustada = _seleccionadas.contains(cocina);

    return Container(
      width: double.infinity,
      height: 310,
      decoration: BoxDecoration(
        gradient: _gradientePorCocina(cocina),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Marca de agua de fondo
          Positioned(
            right: -10,
            bottom: -20,
            child: Opacity(
              opacity: 0.12,
              child: Text(
                icono,
                style: const TextStyle(fontSize: 140),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera de la tarjeta con bandera y badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        icono,
                        style: const TextStyle(fontSize: 34),
                      ),
                    ),
                    if (yaGustada)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'En tus favoritas',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Título de la cocina
                Text(
                  'Cocina $cocina',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),

                // Descripción
                Text(
                  descripcion,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),

                // Platillos emblemáticos
                const Text(
                  'Platillos icónicos:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: platillos.take(4).map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white30, width: 0.8),
                      ),
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '👈 Desliza a la izquierda: Paso  •  Derecha: Me gusta 👉',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirPantallaFin() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.teal.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.celebration_rounded, size: 48, color: Colors.teal),
          const SizedBox(height: 8),
          const Text(
            '¡Terminaste de calificar!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _seleccionadas.isEmpty
                ? 'No seleccionaste ninguna en particular. Se sugerirán platillos variados del mundo.'
                : 'Elegiste ${_seleccionadas.length} cocinas como tus favoritas:',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          if (_seleccionadas.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: _seleccionadas.map((c) {
                final icono = TiposCocina.iconos[c] ?? '🍽️';
                return Chip(
                  avatar: Text(icono, style: const TextStyle(fontSize: 13)),
                  label: Text(
                    c,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: Colors.teal.shade50,
                  side: BorderSide(color: Colors.teal.shade200),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _reiniciarBaraja,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Volver a deslizar desde el principio'),
          ),
        ],
      ),
    );
  }

  Widget _botonCircular({
    required IconData icono,
    required Color colorFondo,
    required Color colorIcono,
    required Color borde,
    required String tooltip,
    required double size,
    required double iconoSize,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colorFondo,
        shape: CircleBorder(side: BorderSide(color: borde, width: 1.5)),
        elevation: onTap != null ? 3 : 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Icon(icono, color: colorIcono, size: iconoSize),
            ),
          ),
        ),
      ),
    );
  }
}
