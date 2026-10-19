import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pantalla_preferencias.dart';
import 'perfiles_nutricionales.dart';
import 'servicio_preferencias.dart';
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
  final Color colorProteina = const Color(0xFFD32F2F); // Rojo
  final Color colorCarbs = const Color(0xFF1976D2); // Azul
  final Color colorGrasas = const Color(0xFFFBC02D); // Amarillo

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
    calcularNutricionDelDia();
  }

  Future<void> _cargarPerfilDesdePreferencias() async {
    try {
      final prefs = await ServicioPreferencias.obtenerPreferencias();
      if (!mounted) return;
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

      setState(() {
        caloriasTotales = cal;
        proteinasTotales = prot;
        carbsTotales = carb;
        grasasTotales = gras;
        comidasDeHoy = listaTemporal;
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
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú principal',
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
                await calcularNutricionDelDia();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SELECTOR DE PERFIL DIETÉTICO ---
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
                        const Row(
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              color: Colors.teal,
                              size: 22,
                            ),
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
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...perfilesNutricionales.keys.map((perfil) {
                                final bool activo =
                                    perfilSeleccionado == perfil;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(perfil),
                                    selected: activo,
                                    selectedColor: Colors.teal.shade100,
                                    labelStyle: TextStyle(
                                      color: activo
                                          ? Colors.teal.shade900
                                          : Colors.black87,
                                      fontWeight: activo
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    onSelected: (val) {
                                      if (val) _aplicarPerfil(perfil);
                                    },
                                  ),
                                );
                              }),
                              ChoiceChip(
                                label: const Text('Personalizada ✏️'),
                                selected: perfilSeleccionado == 'Personalizada',
                                selectedColor: Colors.teal.shade100,
                                onSelected: (_) =>
                                    _mostrarDialogoMetaPersonalizada(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- ANILLO DE CALORÍAS ---
                  Container(
                    padding: const EdgeInsets.all(25),
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
                          width: 100,
                          height: 100,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: progresoCalorias,
                                strokeWidth: 10,
                                backgroundColor: colorCalorias.withValues(
                                  alpha: 0.2,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorCalorias,
                                ),
                              ),
                              Center(
                                child: Text(
                                  '${(progresoCalorias * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 25),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Calorías Consumidas',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$caloriasTotales',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: colorCalorias,
                                ),
                              ),
                              Text(
                                'de $metaCalorias kcal ($perfilSeleccionado)',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

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
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
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

                  const SizedBox(height: 20),
                  _construirTarjetaHidratacion(),

                  const SizedBox(height: 30),

                  // --- DESGLOSE DEL DÍA ---
                  const Text(
                    'Menú de Hoy',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),

                  if (comidasDeHoy.isEmpty)
                    const Center(
                      child: Text(
                        'No tienes comidas planeadas para hoy.\n¡Ve a "Mis Recetas", toca el calendario 📅 y organiza tu día!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, height: 1.4),
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
                          fontSize: 18,
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
}
