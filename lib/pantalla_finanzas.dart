import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'conversor_unidades.dart';
import 'menu_lateral.dart';
import 'pantalla_chef.dart';
import 'servicio_cotizador.dart';
import 'servicio_finanzas_domesticas.dart';
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
  double? _presupuestoExternoActivo;
  double _presupuestoSemanal = 1500.0;
  String _superFavorito = 'Walmart';
  CotizacionSupermercado? _cotizacionElegida;
  CotizacionSupermercado? _cotizacionCentralAbasto;
  double _costoSemanaActual = 0.0;

  // Métricas del Planeador y ROI
  int _comidasPlaneadas = 0;
  double _costoPorPlatillo = 0.0;
  double _ahorroVsRestaurantes = 0.0;
  double _gastoSemanalRegistrado = 0.0;

  // Desglose por departamento
  Map<String, double> _gastoPorDepartamento = {};
  double _totalGastoDepartamentos = 0.0;

  // Despensa
  double _capitalDespensa = 0.0;
  int _totalItemsDespensa = 0;
  String _articuloMayorValor = 'Sin datos';
  List<Map<String, dynamic>> _ultimosIngresos = [];

  // 🛡️ P24: Suite Financiera y Ahorro Doméstico
  List<InsumoEnRiesgo> _insumosEnRiesgo = [];
  double _capitalEnRiesgo = 0.0;
  String _filtroProteina = 'Todos';

  // 🏆 P25: Reto Culinario Antidesperdicio (Zero-Waste Streak & Insignias)
  EstadoRachaZeroWaste? _estadoRacha;

  // 🎯 P25: Desafío de Ahorro Familiar a 30 Días ("Club del Súper")
  DesafioAhorroMensual? _desafioAhorro;

  @override
  void initState() {
    super.initState();
    _presupuestoExternoActivo = widget.presupuestoSuperExterno;
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

      // Si se proporcionó un supermercado elegido explícito (desde Cotizador o Carrito),
      // priorizarlo y sincronizarlo en preferencias para que se mantenga guardado
      final String superObjetivo;
      if (widget.supermercadoElegido != null &&
          widget.supermercadoElegido!.trim().isNotEmpty) {
        superObjetivo = widget.supermercadoElegido!.trim();
        _superFavorito = superObjetivo;
        if (prefs.superFavorito.toLowerCase() != superObjetivo.toLowerCase()) {
          final actualizadas = PreferenciasUsuario(
            objetivo: prefs.objetivo,
            estilos: prefs.estilos,
            alergias: prefs.alergias,
            superFavorito: superObjetivo,
            porciones: prefs.porciones,
            presupuestoSemanal: prefs.presupuestoSemanal,
            notificaciones: prefs.notificaciones,
          );
          await ServicioPreferencias.guardarPreferencias(actualizadas);
        }
      } else {
        superObjetivo = prefs.superFavorito.isNotEmpty &&
                prefs.superFavorito.toLowerCase() != 'ninguno'
            ? prefs.superFavorito
            : 'Walmart';
        _superFavorito = superObjetivo;
      }

      // 2. Cotización actual de la lista de compras
      final cotizaciones =
          await ServicioCotizador.cotizarListaCompleta(supabase);

      if (cotizaciones.isNotEmpty) {
        // Encontrar favorito o el más relevante coincidente con el supermercado objetivo
        final favLower = superObjetivo.toLowerCase();
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

        if (_presupuestoExternoActivo != null &&
            _presupuestoExternoActivo! > 0) {
          _costoSemanaActual = _presupuestoExternoActivo!;
        } else {
          _costoSemanaActual = _cotizacionElegida?.total ?? 0.0;
        }

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
      } else if (_presupuestoExternoActivo != null &&
          _presupuestoExternoActivo! > 0) {
        _costoSemanaActual = _presupuestoExternoActivo!;
      } else {
        _costoSemanaActual = 0.0;
        _cotizacionElegida = null;
        _cotizacionCentralAbasto = null;
        _gastoPorDepartamento = {};
        _totalGastoDepartamentos = 0.0;
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
          : 0.0;

      // En México el costo promedio de comer en restaurante/fonda/delivery es de ~$150 MXN
      const double costoRestauranteRef = 150.0;
      final double gastoRestaurantes = divisorComidas * costoRestauranteRef;
      _ahorroVsRestaurantes = (_costoSemanaActual > 0)
          ? (gastoRestaurantes - _costoSemanaActual)
          : 0.0;

      // 5. Datos de despensa e inventario
      final despensaData = await supabase
          .from('despensa_usuario')
          .select('id_item, nombre, cantidad, precio, fecha_ingreso')
          .order('fecha_ingreso', ascending: false);

      final List itemsDespensa = despensaData as List;
      double capital = 0.0;
      int itemsCount = 0;
      double maxValor = -1.0;
      String mayorNombre = 'Sin datos';
      double gastoSemanal = 0.0;
      final hace7Dias = DateTime.now().subtract(const Duration(days: 7));

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

        // Sumar compras reales y tickets registrados en la última semana
        final fechaStr = item['fecha_ingreso']?.toString() ?? '';
        final fechaItem = DateTime.tryParse(fechaStr);
        if (precio > 0 && fechaItem != null && fechaItem.isAfter(hace7Dias)) {
          gastoSemanal += (precio * (cant > 0 ? cant : 1.0));
        }
      }

      _capitalDespensa = capital;
      _totalItemsDespensa = itemsCount;
      _articuloMayorValor = mayorNombre;
      _gastoSemanalRegistrado = gastoSemanal;
      _ultimosIngresos = itemsDespensa.cast<Map<String, dynamic>>();

      // 🛡️ P24: Detectar insumos perecederos en riesgo para Rescate Culinario
      final enRiesgo = ServicioFinanzasDomesticas.detectarInsumosEnRiesgo(_ultimosIngresos);
      _insumosEnRiesgo = enRiesgo;
      _capitalEnRiesgo = enRiesgo.fold<double>(0.0, (acc, item) => acc + item.precioEstimado);

      // 🏆 P25: Reto Antidesperdicio y Club del Súper
      _estadoRacha = await ServicioFinanzasDomesticas.obtenerEstadoRachaZeroWaste();
      _desafioAhorro = await ServicioFinanzasDomesticas.obtenerDesafioAhorroMensual(
        gastoSemanalActual: _costoSemanaActual,
      );

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

  Future<void> _extenderRachaZeroWaste() async {
    final nuevoEstado = await ServicioFinanzasDomesticas.registrarDiaSinDesperdicio(
      razon: 'Registro manual en Finanzas',
    );
    if (!mounted) return;
    setState(() => _estadoRacha = nuevoEstado);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔥 ¡Racha extendida a ${nuevoEstado.diasRacha} días sin merma! Sigues protegiendo tu economía familiar 🥗👏',
        ),
        backgroundColor: Colors.teal.shade800,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _abrirAjusteMetaDesafio() {
    final double metaActual = _desafioAhorro?.metaAhorroMensual ?? 3000.0;
    final ctrl = TextEditingController(text: metaActual.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.flag_circle_outlined, color: Colors.teal),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Meta del Club del Súper 🎯',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Define el ahorro mensual que tu hogar desea alcanzar cocinando en casa en vez de pedir por delivery:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [2000.0, 3000.0, 4500.0, 6000.0].map((m) {
                  final seleccionada = (double.tryParse(ctrl.text) == m);
                  return ActionChip(
                    label: Text('\$${m.toStringAsFixed(0)}'),
                    backgroundColor: seleccionada ? Colors.teal.shade100 : Colors.grey.shade100,
                    side: BorderSide(color: seleccionada ? Colors.teal : Colors.grey.shade300),
                    onPressed: () {
                      setDialogState(() {
                        ctrl.text = m.toStringAsFixed(0);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  prefixText: '\$ ',
                  suffixText: 'MXN',
                  labelText: 'Meta mensual familiar',
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
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final val = double.tryParse(ctrl.text.trim());
                if (val != null && val >= 500) {
                  await ServicioFinanzasDomesticas.guardarMetaAhorroMensual(val);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _cargarTodoFinanzas();
                }
              },
              child: const Text('Guardar Meta'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _compartirDesafioAhorro() async {
    final desafio = _desafioAhorro;
    if (desafio == null) return;
    final buffer = StringBuffer();
    buffer.writeln('🎯 *CLUB DEL SÚPER: DESAFÍO DE AHORRO FAMILIAR* 🥗💰');
    buffer.writeln('App: *Jitomate y Cebolla* (www.jitomateycebolla.com)');
    buffer.writeln('────────────────────────');
    buffer.writeln('🏆 *Meta Mensual Familiar:* \$${desafio.metaAhorroMensual.toStringAsFixed(0)} MXN');
    buffer.writeln('📈 *Ahorro Acumulado:* +\$${desafio.ahorroLogradoMes.toStringAsFixed(0)} MXN (${desafio.porcentajeCumplido.toStringAsFixed(0)}%)');
    buffer.writeln('🍽️ *Comidas Caseras Preparadas:* ${desafio.comidasCaserasMes} platillos');
    buffer.writeln('⏳ *Días restantes del mes:* ${desafio.diasRestantesMes} días');
    buffer.writeln('────────────────────────');
    buffer.writeln('💡 ${desafio.metafora}');
    buffer.writeln('💪 _"Cocinar en familia es salud física y multiplicación patrimonial."_');
    await SharePlus.instance.share(ShareParams(text: buffer.toString()));
  }

  Future<void> _exportarEstadoCuentaCulinario() async {
    final ahorroData = ServicioFinanzasDomesticas.calcularAhorroVsDelivery(
      costoTotalSuper: _costoSemanaActual,
      comidasPlaneadas: _comidasPlaneadas,
    );

    final reporte = ReporteFinancieroHogar(
      presupuestoSemanal: _presupuestoSemanal,
      costoSuperSemanal: _costoSemanaActual,
      costoPorPlatillo: (ahorroData['costoPorPlatillo'] as num?)?.toDouble() ?? 0.0,
      comidasPlaneadas: _comidasPlaneadas > 0 ? _comidasPlaneadas : 14,
      ahorroSemanalVsDelivery: (ahorroData['ahorroSemanal'] as num?)?.toDouble() ?? 0.0,
      proyeccionAhorroMensual: (ahorroData['ahorroMensual'] as num?)?.toDouble() ?? 0.0,
      proyeccionAhorroAnual: (ahorroData['ahorroAnual'] as num?)?.toDouble() ?? 0.0,
      capitalDespensa: _capitalDespensa,
      capitalEnRiesgoDesperdicio: _capitalEnRiesgo,
      insumosEnRiesgo: _insumosEnRiesgo,
    );

    final textoFormateado = reporte.formatearParaCompartir();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.assessment_outlined, color: Color(0xFFD32F2F)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Estado de Cuenta Culinario',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reporte listo para compartir con tu familia o pareja sobre el ahorro generado al cocinar en casa:',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  textoFormateado,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace', height: 1.35),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366), // WhatsApp Green
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.share, size: 17),
            label: const Text('Compartir por WhatsApp 📱'),
            onPressed: () async {
              Navigator.pop(ctx);
              await SharePlus.instance.share(ShareParams(text: textoFormateado));
            },
          ),
        ],
      ),
    );
  }

  Future<void> _elegirOrigenTicket() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Escanear Ticket de Compra 🧾',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  'Registra tus gastos en finanzas y colabora calibrando los precios de tu supermercado con la comunidad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFBECEF),
                  child: Icon(Icons.camera_alt, color: Color(0xFFD32F2F)),
                ),
                title: const Text('Tomar foto con la cámara',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Captura tu ticket impreso al instante',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _escanearTicketRapido(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFECEFF1),
                  child: Icon(Icons.photo_library, color: Color(0xFF1E2022)),
                ),
                title: const Text('Elegir de la galería',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('Sube una foto o captura de ticket digital',
                    style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _escanearTicketRapido(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _escanearTicketRapido([ImageSource origen = ImageSource.camera]) async {
    final picker = ImagePicker();
    final XFile? foto = await picker.pickImage(
      source: origen,
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
                CircularProgressIndicator(color: Color(0xFFD32F2F)),
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
            'fecha_ingreso': hoyStr,
          });
          insertados++;
        }

        // 🤝 CROWDSOURCING P22: Calibrar precios en Supabase con los datos reales del ticket
        final int calibrados = await ServicioCotizador.reportarPreciosCrowdsourcing(
          supabase: supabase,
          tienda: tienda,
          articulos: articulos,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                calibrados > 0
                    ? '¡$insertados artículos de $tienda registrados! Y se calibraron $calibrados precios para la comunidad 🤝🛒'
                    : '¡$insertados artículos de $tienda registrados en tus finanzas! 🧾✅',
              ),
              backgroundColor: const Color(0xFF1E2022),
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

  Future<void> _confirmarLimpiarFinanzas() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade800, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '¿Limpiar información?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acción te permite reiniciar los registros de compras, tickets escaneados y gastos de tu despensa.',
              style: TextStyle(fontSize: 13.5, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.history_toggle_off,
                      color: Colors.amber.shade900, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '⚠️ ¿Estás seguro de que deseas eliminar estos datos o prefieres mantener tu histórico para seguir monitoreando tus gastos y ahorros?',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Selecciona qué deseas hacer:',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepOrange,
                side: const BorderSide(color: Colors.deepOrange),
                minimumSize: const Size(double.infinity, 42),
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text(
                'Limpiar solo tickets y compras registradas',
                style: TextStyle(fontSize: 12.5),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _ejecutarLimpieza(soloTicketsYCompras: true);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                minimumSize: const Size(double.infinity, 42),
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.delete_forever, size: 18),
              label: const Text(
                'Limpiar todo a ceros (tickets, despensa y compras)',
                style: TextStyle(fontSize: 12.5),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _ejecutarLimpieza(soloTicketsYCompras: false);
              },
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.check, size: 18),
            onPressed: () => Navigator.pop(ctx),
            label: const Text('Mantener histórico'),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutarLimpieza({required bool soloTicketsYCompras}) async {
    setState(() => _cargando = true);
    try {
      _presupuestoExternoActivo = null;

      if (soloTicketsYCompras) {
        final resp = await supabase
            .from('despensa_usuario')
            .select('id_item, precio');
        final List items = resp as List;
        final List<dynamic> idsEliminar = [];

        for (var it in items) {
          final id = it['id_item'];
          if (id == null) continue;
          final p = _parsearNumero(it['precio']);
          if (p > 0) {
            idsEliminar.add(id);
          }
        }

        if (idsEliminar.isNotEmpty) {
          await supabase
              .from('despensa_usuario')
              .delete()
              .inFilter('id_item', idsEliminar);
        }
      } else {
        // Limpiar todo: despensa completa y lista de compras
        await supabase
            .from('despensa_usuario')
            .delete()
            .neq('id_item', -999999);

        await supabase
            .from('lista_compras')
            .delete()
            .neq('id', -999999);

        _costoSemanaActual = 0.0;
        _cotizacionElegida = null;
        _cotizacionCentralAbasto = null;
        _gastoPorDepartamento = {};
        _totalGastoDepartamentos = 0.0;
        _capitalDespensa = 0.0;
        _totalItemsDespensa = 0;
        _articuloMayorValor = 'Sin datos';
        _gastoSemanalRegistrado = 0.0;
        _ultimosIngresos = [];
        _costoPorPlatillo = 0.0;
        _ahorroVsRestaurantes = 0.0;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              soloTicketsYCompras
                  ? '¡Se limpiaron los tickets y compras registradas! 🧹'
                  : '¡Finanzas, despensa y compras limpiadas en ceros! 🧹✨',
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
      await _cargarTodoFinanzas();
    } catch (e) {
      debugPrint('Error al limpiar finanzas: $e');
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al limpiar registros: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const MenuLateral(rutaActual: 'finanzas'),
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
          'Mis Finanzas 📈',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E2022),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Exportar Estado de Cuenta Culinario',
            onPressed: _exportarEstadoCuentaCulinario,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Limpiar información o histórico',
            onPressed: _confirmarLimpiarFinanzas,
          ),
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
        onPressed: _elegirOrigenTicket,
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.receipt_long),
        label: const Text('Escanear Ticket 📸'),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD32F2F)),
            )
          : RefreshIndicator(
              color: const Color(0xFFD32F2F),
              onRefresh: _cargarTodoFinanzas,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                children: [
                  // 1. TERMÓMETRO DE PRESUPUESTO SEMANAL
                  _construirTermometroPresupuesto(),
                  const SizedBox(height: 16),

                  // 2. DESAFÍO DE AHORRO FAMILIAR A 30 DÍAS ("CLUB DEL SÚPER" P25)
                  _construirDesafioAhorroMensual(),
                  const SizedBox(height: 16),

                  // 3. MONITOR DE DINERO EN RIESGO DE DESPERDICIO (RESCATE CULINARIO P24)
                  _construirMonitorRiesgoDesperdicio(),
                  const SizedBox(height: 16),

                  // 4. RETO CULINARIO ANTIDESPERDICIO (ZERO-WASTE STREAK P25)
                  _construirRetoZeroWasteStreak(),
                  const SizedBox(height: 16),

                  // 5. CENTRO DE AHORRO DOMÉSTICO VS DELIVERY (P24)
                  _construirCentroAhorroDomestico(),
                  const SizedBox(height: 16),

                  // 4. RANKING COSTO-PROTEÍNA DEL MERCADO (P24)
                  _construirRankingCostoProteina(),
                  const SizedBox(height: 16),

                  // 5. COMPARATIVA INTELIGENTE SÚPER VS CENTRAL DE ABASTO
                  _construirComparativaAhorroSuper(),
                  const SizedBox(height: 16),

                  // 6. DESGLOSE DEL GASTO POR DEPARTAMENTO
                  _construirDesglosePorDepartamento(),
                  const SizedBox(height: 16),

                  // 7. RESUMEN DE CAPITAL EN DESPENSA
                  _construirResumenCapitalDespensa(),
                  const SizedBox(height: 16),

                  // 8. HISTORIAL DE INGRESOS VALORADOS Y TICKETS
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
    String estadoTexto = _costoSemanaActual <= 0
        ? 'Sin compras activas. Presupuesto completo disponible: \$${_presupuestoSemanal.toStringAsFixed(2)} MXN 🟢'
        : 'Vas \$${saldoRestante.abs().toStringAsFixed(2)} MXN por debajo de tu presupuesto 🟢';
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
          if (_gastoSemanalRegistrado > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Gasto real registrado esta semana: \$${_gastoSemanalRegistrado.toStringAsFixed(2)} MXN',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 🎯 WIDGET P25: DESAFÍO DE AHORRO FAMILIAR A 30 DÍAS ("CLUB DEL SÚPER")
  Widget _construirDesafioAhorroMensual() {
    final desafio = _desafioAhorro;
    if (desafio == null) return const SizedBox.shrink();

    final double ratio = (desafio.porcentajeCumplido / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.teal.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.06),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flag_circle_rounded, color: Colors.teal, size: 22),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Club del Súper: Meta 30 Días',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: _abrirAjusteMetaDesafio,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 14, color: Colors.teal.shade800),
                      const SizedBox(width: 4),
                      Text(
                        'Ajustar Meta',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Medidor de progreso visual
          Row(
            children: [
              // Indicador circular de porcentaje
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 68,
                    height: 68,
                    child: CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 7,
                      backgroundColor: Colors.teal.shade50,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ratio >= 1.0 ? Colors.amber.shade700 : Colors.teal,
                      ),
                    ),
                  ),
                  Text(
                    '${desafio.porcentajeCumplido.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '+\$${desafio.ahorroLogradoMes.toStringAsFixed(0)} MXN',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade900,
                      ),
                    ),
                    Text(
                      'de \$${desafio.metaAhorroMensual.toStringAsFixed(0)} MXN meta este mes',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${desafio.comidasCaserasMes} comidas caseras • ${desafio.diasRestantesMes} días restantes',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Metáfora de impacto
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1), // Teal suave
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.savings_outlined, color: Colors.teal, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    desafio.metafora,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal.shade900,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Botón compartir progreso
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.teal.shade800,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              icon: const Icon(Icons.share, size: 16),
              label: const Text(
                'Compartir logro familiar 📱',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: _compartirDesafioAhorro,
            ),
          ),
        ],
      ),
    );
  }

  // 🍳 WIDGET P24: MONITOR DE MERMA Y RESCATE CULINARIO
  Widget _construirMonitorRiesgoDesperdicio() {
    if (_insumosEnRiesgo.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Despensa Optimizada Sin Merma',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  Text(
                    'No se detectaron ingredientes frescos en riesgo inminente de expirar.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final nombresInsumos = _insumosEnRiesgo.map((e) => e.nombre).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0), // Ámbar/naranja advertencia suave
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orange.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.08),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade800,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Monitor de Merma en Despensa',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '\$${_capitalEnRiesgo.toStringAsFixed(0)} MXN en riesgo',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tienes ${_insumosEnRiesgo.length} ingredientes perecederos que conviene consumir pronto para no perder su valor:',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF4E342E), height: 1.3),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _insumosEnRiesgo.take(6).map((insumo) {
              return Chip(
                avatar: const Icon(Icons.timer, size: 14, color: Colors.deepOrange),
                label: Text(
                  '${insumo.nombre} (\$${insumo.precioEstimado.toStringAsFixed(0)})',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                backgroundColor: Colors.white,
                side: BorderSide(color: Colors.orange.shade200),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F), // Bistró Borgoña
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: Text(
                '🍳 Rescatar \$${_capitalEnRiesgo.toStringAsFixed(0)} MXN con Chef IA',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PantallaChef(
                      ingredientesIniciales: nombresInsumos.take(5).join(', '),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🏆 WIDGET P25: RETO CULINARIO ANTIDESPERDICIO (ZERO-WASTE STREAK & GAMIFICACIÓN)
  Widget _construirRetoZeroWasteStreak() {
    final racha = _estadoRacha;
    if (racha == null) return const SizedBox.shrink();

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 22),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Reto Cero Merma 🏆',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepOrange.shade200),
                ),
                child: Row(
                  children: [
                    const Text('🔥 ', style: TextStyle(fontSize: 12)),
                    Text(
                      '${racha.diasRacha} Días',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            racha.diasRacha > 0
                ? '¡Llevas ${racha.diasRacha} días continuos cocinando sin merma! Ahorro estimado: +\$${racha.ahorroEstimadoAcumulado.toStringAsFixed(0)} MXN protegidos de la basura 🛡️'
                : 'Cocina hoy en casa aprovechando tus ingredientes de la despensa para iniciar tu racha antidesperdicio.',
            style: const TextStyle(fontSize: 12.5, color: Colors.black87, height: 1.3),
          ),
          const SizedBox(height: 14),

          // Próxima insignia y barra de progreso
          if (racha.proximaInsignia != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Próximo hito: ${racha.proximaInsignia!.titulo}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Text(
                  '${racha.diasFaltantesProxima} días restantes',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: racha.progresoProxima,
                minHeight: 7,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(racha.proximaInsignia!.color),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Carrusel de las 4 insignias
          SizedBox(
            height: 94,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: racha.insignias.map((ins) {
                final bool desbloqueada = ins.desbloqueada;
                return Container(
                  width: 110,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: desbloqueada ? ins.color.withValues(alpha: 0.08) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: desbloqueada ? ins.color : Colors.grey.shade300,
                      width: desbloqueada ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        desbloqueada ? ins.icono : Icons.lock_outline,
                        color: desbloqueada ? ins.color : Colors.grey.shade400,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ins.titulo.split(' ').take(2).join(' '),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: desbloqueada ? ins.color : Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '${ins.diasRequeridos} días',
                        style: TextStyle(
                          fontSize: 10,
                          color: desbloqueada ? Colors.black87 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Botón para sumar a la racha
          if (racha.registradoHoy)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '¡Racha de hoy registrada! Cocinaste sin merma ✅',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.local_fire_department, size: 18),
              label: const Text(
                '¡Cociné sin merma hoy! 🔥 Sumar a mi Racha',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: _extenderRachaZeroWaste,
            ),
        ],
      ),
    );
  }

  // 🛵 WIDGET P24: CENTRO DE AHORRO DOMÉSTICO VS DELIVERY
  Widget _construirCentroAhorroDomestico() {
    final ahorroData = ServicioFinanzasDomesticas.calcularAhorroVsDelivery(
      costoTotalSuper: _costoSemanaActual,
      comidasPlaneadas: _comidasPlaneadas,
    );

    final double costoPlatillo = (ahorroData['costoPorPlatillo'] as num?)?.toDouble() ?? _costoPorPlatillo;
    final double ahorroSem = (ahorroData['ahorroSemanal'] as num?)?.toDouble() ?? _ahorroVsRestaurantes;
    final double ahorroMes = (ahorroData['ahorroMensual'] as num?)?.toDouble() ?? (ahorroSem * 4.33);
    final double ahorroAnio = (ahorroData['ahorroAnual'] as num?)?.toDouble() ?? (ahorroSem * 52.0);
    final String metafora = (ahorroData['metafora'] as String?) ?? '¡Ahorro inteligente al cocinar!';

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.savings_outlined, color: Colors.green.shade800, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ahorro vs Restaurantes / Delivery',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, size: 20, color: Colors.teal),
                tooltip: 'Exportar Estado de Cuenta',
                onPressed: _exportarEstadoCuentaCulinario,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Comparador: Por comida vs Delivery
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Platillo en Casa', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        '\$${costoPlatillo.toStringAsFixed(1)} MXN',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.compare_arrows, color: Colors.grey),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Benchmark Delivery / Fonda', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        '\$${ServicioFinanzasDomesticas.benchmarkDeliveryPorPlatillo.toStringAsFixed(0)} MXN',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Métricas de acumulación
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Esta Semana', style: TextStyle(fontSize: 11, color: Colors.green.shade900)),
                      const SizedBox(height: 2),
                      Text(
                        '+\$${ahorroSem.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Proy. Mes (4s)', style: TextStyle(fontSize: 11, color: Colors.teal.shade900)),
                      const SizedBox(height: 2),
                      Text(
                        '+\$${ahorroMes.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Proy. Año (52s)', style: TextStyle(fontSize: 11, color: Colors.amber.shade900)),
                      const SizedBox(height: 2),
                      Text(
                        '+\$${ahorroAnio.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Metáfora de impacto en la vida real
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDCEDC8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_graph, color: Color(0xFF33691E), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    metafora,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF33691E)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🥩 WIDGET P24: RANKING COSTO-PROTEÍNA DEL MERCADO MEXICANO
  Widget _construirRankingCostoProteina() {
    final todosItems = ServicioFinanzasDomesticas.obtenerRankingCostoProteina();
    final itemsFiltrados = todosItems.where((it) {
      if (_filtroProteina == 'Animal') return it.categoria == 'Animal';
      if (_filtroProteina == 'Vegetal') return it.categoria == 'Vegetal';
      return true;
    }).toList();

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
                  Icon(Icons.fitness_center, color: Color(0xFFD32F2F), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Ranking Costo-Proteína',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'MXN / g real',
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Compara cuántos pesos te cuesta 1 gramo de proteína asimilable en el mercado mexicano:',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // Filtros
          Row(
            children: ['Todos', 'Animal', 'Vegetal'].map((cat) {
              final sel = _filtroProteina == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: sel,
                  selectedColor: const Color(0xFFFBECEF),
                  labelStyle: TextStyle(
                    fontSize: 11.5,
                    fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                    color: sel ? const Color(0xFFD32F2F) : Colors.black87,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _filtroProteina = cat);
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Lista de items
          ...itemsFiltrados.map((it) {
            final double pctBarra = (it.costoPorGramo / 1.10).clamp(0.1, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(it.icono, size: 16, color: it.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          it.nombre,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: it.costoPorGramo <= 0.25
                              ? Colors.green.shade50
                              : (it.costoPorGramo <= 0.65 ? Colors.teal.shade50 : Colors.amber.shade50),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '\$${it.costoPorGramo.toStringAsFixed(2)} MXN / g',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: it.costoPorGramo <= 0.25
                                ? Colors.green.shade800
                                : (it.costoPorGramo <= 0.65 ? Colors.teal.shade800 : Colors.brown.shade800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        it.unidadPresentacion,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      Text(
                        '\$${it.precioReferencia.toStringAsFixed(0)} MXN ref.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pctBarra,
                      minHeight: 5,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(it.color),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),

          // Tip Culinario Inteligente
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: Color(0xFFF57F17), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '💡 Tip Culinario Pro: Combinar 50% legumbres (lentejas o frijoles) con 50% pechuga o huevo reduce tu gasto proteico mensual hasta un 35% sin sacrificar biodisponibilidad.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF5D4037), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 💡 3. WIDGET: COMPARATIVA SÚPER VS CENTRAL DE ABASTO
  Widget _construirComparativaAhorroSuper() {
    final double totalFav = _cotizacionElegida?.total ?? 0.0;
    final double totalCentral = _cotizacionCentralAbasto?.total ?? 0.0;
    final double ahorro = (totalFav > 0 && totalFav > totalCentral && totalCentral > 0)
        ? (totalFav - totalCentral)
        : (totalFav > 0 ? (totalFav * 0.22) : 0.0);
    final double porcentajeAhorro =
        totalFav > 0 ? (ahorro / totalFav) * 100.0 : 0.0;

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
            totalFav > 0
                ? '💡 Surtir frutas, verduras y granos en Central de Abasto te ahorraría aproximadamente \$${ahorro.toStringAsFixed(2)} MXN en tu lista.'
                : '💡 Agrega productos a tu lista de compras para calcular el comparativo de ahorro entre supermercados y Central de Abasto.',
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
          if (_ultimosIngresos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _confirmarLimpiarFinanzas,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text(
                  'Limpiar información o histórico',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
