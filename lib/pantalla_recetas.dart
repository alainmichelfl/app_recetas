import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversor_unidades.dart';
import 'pantalla_detalle_receta.dart';
import 'pantalla_planeador.dart';
import 'pantalla_recetas_caninas.dart';
import 'servicio_ia.dart';
import 'servicio_historial_cocina.dart';
import 'menu_lateral.dart';

class PantallaRecetas extends StatefulWidget {
  const PantallaRecetas({super.key});

  @override
  State<PantallaRecetas> createState() => _PantallaRecetasState();
}

class _PantallaRecetasState extends State<PantallaRecetas> {
  List<Map<String, dynamic>> todasLasRecetas = [];
  List<Map<String, dynamic>> recetasFiltradas = [];
  Set<int> _idsCocinadas = {};
  Set<String> _titulosCocinados = {};
  bool cargando = true;

  final TextEditingController _searchController = TextEditingController();
  String categoriaSeleccionada = 'Todos';
  final List<String> categorias = [
    'Todos',
    'Desayuno',
    'Comida',
    'Cena',
    'Snack',
  ];

  @override
  void initState() {
    super.initState();
    cargarRecetas();
    _searchController.addListener(_filtrarRecetas);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> cargarRecetas() async {
    setState(() => cargando = true);
    try {
      final ids = await ServicioHistorialCocina.obtenerIdsCocinadas();
      final tits = await ServicioHistorialCocina.obtenerTitulosCocinadas();
      final respuesta = await Supabase.instance.client
          .from('recetas')
          .select()
          .neq('tipo_comida', 'Premio Perruno')
          .order('id_receta', ascending: false);

      if (!mounted) return;
      setState(() {
        todasLasRecetas = List<Map<String, dynamic>>.from(respuesta);
        recetasFiltradas = todasLasRecetas;
        _idsCocinadas = ids;
        _titulosCocinados = tits;
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar recetas: $e');
      if (mounted) setState(() => cargando = false);
    }
  }

  void _filtrarRecetas() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      recetasFiltradas = todasLasRecetas.where((receta) {
        final titulo = receta['titulo']?.toString().toLowerCase() ?? '';
        final descripcion =
            receta['descripcion']?.toString().toLowerCase() ?? '';
        final tipo = receta['tipo_comida']?.toString() ?? '';

        final coincideTexto = query.isEmpty ||
            titulo.contains(query) ||
            descripcion.contains(query);
        final coincideCategoria =
            categoriaSeleccionada == 'Todos' || tipo == categoriaSeleccionada;

        return coincideTexto && coincideCategoria;
      }).toList();
    });
  }

  // 📅 AGREGAR RECETA DIRECTO AL PLANEADOR SEMANAL
  Future<void> _programarEnPlaneador(
    int idReceta,
    String titulo,
    String tipoReceta,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ahora = DateTime.now();

    final DateTime? fechaSeleccionada = await showDatePicker(
      context: context,
      initialDate: ahora,
      firstDate: ahora.subtract(const Duration(days: 1)),
      lastDate: ahora.add(const Duration(days: 30)),
      helpText: 'PROGRAMAR PARA ESTE DÍA',
      confirmText: 'AGREGAR',
      cancelText: 'CANCELAR',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.orange[800]!,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaSeleccionada == null) return;

    final fechaTexto = fechaSeleccionada.toIso8601String().split('T')[0];

    // Asegurar un tipo válido para evitar restricciones NOT NULL
    final String tipoValido =
        ['Desayuno', 'Comida', 'Cena', 'Snack'].contains(tipoReceta)
        ? tipoReceta
        : 'Comida';

    try {
      await Supabase.instance.client.from('planeador').insert({
        'id_receta': idReceta,
        'fecha': fechaTexto,
        'tipo_comida': tipoValido,
      });

      final bool yaCocino =
          (idReceta > 0 && _idsCocinadas.contains(idReceta)) ||
          _titulosCocinados.contains(titulo.toLowerCase().trim());

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            yaCocino
                ? '¡Aviso: "$titulo" (ya preparada anteriormente) agendada para el $fechaTexto ($tipoValido)! 👨‍🍳📅'
                : '¡"$titulo" agendada para el $fechaTexto ($tipoValido)! 📅✨',
          ),
          backgroundColor: yaCocino ? Colors.green.shade800 : Colors.teal,
        ),
      );
    } catch (e) {
      debugPrint('Error al agendar en planeador: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo programar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmarSaneamientoConIA() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_fix_high, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(child: Text('Pulir con IA ✨')),
          ],
        ),
        content: const Text(
          'Gemini revisará una por una las descripciones para corregir ortografía y formato.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[800],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _ejecutarSaneamiento();
            },
            child: const Text('Comenzar'),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarSaneamiento() async {
    final supabase = Supabase.instance.client;
    final messenger = ScaffoldMessenger.of(context);

    final listaRes = await supabase
        .from('recetas')
        .select('id_receta, titulo, descripcion')
        .order('id_receta', ascending: true);

    final List<Map<String, dynamic>> recetasParaLimpiar =
        List<Map<String, dynamic>>.from(listaRes);

    if (recetasParaLimpiar.isEmpty || !mounted) return;

    int actual = 0;
    String nombreActual = '';
    bool cancelado = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progresoCtx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            void iniciarProceso() async {
              for (var i = 0; i < recetasParaLimpiar.length; i++) {
                if (cancelado) break;

                final r = recetasParaLimpiar[i];
                final int id = r['id_receta'];
                final String titulo = r['titulo'] ?? '';
                final String desc = r['descripcion'] ?? '';

                setStateModal(() {
                  actual = i + 1;
                  nombreActual = titulo;
                });

                if (desc.trim().isNotEmpty) {
                  final descPulida =
                      await ServicioIA.pulirOrtografiaYFormatoReceta(desc);

                  if (descPulida != null && descPulida.isNotEmpty) {
                    await supabase
                        .from('recetas')
                        .update({'descripcion': descPulida})
                        .eq('id_receta', id);

                    try {
                      await ConversorUnidades.sincronizarIngredientesDeTexto(
                        supabase,
                        id,
                        descPulida,
                      );
                    } catch (e) {
                      debugPrint('Error al auto-sincronizar ingredientes: $e');
                    }
                  }
                }

                await Future.delayed(const Duration(milliseconds: 4100));
              }

              if (context.mounted) Navigator.pop(progresoCtx);
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (actual == 0) iniciarProceso();
            });

            final double progreso = recetasParaLimpiar.isEmpty
                ? 0.0
                : (actual / recetasParaLimpiar.length);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.auto_fix_high, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(child: Text('Perfeccionando Recetas')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progreso,
                    color: Colors.orange,
                    backgroundColor: Colors.orange.shade100,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Receta $actual de ${recetasParaLimpiar.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    nombreActual.isNotEmpty
                        ? 'Procesando: $nombreActual'
                        : 'Preparando...',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelado = true;
                    Navigator.pop(progresoCtx);
                  },
                  child: const Text(
                    'Detener',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    await cargarRecetas();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('¡Recetas pulidas y sincronizadas con éxito! ✨📦'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _confirmarMigracionRelacional() {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.teal),
            SizedBox(width: 10),
            Expanded(child: Text('Sincronizar Ingredientes 📦')),
          ],
        ),
        content: const Text(
          'Estructurará y asegurará que todos los ingredientes de todas tus recetas estén registrados en "ingredientes_genericos" y vinculados en "receta_detalle" con sus cantidades y precios comerciales.\n\n'
          '⚡ Proceso automático y ultrarrápido con el conversor inteligente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              _ejecutarMigracionRelacional();
            },
            child: const Text('Iniciar Sincronización'),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarMigracionRelacional() async {
    final supabase = Supabase.instance.client;
    final messenger = ScaffoldMessenger.of(context);

    final listaRes = await supabase
        .from('recetas')
        .select('id_receta, titulo, descripcion')
        .order('id_receta', ascending: true);

    final List<Map<String, dynamic>> recetas = List<Map<String, dynamic>>.from(
      listaRes,
    );

    if (recetas.isEmpty || !mounted) return;

    int actual = 0;
    String nombreActual = '';
    int totalIngredientesInsertados = 0;
    int totalRecetasExitosas = 0;
    bool cancelado = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (progresoCtx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            void iniciarProceso() async {
              for (var i = 0; i < recetas.length; i++) {
                if (cancelado) break;

                final r = recetas[i];
                final int id = r['id_receta'];
                final String titulo = r['titulo'] ?? '';
                final String desc = r['descripcion'] ?? '';

                setStateModal(() {
                  actual = i + 1;
                  nombreActual = titulo;
                });

                if (desc.trim().isNotEmpty) {
                  try {
                    final insertados =
                        await ConversorUnidades.sincronizarIngredientesDeTexto(
                      supabase,
                      id,
                      desc,
                    );
                    totalIngredientesInsertados += insertados;
                    totalRecetasExitosas++;
                  } catch (e) {
                    debugPrint('Error sincronizando receta $id: $e');
                  }
                }

                await Future.delayed(const Duration(milliseconds: 30));
              }

              if (context.mounted) Navigator.pop(progresoCtx);
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (actual == 0) iniciarProceso();
            });

            final double progreso = recetas.isEmpty
                ? 0.0
                : (actual / recetas.length);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: Colors.teal),
                  SizedBox(width: 10),
                  Expanded(child: Text('Sincronizando Ingredientes')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progreso,
                    color: Colors.teal,
                    backgroundColor: Colors.teal.shade100,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    'Receta $actual de ${recetas.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    nombreActual.isNotEmpty
                        ? 'Procesando: $nombreActual'
                        : 'Preparando...',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    cancelado = true;
                    Navigator.pop(progresoCtx);
                  },
                  child: const Text(
                    'Detener',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '¡Sincronización completa! $totalRecetasExitosas recetas verificadas con $totalIngredientesInsertados nuevos ingredientes vinculados. 📦✨',
        ),
        backgroundColor: Colors.teal,
      ),
    );
  }

  void _mostrarOpcionesAgregar() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Agregar Receta 🍳',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withValues(alpha: 0.15),
                    child: const Icon(Icons.camera_alt, color: Colors.orange),
                  ),
                  title: const Text(
                    'Tomar foto con la cámara',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Escanea una página de libro o libreta'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _procesarFotoReceta(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.photo_library,
                      color: Colors.purple,
                    ),
                  ),
                  title: const Text(
                    'Elegir foto de la galería',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Selecciona una captura o foto guardada',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _procesarFotoReceta(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withValues(alpha: 0.15),
                    child: const Icon(Icons.edit_note, color: Colors.teal),
                  ),
                  title: const Text(
                    'Escribir manualmente',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Ingresa título, tipo y pasos tú mismo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _mostrarDialogoAgregarReceta();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _procesarFotoReceta(ImageSource origen) async {
    final picker = ImagePicker();
    final XFile? foto = await picker.pickImage(
      source: origen,
      imageQuality: 85,
    );

    if (foto == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(25.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.orange),
                SizedBox(height: 15),
                Text(
                  'Digitalizando receta con IA... 🔍✨',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final bytes = await foto.readAsBytes();
      final resultado = await ServicioIA.escanearRecetaDeFoto(bytes);

      if (!mounted) return;
      Navigator.pop(context);

      if (resultado != null) {
        _mostrarDialogoAgregarReceta(
          tituloInicial: resultado['titulo']?.toString() ?? '',
          tipoInicial: resultado['tipo_comida']?.toString() ?? 'Comida',
          descInicial: resultado['descripcion']?.toString() ?? '',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos leer la receta de la imagen.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      debugPrint('Error procesando imagen: $e');
    }
  }

  void _mostrarDialogoAgregarReceta({
    String tituloInicial = '',
    String tipoInicial = 'Comida',
    String descInicial = '',
  }) {
    final titleController = TextEditingController(text: tituloInicial);
    String tipoSeleccionado =
        ['Desayuno', 'Comida', 'Cena', 'Snack'].contains(tipoInicial)
        ? tipoInicial
        : 'Comida';
    final descController = TextEditingController(text: descInicial);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            tituloInicial.isEmpty
                ? 'Nueva Receta 🍳'
                : 'Revisar Receta Escaneada 📖',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título de la receta',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipoSeleccionado,
                  items: ['Desayuno', 'Comida', 'Cena', 'Snack']
                      .map(
                        (tipo) =>
                            DropdownMenuItem(value: tipo, child: Text(tipo)),
                      )
                      .toList(),
                  onChanged: (val) => tipoSeleccionado = val ?? 'Comida',
                  decoration: const InputDecoration(
                    labelText: 'Tipo de comida',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Instrucciones / Descripción',
                    hintText: 'PORCIONES: 2\n\n📝 INGREDIENTES:\n- ...\n\n🍳 INSTRUCCIONES:\n1. ...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;

                Navigator.pop(dialogContext);

                final descripcionLimpia = descController.text
                    .replaceFirst(
                      RegExp(
                        r'^\s*TÍTULO:[^\r\n]*[\r\n]*',
                        caseSensitive: false,
                      ),
                      '',
                    )
                    .trim();

                try {
                  await Supabase.instance.client.from('recetas').insert({
                    'titulo': titleController.text.trim(),
                    'tipo_comida': tipoSeleccionado,
                    'descripcion': descripcionLimpia,
                  });

                  if (!mounted) return;
                  cargarRecetas();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Receta agregada con éxito! ✨'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  debugPrint('Error al guardar receta: $e');
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const MenuLateral(rutaActual: 'recetas'),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú principal',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Mis Recetas 📖',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Planeador Semanal 📅',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PantallaPlaneador(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.pets),
            tooltip: 'Recetario Canino 🐾',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PantallaRecetasCaninas(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'sanitizar') {
                _confirmarSaneamientoConIA();
              } else if (val == 'migrar_relacional') {
                _confirmarMigracionRelacional();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'sanitizar',
                child: Row(
                  children: [
                    Icon(Icons.auto_fix_high, color: Colors.orange),
                    SizedBox(width: 10),
                    Text('Pulir ortografía y formato ✨'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'migrar_relacional',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: Colors.teal),
                    SizedBox(width: 10),
                    Text('Sincronizar Ingredientes en BD 📦'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarOpcionesAgregar,
        backgroundColor: Colors.orange[800],
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar receta por nombre...',
                    prefixIcon: const Icon(Icons.search, color: Colors.orange),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filtrarRecetas();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: categorias.map((cat) {
                      final bool seleccionado = categoriaSeleccionada == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: seleccionado,
                          selectedColor: Colors.orange[200],
                          backgroundColor: Colors.grey[200],
                          labelStyle: TextStyle(
                            color: seleccionado
                                ? Colors.orange[900]
                                : Colors.black87,
                            fontWeight: seleccionado
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (bool valor) {
                            if (valor) {
                              setState(() => categoriaSeleccionada = cat);
                              _filtrarRecetas();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cargando
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.orange),
                  )
                : recetasFiltradas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 70,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No se encontraron recetas',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: recetasFiltradas.length,
                    itemBuilder: (context, index) {
                      final receta = recetasFiltradas[index];
                      final titulo = receta['titulo'] ?? 'Sin título';
                      final imagen = receta['imagen_url'];
                      final tipo = receta['tipo_comida'] ?? 'General';
                      final descripcion =
                          receta['descripcion'] ??
                          receta['instrucciones'] ??
                          '';
                      final id = receta['id_receta'];
                      final int idInt = id is int
                          ? id
                          : (int.tryParse(id?.toString() ?? '0') ?? 0);
                      final bool fueCocinada = (idInt > 0 &&
                              _idsCocinadas.contains(idInt)) ||
                          _titulosCocinados
                              .contains(titulo.toString().toLowerCase().trim());

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: fueCocinada
                                ? Colors.green.shade300
                                : Colors.grey.shade200,
                            width: fueCocinada ? 1.5 : 1.0,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(10),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child:
                                imagen != null && imagen.toString().isNotEmpty
                                ? Image.network(
                                    imagen,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        child: const Icon(
                                          Icons.restaurant,
                                          color: Colors.orange,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    child: const Icon(
                                      Icons.restaurant,
                                      color: Colors.orange,
                                    ),
                                  ),
                          ),
                          title: Text(
                            titulo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tipo,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange[800],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (fueCocinada)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.shade400,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.soup_kitchen,
                                            size: 11,
                                            color: Colors.green.shade800,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Preparada',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green.shade800,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (receta['calorias'] != null &&
                                      (receta['calorias'] as num) > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${receta['calorias']} kcal',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.teal[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.event_available,
                                  color: Colors.teal,
                                ),
                                tooltip: 'Programar en Planeador',
                                onPressed: () =>
                                    _programarEnPlaneador(id, titulo, tipo),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PantallaDetalleReceta(
                                  idReceta: id,
                                  titulo: titulo,
                                  descripcion: descripcion,
                                  imagenUrl: imagen,
                                ),
                              ),
                            );
                            final ids =
                                await ServicioHistorialCocina.obtenerIdsCocinadas();
                            final tits =
                                await ServicioHistorialCocina.obtenerTitulosCocinadas();
                            if (mounted) {
                              setState(() {
                                _idsCocinadas = ids;
                                _titulosCocinados = tits;
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
