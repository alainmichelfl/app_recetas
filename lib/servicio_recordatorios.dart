import 'dart:convert';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'servicio_exportar_calendario.dart';

/// Datos estructurados de una alerta de descongelación
class AlertaDescongelacion {
  final bool requiereDescongelado;
  final String platillo;
  final String tipoComida;
  final String proteina;
  final String fechaPlatillo;
  final bool esParaManana;
  final String idIdentificador;

  const AlertaDescongelacion({
    required this.requiereDescongelado,
    this.platillo = '',
    this.tipoComida = '',
    this.proteina = '',
    this.fechaPlatillo = '',
    this.esParaManana = false,
    this.idIdentificador = '',
  });
}

/// Preferencias y ajustes del centro de recordatorios inteligentes
class ConfiguracionRecordatorios {
  final bool alertaDescongelar;
  final String horaDescongelar;
  final bool alertaMermaRefri;
  final int diasUmbralMerma;
  final bool alertaAyunoIntermitente;
  final String horaInicioVentana;
  final String horaFinVentana;
  final int minutosAnticipacionAyuno;

  const ConfiguracionRecordatorios({
    this.alertaDescongelar = true,
    this.horaDescongelar = '20:00',
    this.alertaMermaRefri = true,
    this.diasUmbralMerma = 4,
    this.alertaAyunoIntermitente = false,
    this.horaInicioVentana = '12:00',
    this.horaFinVentana = '20:00',
    this.minutosAnticipacionAyuno = 30,
  });

  Map<String, dynamic> toMap() => {
    'alertaDescongelar': alertaDescongelar,
    'horaDescongelar': horaDescongelar,
    'alertaMermaRefri': alertaMermaRefri,
    'diasUmbralMerma': diasUmbralMerma,
    'alertaAyunoIntermitente': alertaAyunoIntermitente,
    'horaInicioVentana': horaInicioVentana,
    'horaFinVentana': horaFinVentana,
    'minutosAnticipacionAyuno': minutosAnticipacionAyuno,
  };

  factory ConfiguracionRecordatorios.fromMap(Map<String, dynamic> map) {
    return ConfiguracionRecordatorios(
      alertaDescongelar: map['alertaDescongelar'] ?? true,
      horaDescongelar: map['horaDescongelar'] ?? '20:00',
      alertaMermaRefri: map['alertaMermaRefri'] ?? true,
      diasUmbralMerma: map['diasUmbralMerma'] ?? 4,
      alertaAyunoIntermitente: map['alertaAyunoIntermitente'] ?? false,
      horaInicioVentana: map['horaInicioVentana'] ?? '12:00',
      horaFinVentana: map['horaFinVentana'] ?? '20:00',
      minutosAnticipacionAyuno: map['minutosAnticipacionAyuno'] ?? 30,
    );
  }
}

class ServicioRecordatorios {
  // Lista de proteínas que habitualmente se compran o almacenan congeladas
  static const List<Map<String, String>> _proteinasCongelables = [
    {'clave': 'pechuga', 'nombre': 'la pechuga de pollo'},
    {'clave': 'pollo', 'nombre': 'el pollo'},
    {'clave': 'alitas', 'nombre': 'las alitas'},
    {'clave': 'muslo', 'nombre': 'los muslos de pollo'},
    {'clave': 'pierna', 'nombre': 'las piernas de pollo'},
    {'clave': 'arrachera', 'nombre': 'la arrachera'},
    {'clave': 'bistec', 'nombre': 'el bistec de res'},
    {'clave': 'bife', 'nombre': 'el bife / corte'},
    {'clave': 'carne molida', 'nombre': 'la carne molida'},
    {'clave': 'molida', 'nombre': 'la carne molida'},
    {'clave': 'res', 'nombre': 'la carne de res'},
    {'clave': 'costilla', 'nombre': 'las costillas'},
    {'clave': 'chuleta', 'nombre': 'las chuletas'},
    {'clave': 'cerdo', 'nombre': 'la carne de cerdo'},
    {'clave': 'puerco', 'nombre': 'la carne de puerco'},
    {'clave': 'lomo', 'nombre': 'el lomo'},
    {'clave': 'pescado', 'nombre': 'el pescado'},
    {'clave': 'filete', 'nombre': 'los filetes de pescado'},
    {'clave': 'camaron', 'nombre': 'los camarones'},
    {'clave': 'camarón', 'nombre': 'los camarones'},
    {'clave': 'salmon', 'nombre': 'el salmón'},
    {'clave': 'salmón', 'nombre': 'el salmón'},
    {'clave': 'atun', 'nombre': 'el atún fresco'},
    {'clave': 'atún', 'nombre': 'el atún fresco'},
    {'clave': 'pavo', 'nombre': 'la carne de pavo'},
    {'clave': 'milanesa', 'nombre': 'las milanesas'},
  ];

  /// Detecta si hay algún platillo para mañana (o para hoy) que requiera descongelar carne
  static Future<AlertaDescongelacion?> detectarAlertaDescongelacion(
    List<dynamic> plan,
  ) async {
    if (plan.isEmpty) return null;

    final sp = await SharedPreferences.getInstance();
    final hoy = DateTime.now();
    final hoyStr = hoy.toIso8601String().split('T')[0];
    final manana = hoy.add(const Duration(days: 1));
    final mananaStr = manana.toIso8601String().split('T')[0];

    // 1. Revisar primero los platillos de mañana (aviso preventivo nocturno)
    for (var item in plan) {
      final f = item['fecha']?.toString() ?? '';
      if (f == mananaStr) {
        final alerta = _analizarItemParaDescongelar(item, f, esParaManana: true, sp: sp);
        if (alerta != null) return alerta;
      }
    }

    // 2. Si no hay para mañana, revisar si hoy temprano hay comida/cena pendiente
    for (var item in plan) {
      final f = item['fecha']?.toString() ?? '';
      if (f == hoyStr) {
        final tipo = item['tipo_comida']?.toString() ?? '';
        // Si ya pasó la mañana, avisar para comida o cena
        if (tipo == 'Comida' || tipo == 'Cena') {
          final alerta = _analizarItemParaDescongelar(item, f, esParaManana: false, sp: sp);
          if (alerta != null) return alerta;
        }
      }
    }

    return null;
  }

  static AlertaDescongelacion? _analizarItemParaDescongelar(
    dynamic item,
    String fecha, {
    required bool esParaManana,
    required SharedPreferences sp,
  }) {
    final receta = item['recetas'] is Map ? item['recetas'] as Map : {};
    final titulo = (receta['titulo'] ?? item['titulo'] ?? '').toString();
    final desc = (receta['descripcion'] ?? item['descripcion'] ?? '').toString();
    final tipoComida = (item['tipo_comida'] ?? 'Comida').toString();
    final idPlan = item['id_planeador']?.toString() ?? '${fecha}_$titulo';

    // Verificar si el usuario ya presionó "Ya lo bajé" para este item
    final atendido = sp.getBool('descongelado_atendido_$idPlan') ?? false;
    if (atendido) return null;

    final textoTotal = '$titulo $desc'.toLowerCase();

    for (var p in _proteinasCongelables) {
      if (textoTotal.contains(p['clave']!)) {
        return AlertaDescongelacion(
          requiereDescongelado: true,
          platillo: titulo.isNotEmpty ? titulo : 'Platillo con ${p['clave']}',
          tipoComida: tipoComida,
          proteina: p['nombre']!,
          fechaPlatillo: fecha,
          esParaManana: esParaManana,
          idIdentificador: idPlan,
        );
      }
    }

    return null;
  }

  /// Marca la alerta como atendida para que no vuelva a aparecer
  static Future<void> marcarComoAtendido(String idIdentificador) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('descongelado_atendido_$idIdentificador', true);
  }

  /// Agrega un evento con alarma al calendario del dispositivo a las 20:00 (8:00 PM)
  static Future<bool> agendarAlarmaEnCalendario({
    required String platillo,
    required String proteina,
    required String tipoComida,
    BuildContext? context,
  }) async {
    final hoy = DateTime.now();
    // Programar para hoy a las 20:00 (8:00 PM)
    final fechaAlarma = DateTime(hoy.year, hoy.month, hoy.day, 20, 0, 0);
    final fechaFin = fechaAlarma.add(const Duration(minutes: 30));

    if (kIsWeb && context != null) {
      final item = {
        'recetas': {
          'titulo': 'Descongelar $proteina',
          'descripcion':
              'Baja $proteina del congelador al refrigerador para preparar "$platillo" ($tipoComida).',
          'calorias': 'N/A',
        },
        'tipo_comida': 'Recordatorio',
        'fecha': '${hoy.year}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}',
      };
      ServicioExportarCalendario.mostrarModalExportacion(
        context: context,
        items: [item],
        titulo: 'Alarma de Descongelado 🧊',
        subtitulo: 'Para preparar "$platillo"',
      );
      return true;
    }

    final Event event = Event(
      title: '🧊 Descongelar $proteina',
      description:
          'Recordatorio de Jitomate y Cebolla:\nBaja $proteina del congelador al refrigerador para preparar "$platillo" ($tipoComida).',
      location: 'Mi Cocina',
      startDate: fechaAlarma,
      endDate: fechaFin,
      allDay: false,
    );

    try {
      if (!kIsWeb) {
        return await Add2Calendar.addEvent2Cal(event);
      }
      return false;
    } catch (e) {
      debugPrint('Error al agregar evento de descongelado al calendario: $e');
      return false;
    }
  }

  /// Obtiene los ingredientes con semáforo amarillo (>=4 días) o rojo (>=7 días) de la despensa
  static Future<List<Map<String, dynamic>>> obtenerAlimentosEnRiesgoDespensa() async {
    try {
      final List res = await Supabase.instance.client
          .from('despensa_usuario')
          .select('id_item, nombre, cantidad, fecha_ingreso')
          .order('fecha_ingreso', ascending: true);

      final List<Map<String, dynamic>> enRiesgo = [];
      final hoy = DateTime.now();

      for (var row in res) {
        final fStr = row['fecha_ingreso']?.toString();
        if (fStr != null) {
          final dt = DateTime.tryParse(fStr);
          if (dt != null) {
            final dias = hoy.difference(dt).inDays;
            if (dias >= 4) {
              enRiesgo.add({
                'id_item': row['id_item'],
                'nombre': row['nombre'] ?? '',
                'cantidad': row['cantidad'],
                'dias': dias,
                'esUrgente': dias >= 7,
              });
            }
          }
        }
      }

      return enRiesgo;
    } catch (e) {
      debugPrint('Error al consultar alimentos en riesgo: $e');
      return [];
    }
  }

  /// Muestra una guía interactiva con los mejores trucos y precauciones para descongelar
  static void mostrarModalTipsDescongelado(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.ac_unit_rounded, color: Colors.blueAccent, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Guía de Descongelado Seguro 🧊',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'El secreto de los grandes chefs para carnes jugosas, seguras y sin bacterias.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 18),

                // Método 1: Refrigerador (El Rey)
                _construirTarjetaMetodo(
                  icono: Icons.kitchen_rounded,
                  colorIcono: Colors.teal,
                  fondoColor: Colors.teal.shade50,
                  titulo: '1. El Método de Oro: En el Refrigerador (24 hrs)',
                  recomendado: true,
                  descripcion:
                      'Es el método más seguro y profesional. Al bajar la carne del congelador al estante inferior del refri la noche anterior, se descongela gradualmente. Los jugos no se pierden y las bacterias quedan completamente inactivas.',
                  tiempo: '⏳ Tiempo: 12 a 24 horas',
                ),
                const SizedBox(height: 14),

                // Método 2: Agua Fría (El Express)
                _construirTarjetaMetodo(
                  icono: Icons.water_drop_rounded,
                  colorIcono: Colors.blue,
                  fondoColor: Colors.blue.shade50,
                  titulo: '2. El Express Seguro: Baño de Agua Fría (30-60 min)',
                  recomendado: false,
                  descripcion:
                      '¿Se te olvidó anoche? Coloca la carne en una bolsa hermética tipo Ziploc y sumérgela en un bowl con agua de la llave bien fría. Cambia el agua cada 20-30 minutos. En menos de 1 hora estará lista para la sartén.',
                  tiempo: '⚡ Tiempo: 30 a 60 minutos',
                ),
                const SizedBox(height: 14),

                // Método 3: Lo que NUNCA debes hacer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
                          const SizedBox(width: 8),
                          Text(
                            '🛑 Lo que NUNCA debes hacer',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• NUNCA la dejes sobre la barra a temperatura ambiente: entre 4°C y 60°C las bacterias se multiplican cada 20 minutos.\n'
                        '• NUNCA uses agua caliente: cocinará el exterior mientras el centro sigue congelado.\n'
                        '• Evita el microondas: suele cocer las orillas dejando la carne gomosa y seca.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('¡Entendido Chef! 👨‍🍳✨'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _construirTarjetaMetodo({
    required IconData icono,
    required Color colorIcono,
    required Color fondoColor,
    required String titulo,
    required bool recomendado,
    required String descripcion,
    required String tiempo,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fondoColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorIcono.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: colorIcono, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorIcono is MaterialColor ? colorIcono.shade900 : colorIcono,
                  ),
                ),
              ),
              if (recomendado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⭐ TOP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            descripcion,
            style: const TextStyle(fontSize: 12.5, height: 1.35, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            tiempo,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorIcono is MaterialColor ? colorIcono.shade800 : colorIcono,
            ),
          ),
        ],
      ),
    );
  }

  static const String _keyConfigRecordatorios = 'config_recordatorios_inteligentes_v1';

  /// Obtiene la configuración de recordatorios persistida en el dispositivo
  static Future<ConfiguracionRecordatorios> obtenerConfiguracion() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final str = sp.getString(_keyConfigRecordatorios);
      if (str != null && str.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(str);
        return ConfiguracionRecordatorios.fromMap(map);
      }
    } catch (e) {
      debugPrint('Error cargando configuración de recordatorios: $e');
    }
    return const ConfiguracionRecordatorios();
  }

  /// Guarda la configuración de recordatorios
  static Future<void> guardarConfiguracion(ConfiguracionRecordatorios config) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_keyConfigRecordatorios, jsonEncode(config.toMap()));
    } catch (e) {
      debugPrint('Error guardando configuración de recordatorios: $e');
    }
  }

  /// Calcula el estado actual de la ventana de alimentación / ayuno intermitente
  static String calcularEstadoVentanaAyuno(
    ConfiguracionRecordatorios config, {
    DateTime? ahora,
  }) {
    if (!config.alertaAyunoIntermitente) {
      return 'Monitoreo de ayuno desactivado';
    }

    final dt = ahora ?? DateTime.now();
    final minutosActuales = dt.hour * 60 + dt.minute;

    final partesInicio = config.horaInicioVentana.split(':');
    final minutosInicio = (int.tryParse(partesInicio[0]) ?? 12) * 60 +
        (partesInicio.length > 1 ? int.tryParse(partesInicio[1]) ?? 0 : 0);

    final partesFin = config.horaFinVentana.split(':');
    final minutosFin = (int.tryParse(partesFin[0]) ?? 20) * 60 +
        (partesFin.length > 1 ? int.tryParse(partesFin[1]) ?? 0 : 0);

    final anticipacion = config.minutosAnticipacionAyuno;

    // 1. Pre-apertura
    if (minutosActuales >= (minutosInicio - anticipacion) && minutosActuales < minutosInicio) {
      final restantes = minutosInicio - minutosActuales;
      return 'Apertura en $restantes min (${config.horaInicioVentana}). Prepara tu primer alimento.';
    }

    // 2. Ventana abierta
    if (minutosActuales >= minutosInicio && minutosActuales < (minutosFin - anticipacion)) {
      return 'Ventana de alimentación abierta (hasta las ${config.horaFinVentana})';
    }

    // 3. Pre-cierre
    if (minutosActuales >= (minutosFin - anticipacion) && minutosActuales < minutosFin) {
      final restantes = minutosFin - minutosActuales;
      return '¡Cierre de ventana en $restantes min! Última ingesta recomendada.';
    }

    // 4. Período de ayuno
    return 'En período de ayuno. Ventana abre a las ${config.horaInicioVentana}.';
  }

  /// Despliega el Centro de Recordatorios y Notificaciones Inteligentes
  static void mostrarModalCentroRecordatorios(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _DialogoCentroRecordatoriosModal(),
    );
  }
}

class _DialogoCentroRecordatoriosModal extends StatefulWidget {
  const _DialogoCentroRecordatoriosModal();

  @override
  State<_DialogoCentroRecordatoriosModal> createState() =>
      _DialogoCentroRecordatoriosModalState();
}

class _DialogoCentroRecordatoriosModalState
    extends State<_DialogoCentroRecordatoriosModal> {
  ConfiguracionRecordatorios _config = const ConfiguracionRecordatorios();
  bool _cargando = true;
  int _alimentosEnRiesgoCount = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final c = await ServicioRecordatorios.obtenerConfiguracion();
    final alimentosRiesgo =
        await ServicioRecordatorios.obtenerAlimentosEnRiesgoDespensa();
    if (mounted) {
      setState(() {
        _config = c;
        _alimentosEnRiesgoCount = alimentosRiesgo.length;
        _cargando = false;
      });
    }
  }

  Future<void> _actualizar(ConfiguracionRecordatorios nueva) async {
    setState(() => _config = nueva);
    await ServicioRecordatorios.guardarConfiguracion(nueva);
  }

  @override
  Widget build(BuildContext context) {
    final estadoAyuno = ServicioRecordatorios.calcularEstadoVentanaAyuno(_config);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: Colors.deepOrange),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.deepOrange,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Centro de Recordatorios 🔔',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Alertas automáticas de cocina, despensa y salud',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Tarjeta 1: Descongelar a las 8:00 PM
                  _tarjetaRecordatorio(
                    icono: Icons.ac_unit_rounded,
                    color: Colors.blueAccent,
                    titulo: 'Descongelar a Tiempo (${_config.horaDescongelar})',
                    descripcion:
                        'Avisa la noche anterior si tienes pollo, res o pescado programado en tu planeador para que baje al refrigerador sin bacterias.',
                    activo: _config.alertaDescongelar,
                    onChanged: (val) {
                      _actualizar(
                        ConfiguracionRecordatorios(
                          alertaDescongelar: val,
                          horaDescongelar: _config.horaDescongelar,
                          alertaMermaRefri: _config.alertaMermaRefri,
                          diasUmbralMerma: _config.diasUmbralMerma,
                          alertaAyunoIntermitente: _config.alertaAyunoIntermitente,
                          horaInicioVentana: _config.horaInicioVentana,
                          horaFinVentana: _config.horaFinVentana,
                          minutosAnticipacionAyuno: _config.minutosAnticipacionAyuno,
                        ),
                      );
                    },
                    accionExtra: TextButton.icon(
                      icon: const Icon(Icons.tips_and_updates_outlined, size: 16),
                      label: const Text('Ver Guía de Descongelado'),
                      onPressed: () =>
                          ServicioRecordatorios.mostrarModalTipsDescongelado(context),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tarjeta 2: Alerta Anti-Merma (Refrigerador > 4 días)
                  _tarjetaRecordatorio(
                    icono: Icons.kitchen_rounded,
                    color: Colors.teal,
                    titulo: 'Prevención de Merma (Refri > 4 días)',
                    descripcion:
                        'Detecta insumos frescos que llevan más de 4 días y te sugiere recetas para aprovecharlos antes de que se desperdicien.',
                    activo: _config.alertaMermaRefri,
                    badgeTexto: _alimentosEnRiesgoCount > 0
                        ? '$_alimentosEnRiesgoCount en riesgo'
                        : '0 en riesgo ✓',
                    colorBadge: _alimentosEnRiesgoCount > 0
                        ? Colors.deepOrange
                        : Colors.green,
                    onChanged: (val) {
                      _actualizar(
                        ConfiguracionRecordatorios(
                          alertaDescongelar: _config.alertaDescongelar,
                          horaDescongelar: _config.horaDescongelar,
                          alertaMermaRefri: val,
                          diasUmbralMerma: _config.diasUmbralMerma,
                          alertaAyunoIntermitente: _config.alertaAyunoIntermitente,
                          horaInicioVentana: _config.horaInicioVentana,
                          horaFinVentana: _config.horaFinVentana,
                          minutosAnticipacionAyuno: _config.minutosAnticipacionAyuno,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Tarjeta 3: Ventana de Ayuno Intermitente
                  _tarjetaRecordatorio(
                    icono: Icons.timer_outlined,
                    color: Colors.purple,
                    titulo: 'Ventana de Ayuno (${_config.horaInicioVentana} - ${_config.horaFinVentana})',
                    descripcion:
                        'Avisa ${_config.minutosAnticipacionAyuno} minutos antes de abrir o cerrar tu ventana de alimentación (protocolo 16:8).',
                    activo: _config.alertaAyunoIntermitente,
                    pieDePagina: _config.alertaAyunoIntermitente
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Estado hoy: $estadoAyuno',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                          )
                        : null,
                    onChanged: (val) {
                      _actualizar(
                        ConfiguracionRecordatorios(
                          alertaDescongelar: _config.alertaDescongelar,
                          horaDescongelar: _config.horaDescongelar,
                          alertaMermaRefri: _config.alertaMermaRefri,
                          diasUmbralMerma: _config.diasUmbralMerma,
                          alertaAyunoIntermitente: val,
                          horaInicioVentana: _config.horaInicioVentana,
                          horaFinVentana: _config.horaFinVentana,
                          minutosAnticipacionAyuno: _config.minutosAnticipacionAyuno,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E2022),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Listo'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _tarjetaRecordatorio({
    required IconData icono,
    required Color color,
    required String titulo,
    required String descripcion,
    required bool activo,
    required ValueChanged<bool> onChanged,
    Widget? accionExtra,
    String? badgeTexto,
    Color? colorBadge,
    Widget? pieDePagina,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (badgeTexto != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (colorBadge ?? color).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeTexto,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorBadge ?? color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: activo,
                activeThumbColor: color,
                onChanged: onChanged,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            descripcion,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700, height: 1.3),
          ),
          ?pieDePagina,
          ?accionExtra,
        ],
      ),
    );
  }
}

