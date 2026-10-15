import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

import 'menu_lateral.dart';
import 'pantalla_planeador.dart';
import 'pantalla_detalle_receta.dart';
import 'servicio_historial_cocina.dart';
import 'servicio_despensa.dart';

/// Pantalla de Calendario Interactivo del Planeador de Comidas.
/// Permite al usuario visualizar sus recetas planeadas organizadas por días y meses,
/// revisar ingredientes, marcar platillos como cocinados y exportar a su calendario.
class PantallaCalendario extends StatefulWidget {
  final DateTime? fechaInicial;
  final List<dynamic>? planesIniciales;

  const PantallaCalendario({
    super.key,
    this.fechaInicial,
    this.planesIniciales,
  });

  @override
  State<PantallaCalendario> createState() => _PantallaCalendarioState();
}

class _PantallaCalendarioState extends State<PantallaCalendario> {
  late DateTime _mesVisualizado;
  late DateTime _diaSeleccionado;

  bool _cargando = true;
  String? _errorCarga;
  List<dynamic> _todosLosPlanes = [];
  Map<String, List<Map<String, dynamic>>> _planesPorFecha = {};

  Set<int> _idsCocinadas = {};
  Set<String> _titulosCocinados = {};

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _diaSeleccionado = widget.fechaInicial ?? DateTime(hoy.year, hoy.month, hoy.day);
    _mesVisualizado = DateTime(_diaSeleccionado.year, _diaSeleccionado.month, 1);

    if (widget.planesIniciales != null && widget.planesIniciales!.isNotEmpty) {
      _procesarPlanes(widget.planesIniciales!);
      _cargando = false;
      _cargarDatos(silencioso: true);
    } else {
      _cargarDatos();
    }
  }

  static const List<String> _meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static const List<String> _diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  String _formatoFechaClave(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatoMesAno(DateTime dt) {
    final mes = _meses[dt.month - 1];
    return '$mes ${dt.year}';
  }

  String _formatoDiaCompleto(DateTime dt) {
    final diaSemana = _diasSemana[dt.weekday - 1];
    final mes = _meses[dt.month - 1];
    return '$diaSemana ${dt.day} de $mes';
  }

  static Map<String, dynamic> _obtenerRecetaSegura(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is List && raw.isNotEmpty && raw.first is Map) {
      return Map<String, dynamic>.from(raw.first);
    }
    return {};
  }

  static String _normalizarClaveFecha(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString().trim();
    if (s.isEmpty) return '';
    if (s.contains('T')) return s.split('T')[0].trim();
    if (s.contains(' ')) return s.split(' ')[0].trim();
    return s;
  }

  void _procesarPlanes(List<dynamic> planes) {
    final Map<String, List<Map<String, dynamic>>> agrupados = {};
    for (final raw in planes) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final rawFecha = item['fecha'];
      final f = _normalizarClaveFecha(rawFecha);
      if (f.isNotEmpty) {
        agrupados.putIfAbsent(f, () => []).add(item);
      }
    }
    _todosLosPlanes = planes;
    _planesPorFecha = agrupados;
  }

  Future<void> _cargarDatos({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _errorCarga = null;
      });
    }
    try {
      final ids = await ServicioHistorialCocina.obtenerIdsCocinadas();
      final tits = await ServicioHistorialCocina.obtenerTitulosCocinadas();

      final respuesta = await Supabase.instance.client
          .from('planeador')
          .select(
            'id_planeador, fecha, tipo_comida, id_receta, recetas(titulo, imagen_url, instrucciones, descripcion, calorias)',
          )
          .order('fecha', ascending: true);

      if (!mounted) return;
      setState(() {
        _procesarPlanes(respuesta);
        _idsCocinadas = ids;
        _titulosCocinados = tits;
        _cargando = false;
        _errorCarga = null;
      });
    } catch (e) {
      debugPrint('Error al cargar datos en calendario: $e');
      if (mounted) {
        setState(() {
          _errorCarga = e.toString();
          _cargando = false;
        });
      }
    }
  }

  void _cambiarMes(int offset) {
    setState(() {
      _mesVisualizado = DateTime(
        _mesVisualizado.year,
        _mesVisualizado.month + offset,
        1,
      );
    });
    _cargarDatos();
  }

  void _irAHoy() {
    final hoy = DateTime.now();
    setState(() {
      _diaSeleccionado = DateTime(hoy.year, hoy.month, hoy.day);
      _mesVisualizado = DateTime(hoy.year, hoy.month, 1);
    });
    _cargarDatos();
  }

  Color _colorTipoComida(String? tipo) {
    switch (tipo) {
      case 'Desayuno':
        return Colors.orange;
      case 'Comida':
        return Colors.green.shade700;
      case 'Snack':
        return Colors.redAccent;
      case 'Cena':
        return Colors.indigo;
      default:
        return Colors.teal;
    }
  }

  String _iconoTipoComida(String? tipo) {
    switch (tipo) {
      case 'Desayuno':
        return '🍳';
      case 'Comida':
        return '🍲';
      case 'Snack':
        return '🍎';
      case 'Cena':
        return '🌙';
      default:
        return '🍽️';
    }
  }

  Future<void> _marcarRecetaComoCocinada({
    required int idPlaneador,
    required int idReceta,
    required String titulo,
    required String textoReceta,
  }) async {
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.soup_kitchen, color: Colors.green),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '¡Cocinaste este platillo! 👨‍🍳🔥',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          '¿Deseas registrar "$titulo" como ya preparada y descontar automáticamente sus ingredientes de tu Despensa?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancelar'),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'solo_marcar'),
            child: const Text('Solo marcar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, 'marcar_y_descontar'),
            child: const Text('Marcar y descontar'),
          ),
        ],
      ),
    );

    if (resultado == null || resultado == 'cancelar' || !mounted) return;

    try {
      await ServicioHistorialCocina.marcarComoCocinada(
        idReceta: idReceta,
        titulo: titulo,
        origen: 'calendario',
      );

      List<String> descontados = [];
      if (resultado == 'marcar_y_descontar' && textoReceta.isNotEmpty) {
        descontados = await ServicioDespensa.descontarIngredientesDeReceta(
          idReceta: idReceta,
          descripcionReceta: textoReceta,
        );
      }

      await _cargarDatos();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            descontados.isNotEmpty
                ? '¡"$titulo" registrada! Se descontaron ${descontados.length} ingredientes de tu Despensa.'
                : '¡"$titulo" registrada como ya cocinada! 🍲✨',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      debugPrint('Error al marcar plato como cocinado: $e');
    }
  }

  void _exportarAlCalendarioNativo(Map<String, dynamic> item) {
    try {
      final receta = _obtenerRecetaSegura(item['recetas']);
      final titulo = (receta['titulo'] ?? 'Receta').toString();
      final tipo = (item['tipo_comida'] ?? 'Comida').toString();
      final fechaStr = (item['fecha'] ?? '').toString();

      final fecha = DateTime.tryParse(fechaStr) ?? DateTime.now();
      int hora = 14;
      if (tipo == 'Desayuno') hora = 9;
      if (tipo == 'Cena') hora = 20;
      if (tipo == 'Snack') hora = 17;

      final inicio = DateTime(fecha.year, fecha.month, fecha.day, hora, 0);
      final fin = inicio.add(const Duration(hours: 1));

      final Event evento = Event(
        title: '👨‍🍳 Cocinar: $titulo ($tipo)',
        description:
            'Platillo planeado desde Jitomate y Cebolla.\nCalorías: ${receta['calorias'] ?? "N/A"} kcal\n${receta['descripcion'] ?? ""}',
        location: 'Mi Cocina',
        startDate: inicio,
        endDate: fin,
        allDay: false,
      );

      Add2Calendar.addEvent2Cal(evento);
    } catch (e) {
      debugPrint('Error al exportar evento a calendario: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar el evento: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final fechaHoyClave = _formatoFechaClave(hoy);
    final fechaSeleccionadaClave = _formatoFechaClave(_diaSeleccionado);
    final comidasDia = _planesPorFecha[fechaSeleccionadaClave] ?? [];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      drawer: const MenuLateral(rutaActual: 'calendario'),
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Regresar',
                onPressed: () => Navigator.pop(context),
              )
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Menú principal',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: const Text(
          'Calendario de Comidas 📅',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (Navigator.canPop(context))
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Menú principal',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Ir a Hoy',
            onPressed: _irAHoy,
          ),
          IconButton(
            icon: const Icon(Icons.view_list_rounded),
            tooltip: 'Ver Planeador por Tiempos',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const PantallaPlaneador()),
              );
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            )
          : _errorCarga != null && _todosLosPlanes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_month, size: 54, color: Colors.teal),
                        const SizedBox(height: 14),
                        const Text(
                          'No se pudieron cargar los datos del calendario',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorCarga!,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _cargarDatos(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
              color: Colors.teal,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🗓️ 1. BARRA DE CONTROL DEL MES
                    _construirBarraControlMes(),
                    const SizedBox(height: 12),

                    // 📆 2. CUADRÍCULA DE CALENDARIO MENSUAL
                    _construirCuadriculaCalendario(fechaHoyClave, fechaSeleccionadaClave),
                    const SizedBox(height: 14),

                    // 🏷️ 3. LEYENDA RÁPIDA DE TIEMPOS DE COMIDA
                    _construirLeyendaTiempos(),
                    const SizedBox(height: 16),

                    // 🍽️ 4. DETALLE DEL DÍA SELECCIONADO
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatoDiaCompleto(_diaSeleccionado).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                '${comidasDia.length} ${comidasDia.length == 1 ? "platillo planeado" : "platillos planeados"}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (comidasDia.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              for (final item in comidasDia) {
                                _exportarAlCalendarioNativo(item);
                              }
                            },
                            icon: const Icon(Icons.event_available, size: 16, color: Colors.teal),
                            label: const Text(
                              'Exportar día',
                              style: TextStyle(fontSize: 12, color: Colors.teal),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Lista de comidas del día seleccionado
                    if (comidasDia.isEmpty)
                      _construirDiaVacio()
                    else
                      ...comidasDia.map((item) => _construirTarjetaComidaDia(item)),

                    const SizedBox(height: 24),

                    // 📊 5. TARJETA RESUMEN MENSUAL Y ACCESO RÁPIDO AL PLANEADOR
                    _construirTarjetaResumenMensual(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _construirBarraControlMes() {
    final capitalizado = _formatoMesAno(_mesVisualizado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            color: Colors.teal.shade800,
            tooltip: 'Mes anterior',
            onPressed: () => _cambiarMes(-1),
          ),
          Row(
            children: [
              Icon(Icons.calendar_month, color: Colors.teal.shade800, size: 20),
              const SizedBox(width: 8),
              Text(
                capitalizado,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
            color: Colors.teal.shade800,
            tooltip: 'Mes siguiente',
            onPressed: () => _cambiarMes(1),
          ),
        ],
      ),
    );
  }

  Widget _construirCuadriculaCalendario(String fechaHoyClave, String fechaSeleccionadaClave) {
    const diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    // Días del mes actual
    final primerDiaMes = DateTime(_mesVisualizado.year, _mesVisualizado.month, 1);
    final ultimoDiaMes = DateTime(_mesVisualizado.year, _mesVisualizado.month + 1, 0);

    // Ajustar para empezar en Lunes (1 = Lunes, 7 = Domingo)
    final diaSemanaInicio = primerDiaMes.weekday; // 1 to 7
    final celdasVaciasInicio = diaSemanaInicio - 1;

    final totalDias = ultimoDiaMes.day;
    final totalCeldas = celdasVaciasInicio + totalDias;
    final filasNecesarias = (totalCeldas / 7).ceil();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabecera con días de la semana
          Row(
            children: diasSemana.map((dia) {
              final esFinde = dia == 'Sáb' || dia == 'Dom';
              return Expanded(
                child: Center(
                  child: Text(
                    dia,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: esFinde ? Colors.orange.shade800 : Colors.blueGrey.shade600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),

          // Cuadrícula de días
          for (int f = 0; f < filasNecesarias; f++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  for (int c = 0; c < 7; c++) ...[
                    Expanded(
                      child: _construirCeldaDia(
                        indiceFila: f,
                        indiceColumna: c,
                        celdasVaciasInicio: celdasVaciasInicio,
                        totalDias: totalDias,
                        fechaHoyClave: fechaHoyClave,
                        fechaSeleccionadaClave: fechaSeleccionadaClave,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirCeldaDia({
    required int indiceFila,
    required int indiceColumna,
    required int celdasVaciasInicio,
    required int totalDias,
    required String fechaHoyClave,
    required String fechaSeleccionadaClave,
  }) {
    final indiceTotal = (indiceFila * 7) + indiceColumna;
    final numeroDia = indiceTotal - celdasVaciasInicio + 1;

    if (numeroDia < 1 || numeroDia > totalDias) {
      return const SizedBox(height: 48);
    }

    final fechaDia = DateTime(_mesVisualizado.year, _mesVisualizado.month, numeroDia);
    final claveDia = _formatoFechaClave(fechaDia);
    final esHoy = claveDia == fechaHoyClave;
    final esSeleccionado = claveDia == fechaSeleccionadaClave;

    final comidas = _planesPorFecha[claveDia] ?? [];
    final tieneComidas = comidas.isNotEmpty;

    return InkWell(
      onTap: () {
        setState(() => _diaSeleccionado = fechaDia);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: esSeleccionado
              ? Colors.teal.shade700
              : (esHoy ? Colors.teal.shade50 : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: esSeleccionado
                ? Colors.teal.shade800
                : (esHoy ? Colors.teal.shade300 : Colors.transparent),
            width: esHoy ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$numeroDia',
              style: TextStyle(
                fontSize: 13,
                fontWeight: (esHoy || esSeleccionado) ? FontWeight.bold : FontWeight.w500,
                color: esSeleccionado
                    ? Colors.white
                    : (esHoy ? Colors.teal.shade900 : Colors.black87),
              ),
            ),
            const SizedBox(height: 3),
            if (tieneComidas)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: comidas.take(4).map((c) {
                  final tipo = c['tipo_comida']?.toString();
                  return Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: esSeleccionado ? Colors.white : _colorTipoComida(tipo),
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _construirLeyendaTiempos() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _indicadorLeyenda('Desayuno', Colors.orange, '🍳'),
          _indicadorLeyenda('Comida', Colors.green.shade700, '🍲'),
          _indicadorLeyenda('Snack', Colors.redAccent, '🍎'),
          _indicadorLeyenda('Cena', Colors.indigo, '🌙'),
        ],
      ),
    );
  }

  Widget _indicadorLeyenda(String etiqueta, Color color, String icono) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _construirDiaVacio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_outlined, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Text(
            'Sin comidas planeadas para este día',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Usa el planeador o Chef IA para llenar tu semana con recetas deliciosas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PantallaPlaneador()),
              );
            },
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Planear en Mi Planeador'),
          ),
        ],
      ),
    );
  }

  Widget _construirTarjetaComidaDia(Map<String, dynamic> item) {
    final receta = _obtenerRecetaSegura(item['recetas']);
    final idPlaneador = int.tryParse(item['id_planeador']?.toString() ?? '0') ?? 0;
    final idReceta = int.tryParse(item['id_receta']?.toString() ?? '0') ?? 0;
    final tipoComida = (item['tipo_comida'] ?? 'Comida').toString();
    final titulo = (receta['titulo'] ?? 'Receta sin título').toString();
    final calorias = int.tryParse(receta['calorias']?.toString() ?? '0') ?? 0;
    final imagen = receta['imagen_url']?.toString();
    final instrucciones = (receta['instrucciones'] ?? '').toString();
    final macros = (receta['macros'] ?? '').toString();

    final bool fueCocinada = (idReceta > 0 && _idsCocinadas.contains(idReceta)) ||
        _titulosCocinados.contains(titulo.toLowerCase().trim());

    final colorTema = _colorTipoComida(tipoComida);
    final icono = _iconoTipoComida(tipoComida);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: fueCocinada ? Colors.green.shade300 : Colors.grey.shade200,
          width: fueCocinada ? 1.5 : 1,
        ),
      ),
      color: fueCocinada ? Colors.green.shade50.withValues(alpha: 0.5) : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imagen != null && imagen.isNotEmpty
              ? Image.network(
                  imagen,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    width: 50,
                    height: 50,
                    color: colorTema.withValues(alpha: 0.15),
                    child: Center(
                      child: Text(icono, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                )
              : Container(
                  width: 50,
                  height: 50,
                  color: colorTema.withValues(alpha: 0.15),
                  child: Center(
                    child: Text(icono, style: const TextStyle(fontSize: 22)),
                  ),
                ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorTema.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tipoComida,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: colorTema,
                ),
              ),
            ),
            const SizedBox(width: 6),
            if (fueCocinada)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Cocinada ✅',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: fueCocinada ? Colors.green.shade900 : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                if (calorias > 0) ...[
                  Icon(Icons.local_fire_department, size: 13, color: Colors.deepOrange.shade400),
                  const SizedBox(width: 2),
                  Text(
                    '$calorias kcal',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
                if (macros.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      macros,
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                fueCocinada ? Icons.check_circle : Icons.check_circle_outline,
                color: fueCocinada ? Colors.green.shade700 : Colors.grey.shade400,
              ),
              tooltip: fueCocinada
                  ? 'Platillo ya cocinado'
                  : 'Marcar como cocinada y descontar despensa',
              onPressed: () => _marcarRecetaComoCocinada(
                idPlaneador: idPlaneador,
                idReceta: idReceta,
                titulo: titulo,
                textoReceta: instrucciones,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              tooltip: 'Ver detalle',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PantallaDetalleReceta(
                      idReceta: idReceta,
                      titulo: titulo,
                      descripcion: (receta['descripcion'] ?? '').toString(),
                      imagenUrl: imagen,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirTarjetaResumenMensual() {
    final diasConComida = _planesPorFecha.keys.length;
    final totalPlatillos = _todosLosPlanes.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade700, Colors.teal.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.3),
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
              Icon(Icons.insights, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Resumen de tu Mes Culinario 📈',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _metricaResumen('$diasConComida', 'Días con plan'),
              Container(width: 1, height: 35, color: Colors.white24),
              _metricaResumen('$totalPlatillos', 'Platillos listos'),
              Container(width: 1, height: 35, color: Colors.white24),
              _metricaResumen('${_idsCocinadas.length}', 'Cocinadas 🔥'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.teal.shade900,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PantallaPlaneador()),
                );
              },
              icon: const Icon(Icons.calendar_view_week, size: 18),
              label: const Text(
                'Ir a Mi Planeador (Por categorías)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricaResumen(String valor, String etiqueta) {
    return Column(
      children: [
        Text(
          valor,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          etiqueta,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }
}
