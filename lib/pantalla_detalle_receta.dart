import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pantalla_modo_cocina.dart';
import 'pantalla_cotizador.dart';
import 'servicio_despensa.dart';
import 'servicio_historial_cocina.dart';
import 'servicio_recetas.dart';
import 'servicio_admin.dart';
import 'servicio_copiloto_cocina.dart';
import 'servicio_sommelier.dart';

class PantallaDetalleReceta extends StatefulWidget {
  final int idReceta;
  final String titulo;
  final String descripcion;
  final String? imagenUrl;

  const PantallaDetalleReceta({
    super.key,
    required this.idReceta,
    required this.titulo,
    required this.descripcion,
    this.imagenUrl,
  });

  @override
  State<PantallaDetalleReceta> createState() => _PantallaDetalleRecetaState();
}

class _PantallaDetalleRecetaState extends State<PantallaDetalleReceta> {
  final Color naranjaZanahoria = const Color(0xFFF57C00);
  final Color rojoJitomate = const Color(0xFFD32F2F);

  int porcionesOriginales = 1;
  int porcionesActuales = 1;
  double multiplicador = 1.0;
  RegistroCocina? _registroCocina;
  String? _textoCargado;
  String? _recipeUserId;

  MaridajeReceta? _maridaje;
  int _tabMaridaje = 0; // 0: Vino, 1: Destilado, 2: Mocktail
  bool _cargandoSommelierIA = false;

  bool get _puedeEliminar =>
      ServicioAdmin.esAdmin() ||
      (_recipeUserId != null &&
          _recipeUserId == Supabase.instance.client.auth.currentUser?.id);

  @override
  void initState() {
    super.initState();
    _extraerPorciones();
    _inicializarDatosReceta();
    _verificarPermisosYReceta();
    _cargarEstadoCocinada(mostrarAvisoAlEntrar: true);
  }

  Future<void> _verificarPermisosYReceta() async {
    if (widget.idReceta > 0) {
      try {
        final res = await Supabase.instance.client
            .from('recetas')
            .select('user_id')
            .eq('id_receta', widget.idReceta)
            .maybeSingle();
        if (res != null && mounted) {
          setState(() {
            _recipeUserId = res['user_id']?.toString();
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _inicializarDatosReceta() async {
    final bool tieneIngredientes = RegExp(
      r'(?:📝\s*)?ingredientes\s*:?',
      caseSensitive: false,
    ).hasMatch(widget.descripcion);
    final bool tieneInstrucciones = RegExp(
      r'(?:🍳\s*)?(?:instrucciones|preparaci[oó]n|elaboraci[oó]n|pasos)\s*:?',
      caseSensitive: false,
    ).hasMatch(widget.descripcion);

    // Si le faltan ingredientes o instrucciones en el texto y tenemos idReceta válido, consultar Supabase
    if ((!tieneIngredientes || !tieneInstrucciones) && widget.idReceta > 0) {
      try {
        final resReceta = await Supabase.instance.client
            .from('recetas')
            .select(
              'descripcion, instrucciones, calorias, macros, tipo_comida, porciones, tiempo_preparacion',
            )
            .eq('id_receta', widget.idReceta)
            .maybeSingle();

        final resDetalle = await Supabase.instance.client
            .from('receta_detalle')
            .select(
              'cantidad, unidad_medida, ingredientes_genericos(nombre_estandar)',
            )
            .eq('id_receta', widget.idReceta);

        if (resReceta != null && mounted) {
          String descDb = resReceta['descripcion']?.toString() ?? '';
          if (RegExp(
            r'(?:📝\s*)?ingredientes\s*:?',
            caseSensitive: false,
          ).hasMatch(descDb)) {
            setState(() {
              _textoCargado = descDb;
            });
            _extraerPorciones();
            return;
          }

          // Ensamblar dinámicamente si la base de datos tenía datos relacionales
          final sb = StringBuffer();
          final porc = resReceta['porciones'] ?? porcionesOriginales;
          sb.writeln('PORCIONES: $porc');
          if (resReceta['calorias'] != null) {
            sb.writeln('CALORÍAS: ${resReceta['calorias']} kcal');
          }
          if (resReceta['macros'] != null &&
              resReceta['macros'].toString().isNotEmpty) {
            sb.writeln('MACROS: ${resReceta['macros']}');
          }
          if (resReceta['tipo_comida'] != null) {
            sb.writeln('TIPO: ${resReceta['tipo_comida']}');
          }
          if (resReceta['tiempo_preparacion'] != null &&
              resReceta['tiempo_preparacion'] != 'No especificado') {
            sb.writeln('TIEMPO: ${resReceta['tiempo_preparacion']}');
          }

          sb.writeln('\n📝 INGREDIENTES:');
          if (resDetalle.isNotEmpty) {
            for (var d in resDetalle) {
              final nom =
                  d['ingredientes_genericos']?['nombre_estandar'] ??
                  'Ingrediente';
              final cant = d['cantidad'];
              final uni = d['unidad_medida'] ?? '';
              sb.writeln('- $cant $uni $nom');
            }
          }

          sb.writeln('\n🍳 INSTRUCCIONES:');
          final inst = resReceta['instrucciones'] ?? descDb;
          sb.writeln(
            inst.toString().isNotEmpty
                ? inst
                : 'Sigue los pasos tradicionales para preparar este platillo.',
          );

          setState(() {
            _textoCargado = sb.toString();
          });
          _extraerPorciones();
        }
      } catch (e) {
        debugPrint('Error al cargar datos adicionales de receta: $e');
      }
    }
  }

  Future<void> _cargarEstadoCocinada({bool mostrarAvisoAlEntrar = false}) async {
    final reg = await ServicioHistorialCocina.obtenerRegistro(
      widget.idReceta,
      titulo: widget.titulo,
    );
    if (mounted) {
      setState(() {
        _registroCocina = reg;
      });

      if (mostrarAvisoAlEntrar && reg != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.soup_kitchen,
                      color: Colors.lightGreenAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '¡Aviso! Ya preparaste esta receta anteriormente (${reg.veces} ${reg.veces == 1 ? "vez" : "veces"}). 👨‍🍳✨',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF1B5E20),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
        });
      }
    }
  }

  Future<void> _confirmarEliminarReceta() async {
    final bool esAdmin = ServicioAdmin.esAdmin();
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
        content: Text(
          esAdmin
              ? '¿Eliminar definitivamente "${widget.titulo}" del sistema? Como administrador, esta receta se borrará para todos los usuarios.'
              : '¿Estás seguro de eliminar tu receta "${widget.titulo}"? Esta acción no se puede deshacer.',
        ),
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
            child: const Text('Eliminar Definitivamente'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final nav = Navigator.of(context);
      final ok = await ServicioRecetas.eliminarReceta(widget.idReceta);
      if (ok) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Receta "${widget.titulo}" eliminada correctamente.'),
            backgroundColor: Colors.black87,
          ),
        );
        nav.pop(true);
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo eliminar la receta. Verifica permisos en Supabase o conexión.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatearFecha(DateTime dt) {
    final dia = dt.day.toString().padLeft(2, '0');
    final mes = dt.month.toString().padLeft(2, '0');
    final anio = dt.year;
    return '$dia/$mes/$anio';
  }

  void _extraerPorciones() {
    final texto = _textoCargado ?? widget.descripcion;
    final regex = RegExp(r'PORCIONES:\s*(\d+)', caseSensitive: false);
    final match = regex.firstMatch(texto);
    if (match != null && match.groupCount >= 1) {
      porcionesOriginales = int.tryParse(match.group(1)!) ?? 1;
    } else {
      porcionesOriginales = 1;
    }
    porcionesActuales = porcionesOriginales;
  }

  void cambiarPorciones(int cambio) {
    setState(() {
      if (porcionesActuales + cambio > 0) {
        porcionesActuales += cambio;
        multiplicador = porcionesActuales / porcionesOriginales;
      }
    });
  }

  String _ajustarCantidadesEnTexto(String textoOriginal) {
    if (multiplicador == 1.0) return textoOriginal;

    String texto = textoOriginal.replaceFirst(
      RegExp(r'PORCIONES:\s*\d+', caseSensitive: false),
      'PORCIONES: $porcionesActuales (Originalmente $porcionesOriginales)',
    );

    final matchIng = RegExp(
      r'(?:📝\s*)?INGREDIENTES\s*:?',
      caseSensitive: false,
    ).firstMatch(texto);

    if (matchIng == null) return texto;

    final cabecera = texto.substring(0, matchIng.start);
    final resto = texto.substring(matchIng.end);

    final matchInst = RegExp(
      r'(?:🍳\s*)?(?:INSTRUCCIONES|PREPARACI[OÓ]N|PASOS|ELABORACI[OÓ]N)\s*:?',
      caseSensitive: false,
    ).firstMatch(resto);

    final ingredientesOriginales = matchInst != null
        ? resto.substring(0, matchInst.start)
        : resto;
    final instrucciones = matchInst != null
        ? '\n\n🍳 INSTRUCCIONES:\n${resto.substring(matchInst.end).trim()}'
        : '';

    final regexLinea = RegExp(
      r'^(\s*-\s*)(\d+(?:[\.,]\d+)?(?:/\d+)?)(.*)',
      multiLine: true,
    );

    String ingredientesNuevos = ingredientesOriginales.replaceAllMapped(regexLinea, (
      match,
    ) {
      String prefijo = match.group(1) ?? '- ';
      String numeroStr = match.group(2) ?? '';
      String sufijo = match.group(3) ?? '';

      double valor = 0;

      if (numeroStr.contains('/')) {
        final frac = numeroStr.split('/');
        final n = double.tryParse(frac[0]) ?? 0;
        final d = double.tryParse(frac[1]) ?? 1;
        valor = d != 0 ? n / d : 0;
      } else {
        valor = double.tryParse(numeroStr.replaceAll(',', '.')) ?? 0;
      }

      if (valor > 0) {
        double calculado = valor * multiplicador;
        String nuevoNum = calculado == calculado.roundToDouble()
            ? calculado.toInt().toString()
            : calculado.toStringAsFixed(1);
        return '$prefijo$nuevoNum$sufijo';
      }

      return match.group(0)!;
    });

    return '${cabecera.trim()}\n\n📝 INGREDIENTES:\n${ingredientesNuevos.trim()}$instrucciones';
  }

  @override
  Widget build(BuildContext context) {
    final textoBase = _textoCargado ?? widget.descripcion;
    String textoMostrar = _ajustarCantidadesEnTexto(textoBase);

    // 💡 LÓGICA DE SEPARACIÓN VISUAL CON MACROS Y CALORÍAS INCLUIDAS
    String bloqueNutricional = "";
    String bloqueIngredientes = "";
    String bloqueInstrucciones = "";

    final matchIng = RegExp(
      r'(?:📝\s*)?INGREDIENTES\s*:?',
      caseSensitive: false,
    ).firstMatch(textoMostrar);

    if (matchIng != null) {
      bloqueNutricional = textoMostrar.substring(0, matchIng.start).trim();
      final resto = textoMostrar.substring(matchIng.end);

      final matchInst = RegExp(
        r'(?:🍳\s*)?(?:INSTRUCCIONES|PREPARACI[OÓ]N|PASOS|ELABORACI[OÓ]N)\s*:?',
        caseSensitive: false,
      ).firstMatch(resto);

      if (matchInst != null) {
        bloqueIngredientes = resto.substring(0, matchInst.start).trim();
        bloqueInstrucciones = resto.substring(matchInst.end).trim();
      } else {
        bloqueIngredientes = resto.trim();
      }
    } else {
      bloqueIngredientes = textoMostrar;
    }

    // Limpiamos la palabra "PORCIONES:" del texto de macros porque ya tenemos nuestro widget interactivo
    bloqueNutricional = bloqueNutricional
        .split('\n')
        .where((l) => !l.toLowerCase().contains('porciones:'))
        .join('\n')
        .trim();

    // Convertir ingredientes en lista
    List<String> listaIngredientes = bloqueIngredientes
        .split('\n')
        .where(
          (l) => l.trim().isNotEmpty && !l.toLowerCase().contains('porciones:'),
        )
        .toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 🖼️ CABECERA TIPO REVISTA
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            backgroundColor: rojoJitomate,
            foregroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.45),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: 'Regresar a recetas',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _registroCocina != null
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  color: _registroCocina != null
                      ? Colors.lightGreenAccent
                      : Colors.white,
                ),
                tooltip: _registroCocina != null
                    ? '¡Ya preparada ${_registroCocina!.veces} ${_registroCocina!.veces == 1 ? "vez" : "veces"}! (Toca para volver a marcar)'
                    : '¡Cociné esta receta! (Descontar de despensa)',
                onPressed: _marcarCocinadaYDescontar,
              ),
              if (_puedeEliminar)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: ServicioAdmin.esAdmin()
                      ? 'Eliminar receta (Administrador)'
                      : 'Eliminar mi receta',
                  onPressed: _confirmarEliminarReceta,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
                textAlign: TextAlign.center,
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  widget.imagenUrl != null && widget.imagenUrl!.isNotEmpty
                      ? Image.network(widget.imagenUrl!, fit: BoxFit.cover)
                      : Container(
                          color: naranjaZanahoria.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.restaurant,
                            size: 80,
                            color: naranjaZanahoria,
                          ),
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                        stops: [0.0, 0.4],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 📄 CONTENIDO DE LA RECETA
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🍳 BANNER DE RECETA YA COCINADA / PREPARADA
                  if (_registroCocina != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.green.shade400,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.shade600,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.soup_kitchen,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      '¡Ya preparaste esta receta! 👨‍🍳✨',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1B5E20),
                                      ),
                                    ),
                                    if (_registroCocina!.veces > 1) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade700,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          '${_registroCocina!.veces} veces',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Última preparación: ${_formatearFecha(_registroCocina!.fecha)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 📊 TARJETA DE INFORMACIÓN NUTRICIONAL (Calorías, macros, tiempo)
                  if (bloqueNutricional.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.teal.shade700,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              bloqueNutricional,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: Colors.teal.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 🧑‍🍳 CONTROLADOR DE PORCIONES
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              color: naranjaZanahoria,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Porciones',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: rojoJitomate,
                                size: 30,
                              ),
                              onPressed: () => cambiarPorciones(-1),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: rojoJitomate.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$porcionesActuales',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: rojoJitomate,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add_circle_outline,
                                color: rojoJitomate,
                                size: 30,
                              ),
                              onPressed: () => cambiarPorciones(1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 💰 BOTÓN DE COTIZAR
                  SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PantallaCotizador(
                              idReceta: widget.idReceta,
                              titulo: widget.titulo,
                              multiplicador: multiplicador,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.shopping_cart_checkout, size: 24),
                      label: const Text(
                        'Cotizar Ingredientes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ),

                  // 🤖 COPILOTO INTELIGENTE (THERMOMIX & AIR FRYER)
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF004D40),
                          Color(0xFF00897B),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF004D40).withValues(alpha: 0.25),
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
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('🤖', style: TextStyle(fontSize: 24)),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Modo Thermomix & Air Fryer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Adapta tiempos, temperaturas y velocidades',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF004D40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () => _abrirModalCopilotoElectrodomesticos(
                            ingredientes: listaIngredientes,
                            instrucciones: bloqueInstrucciones,
                          ),
                          child: const Text(
                            'Adaptar ⚡',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),

                  // 📝 SECCIÓN INGREDIENTES
                  Row(
                    children: [
                      Icon(Icons.format_list_bulleted, color: rojoJitomate),
                      const SizedBox(width: 10),
                      const Text(
                        'Ingredientes',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  if (multiplicador != 1.0)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        '⚠️ Cantidades ajustadas para $porcionesActuales porciones',
                        style: TextStyle(
                          color: naranjaZanahoria,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: listaIngredientes.map((ingrediente) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: naranjaZanahoria.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  ingrediente
                                      .replaceFirst(RegExp(r'^[\-\*]\s*'), '')
                                      .trim(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 35),

                  // 🍳 SECCIÓN PREPARACIÓN
                  if (bloqueInstrucciones.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.soup_kitchen, color: rojoJitomate),
                        const SizedBox(width: 10),
                        const Text(
                          'Preparación',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      bloqueInstrucciones,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ],

                  // 🍷 SOMMELIER IA & CAVA VIRTUAL
                  const SizedBox(height: 35),
                  _construirTarjetaSommelier(listaIngredientes),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // 🔥 BOTÓN FLOTANTE
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_registroCocina != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B5E20),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.lightGreenAccent,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '¡Ya la preparaste ${_registroCocina!.veces} ${_registroCocina!.veces == 1 ? "vez" : "veces"}!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: 60,
            child: FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PantallaModoCocina(
                      recetaInstrucciones: textoMostrar,
                      idReceta: widget.idReceta,
                      titulo: widget.titulo,
                      multiplicador: multiplicador,
                      listaIngredientes: listaIngredientes,
                      textoInstrucciones: bloqueInstrucciones,
                    ),
                  ),
                );
                if (mounted) _cargarEstadoCocinada();
              },
              backgroundColor: _registroCocina != null
                  ? Colors.green.shade800
                  : rojoJitomate,
              elevation: 6,
              icon: Icon(
                _registroCocina != null
                    ? Icons.soup_kitchen
                    : Icons.local_fire_department,
                color: Colors.white,
                size: 28,
              ),
              label: Text(
                _registroCocina != null
                    ? '¡Volver a Cocinar Receta!'
                    : '¡Entrar al Modo Cocina!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _marcarCocinadaYDescontar() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.green),
            SizedBox(width: 8),
            Text('¡Cociné esta receta! 👨‍🍳🔥'),
          ],
        ),
        content: Text(
          '¿Deseas registrar "${widget.titulo}" como cocinada y descontar automáticamente '
          'sus ingredientes ($porcionesActuales porciones) de tu Despensa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check),
            label: const Text('Sí, registrar y descontar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    // 🍳 Registrar en historial de recetas cocinadas
    final nuevoRegistro = await ServicioHistorialCocina.marcarComoCocinada(
      idReceta: widget.idReceta,
      titulo: widget.titulo,
      origen: 'detalle',
    );
    if (mounted) {
      setState(() => _registroCocina = nuevoRegistro);
    }

    final descontados = await ServicioDespensa.descontarIngredientesDeReceta(
      idReceta: widget.idReceta,
      descripcionReceta: widget.descripcion,
      multiplicador: multiplicador,
    );

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (descontados.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '¡Listo! Receta guardada como cocinada y se descontaron de tu despensa: ${descontados.join(', ')} 🥫✅',
          ),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            '¡Listo! Receta guardada como cocinada 👨‍🍳✅ (No se encontraron ingredientes coincidentes en despensa).',
          ),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  Future<void> _abrirModalCopilotoElectrodomesticos({
    required List<String> ingredientes,
    required String instrucciones,
  }) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🤖', style: TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Copiloto de Electrodomésticos ⚡',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Adapta con IA a los parámetros exactos de tu equipo',
                          style: TextStyle(fontSize: 12.5, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Opción Thermomix
              _tarjetaSeleccionElectrodomestico(
                icono: '🤖',
                titulo: 'Thermomix (TM5 / TM6 / TM7)',
                descripcion:
                    'Tiempos cortos, velocidad de cuchillas, temperatura Varoma/120°C y giro inverso ↺.',
                colorTema: const Color(0xFF00897B),
                onTap: () {
                  Navigator.pop(ctx);
                  _procesarAdaptacionIA(
                    modo: ModoElectrodomestico.thermomix,
                    ingredientes: ingredientes,
                    instrucciones: instrucciones,
                  );
                },
              ),
              const SizedBox(height: 12),

              // Opción Air Fryer
              _tarjetaSeleccionElectrodomestico(
                icono: '🍟',
                titulo: 'Air Fryer (Freidora de Aire)',
                descripcion:
                    'Temperatura de convección, tiempos reducidos y alertas de agitar canastilla.',
                colorTema: const Color(0xFFF57C00),
                onTap: () {
                  Navigator.pop(ctx);
                  _procesarAdaptacionIA(
                    modo: ModoElectrodomestico.airFryer,
                    ingredientes: ingredientes,
                    instrucciones: instrucciones,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tarjetaSeleccionElectrodomestico({
    required String icono,
    required String titulo,
    required String descripcion,
    required Color colorTema,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorTema.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorTema.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorTema.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(icono, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorTema,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    descripcion,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: colorTema),
          ],
        ),
      ),
    );
  }

  Future<void> _procesarAdaptacionIA({
    required ModoElectrodomestico modo,
    required List<String> ingredientes,
    required String instrucciones,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctxDialog) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: modo.colorPrimario),
                const SizedBox(height: 20),
                Text(
                  'El Chef IA está adaptando la receta...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: modo.colorPrimario,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  modo == ModoElectrodomestico.thermomix
                      ? 'Calculando tiempos, velocidades y temperaturas Varoma...'
                      : 'Optimizando temperatura de aire y tiempo de convección...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final resultado = await ServicioCopilotoCocina.adaptarReceta(
        titulo: widget.titulo,
        ingredientes: ingredientes.join('\n'),
        instrucciones: instrucciones,
        modo: modo,
      );

      if (!mounted) return;
      Navigator.pop(context); // Cierra diálogo de carga

      if (resultado != null && resultado.isNotEmpty) {
        _mostrarResultadoAdaptacion(
          modo: modo,
          instruccionesAdaptadas: resultado,
          ingredientes: ingredientes,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No fue posible adaptar la receta con IA en este momento.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarResultadoAdaptacion({
    required ModoElectrodomestico modo,
    required String instruccionesAdaptadas,
    required List<String> ingredientes,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(modo.icono, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receta Adaptada a ${modo.etiqueta.split(' ')[0]}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: modo.colorPrimario,
                          ),
                        ),
                        Text(
                          modo.subtitulo,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    instruccionesAdaptadas,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: modo.colorPrimario,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PantallaModoCocina(
                        recetaInstrucciones: widget.descripcion,
                        idReceta: widget.idReceta,
                        titulo: widget.titulo,
                        multiplicador: multiplicador,
                        listaIngredientes: ingredientes,
                        textoInstrucciones: instruccionesAdaptadas,
                        modoInicial: modo,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.soup_kitchen, size: 24),
                label: Text(
                  '¡Entrar al Modo Cocina ${modo.etiqueta.split(' ')[0]}!',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ───────────── SOMMELIER IA & CAVA VIRTUAL ─────────────
  MaridajeReceta _obtenerMaridaje(List<String> ingredientes) {
    return _maridaje ??
        ServicioSommelier.generarMaridajeHeuristico(
          widget.titulo,
          ingredientes: ingredientes,
          descripcion: widget.descripcion,
        );
  }

  Future<void> _afinarConSommelierIA(List<String> ingredientes) async {
    setState(() => _cargandoSommelierIA = true);
    try {
      final res = await ServicioSommelier.consultarSommelierIA(
        titulo: widget.titulo,
        ingredientes: ingredientes,
        descripcion: widget.descripcion,
      );
      if (mounted) {
        setState(() {
          _maridaje = res;
          _cargandoSommelierIA = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ ¡Sommelier IA afinó el maridaje con éxito! 🍷'),
            backgroundColor: Color(0xFF4A1222),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoSommelierIA = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aviso: Se mantuvo el maridaje de cava ($e)'),
            backgroundColor: Colors.brown,
          ),
        );
      }
    }
  }

  Future<void> _agregarBebidaAlCarrito(String nombreBebida) async {
    final ok = await ServicioSommelier.agregarBebidaAListaCompras(
      nombreBebida,
      cantidad: '1 botella / porción',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '🛒 "$nombreBebida" agregado a tu Lista de Compras'
              : 'Error al agregar la bebida a tu lista',
        ),
        backgroundColor: ok ? const Color(0xFF004D40) : Colors.red,
      ),
    );
  }

  Future<void> _compartirMaridaje(MaridajeReceta m) async {
    final texto = m.resumenParaCompartir(widget.titulo);
    await SharePlus.instance.share(ShareParams(text: texto));
  }

  Widget _construirTarjetaSommelier(List<String> ingredientes) {
    final m = _obtenerMaridaje(ingredientes);

    String descripcionBebidaActual;
    IconData iconoBebidaActual;
    String etiquetaPestana;

    switch (_tabMaridaje) {
      case 1:
        descripcionBebidaActual = m.destilado;
        iconoBebidaActual = Icons.local_bar;
        etiquetaPestana = 'Coctelería & Destilados';
        break;
      case 2:
        descripcionBebidaActual = m.sinAlcohol;
        iconoBebidaActual = Icons.local_drink;
        etiquetaPestana = '0.0% Alcohol · Artesanal';
        break;
      case 0:
      default:
        descripcionBebidaActual = m.vino;
        iconoBebidaActual = Icons.wine_bar;
        etiquetaPestana = 'Cepa & Bodega';
        break;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF230611),
            Color(0xFF3F0F20),
            Color(0xFF5A162D),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF230611).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CABECERA
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                  ),
                ),
                child: const Text('🍷', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Sommelier IA & Cava Virtual',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.share_outlined,
                            color: Color(0xFFE5C158),
                            size: 20,
                          ),
                          tooltip: 'Compartir maridaje',
                          onPressed: () => _compartirMaridaje(m),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Perfil: ${m.categoriaPerfil}',
                      style: const TextStyle(
                        color: Color(0xFFE5C158),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // PESTAÑAS SELECTORAS (Vino, Destilado, Mocktail)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _construirPestana(0, '🍷 Vino', _tabMaridaje == 0),
                _construirPestana(1, '🥃 Destilado', _tabMaridaje == 1),
                _construirPestana(2, '🍹 Sin alcohol', _tabMaridaje == 2),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // TARJETA DE LA BEBIDA SELECCIONADA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(iconoBebidaActual, color: const Color(0xFFE5C158), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      etiquetaPestana,
                      style: const TextStyle(
                        color: Color(0xFFE5C158),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  descripcionBebidaActual,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ARMONÍA EN BOCA
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎯', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Armonía del maridaje:',
                        style: TextStyle(
                          color: Color(0xFFE5C158),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.notasArmonia,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // SERVICIO & COPA
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('❄️', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      m.temperaturaServicio,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🥂', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      m.tipoCopa,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // BOTONES DE ACCIÓN
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF230611),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    final bebidaAComprar = _tabMaridaje == 0
                        ? m.vino
                        : (_tabMaridaje == 1 ? m.destilado : m.sinAlcohol);
                    _agregarBebidaAlCarrito(bebidaAComprar);
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text(
                    'Comprar Bebida 🛒',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                onPressed: _cargandoSommelierIA
                    ? null
                    : () => _afinarConSommelierIA(ingredientes),
                icon: _cargandoSommelierIA
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFE5C158)),
                label: Text(
                  _cargandoSommelierIA ? 'Afinando...' : 'Afinar IA ✨',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirPestana(int indice, String label, bool activa) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabMaridaje = indice),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: activa
                ? const Color(0xFFD4AF37)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: activa ? const Color(0xFF230611) : Colors.white70,
              fontSize: 12,
              fontWeight: activa ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
