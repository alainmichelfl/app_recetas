import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversor_unidades.dart';
import 'menu_lateral.dart';
import 'servicio_cotizador.dart';
import 'servicio_ia.dart';
import 'servicio_preferencias.dart';

class PantallaFinanzas extends StatefulWidget {
  final double? presupuestoSuperExterno;
  final String? supermercadoElegido;

  const PantallaFinanzas({
    super.key,
    this.presupuestoSuperExterno,
    this.supermercadoElegido,
  });

  @override
  State<PantallaFinanzas> createState() => _PantallaFinanzasState();
}

class _PantallaFinanzasState extends State<PantallaFinanzas> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _cargando = true;
  PreferenciasUsuario? _preferencias;

  // Presupuesto y Cotización
  double _presupuestoSemanal = 1500.0;
  String _superFavorito = 'Walmart';
  CotizacionSupermercado? _cotizacionElegida;
  CotizacionSupermercado? _cotizacionCentralAbasto;
  double _costoSemanaActual = 0.0;

  // Métricas del Planeador y ROI
  int _comidasPlaneadas = 0;
  double _costoPorPlatillo = 0.0;
  double _ahorroVsRestaurantes = 0.0;

  // Desglose por departamento
  Map<String, double> _gastoPorDepartamento = {};
  double _totalGastoDepartamentos = 0.0;

  // Despensa
  double _capitalDespensa = 0.0;
  int _totalItemsDespensa = 0;
  String _articuloMayorValor = 'Sin datos';
  List<Map<String, dynamic>> _ultimosIngresos = [];

  @override
  void initState() {
    super.initState();
    _cargarTodoFinanzas();
  }

  double _parsearNumero(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is num) return valor.toDouble();
    if (valor is String) {
      final match = RegExp(r'[0-9]+(\.[0-9]+)?').firstMatch(valor);
      if (match != null) {
        return double.tryParse(match.group(0)!) ?? 0.0;
      }
    }
    return 0.0;
  }

  Future<void> _cargarTodoFinanzas() async {
    setState(() => _cargando = true);
    try {
      // 1. Preferencias de presupuesto y supermercado
      final prefs = await ServicioPreferencias.obtenerPreferencias();
      _preferencias = prefs;
      _presupuestoSemanal = prefs.presupuestoSemanal > 0
          ? prefs.presupuestoSemanal
          : 1500.0;
      _superFavorito = prefs.superFavorito.isNotEmpty &&
              prefs.superFavorito.toLowerCase() != 'ninguno'
          ? prefs.superFavorito
          : 'Walmart';

      // 2. Cotización actual de la lista de compras
      final cotizaciones =
          await ServicioCotizador.cotizarListaCompleta(supabase);

      if (cotizaciones.isNotEmpty) {
        // Encontrar favorito o el más relevante
        final favLower = _superFavorito.toLowerCase();
        final matchFav = cotizaciones.where((c) {
          final n = c.nombreSupermercado.toLowerCase();
          return n.contains(favLower) || favLower.contains(n);
        }).toList();

        _cotizacionElegida = matchFav.isNotEmpty
            ? matchFav.first
            : cotizaciones.firstWhere(
                (c) => c.total > 0,
                orElse: () => cotizaciones.first,
              );

        _costoSemanaActual = _cotizacionElegida?.total ?? 0.0;

        // Encontrar Central de Abasto
        final matchCentral = cotizaciones.where((c) {
          final n = c.nombreSupermercado.toLowerCase();
          return n.contains('central') || n.contains('abasto');
        }).toList();

        if (matchCentral.isNotEmpty) {
          _cotizacionCentralAbasto = matchCentral.first;
        }

        // 3. Desglose del gasto por departamentos usando los items cotizados
        final Map<String, double> gastosDepto = {};
        double sumDeptos = 0.0;

        for (var item in _cotizacionElegida!.desglose) {
          final cat = ConversorUnidades.determinarCategoria(item.nombre);
          gastosDepto[cat] = (gastosDepto[cat] ?? 0.0) + item.subtotal;
          sumDeptos += item.subtotal;
        }

        _gastoPorDepartamento = gastosDepto;
        _totalGastoDepartamentos = sumDeptos > 0 ? sumDeptos : _costoSemanaActual;
      } else if (widget.presupuestoSuperExterno != null) {
        _costoSemanaActual = widget.presupuestoSuperExterno!;
      }

      // 4. Analizar comidas del planeador semanal para calcular Costo por Platillo y ROI
      final hoy = DateTime.now().toIso8601String().split('T')[0];
      final dia7 = DateTime.now()
          .add(const Duration(days: 6))
          .toIso8601String()
          .split('T')[0];

      final planeadorData = await supabase
          .from('planeador')
          .select('id_planeador')
          .gte('fecha', hoy)
          .lte('fecha', dia7);

      final int comidasSemana = (planeadorData as List).length;
      _comidasPlaneadas = comidasSemana;

      final int divisorComidas = comidasSemana > 0 ? comidasSemana : 14;
      _costoPorPlatillo = _costoSemanaActual > 0
          ? (_costoSemanaActual / divisorComidas)
          : 45.0;

      // En México el costo promedio de comer en restaurante/fonda/delivery es de ~$150 MXN
      const double costoRestauranteRef = 150.0;
      final double gastoRestaurantes = divisorComidas * costoRestauranteRef;
      _ahorroVsRestaurantes = (_costoSemanaActual > 0)
          ? (gastoRestaurantes - _costoSemanaActual)
          : (divisorComidas * (costoRestauranteRef - 45.0));

      // 5. Datos de despensa e inventario
      final despensaData = await supabase
          .from('despensa_usuario')
          .select('nombre, cantidad, precio, fecha_ingreso')
          .order('fecha_ingreso', ascending: false);

      final List itemsDespensa = despensaData as List;
      double capital = 0.0;
      int itemsCount = 0;
      double maxValor = -1.0;
      String mayorNombre = 'Sin datos';

      for (var item in itemsDespensa) {
        final double cant = _parsearNumero(item['cantidad']);
        final double precio = _parsearNumero(item['precio']);
        final double valorItem = (precio > 0)
            ? (precio * (cant > 0 ? cant : 1.0))
            : ((cant > 0 ? cant : 1.0) * 25.0);

        capital += valorItem;
        itemsCount += (cant > 0 ? cant.toInt() : 1);

        if (valorItem > maxValor) {
          maxValor = valorItem;
          final String nom = item['nombre'] ?? 'Artículo';
          mayorNombre = '$nom (\$${valorItem.toStringAsFixed(2)})';
        }
      }

      _capitalDespensa = capital;
      _totalItemsDespensa = itemsCount;
      _articuloMayorValor = mayorNombre;
      _ultimosIngresos = itemsDespensa.cast<Map<String, dynamic>>();

      if (mounted) setState(() => _cargando = false);
    } catch (e) {
      debugPrint('Error al cargar pantalla de finanzas: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _abrirAjustePresupuesto() {
    final ctrl = TextEditingController(
      text: _presupuestoSemanal.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.tune, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('Presupuesto Semanal'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ajusta tu meta de gasto para las compras semanales de comida:',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: '\$ ',
                suffixText: 'MXN',
                labelText: 'Monto semanal objetivo',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final nuevo = double.tryParse(ctrl.text.trim());
              if (nuevo != null && nuevo > 0) {
                final prefsActuales =
                    _preferencias ?? const PreferenciasUsuario();
                final actualizadas = PreferenciasUsuario(
                  objetivo: prefsActuales.objetivo,
                  estilos: prefsActuales.estilos,
                  alergias: prefsActuales.alergias,
                  superFavorito: prefsActuales.superFavorito,
                  porciones: prefsActuales.porciones,
                  presupuestoSemanal: nuevo,
                  notificaciones: prefsActuales.notificaciones,
                );
                await ServicioPreferencias.guardarPreferencias(actualizadas);
                if (ctx.mounted) Navigator.pop(ctx);
                _cargarTodoFinanzas();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _escanearTicketRapido() async {
    final picker = ImagePicker();
    final XFile? foto = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (foto == null || !mounted) return;

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
                CircularProgressIndicator(color: Colors.deepOrange),
                SizedBox(height: 15),
                Text(
                  'Leyendo ticket con IA... 🧾✨',
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
      final resultado = await ServicioIA.leerTicketSupermercado(bytes);

      if (!mounted) return;
      Navigator.pop(context); // Cierra loader

      if (resultado != null && resultado['articulos'] != null) {
        final List articulos = resultado['articulos'] as List;
        final String tienda = resultado['tienda'] ?? 'Supermercado';
        final hoyStr = DateTime.now().toIso8601String().split('T')[0];

        int insertados = 0;
        for (var art in articulos) {
          final nombre = art['nombre']?.toString().trim() ?? '';
          if (nombre.isEmpty) continue;
          final cant = _parsearNumero(art['cantidad']);
          final precio = _parsearNumero(art['precio']);

          await supabase.from('despensa_usuario').insert({
            'nombre': nombre,
            'cantidad': cant > 0 ? cant : 1.0,
            'precio': precio > 0 ? precio : null,
            'categoria': 'Ticket $tienda',
            'fecha_ingreso': hoyStr,
          });
          insertados++;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '¡$insertados artículos de $tienda registrados en tus finanzas! 🧾✅',
              ),
              backgroundColor: Colors.green.shade800,
            ),
          );
        }

        _cargarTodoFinanzas();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudieron leer artículos válidos del ticket.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color colorTema = Colors.deepOrange;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const MenuLateral(rutaActual: 'finanzas'),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú principal',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Mis Finanzas 📈',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorTema,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Ajustar Presupuesto',
            onPressed: _abrirAjustePresupuesto,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _cargarTodoFinanzas,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _escanearTicketRapido,
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.receipt_long),
        label: const Text('Escanear Ticket 📸'),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            )
          : RefreshIndicator(
              color: Colors.deepOrange,
              onRefresh: _cargarTodoFinanzas,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  // 1. TERMÓMETRO DE PRESUPUESTO SEMANAL
                  _construirTermometroPresupuesto(),
                  const SizedBox(height: 16),

                  // 2. MÉTRICAS DE AHORRO Y ROI (Costo por platillo vs Restaurantes)
                  _construirMetricasRoiYComida(),
                  const SizedBox(height: 16),

                  // 3. COMPARATIVA INTELIGENTE SÚPER VS CENTRAL DE ABASTO
                  _construirComparativaAhorroSuper(),
                  const SizedBox(height: 16),

                  // 4. DESGLOSE DEL GASTO POR DEPARTAMENTO
                  _construirDesglosePorDepartamento(),
                  const SizedBox(height: 16),

                  // 5. RESUMEN DE CAPITAL EN DESPENSA
                  _construirResumenCapitalDespensa(),
                  const SizedBox(height: 16),

                  // 6. HISTORIAL DE INGRESOS VALORADOS Y TICKETS
                  _construirHistorialIngresos(),
                ],
              ),
            ),
    );
  }

  // 🌡️ 1. WIDGET: TERMÓMETRO DE PRESUPUESTO
  Widget _construirTermometroPresupuesto() {
    final double usoRatio = _presupuestoSemanal > 0
        ? (_costoSemanaActual / _presupuestoSemanal).clamp(0.0, 1.5)
        : 0.0;
    final double porcentajeUso = (_presupuestoSemanal > 0)
        ? (_costoSemanaActual / _presupuestoSemanal) * 100.0
        : 0.0;
    final double saldoRestante = _presupuestoSemanal - _costoSemanaActual;

    Color colorEstado = Colors.green.shade700;
    String estadoTexto =
        'Vas \$${saldoRestante.abs().toStringAsFixed(2)} MXN por debajo de tu presupuesto 🟢';
    IconData iconoEstado = Icons.check_circle_outline;

    if (porcentajeUso > 100.0) {
      colorEstado = Colors.red.shade700;
      estadoTexto =
          '¡Alerta! Excedes tu presupuesto por \$${saldoRestante.abs().toStringAsFixed(2)} MXN 🔴';
      iconoEstado = Icons.error_outline;
    } else if (porcentajeUso >= 85.0) {
      colorEstado = Colors.orange.shade800;
      estadoTexto =
          'Atención: Estás al ${porcentajeUso.toStringAsFixed(0)}% de tu meta semanal 🟡';
      iconoEstado = Icons.warning_amber_rounded;
    }

    final String superNombre =
        _cotizacionElegida?.nombreSupermercado ?? _superFavorito;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  Icon(Icons.query_stats, color: Colors.deepOrange, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Termómetro Semanal',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _abrirAjustePresupuesto,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 14, color: Colors.grey.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Ajustar',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Monto y Barra
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cotización $superNombre',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${_costoSemanaActual.toStringAsFixed(2)} MXN',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Meta Semanal',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${_presupuestoSemanal.toStringAsFixed(2)} MXN',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Barra de progreso visual
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: usoRatio.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(colorEstado),
            ),
          ),
          const SizedBox(height: 10),

          // Mensaje de estado semáforo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(iconoEstado, size: 16, color: colorEstado),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    estadoTexto,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorEstado,
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

  // 🍽️ 2. WIDGET: MÉTRICAS DE ROI Y COSTO POR PLATILLO
  Widget _construirMetricasRoiYComida() {
    return Row(
      children: [
        // Costo por Comida Casera
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.restaurant,
                          color: Colors.teal, size: 18),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Por Comida',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '\$${_costoPorPlatillo.toStringAsFixed(1)} MXN',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _comidasPlaneadas > 0
                      ? '$_comidasPlaneadas platillos planeados'
                      : 'Promedio 14 comidas',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Ahorro vs Comer Fuera
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.savings_outlined,
                          color: Colors.green.shade700, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ahorro vs Fuera',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '+\$${_ahorroVsRestaurantes.toStringAsFixed(0)} MXN',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'vs comer en restaurante',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 💡 3. WIDGET: COMPARATIVA SÚPER VS CENTRAL DE ABASTO
  Widget _construirComparativaAhorroSuper() {
    final double totalFav = _cotizacionElegida?.total ?? 0.0;
    final double totalCentral = _cotizacionCentralAbasto?.total ?? 0.0;
    final double ahorro = (totalFav > totalCentral && totalCentral > 0)
        ? (totalFav - totalCentral)
        : (totalFav * 0.22); // Estimación 22% promedio si no hay fila exacta
    final double porcentajeAhorro =
        totalFav > 0 ? (ahorro / totalFav) * 100.0 : 22.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // Amarillo suave
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE082), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB300),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.store_mall_directory_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Comparativa de Ahorro Inteligente',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6D4C41),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8F00),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Ahorro: -${porcentajeAhorro.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _cotizacionElegida?.nombreSupermercado ?? _superFavorito,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text(
                    '\$${totalFav.toStringAsFixed(2)} MXN',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Central de Abasto',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  Text(
                    totalCentral > 0
                        ? '\$${totalCentral.toStringAsFixed(2)} MXN'
                        : '\$${(totalFav - ahorro).toStringAsFixed(2)} MXN',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '💡 Surtir frutas, verduras y granos en Central de Abasto te ahorraría aproximadamente \$${ahorro.toStringAsFixed(2)} MXN en tu lista.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5D4037),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // 🥩 4. WIDGET: DESGLOSE POR DEPARTAMENTOS
  Widget _construirDesglosePorDepartamento() {
    if (_gastoPorDepartamento.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.pie_chart_outline,
                    color: Colors.deepOrange, size: 20),
                SizedBox(width: 8),
                Text(
                  'Desglose por Departamento',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Agrega productos a tu lista de compras para visualizar en qué departamentos se concentra tu gasto semanal.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final ordenCat = [
      {'nombre': 'Carnes y Aves', 'color': Colors.red, 'icono': Icons.kebab_dining_outlined},
      {'nombre': 'Frutas y Verduras', 'color': Colors.green, 'icono': Icons.eco_outlined},
      {'nombre': 'Pescados y Mariscos', 'color': Colors.teal, 'icono': Icons.set_meal_outlined},
      {'nombre': 'Lácteos y Huevos', 'color': Colors.amber.shade800, 'icono': Icons.egg_outlined},
      {'nombre': 'Abarrotes y Alacena', 'color': Colors.indigo, 'icono': Icons.shelves},
      {'nombre': 'Panadería y Tortillería', 'color': Colors.orange, 'icono': Icons.bakery_dining_outlined},
      {'nombre': 'Especias y Condimentos', 'color': Colors.brown, 'icono': Icons.grain_outlined},
      {'nombre': 'Otros', 'color': Colors.blueGrey, 'icono': Icons.shopping_basket_outlined},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline, color: Colors.deepOrange, size: 22),
              SizedBox(width: 8),
              Text(
                'Distribución por Departamento',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...ordenCat.map((catConfig) {
            final String nom = catConfig['nombre'] as String;
            final double monto = _gastoPorDepartamento[nom] ?? 0.0;
            if (monto <= 0) return const SizedBox.shrink();

            final double pct = _totalGastoDepartamentos > 0
                ? (monto / _totalGastoDepartamentos)
                : 0.0;
            final Color colorCat = catConfig['color'] as Color;
            final IconData iconoCat = catConfig['icono'] as IconData;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(iconoCat, size: 16, color: colorCat),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          nom,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      Text(
                        '\$${monto.toStringAsFixed(2)} MXN',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: colorCat.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorCat,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: pct.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(colorCat),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 🥫 5. WIDGET: RESUMEN DE CAPITAL EN DESPENSA
  Widget _construirResumenCapitalDespensa() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  color: Colors.teal, size: 22),
              SizedBox(width: 8),
              Text(
                'Capital en Despensa',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Valor Total Almacenado',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${_capitalDespensa.toStringAsFixed(2)} MXN',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Artículos en Casa',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_totalItemsDespensa insumos',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.star_outline, size: 15, color: Colors.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mayor valor: $_articuloMayorValor',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🧾 6. WIDGET: HISTORIAL DE INGRESOS Y TICKETS
  Widget _construirHistorialIngresos() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  Icon(Icons.receipt_outlined,
                      color: Colors.deepOrange, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Últimos Ingresos Valorados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Text(
                '${_ultimosIngresos.length} registros',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_ultimosIngresos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No hay ingresos registrados aún.\nToca "Escanear Ticket 📸" para registrar tu primera compra.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ..._ultimosIngresos.take(6).map((ing) {
              final double cant = _parsearNumero(ing['cantidad']);
              final double precio = _parsearNumero(ing['precio']);
              final double sub = (precio > 0) ? (precio * cant) : (cant * 25.0);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.deepOrange.shade50,
                      child: const Icon(Icons.shopping_bag_outlined,
                          size: 16, color: Colors.deepOrange),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ing['nombre'] ?? 'Artículo',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Cantidad: $cant • ${ing['fecha_ingreso'] ?? ""}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${sub.toStringAsFixed(2)} MXN',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
