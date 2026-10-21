import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pantalla_preferencias.dart';
import 'perfiles_nutricionales.dart';
import 'servicio_bienestar.dart';
import 'servicio_preferencias.dart';
import 'servicio_finanzas_domesticas.dart';
import 'menu_lateral.dart';

class PantallaSalud extends StatefulWidget {
  const PantallaSalud({super.key});

  @override
  State<PantallaSalud> createState() => _PantallaSaludState();
}

class _PantallaSaludState extends State<PantallaSalud> {
  bool cargando = true;

  // 💧 Hidratación diaria (8 vasos * 250ml = 2000ml)
  int _vasosAguaHoy = 0;
  static const int _metaVasosAgua = 8;

  // Totales consumidos hoy
  int caloriasTotales = 0;
  int proteinasTotales = 0;
  int carbsTotales = 0;
  int grasasTotales = 0;

  // Metas nutricionales dinámicas
  String perfilSeleccionado = 'Mantenimiento';
  int metaCalorias = 2000;
  int metaProteinas = 140;
  int metaCarbs = 230;
  int metaGrasas = 65;

  List<Map<String, dynamic>> comidasDeHoy = [];

  final Color colorCalorias = const Color(0xFFF57C00); // Naranja
  final Color colorProteina = const Color(0xFFD32F2F); // Rojo Borgoña
  final Color colorCarbs = const Color(0xFF1976D2); // Azul
  final Color colorGrasas = const Color(0xFFFBC02D); // Amarillo

  // ⏱️ Temporizador de Ayuno Intermitente
  bool _ayunoActivo = false;
  String _protocoloAyuno = '16/8';
  DateTime? _inicioAyuno;
  Timer? _tickerAyuno;

  // 🧮 Datos Calculadora TDEE Mifflin-St Jeor
  double _tdeePeso = 72.0;
  double _tdeeAltura = 172.0;
  int _tdeeEdad = 28;
  bool _tdeeEsHombre = true;
  String _tdeeActividad = 'Moderado';
  String _tdeeObjetivo = 'Mantenimiento';

  // 🌱 P28: Eco-Score Culinario & Huella Positiva
  ImpactoEcologico? _impactoEcologico;

  final Map<String, Map<String, int>> perfilesNutricionales = {
    'Déficit (Baja)': {
      'calorias': 1500,
      'proteinas': 130,
      'carbs': 140,
      'grasas': 45,
    },
    'Mantenimiento': {
      'calorias': 2000,
      'proteinas': 140,
      'carbs': 230,
      'grasas': 65,
    },
    'Volumen (Alta)': {
      'calorias': 2500,
      'proteinas': 180,
      'carbs': 300,
      'grasas': 75,
    },
    'Keto': {'calorias': 1700, 'proteinas': 110, 'carbs': 30, 'grasas': 130},
    'Baja en grasa': {
      'calorias': 1600,
      'proteinas': 135,
      'carbs': 220,
      'grasas': 20,
    },
  };

  @override
  void initState() {
    super.initState();
    _cargarPerfilDesdePreferencias();
    _cargarHidratacionHoy();
    _cargarEstadoAyuno();
    _cargarParametrosTdee();
    calcularNutricionDelDia();

    // Actualizador suave cada minuto para el reloj de ayuno
    _tickerAyuno = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && _ayunoActivo) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tickerAyuno?.cancel();
    super.dispose();
  }

  Future<void> _cargarPerfilDesdePreferencias() async {
    try {
      final prefs = await ServicioPreferencias.obtenerPreferencias();
      final sp = await SharedPreferences.getInstance();
      final String? metaTdeeGuardada = sp.getString('meta_tdee_nombre');

      if (!mounted) return;

      if (metaTdeeGuardada != null && sp.containsKey('tdee_meta_calorias')) {
        setState(() {
          perfilSeleccionado = metaTdeeGuardada;
          metaCalorias = sp.getInt('tdee_meta_calorias') ?? 2000;
          metaProteinas = sp.getInt('tdee_meta_proteinas') ?? 140;
          metaCarbs = sp.getInt('tdee_meta_carbs') ?? 230;
          metaGrasas = sp.getInt('tdee_meta_grasas') ?? 65;
        });
        return;
      }

      final perfil = prefs.estilos.contains(PerfilesNutricionales.keto)
          ? 'Keto'
          : (prefs.estilos.contains(PerfilesNutricionales.bajaEnGrasa)
              ? 'Baja en grasa'
              : prefs.objetivo);
      _aplicarPerfil(
        perfilesNutricionales.containsKey(perfil)
            ? perfil
            : PerfilesNutricionales.mantenimiento,
      );
    } catch (e) {
      debugPrint('Error al cargar perfil desde preferencias: $e');
    }
  }

  void _aplicarPerfil(String nombrePerfil) {
    if (nombrePerfil == 'Personalizada') {
      _mostrarDialogoMetaPersonalizada();
      return;
    }

    final config = perfilesNutricionales[nombrePerfil];
    if (config != null) {
      setState(() {
        perfilSeleccionado = nombrePerfil;
        metaCalorias = config['calorias']!;
        metaProteinas = config['proteinas']!;
        metaCarbs = config['carbs']!;
        metaGrasas = config['grasas']!;
      });
    }
  }

  // =========================================================================
  // 🧮 CALCULADORA METABÓLICA TDEE (Mifflin-St Jeor)
  // =========================================================================

  Future<void> _cargarParametrosTdee() async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _tdeePeso = sp.getDouble('tdee_peso') ?? 72.0;
          _tdeeAltura = sp.getDouble('tdee_altura') ?? 172.0;
          _tdeeEdad = sp.getInt('tdee_edad') ?? 28;
          _tdeeEsHombre = sp.getBool('tdee_es_hombre') ?? true;
          _tdeeActividad = sp.getString('tdee_actividad') ?? 'Moderado';
          _tdeeObjetivo = sp.getString('tdee_objetivo') ?? 'Mantenimiento';
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos TDEE: $e');
    }
  }

  Future<void> _mostrarModalCalculadoraTdee() async {
    double tempPeso = _tdeePeso;
    double tempAltura = _tdeeAltura;
    int tempEdad = _tdeeEdad;
    bool tempHombre = _tdeeEsHombre;
    String tempActividad = _tdeeActividad;
    String tempObjetivo = _tdeeObjetivo;

    final pesoCtrl = TextEditingController(text: tempPeso.toStringAsFixed(1));
    final alturaCtrl = TextEditingController(text: tempAltura.toStringAsFixed(0));
    final edadCtrl = TextEditingController(text: tempEdad.toString());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final res = ServicioBienestar.calcularPlanNutricional(
            pesoKg: tempPeso,
            alturaCm: tempAltura,
            edad: tempEdad,
            esHombre: tempHombre,
            nivelActividad: tempActividad,
            objetivo: tempObjetivo,
          );

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calculate, color: Colors.teal, size: 24),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Calculadora Metabólica TDEE',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Fórmula Clínica Mifflin-St Jeor',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Sexo Biológico
                  const Text('Sexo Biológico:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Hombre 👨')),
                          selected: tempHombre,
                          selectedColor: Colors.teal.shade100,
                          onSelected: (val) {
                            if (val) setModalState(() => tempHombre = true);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Mujer 👩')),
                          selected: !tempHombre,
                          selectedColor: Colors.teal.shade100,
                          onSelected: (val) {
                            if (val) setModalState(() => tempHombre = false);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Medidas Corporales
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pesoCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Peso',
                            suffixText: 'kg',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final n = double.tryParse(v);
                            if (n != null && n > 25 && n < 300) {
                              setModalState(() => tempPeso = n);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: alturaCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Estatura',
                            suffixText: 'cm',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final n = double.tryParse(v);
                            if (n != null && n > 100 && n < 250) {
                              setModalState(() => tempAltura = n);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: edadCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Edad',
                            suffixText: 'años',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n > 10 && n < 110) {
                              setModalState(() => tempEdad = n);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Nivel de Actividad
                  const Text('Nivel de Actividad Física:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['Sedentario', 'Ligero', 'Moderado', 'Intenso', 'Atleta'].map((act) {
                        final sel = tempActividad.toLowerCase() == act.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(act),
                            selected: sel,
                            selectedColor: Colors.teal.shade100,
                            onSelected: (val) {
                              if (val) setModalState(() => tempActividad = act);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Objetivo
                  const Text('Objetivo Principal:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Déficit 🔥', style: TextStyle(fontSize: 12))),
                          selected: tempObjetivo == 'Déficit',
                          selectedColor: Colors.orange.shade100,
                          onSelected: (_) => setModalState(() => tempObjetivo = 'Déficit'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Mantener ⚖️', style: TextStyle(fontSize: 12))),
                          selected: tempObjetivo == 'Mantenimiento',
                          selectedColor: Colors.teal.shade100,
                          onSelected: (_) => setModalState(() => tempObjetivo = 'Mantenimiento'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Volumen 💪', style: TextStyle(fontSize: 12))),
                          selected: tempObjetivo == 'Superávit',
                          selectedColor: Colors.blue.shade100,
                          onSelected: (_) => setModalState(() => tempObjetivo = 'Superávit'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // TARJETA DE RESULTADO EN VIVO
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade700, const Color(0xFF004D40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Metabolismo Basal (BMR): ${res.bmr} kcal',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              'Gasto Total: ${res.tdee} kcal',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '${res.caloriasObjetivo}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'kcal objetivo / día',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text(
                                '🍗 Prot: ${res.proteinasGramos}g',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '🍚 Carbs: ${res.carbohidratosGramos}g',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Text(
                                '🥑 Grasa: ${res.grasasGramos}g',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E2022),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text(
                        'Aplicar como mi Meta Diaria ✅',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: () async {
                        final sp = await SharedPreferences.getInstance();
                        await sp.setDouble('tdee_peso', tempPeso);
                        await sp.setDouble('tdee_altura', tempAltura);
                        await sp.setInt('tdee_edad', tempEdad);
                        await sp.setBool('tdee_es_hombre', tempHombre);
                        await sp.setString('tdee_actividad', tempActividad);
                        await sp.setString('tdee_objetivo', tempObjetivo);

                        final nombrePerfil = 'TDEE ($tempObjetivo)';
                        await sp.setString('meta_tdee_nombre', nombrePerfil);
                        await sp.setInt('tdee_meta_calorias', res.caloriasObjetivo);
                        await sp.setInt('tdee_meta_proteinas', res.proteinasGramos);
                        await sp.setInt('tdee_meta_carbs', res.carbohidratosGramos);
                        await sp.setInt('tdee_meta_grasas', res.grasasGramos);

                        if (!mounted) return;
                        setState(() {
                          _tdeePeso = tempPeso;
                          _tdeeAltura = tempAltura;
                          _tdeeEdad = tempEdad;
                          _tdeeEsHombre = tempHombre;
                          _tdeeActividad = tempActividad;
                          _tdeeObjetivo = tempObjetivo;

                          perfilSeleccionado = nombrePerfil;
                          metaCalorias = res.caloriasObjetivo;
                          metaProteinas = res.proteinasGramos;
                          metaCarbs = res.carbohidratosGramos;
                          metaGrasas = res.grasasGramos;
                        });

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '¡Meta calibrada con TDEE! ${res.caloriasObjetivo} kcal y ${res.proteinasGramos}g de proteína calculados 🎯',
                              ),
                              backgroundColor: Colors.teal.shade800,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _mostrarDialogoMetaPersonalizada() {
    final calCtrl = TextEditingController(text: metaCalorias.toString());
    final protCtrl = TextEditingController(text: metaProteinas.toString());
    final carbsCtrl = TextEditingController(text: metaCarbs.toString());
    final grasCtrl = TextEditingController(text: metaGrasas.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.tune, color: Colors.teal),
            SizedBox(width: 10),
            Text('Meta Personalizada'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: calCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calorías Diarias (kcal)',
                  prefixIcon: Icon(
                    Icons.local_fire_department,
                    color: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: protCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Proteína (gramos)',
                  prefixIcon: Icon(Icons.fitness_center, color: Colors.red),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: carbsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Carbohidratos (gramos)',
                  prefixIcon: Icon(Icons.grain, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: grasCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Grasas (gramos)',
                  prefixIcon: Icon(Icons.opacity, color: Colors.amber),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                perfilSeleccionado = 'Personalizada';
                metaCalorias = int.tryParse(calCtrl.text) ?? metaCalorias;
                metaProteinas = int.tryParse(protCtrl.text) ?? metaProteinas;
                metaCarbs = int.tryParse(carbsCtrl.text) ?? metaCarbs;
                metaGrasas = int.tryParse(grasCtrl.text) ?? metaGrasas;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Guardar Metas'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ⏱️ TEMPORIZADOR DE AYUNO INTERMITENTE
  // =========================================================================

  Future<void> _cargarEstadoAyuno() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final activo = sp.getBool('ayuno_activo') ?? false;
      final proto = sp.getString('ayuno_protocolo') ?? '16/8';
      final inicioMs = sp.getInt('ayuno_inicio_ms');

      if (mounted) {
        setState(() {
          _ayunoActivo = activo;
          _protocoloAyuno = proto;
          _inicioAyuno = inicioMs != null ? DateTime.fromMillisecondsSinceEpoch(inicioMs) : null;
        });
      }
    } catch (e) {
      debugPrint('Error cargando ayuno: $e');
    }
  }

  Future<void> _iniciarAyuno([String? proto]) async {
    final protocolo = proto ?? _protocoloAyuno;
    final ahora = DateTime.now();

    final sp = await SharedPreferences.getInstance();
    await sp.setBool('ayuno_activo', true);
    await sp.setString('ayuno_protocolo', protocolo);
    await sp.setInt('ayuno_inicio_ms', ahora.millisecondsSinceEpoch);

    if (mounted) {
      setState(() {
        _ayunoActivo = true;
        _protocoloAyuno = protocolo;
        _inicioAyuno = ahora;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Ayuno $protocolo iniciado con éxito! Mucho éxito en tu jornada metabólica 🔥💧'),
          backgroundColor: const Color(0xFF1E2022),
        ),
      );
    }
  }

  Future<void> _terminarAyuno() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('ayuno_activo', false);
    await sp.remove('ayuno_inicio_ms');

    if (mounted) {
      setState(() {
        _ayunoActivo = false;
        _inicioAyuno = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Ayuno finalizado! Ventana de alimentación abierta. Come balanceado 🥗'),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  Widget _construirTarjetaAyunoIntermitente() {
    final estado = ServicioBienestar.evaluarEstadoAyuno(
      enAyuno: _ayunoActivo,
      protocolo: _protocoloAyuno,
      inicio: _inicioAyuno,
    );

    final horas = estado.tiempoTranscurrido.inHours;
    final minutos = estado.tiempoTranscurrido.inMinutes % 60;
    final horasRestantes = estado.tiempoRestante.inHours;
    final minutosRestantes = estado.tiempoRestante.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: _ayunoActivo ? Colors.indigo.shade100 : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.timer_outlined,
                      color: Colors.indigo.shade700,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ayuno Intermitente',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Regeneración celular & Autofagia',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _ayunoActivo ? Colors.indigo.shade50 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _ayunoActivo ? Colors.indigo.shade200 : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  _protocoloAyuno,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _ayunoActivo ? Colors.indigo.shade800 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Selector de protocolo rápido
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['16/8', '14/10', '12/12', '18/6'].map((proto) {
                final activo = _protocoloAyuno == proto;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(proto),
                    selected: activo,
                    selectedColor: Colors.indigo.shade100,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                      color: activo ? Colors.indigo.shade900 : Colors.black87,
                    ),
                    onSelected: (val) {
                      if (val) {
                        if (_ayunoActivo) {
                          _iniciarAyuno(proto);
                        } else {
                          setState(() => _protocoloAyuno = proto);
                        }
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          if (_ayunoActivo) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tiempo en Ayuno', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${horas}h ${minutos}m',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      estado.completado ? '¡Meta lograda!' : 'Resta para meta',
                      style: TextStyle(
                        fontSize: 12,
                        color: estado.completado ? Colors.green.shade700 : Colors.grey,
                      ),
                    ),
                    Text(
                      estado.completado ? '🎉 Cumplido' : '${horasRestantes}h ${minutosRestantes}m',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: estado.completado ? Colors.green.shade700 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: estado.progreso,
                minHeight: 12,
                backgroundColor: Colors.indigo.shade50,
                valueColor: AlwaysStoppedAnimation<Color>(
                  estado.completado ? Colors.green.shade600 : Colors.indigo.shade600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estado.faseFisiologica,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: Colors.indigo.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    estado.descripcionFase,
                    style: TextStyle(fontSize: 11.5, color: Colors.indigo.shade800, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.stop_circle_outlined, size: 18),
                    label: const Text('Romper / Terminar Ayuno', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    onPressed: _terminarAyuno,
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.restaurant, color: Colors.teal, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Actualmente estás en tu ventana de alimentación. Al terminar tu última comida del día, toca "Iniciar Ayuno" para monitorear tus fases de autofagia y cetosis.',
                      style: TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: Text(
                  'Iniciar Ayuno $_protocoloAyuno 🔥',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: () => _iniciarAyuno(_protocoloAyuno),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // 🥗 SEMÁFORO DE DENSIDAD NUTRICIONAL Y CALIDAD
  // =========================================================================

  Widget _construirSemaforoDensidadNutricional() {
    final eval = ServicioBienestar.evaluarDensidadDia(
      vasosAgua: _vasosAguaHoy,
      metaVasosAgua: _metaVasosAgua,
      caloriasConsumidas: caloriasTotales,
      metaCalorias: metaCalorias,
      proteinasConsumidas: proteinasTotales,
      metaProteinas: metaProteinas,
      comidasPlaneadasHoy: comidasDeHoy.length,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: eval.colorGrado.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: eval.colorGrado.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.eco, color: eval.colorGrado, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Semáforo de Calidad Culinaria',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: eval.colorGrado,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Grado ${eval.grado}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${eval.puntuacion}',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: eval.colorGrado,
                ),
              ),
              const Text(
                ' / 100 pts',
                style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  eval.titulo,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: eval.colorGrado),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: eval.puntuacion / 100.0,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(eval.colorGrado),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            eval.diagnostico,
            style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.3),
          ),
          if (eval.consejos.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...eval.consejos.take(2).map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                  Expanded(
                    child: Text(
                      c,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // 📊 CÁLCULO DE NUTRICIÓN Y PLANEADOR
  // =========================================================================

  Future<void> calcularNutricionDelDia() async {
    setState(() => cargando = true);
    try {
      final hoy = DateTime.now().toIso8601String().split('T')[0];

      final respuesta = await Supabase.instance.client
          .from('planeador')
          .select('tipo_comida, recetas(titulo, calorias, macros, descripcion)')
          .eq('fecha', hoy);

      int cal = 0;
      int prot = 0;
      int carb = 0;
      int gras = 0;
      List<Map<String, dynamic>> listaTemporal = [];

      for (var item in respuesta) {
        final receta = item['recetas'];
        if (receta != null) {
          int caloriasReceta =
              int.tryParse(receta['calorias']?.toString() ?? '0') ?? 0;

          final desc = receta['descripcion']?.toString() ?? '';
          if (caloriasReceta == 0 && desc.isNotEmpty) {
            final matchCal = RegExp(
              r'(\d+)\s*(?:kcal|calor[íi]as)',
              caseSensitive: false,
            ).firstMatch(desc);
            if (matchCal != null) {
              caloriasReceta = int.tryParse(matchCal.group(1) ?? '0') ?? 0;
            }
          }

          if (caloriasReceta == 0) caloriasReceta = 450;
          cal += caloriasReceta;

          final macrosTexto = '${receta['macros']?.toString() ?? ''} $desc';

          int p = _extraerNumero(macrosTexto, r'Prot(?:e[íi]na)?:\s*(\d+)');
          int c = _extraerNumero(macrosTexto, r'Carb(?:s|ohidratos)?:\s*(\d+)');
          int g = _extraerNumero(macrosTexto, r'Grasas?:\s*(\d+)');

          if (p == 0 && c == 0 && g == 0) {
            p = (caloriasReceta * 0.25 / 4).round();
            c = (caloriasReceta * 0.50 / 4).round();
            g = (caloriasReceta * 0.25 / 9).round();
          }

          prot += p;
          carb += c;
          gras += g;

          listaTemporal.add({
            'tipo': item['tipo_comida'],
            'titulo': receta['titulo'] ?? 'Platillo',
            'calorias': caloriasReceta,
            'macros': 'P: ${p}g | C: ${c}g | G: ${g}g',
          });
        }
      }

      final int totalComidasSemana = listaTemporal.isNotEmpty ? listaTemporal.length * 7 : 14;
      final eco = ServicioFinanzasDomesticas.calcularImpactoEcologico(
        comidasCaseras: totalComidasSemana,
        insumosRescatados: 3,
      );

      setState(() {
        caloriasTotales = cal;
        proteinasTotales = prot;
        carbsTotales = carb;
        grasasTotales = gras;
        comidasDeHoy = listaTemporal;
        _impactoEcologico = eco;
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar nutrición: $e');
      setState(() => cargando = false);
    }
  }

  int _extraerNumero(String texto, String patronRegex) {
    try {
      final match = RegExp(patronRegex, caseSensitive: false).firstMatch(texto);
      if (match != null && match.groupCount >= 1) {
        return int.tryParse(match.group(1)!) ?? 0;
      }
    } catch (e) {
      debugPrint('Error extrayendo macro: $e');
    }
    return 0;
  }

  Widget _crearBarraProgreso(String titulo, int actual, int meta, Color color) {
    final double porcentaje = (actual / meta).clamp(0.0, 1.0);
    final bool excedido = actual > meta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              titulo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              '$actual / ${meta}g',
              style: TextStyle(
                color: excedido ? Colors.red : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: porcentaje,
            minHeight: 12,
            backgroundColor: color.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              excedido ? Colors.red : color,
            ),
          ),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  // =========================================================================
  // 🏗️ BUILD PRINCIPAL
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final double progresoCalorias = (caloriasTotales / metaCalorias).clamp(
      0.0,
      1.0,
    );

    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const MenuLateral(rutaActual: 'salud'),
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
        title: const Text(
          'Mi Salud 🍏',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E2022),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: 'Calculadora Metabólica TDEE',
            onPressed: _mostrarModalCalculadoraTdee,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Mis Preferencias',
            onPressed: () async {
              final actualizado = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PantallaPreferencias(),
                ),
              );
              if (actualizado == true) {
                _cargarPerfilDesdePreferencias();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Configurar Meta Personalizada',
            onPressed: _mostrarDialogoMetaPersonalizada,
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : RefreshIndicator(
              color: Colors.teal,
              onRefresh: () async {
                await _cargarPerfilDesdePreferencias();
                await _cargarHidratacionHoy();
                await _cargarEstadoAyuno();
                await calcularNutricionDelDia();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SELECTOR DE PERFIL DIETÉTICO Y TDEE ---
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.flag_outlined, color: Colors.teal, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'Objetivo Nutricional',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  foregroundColor: Colors.teal.shade800,
                                ),
                                icon: const Icon(Icons.calculate_outlined, size: 16),
                                label: const Text('TDEE 🧮', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: _mostrarModalCalculadoraTdee,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ActionChip(
                                  avatar: const Icon(Icons.auto_awesome, size: 15, color: Colors.teal),
                                  label: const Text('Calcular TDEE 🧮', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                                  backgroundColor: Colors.teal.shade50,
                                  side: BorderSide(color: Colors.teal.shade200),
                                  onPressed: _mostrarModalCalculadoraTdee,
                                ),
                                const SizedBox(width: 8),
                                ...perfilesNutricionales.keys.map((perfil) {
                                  final bool activo = perfilSeleccionado == perfil;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(perfil),
                                      selected: activo,
                                      selectedColor: Colors.teal.shade100,
                                      labelStyle: TextStyle(
                                        color: activo ? Colors.teal.shade900 : Colors.black87,
                                        fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                                      ),
                                      onSelected: (val) {
                                        if (val) _aplicarPerfil(perfil);
                                      },
                                    ),
                                  );
                                }),
                                ChoiceChip(
                                  label: const Text('Personalizada ✏️'),
                                  selected: perfilSeleccionado.contains('Personalizada') || perfilSeleccionado.contains('TDEE'),
                                  selectedColor: Colors.teal.shade100,
                                  onSelected: (_) => _mostrarDialogoMetaPersonalizada(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --- SEMÁFORO DE DENSIDAD NUTRICIONAL ---
                    _construirSemaforoDensidadNutricional(),

                    const SizedBox(height: 16),

                    // --- ANILLO DE CALORÍAS ---
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 95,
                            height: 95,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: progresoCalorias,
                                  strokeWidth: 10,
                                  backgroundColor: colorCalorias.withValues(alpha: 0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(colorCalorias),
                                ),
                                Center(
                                  child: Text(
                                    '${(progresoCalorias * 100).toInt()}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 22),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Calorías Consumidas',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$caloriasTotales',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: colorCalorias,
                                  ),
                                ),
                                Text(
                                  'de $metaCalorias kcal ($perfilSeleccionado)',
                                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --- BARRAS DE MACROS ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Distribución de Macros',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _crearBarraProgreso(
                            'Proteína',
                            proteinasTotales,
                            metaProteinas,
                            colorProteina,
                          ),
                          _crearBarraProgreso(
                            'Carbohidratos',
                            carbsTotales,
                            metaCarbs,
                            colorCarbs,
                          ),
                          _crearBarraProgreso(
                            'Grasas',
                            grasasTotales,
                            metaGrasas,
                            colorGrasas,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // --- TEMPORIZADOR DE AYUNO INTERMITENTE ---
                    _construirTarjetaAyunoIntermitente(),

                    const SizedBox(height: 16),

                    // --- REGISTRO DE HIDRATACIÓN DIARIA ---
                    _construirTarjetaHidratacion(),

                    const SizedBox(height: 16),

                    // --- ECO-SCORE & HUELLA POSITIVA (P28) ---
                    _construirTarjetaEcoScoreSalud(),

                    const SizedBox(height: 24),

                    // --- DESGLOSE DEL MENÚ DE HOY ---
                    const Text(
                      'Menú de Hoy 🍽️',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (comidasDeHoy.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'No tienes comidas planeadas para hoy.\n¡Ve al "Planeador por Tiempos" o Calendario y organiza tu día!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, height: 1.4),
                          ),
                        ),
                      )
                    else
                      ...comidasDeHoy.map((comida) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.restaurant,
                                color: Colors.teal,
                              ),
                            ),
                            title: Text(
                              comida['titulo'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${comida['tipo']} • ${comida['macros']}',
                            ),
                            trailing: Text(
                              '${comida['calorias']} kcal',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  // =========================================================================
  // 💧 REGISTRO DE HIDRATACIÓN DIARIA
  // =========================================================================

  Future<void> _cargarHidratacionHoy() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fechaHoy = DateTime.now().toIso8601String().split('T').first;
      final key = 'hidratacion_$fechaHoy';
      final vasos = prefs.getInt(key) ?? 0;
      if (mounted) {
        setState(() => _vasosAguaHoy = vasos);
      }
    } catch (e) {
      debugPrint('Error al cargar hidratación: $e');
    }
  }

  Future<void> _ajustarVasosAgua(int delta) async {
    final nuevo = (_vasosAguaHoy + delta).clamp(0, 20);
    setState(() => _vasosAguaHoy = nuevo);
    try {
      final prefs = await SharedPreferences.getInstance();
      final fechaHoy = DateTime.now().toIso8601String().split('T').first;
      final key = 'hidratacion_$fechaHoy';
      await prefs.setInt(key, nuevo);
      if (nuevo == _metaVasosAgua && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Excelente! Has alcanzado tu meta diaria de 2L de agua 💧🎉',
            ),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error al guardar hidratación: $e');
    }
  }

  Widget _construirTarjetaHidratacion() {
    final double progreso = (_vasosAguaHoy / _metaVasosAgua).clamp(0.0, 1.0);
    final int mlActuales = _vasosAguaHoy * 250;
    final int mlMeta = _metaVasosAgua * 250;
    final bool metaAlcanzada = _vasosAguaHoy >= _metaVasosAgua;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: metaAlcanzada ? Colors.blue.shade200 : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.water_drop,
                      color: Colors.blueAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hidratación Diaria',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Objetivo saludable: 2,000 ml al día',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (metaAlcanzada)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blueAccent),
                  ),
                  child: const Text(
                    '¡Cumplida! 🎉',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$mlActuales ',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                    TextSpan(
                      text: '/ $mlMeta ml',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$_vasosAguaHoy de $_metaVasosAgua vasos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 12,
              backgroundColor: Colors.blue.shade50,
              valueColor: AlwaysStoppedAnimation<Color>(
                metaAlcanzada ? Colors.teal : Colors.blueAccent,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 8 Vasos interactivos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_metaVasosAgua, (index) {
              final bool lleno = index < _vasosAguaHoy;
              return InkWell(
                onTap: () {
                  if (lleno) {
                    _ajustarVasosAgua(-1);
                  } else {
                    _ajustarVasosAgua(1);
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Icon(
                    lleno ? Icons.local_drink : Icons.local_drink_outlined,
                    color: lleno ? Colors.blueAccent : Colors.grey.shade400,
                    size: 26,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          // Botonera de incremento rápido
          Row(
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.remove, size: 18),
                tooltip: 'Quitar 1 vaso (250 ml)',
                style: IconButton.styleFrom(
                  foregroundColor: Colors.blueAccent,
                  side: BorderSide(color: Colors.blue.shade200),
                ),
                onPressed:
                    _vasosAguaHoy > 0 ? () => _ajustarVasosAgua(-1) : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade800,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.blue.shade200),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text(
                    '+1 Vaso (250 ml)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () => _ajustarVasosAgua(1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.water_drop, size: 16),
                  label: const Text(
                    '+ Botella (500 ml)',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: () => _ajustarVasosAgua(2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🌱 WIDGET P28: ECO-SCORE CULINARIO & HUELLA POSITIVA EN SALUD
  Widget _construirTarjetaEcoScoreSalud() {
    final eco = _impactoEcologico;
    if (eco == null) return const SizedBox.shrink();

    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: esOscuro ? const Color(0xFF1E2822) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.eco_rounded, color: Colors.green, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Salud & Huella Positiva 🌱',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: esOscuro ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Eco-Score',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Comer saludable en casa nutre tu cuerpo y reduce drásticamente las emisiones de delivery y el uso de plásticos.',
            style: TextStyle(
              fontSize: 12.5,
              color: esOscuro ? Colors.white70 : Colors.black54,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text('🌍 CO₂ Evitado', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${eco.co2PrevenidoKg.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text('💧 Agua Virtual', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${eco.aguaVirtualSalvadaLitros} L', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      const Text('🥡 Sin Unicel', style: TextStyle(fontSize: 11, color: Colors.brown, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${eco.envasesPlasticosAhorrados} pzas', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.brown)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
