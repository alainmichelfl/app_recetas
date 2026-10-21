import 'package:flutter/material.dart';

/// Esqueleto visual con animación de pulso sutil (Shimmer Skeleton)
/// para evitar saltos o parpadeos en blanco mientras descargan las fotografías gastronómicas.
class WidgetShimmerEsqueleto extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final IconData? icono;

  const WidgetShimmerEsqueleto({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 10,
    this.icono = Icons.restaurant_menu_rounded,
  });

  @override
  State<WidgetShimmerEsqueleto> createState() => _WidgetShimmerEsqueletoState();
}

class _WidgetShimmerEsqueletoState extends State<WidgetShimmerEsqueleto>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animacion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);

    _animacion = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animacion,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade200.withValues(alpha: _animacion.value),
                Colors.orange.shade50.withValues(alpha: _animacion.value * 0.7),
                Colors.grey.shade200.withValues(alpha: _animacion.value),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Icon(
              widget.icono,
              size: (widget.height != null && widget.height! < 70) ? 22 : 36,
              color: Colors.black12,
            ),
          ),
        );
      },
    );
  }
}
