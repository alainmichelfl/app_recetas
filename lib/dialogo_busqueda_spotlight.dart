import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pantalla_detalle_receta.dart';
import 'servicio_busqueda_spotlight.dart';
import 'servicio_zonas_despensa.dart';

class DialogoBusquedaSpotlight extends StatefulWidget {
  final List<Map<String, dynamic>>? recetasIniciales;
  final List<Map<String, dynamic>>? despensaInicial;

  const DialogoBusquedaSpotlight({
    super.key,
    this.recetasIniciales,
    this.despensaInicial,
  });

  static Future<void> mostrar(
    BuildContext context, {
    List<Map<String, dynamic>>? recetas,
    List<Map<String, dynamic>>? despensa,
  }) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => DialogoBusquedaSpotlight(
        recetasIniciales: recetas,
        despensaInicial: despensa,
      ),
    );
  }

  @override
  State<DialogoBusquedaSpotlight> createState() =>
      _DialogoBusquedaSpotlightState();
}

class _DialogoBusquedaSpotlightState extends State<DialogoBusquedaSpotlight> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _recetas = [];
  List<Map<String, dynamic>> _despensa = [];
  Map<String, String> _overridesZonas = {};
  bool _cargandoDatos = false;
  String _filtroTipo = 'todos'; // 'todos', 'receta', 'despensa', 'cava', 'utensilio'
  List<ResultadoSpotlight> _resultados = [];

  @override
  void initState() {
    super.initState();
    if (widget.recetasIniciales != null) {
      _recetas = widget.recetasIniciales!;
    }
    if (widget.despensaInicial != null) {
      _despensa = widget.despensaInicial!;
    }
    _inicializarDatos();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _inicializarDatos() async {
    try {
      final overrides = await ServicioZonasDespensa.obtenerOverrides();
      if (mounted) {
        setState(() => _overridesZonas = overrides);
      }

      if (_recetas.isEmpty || _despensa.isEmpty) {
        setState(() => _cargandoDatos = true);
        final sb = Supabase.instance.client;

        final futures = await Future.wait([
          if (_recetas.isEmpty)
            sb.from('recetas').select('id, titulo, descripcion, categoria, tiempo_preparacion').limit(150),
          if (_despensa.isEmpty)
            sb.from('despensa_usuario').select('id_item, nombre, cantidad, unidad_medida').limit(150),
        ]);

        if (mounted) {
          setState(() {
            int idx = 0;
            if (_recetas.isEmpty && futures.isNotEmpty) {
              _recetas = List<Map<String, dynamic>>.from(futures[idx++] as List);
            }
            if (_despensa.isEmpty && futures.length > idx) {
              _despensa = List<Map<String, dynamic>>.from(futures[idx] as List);
            }
            _cargandoDatos = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error inicializando spotlight: $e');
      if (mounted) setState(() => _cargandoDatos = false);
    }
  }

  void _ejecutarBusqueda(String q) {
    if (q.trim().length < 2) {
      setState(() => _resultados = []);
      return;
    }

    final res = ServicioBusquedaSpotlight.buscar(
      query: q,
      recetas: _recetas,
      despensa: _despensa,
      zonaOverrides: _overridesZonas,
    );

    setState(() => _resultados = res);
  }

  List<ResultadoSpotlight> get _resultadosFiltrados {
    if (_filtroTipo == 'todos') return _resultados;
    return _resultados.where((r) => r.tipo.name == _filtroTipo).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool esOscuro = Theme.of(context).brightness == Brightness.dark;
    final Color fondo = esOscuro ? const Color(0xFF1E2022) : Colors.white;

    return Dialog(
      backgroundColor: fondo,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra de búsqueda superior
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Colors.deepOrange, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: esOscuro ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Buscar recetas, despensa, cava o utensilios...',
                        hintStyle: TextStyle(
                          color: esOscuro ? Colors.white38 : Colors.grey.shade500,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: _ejecutarBusqueda,
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 20),
                      onPressed: () {
                        _ctrl.clear();
                        _ejecutarBusqueda('');
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Chips de filtrado transversal
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  _chipTipo('todos', 'Todos'),
                  _chipTipo('receta', '📖 Recetas'),
                  _chipTipo('despensa', '🥫 Despensa'),
                  _chipTipo('cava', '🍷 Cava & Bar'),
                  _chipTipo('utensilio', '🍳 Utensilios'),
                ],
              ),
            ),

            // Cuerpo de resultados o recomendaciones
            Expanded(
              child: _cargandoDatos
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.deepOrange),
                    )
                  : _ctrl.text.trim().length < 2
                      ? _construirSugerenciasIniciales()
                      : _resultadosFiltrados.isEmpty
                          ? _construirSinResultados()
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              itemCount: _resultadosFiltrados.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1, indent: 60),
                              itemBuilder: (ctx, i) {
                                final item = _resultadosFiltrados[i];
                                return _construirTileResultado(item);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipTipo(String clave, String texto) {
    final bool seleccionado = _filtroTipo == clave;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(texto),
        selected: seleccionado,
        selectedColor: Colors.deepOrange.shade100,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
          color: seleccionado ? Colors.deepOrange.shade900 : Colors.grey.shade700,
        ),
        onSelected: (val) {
          if (val) setState(() => _filtroTipo = clave);
        },
      ),
    );
  }

  Widget _construirSugerenciasIniciales() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 44,
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Búsqueda Global Spotlight',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Encuentra platillos, insumos en tu refrigerador o alacena,\nbotellas de tu cava y utensilios en un solo lugar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _sugerenciaBoton('Pollo'),
                _sugerenciaBoton('Jitomate'),
                _sugerenciaBoton('Airfryer'),
                _sugerenciaBoton('Vino'),
                _sugerenciaBoton('Tacos'),
                _sugerenciaBoton('Batidora'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sugerenciaBoton(String termino) {
    return ActionChip(
      avatar: const Icon(Icons.search, size: 14, color: Colors.deepOrange),
      label: Text(termino),
      onPressed: () {
        _ctrl.text = termino;
        _ejecutarBusqueda(termino);
      },
    );
  }

  Widget _construirSinResultados() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No se encontraron resultados para "${_ctrl.text}"',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Intenta buscar otro ingrediente, categoría o electrodoméstico.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirTileResultado(ResultadoSpotlight item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(item.icono, color: item.color, size: 22),
      ),
      title: Text(
        item.titulo,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        item.subtitulo,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          item.tipo.etiqueta,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: item.color,
          ),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        if (item.tipo == TipoResultadoSpotlight.receta) {
          final idReceta = item.metadata['id'] ?? item.metadata['id_receta'];
          if (idReceta != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PantallaDetalleReceta(
                  idReceta: idReceta as int,
                  titulo: item.titulo,
                  descripcion: item.subtitulo,
                  imagenUrl: item.metadata['imagen_url']?.toString(),
                ),
              ),
            );
          }
        } else if (item.tipo == TipoResultadoSpotlight.utensilio) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🍳 ${item.titulo}: ${item.subtitulo}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.teal.shade800,
            ),
          );
        } else {
          // Despensa o Cava
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '📍 ${item.titulo} ubicado en ${item.ubicacion ?? 'tu Despensa'}.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: item.color,
            ),
          );
        }
      },
    );
  }
}
