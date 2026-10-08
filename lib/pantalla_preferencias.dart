import 'package:flutter/material.dart';

import 'perfiles_nutricionales.dart';
import 'servicio_preferencias.dart';
import 'menu_lateral.dart';

class PantallaPreferencias extends StatefulWidget {
  const PantallaPreferencias({super.key});

  @override
  State<PantallaPreferencias> createState() => _PantallaPreferenciasState();
}

class _PantallaPreferenciasState extends State<PantallaPreferencias> {
  // Variables de estado para las preferencias
  String objetivoSeleccionado = PerfilesNutricionales.mantenimiento;
  List<String> estilosSeleccionados = [PerfilesNutricionales.libre];
  double presupuestoSemanal = 1500;
  int porcionesDefecto = 2;
  String superFavorito = 'Walmart';
  final TextEditingController alergiasController = TextEditingController();
  bool notificacionesActivas = true;
  bool guardando = false;
  bool cargando = true;

  // 🍎 OBJETIVOS Y ESTILOS (fuente única compartida con Planeador, Salud y Chef)
  final List<String> opcionesObjetivo = PerfilesNutricionales.objetivos;
  final List<String> opcionesEstilo = PerfilesNutricionales.estilos;

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

  Future<void> _cargarPreferencias() async {
    setState(() => cargando = true);
    try {
      final prefs = await ServicioPreferencias.obtenerPreferencias();
      if (!mounted) return;
      setState(() {
        objetivoSeleccionado = prefs.objetivo;
        estilosSeleccionados = PerfilesNutricionales.normalizar(prefs.estilos);
        alergiasController.text = prefs.alergias;
        superFavorito = opcionesSuper.contains(prefs.superFavorito)
            ? prefs.superFavorito
            : 'Walmart';
        porcionesDefecto = prefs.porciones.clamp(1, 12);
        presupuestoSemanal = prefs.presupuestoSemanal.clamp(500.0, 5000.0);
        notificacionesActivas = prefs.notificaciones;
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
        alergias: alergiasController.text.trim(),
        superFavorito: superFavorito,
        porciones: porcionesDefecto,
        presupuestoSemanal: presupuestoSemanal,
        notificaciones: notificacionesActivas,
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
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú principal',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Mis Preferencias ⚙️',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorPrincipal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueGrey),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  // 💡 2. HOGAR Y COMPRAS (SUPERMERCADOS COMO BOTONES)
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
                              const Text(
                                'Porciones por defecto',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
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

                  // 💡 3. FINANZAS
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
                              const Text(
                                'Presupuesto Semanal Súper',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '\$${presupuestoSemanal.toInt()} MXN',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
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

                  // 💡 4. SISTEMA
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Notificaciones del Planeador',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Text('Recordatorios para cocinar'),
                      activeThumbColor: Colors.blueGrey,
                      value: notificacionesActivas,
                      onChanged: (val) =>
                          setState(() => notificacionesActivas = val),
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
                      label: Text(
                        guardando ? 'Guardando...' : 'Guardar Preferencias',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
