import 'package:flutter/material.dart';

import 'perfiles_nutricionales.dart';
import 'tipos_cocina.dart';
import 'widget_deslizador_cocinas.dart';
import 'utensilios_cocina.dart';
import 'servicio_preferencias.dart';
import 'servicio_perfil_usuario.dart';
import 'menu_lateral.dart';
import 'dialogo_contacto_soporte.dart';
import 'main.dart';

class PantallaPreferencias extends StatefulWidget {
  const PantallaPreferencias({super.key});

  @override
  State<PantallaPreferencias> createState() => _PantallaPreferenciasState();
}

class _PantallaPreferenciasState extends State<PantallaPreferencias> {
  // Variables de estado para las preferencias
  String objetivoSeleccionado = PerfilesNutricionales.mantenimiento;
  List<String> estilosSeleccionados = [PerfilesNutricionales.libre];
  List<String> tiposCocinaSeleccionados = [TiposCocina.todas];
  List<String> utensiliosSeleccionados = UtensiliosCocina.porDefecto;
  bool _modoTarjetasDeslizables = true;
  double presupuestoSemanal = 1500;
  int porcionesDefecto = 2;
  String superFavorito = 'Walmart';
  final TextEditingController alergiasController = TextEditingController();
  bool notificacionesActivas = true;
  bool alertaDescongeladoActiva = true;
  bool alertaLunchEscolarActiva = true;
  bool alertaFrescuraActiva = true;
  String horaDescongelado = '20:00';
  String horaLunchEscolar = '20:30';
  bool guardando = false;
  bool cargando = true;

  // 🍎 OBJETIVOS Y ESTILOS (fuente única compartida con Planeador, Salud y Chef)
  final List<String> opcionesObjetivo = PerfilesNutricionales.objetivos;
  final List<String> opcionesEstilo = PerfilesNutricionales.estilos;
  final List<String> opcionesTiposCocina = TiposCocina.lista;

  // 🛒 SUPERMERCADOS EN FORMATO DE BOTÓN
  final List<String> opcionesSuper = [
    'Ninguno',
    'Walmart',
    'Soriana',
    'La Comer',
    'Central de Abasto',
    'Costco',
    'Sam\'s Club',
  ];

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  /// "Libre" es exclusivo: al elegir otro estilo se quita, y si no queda
  /// ninguno vuelve a "Libre".
  void _alternarEstilo(String estilo, bool activo) {
    setState(() {
      final actuales = List<String>.from(estilosSeleccionados);
      if (estilo == PerfilesNutricionales.libre) {
        estilosSeleccionados = [PerfilesNutricionales.libre];
        return;
      }
      if (activo) {
        actuales.add(estilo);
      } else {
        actuales.remove(estilo);
      }
      estilosSeleccionados = PerfilesNutricionales.normalizar(actuales);
    });
  }

  /// "Variada / Todas" es exclusivo: al elegir otro tipo de cocina se quita,
  /// y si no queda ninguno vuelve a "Variada / Todas".
  void _alternarTipoCocina(String tipo, bool activo) {
    setState(() {
      final actuales = List<String>.from(tiposCocinaSeleccionados);
      if (tipo == TiposCocina.todas) {
        tiposCocinaSeleccionados = [TiposCocina.todas];
        return;
      }
      if (activo) {
        actuales.add(tipo);
      } else {
        actuales.remove(tipo);
      }
      tiposCocinaSeleccionados = TiposCocina.normalizar(actuales);
    });
  }

  Future<void> _cargarPreferencias() async {
    setState(() => cargando = true);
    try {
      final prefs = await ServicioPreferencias.obtenerPreferencias();
      if (!mounted) return;
      setState(() {
        objetivoSeleccionado = prefs.objetivo;
        estilosSeleccionados = PerfilesNutricionales.normalizar(prefs.estilos);
        tiposCocinaSeleccionados = TiposCocina.normalizar(prefs.tiposCocina);
        utensiliosSeleccionados = List<String>.from(prefs.utensilios);
        alergiasController.text = prefs.alergias;
        superFavorito = opcionesSuper.contains(prefs.superFavorito)
            ? prefs.superFavorito
            : 'Walmart';
        porcionesDefecto = prefs.porciones.clamp(1, 12);
        presupuestoSemanal = prefs.presupuestoSemanal.clamp(500.0, 5000.0);
        notificacionesActivas = prefs.notificaciones;
        alertaDescongeladoActiva = prefs.alertaDescongelado;
        alertaLunchEscolarActiva = prefs.alertaLunchEscolar;
        alertaFrescuraActiva = prefs.alertaFrescura;
        horaDescongelado = prefs.horaDescongelado;
        horaLunchEscolar = prefs.horaLunchEscolar;
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar preferencias: $e');
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> guardarPreferencias() async {
    setState(() => guardando = true);

    try {
      final prefs = PreferenciasUsuario(
        objetivo: objetivoSeleccionado,
        estilos: estilosSeleccionados,
        tiposCocina: tiposCocinaSeleccionados,
        utensilios: utensiliosSeleccionados,
        alergias: alergiasController.text.trim(),
        superFavorito: superFavorito,
        porciones: porcionesDefecto,
        presupuestoSemanal: presupuestoSemanal,
        notificaciones: notificacionesActivas,
        alertaDescongelado: alertaDescongeladoActiva,
        alertaLunchEscolar: alertaLunchEscolarActiva,
        alertaFrescura: alertaFrescuraActiva,
        horaDescongelado: horaDescongelado,
        horaLunchEscolar: horaLunchEscolar,
      );

      await ServicioPreferencias.guardarPreferencias(prefs);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Tus preferencias se han guardado con éxito! ⚙️'),
          backgroundColor: Colors.blueGrey,
        ),
      );

      Navigator.pop(context, true); // Devuelve true para notificar cambios
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar preferencias: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  void dispose() {
    alergiasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color colorPrincipal = Colors.blueGrey.shade800;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: const MenuLateral(rutaActual: 'preferencias'),
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
          child: Text(
            'Mis Preferencias ⚙️',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: const Color(0xFF1E2022),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueGrey),
            )
          : Builder(
              builder: (context) {
                final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: isLandscape ? 32 : 20, vertical: isLandscape ? 12 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 👤 IDENTIDAD CULINARIA & APODO
                      const Text(
                        '👤 Identidad Culinaria',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.person, color: Color(0xFFD32F2F), size: 26),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '¿Cómo te gustaría que te llamemos?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      ServicioPerfilUsuario.obtenerNombreSincrono(),
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E2022),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  ServicioPerfilUsuario.mostrarDialogoEditarNombre(
                                    context,
                                    alGuardar: () => setState(() {}),
                                  );
                                },
                                icon: const Icon(Icons.edit, size: 14),
                                label: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Cambiar'),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFD32F2F),
                                  side: const BorderSide(color: Color(0xFFD32F2F)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: 24),

                  // 💡 1. PERFIL NUTRICIONAL (DIETA Y ALERGIAS)
                  const Text(
                    '🍎 Perfil Nutricional',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Objetivo Calórico',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            PerfilesNutricionales
                                    .descripcionObjetivo[objetivoSeleccionado] ??
                                '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: opcionesObjetivo.map((objetivo) {
                              final bool seleccionado =
                                  objetivoSeleccionado == objetivo;
                              return ChoiceChip(
                                label: Text(objetivo),
                                selected: seleccionado,
                                selectedColor: colorPrincipal,
                                backgroundColor: Colors.grey.shade200,
                                labelStyle: TextStyle(
                                  color: seleccionado
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: seleccionado
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                onSelected: (bool selected) {
                                  if (selected) {
                                    setState(
                                      () => objetivoSeleccionado = objetivo,
                                    );
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Estilo de Dieta o Condición',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Puedes combinar varios (ej. Vegana + Sin gluten).',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: opcionesEstilo.map((estilo) {
                              final bool seleccionado = estilosSeleccionados
                                  .contains(estilo);
                              return FilterChip(
                                label: Text(estilo),
                                selected: seleccionado,
                                showCheckmark: false,
                                selectedColor: colorPrincipal,
                                backgroundColor: Colors.grey.shade200,
                                labelStyle: TextStyle(
                                  color: seleccionado
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: seleccionado
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                onSelected: (bool selected) =>
                                    _alternarEstilo(estilo, selected),
                              );
                            }).toList(),
                          ),
                          if (estilosSeleccionados.contains(
                            PerfilesNutricionales.bajaEnGrasa,
                          )) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.teal.shade300),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.favorite_outline,
                                    size: 20,
                                    color: Colors.teal.shade800,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '"Baja en grasa" restringe frituras, manteca, mayonesa y empanizados, priorizando cocción al vapor, air fryer y proteínas magras (~20g de grasa diaria). Ideal para salud hepática, vesícula o definición.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.teal.shade900,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (estilosSeleccionados.contains(
                            PerfilesNutricionales.diabetes,
                          )) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Colors.amber.shade900,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '"Apto para diabetes" orienta al Chef y Planeador a elegir opciones con bajo índice glucémico y sin azúcares añadidos. No sustituye la prescripción de tu médico o especialista.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.brown.shade900,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          const Text(
                            'Alergias o evitar ingredientes (Chef IA)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: alergiasController,
                            decoration: InputDecoration(
                              hintText: 'Ej. Mariscos, cacahuates, picante...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(
                                Icons.warning_amber,
                                color: Colors.blueGrey,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 💡 2. COCINAS DEL MUNDO FAVORITAS
                  const Text(
                    '🌮 Tipos de Cocina Favoritos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Gastronomías del Mundo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              // Selector de vista: Tarjetas vs Chips
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () => setState(() => _modoTarjetasDeslizables = true),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: _modoTarjetasDeslizables ? colorPrincipal : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.style,
                                              size: 14,
                                              color: _modoTarjetasDeslizables ? Colors.white : Colors.black87,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Tarjetas 🎴',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: _modoTarjetasDeslizables ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setState(() => _modoTarjetasDeslizables = false),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: !_modoTarjetasDeslizables ? colorPrincipal : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.apps,
                                              size: 14,
                                              color: !_modoTarjetasDeslizables ? Colors.white : Colors.black87,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Chips',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: !_modoTarjetasDeslizables ? Colors.white : Colors.black87,
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
                          const SizedBox(height: 6),
                          Text(
                            _modoTarjetasDeslizables
                                ? '👉 Desliza la tarjeta a la derecha si te gusta, o 👈 a la izquierda para pasar.'
                                : 'Toca los estilos que quieras incluir en tu menú semanal y para el Chef IA.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_modoTarjetasDeslizables)
                            WidgetDeslizadorCocinas(
                              seleccionInicial: tiposCocinaSeleccionados,
                              onSeleccionCambiada: (nuevas) {
                                setState(() {
                                  tiposCocinaSeleccionados = nuevas;
                                });
                              },
                            )
                          else
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: opcionesTiposCocina.map((tipo) {
                                final bool seleccionado =
                                    tiposCocinaSeleccionados.contains(tipo);
                                final icono = TiposCocina.iconos[tipo] ?? '🍽️';
                                return FilterChip(
                                  avatar: Text(
                                    icono,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  label: Text(tipo),
                                  selected: seleccionado,
                                  showCheckmark: false,
                                  selectedColor: colorPrincipal,
                                  backgroundColor: Colors.grey.shade200,
                                  labelStyle: TextStyle(
                                    color: seleccionado
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: seleccionado
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  onSelected: (bool selected) =>
                                      _alternarTipoCocina(tipo, selected),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.teal.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 20,
                                  color: Colors.teal.shade800,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tiposCocinaSeleccionados.contains(TiposCocina.todas)
                                        ? 'Selección actual: Variada / Todas (El Chef IA sugerirá recetas diversas del mundo).'
                                        : 'Selección actual: ${tiposCocinaSeleccionados.join(", ")} (El Chef IA y Planeador priorizarán estas cocinas).',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.teal.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 💡 3. TU COCINA Y UTENSILIOS
                  const Text(
                    '🍳 Tu Cocina y Utensilios',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Electrodomésticos y Equipo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        utensiliosSeleccionados = UtensiliosCocina.catalogo
                                            .map((u) => u.id)
                                            .toList();
                                      });
                                    },
                                    child: const Text('Todos', style: TextStyle(fontSize: 12)),
                                  ),
                                  const Text('•', style: TextStyle(color: Colors.grey)),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        utensiliosSeleccionados = UtensiliosCocina.porDefecto;
                                      });
                                    },
                                    child: const Text('Básicos', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Toca las tarjetas con los utensilios que tienes. El Chef IA adaptará las recetas para que nunca te pida un equipo que no tengas en casa.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final cardWidth = (constraints.maxWidth - 10) / 2;
                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: UtensiliosCocina.catalogo.map((utensilio) {
                                  final bool activo =
                                      utensiliosSeleccionados.contains(utensilio.id);
                                  return SizedBox(
                                    width: cardWidth,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (activo) {
                                              if (utensiliosSeleccionados.length > 1) {
                                                utensiliosSeleccionados.remove(utensilio.id);
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Debes conservar al menos 1 utensilio seleccionado.',
                                                    ),
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                              }
                                            } else {
                                              utensiliosSeleccionados.add(utensilio.id);
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(14),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: activo
                                                ? colorPrincipal.withValues(alpha: 0.08)
                                                : Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: activo
                                                  ? colorPrincipal
                                                  : Colors.grey.shade300,
                                              width: activo ? 2 : 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    utensilio.icono,
                                                    style: const TextStyle(fontSize: 22),
                                                  ),
                                                  Icon(
                                                    activo
                                                        ? Icons.check_circle
                                                        : Icons.radio_button_unchecked,
                                                    size: 18,
                                                    color: activo
                                                        ? colorPrincipal
                                                        : Colors.grey.shade400,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                utensilio.nombre,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: activo
                                                      ? colorPrincipal
                                                      : Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                utensilio.descripcion,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                  height: 1.2,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tips_and_updates_outlined,
                                  size: 20,
                                  color: Colors.amber.shade900,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${utensiliosSeleccionados.length} de ${UtensiliosCocina.catalogo.length} equipos activos. Si seleccionas Freidora de Aire o Thermomix, se habilitará el Copiloto IA con pasos y parámetros programados.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.brown.shade900,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 💡 4. HOGAR Y COMPRAS (SUPERMERCADOS COMO BOTONES)
                  const Text(
                    '🛒 Hogar y Compras',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Supermercado Favorito',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: opcionesSuper.map((supermercado) {
                              final bool seleccionado =
                                  superFavorito == supermercado;
                              return ChoiceChip(
                                label: Text(supermercado),
                                selected: seleccionado,
                                selectedColor: colorPrincipal,
                                backgroundColor: Colors.grey.shade200,
                                labelStyle: TextStyle(
                                  color: seleccionado
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: seleccionado
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                onSelected: (bool selected) {
                                  if (selected) {
                                    setState(
                                      () => superFavorito = supermercado,
                                    );
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Porciones por defecto',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.blueGrey,
                                    ),
                                    onPressed: () {
                                      if (porcionesDefecto > 1) {
                                        setState(() => porcionesDefecto--);
                                      }
                                    },
                                  ),
                                  Text(
                                    '$porcionesDefecto pers.',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.blueGrey,
                                    ),
                                    onPressed: () {
                                      if (porcionesDefecto < 12) {
                                        setState(() => porcionesDefecto++);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 💡 5. FINANZAS
                  const Text(
                    '💰 Finanzas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Presupuesto Semanal Súper',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '\$${presupuestoSemanal.toInt()} MXN',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Slider(
                            value: presupuestoSemanal,
                            min: 500,
                            max: 5000,
                            divisions: 45,
                            activeColor: Colors.green,
                            label: '\$${presupuestoSemanal.toInt()}',
                            onChanged: (val) =>
                                setState(() => presupuestoSemanal = val),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 💡 6. ASISTENTE Y RECORDATORIOS
                  const Text(
                    '🔔 Asistente y Recordatorios',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(
                            Icons.ac_unit_rounded,
                            color: Colors.blueAccent,
                          ),
                          title: Row(
                            children: [
                              const Text(
                                'Alertas para Descongelar',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  final partes = horaDescongelado.split(':');
                                  final h = partes.isNotEmpty ? int.tryParse(partes[0]) ?? 20 : 20;
                                  final m = partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0;
                                  final pick = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(hour: h, minute: m),
                                  );
                                  if (pick != null) {
                                    setState(() {
                                      horaDescongelado =
                                          '${pick.hour.toString().padLeft(2, '0')}:${pick.minute.toString().padLeft(2, '0')}';
                                    });
                                  }
                                },
                                child: Text(
                                  horaDescongelado,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Avisa la noche anterior ($horaDescongelado) si tu comida planeada requiere bajar carne o pollo al refri.',
                            style: const TextStyle(fontSize: 12),
                          ),
                          activeThumbColor: Colors.blueAccent,
                          value: alertaDescongeladoActiva,
                          onChanged: (val) =>
                              setState(() => alertaDescongeladoActiva = val),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: const Icon(
                            Icons.backpack_rounded,
                            color: Color(0xFF00897B),
                          ),
                          title: Row(
                            children: [
                              const Text(
                                'Lunch & Snacks Escolares 🎒',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  final partes = horaLunchEscolar.split(':');
                                  final h = partes.isNotEmpty ? int.tryParse(partes[0]) ?? 20 : 20;
                                  final m = partes.length > 1 ? int.tryParse(partes[1]) ?? 30 : 30;
                                  final pick = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(hour: h, minute: m),
                                  );
                                  if (pick != null) {
                                    setState(() {
                                      horaLunchEscolar =
                                          '${pick.hour.toString().padLeft(2, '0')}:${pick.minute.toString().padLeft(2, '0')}';
                                    });
                                  }
                                },
                                child: Text(
                                  horaLunchEscolar,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00897B)),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Avisa la noche anterior ($horaLunchEscolar) a mamás y papás para preparar recipientes y lonchera de los peques.',
                            style: const TextStyle(fontSize: 12),
                          ),
                          activeThumbColor: const Color(0xFF00897B),
                          value: alertaLunchEscolarActiva,
                          onChanged: (val) =>
                              setState(() => alertaLunchEscolarActiva = val),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: const Icon(
                            Icons.backpack_rounded,
                            color: Color(0xFF00897B),
                          ),
                          title: const Text(
                            'Recordatorio de Lunch Escolar 🎒🍎',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: const Text(
                            'Avisa la noche anterior (8:30 PM) para preparar los snacks y lonchera escolar de los niños sin prisas.',
                            style: TextStyle(fontSize: 12),
                          ),
                          activeThumbColor: const Color(0xFF00897B),
                          value: alertaLunchEscolarActiva,
                          onChanged: (val) =>
                              setState(() => alertaLunchEscolarActiva = val),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: const Icon(
                            Icons.eco_rounded,
                            color: Colors.green,
                          ),
                          title: const Text(
                            'Monitor de Frescura y Desperdicio Cero',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: const Text(
                            'Detecta alimentos con varios días en despensa y ofrece recetas express para rescatarlos.',
                            style: TextStyle(fontSize: 12),
                          ),
                          activeThumbColor: Colors.green,
                          value: alertaFrescuraActiva,
                          onChanged: (val) =>
                              setState(() => alertaFrescuraActiva = val),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: const Icon(
                            Icons.notifications_active_outlined,
                            color: Colors.orange,
                          ),
                          title: const Text(
                            'Notificaciones del Planeador',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                          subtitle: const Text(
                            'Recordatorios generales para cocinar y preparar platillos.',
                            style: TextStyle(fontSize: 12),
                          ),
                          activeThumbColor: Colors.orange,
                          value: notificacionesActivas,
                          onChanged: (val) =>
                              setState(() => notificacionesActivas = val),
                        ),
                        const Divider(height: 1),
                        ValueListenableBuilder<ThemeMode>(
                          valueListenable: themeModeNotifier,
                          builder: (context, mode, _) {
                            final bool esOscuro = mode == ThemeMode.dark;
                            return SwitchListTile(
                              secondary: Icon(
                                esOscuro ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                color: esOscuro ? Colors.amber : Colors.indigo,
                              ),
                              title: const Text(
                                'Modo Nocturno Culinario 🌙',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                              subtitle: const Text(
                                'Tema oscuro descansado para tus ojos al preparar la cena o cocinar de noche.',
                                style: TextStyle(fontSize: 12),
                              ),
                              activeThumbColor: const Color(0xFFD32F2F),
                              value: esOscuro,
                              onChanged: (val) => alternarModoOscuro(val),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),

                  // 💡 BOTÓN GUARDAR
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: guardando ? null : guardarPreferencias,
                      icon: guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          guardando ? 'Guardando...' : 'Guardar Preferencias',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorPrincipal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 💬 FEEDBACK EN 1 TOQUE POR WHATSAPP
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(
                        color: const Color(0xFF25D366).withValues(alpha: 0.35),
                      ),
                    ),
                    color: const Color(0xFF25D366).withValues(alpha: 0.08),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF25D366),
                          size: 22,
                        ),
                      ),
                      title: const Text(
                        'Danos tu Opinión por WhatsApp 💬',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: const Text(
                        'Escríbele tus ideas, dudas o comentarios directo al Chef Alain en 1 toque.',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF25D366),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '1 Toque 📲',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      onTap: () => DialogoContactoSoporte.abrirWhatsAppFeedback(context),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ✉️ CANALES OFICIALES DE CONTACTO
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(
                        color: Colors.blueAccent.withValues(alpha: 0.25),
                      ),
                    ),
                    color: Colors.blue.shade50.withValues(alpha: 0.4),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.alternate_email_rounded,
                          color: Colors.blueAccent,
                          size: 22,
                        ),
                      ),
                      title: const Text(
                        'Contacto y Soporte Oficial',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                      subtitle: const Text(
                        'hola, contacto y alain @jitomateycebolla.com',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 15,
                        color: Colors.blueAccent,
                      ),
                      onTap: () => DialogoContactoSoporte.mostrar(context),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        ),
    );
  }
}
