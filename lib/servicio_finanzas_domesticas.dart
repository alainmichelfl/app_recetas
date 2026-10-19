import 'package:flutter/material.dart';

/// Modelo de artículo con costo por gramo de proteína
class ItemProteina {
  final String nombre;
  final String categoria; // 'Animal', 'Vegetal'
  final double precioReferencia;
  final String unidadPresentacion;
  final double gramosProteinaPorUnidad;
  final double costoPorGramo; // MXN por gramo de proteína real
  final IconData icono;
  final Color color;

  const ItemProteina({
    required this.nombre,
    required this.categoria,
    required this.precioReferencia,
    required this.unidadPresentacion,
    required this.gramosProteinaPorUnidad,
    required this.costoPorGramo,
    required this.icono,
    required this.color,
  });
}

/// Insumo en riesgo de merma en la despensa
class InsumoEnRiesgo {
  final dynamic id;
  final String nombre;
  final double cantidad;
  final double precioEstimado;
  final String categoria;
  final int diasEnDespensa;

  const InsumoEnRiesgo({
    required this.id,
    required this.nombre,
    required this.cantidad,
    required this.precioEstimado,
    required this.categoria,
    required this.diasEnDespensa,
  });
}

/// Reporte consolidado de finanzas y ahorro doméstico
class ReporteFinancieroHogar {
  final double presupuestoSemanal;
  final double costoSuperSemanal;
  final double costoPorPlatillo;
  final int comidasPlaneadas;
  final double ahorroSemanalVsDelivery;
  final double proyeccionAhorroMensual;
  final double proyeccionAhorroAnual;
  final double capitalDespensa;
  final double capitalEnRiesgoDesperdicio;
  final List<InsumoEnRiesgo> insumosEnRiesgo;

  const ReporteFinancieroHogar({
    required this.presupuestoSemanal,
    required this.costoSuperSemanal,
    required this.costoPorPlatillo,
    required this.comidasPlaneadas,
    required this.ahorroSemanalVsDelivery,
    required this.proyeccionAhorroMensual,
    required this.proyeccionAhorroAnual,
    required this.capitalDespensa,
    required this.capitalEnRiesgoDesperdicio,
    required this.insumosEnRiesgo,
  });

  /// Formatea un mensaje con estilo profesional y emojis para WhatsApp o portapapeles
  String formatearParaCompartir() {
    final buffer = StringBuffer();
    buffer.writeln('📊 *ESTADO DE CUENTA CULINARIO & AHORRO FAMILIAR* 🥗💰');
    buffer.writeln('App: *Jitomate y Cebolla* (www.jitomateycebolla.com)');
    buffer.writeln('────────────────────────');
    buffer.writeln('🛒 *Presupuesto Semanal:* \$${presupuestoSemanal.toStringAsFixed(2)} MXN');
    buffer.writeln('🧾 *Costo Real Súper:* \$${costoSuperSemanal.toStringAsFixed(2)} MXN');
    buffer.writeln('🍽️ *Costo Promedio / Platillo Casero:* \$${costoPorPlatillo.toStringAsFixed(2)} MXN');
    buffer.writeln('📅 *Comidas Caseras Planeadas:* $comidasPlaneadas platillos');
    buffer.writeln('────────────────────────');
    buffer.writeln('🛵 *Ahorro vs Comer Fuera / Delivery:*');
    buffer.writeln('  • Semanal: *+\$${ahorroSemanalVsDelivery.toStringAsFixed(2)} MXN*');
    buffer.writeln('  • Proyección Mensual: *+\$${proyeccionAhorroMensual.toStringAsFixed(2)} MXN*');
    buffer.writeln('  • Proyección Anual: *+\$${proyeccionAhorroAnual.toStringAsFixed(2)} MXN*');
    buffer.writeln('────────────────────────');
    buffer.writeln('🥫 *Patrimonio en Despensa:* \$${capitalDespensa.toStringAsFixed(2)} MXN');
    if (capitalEnRiesgoDesperdicio > 0) {
      buffer.writeln('⚠️ *Insumos frescos por cocinar:* \$${capitalEnRiesgoDesperdicio.toStringAsFixed(2)} MXN');
    }
    buffer.writeln('────────────────────────');
    buffer.writeln('💡 _"Cocinar en casa no solo cuida tu salud, sino que multiplica el patrimonio de tu hogar."_');
    return buffer.toString();
  }
}

/// Servicio de Finanzas Culinarias y Ahorro Doméstico
class ServicioFinanzasDomesticas {
  ServicioFinanzasDomesticas._();

  /// Benchmark promedio de comer un platillo en restaurante o delivery en México
  static const double benchmarkDeliveryPorPlatillo = 140.0;

  // =========================================================================
  // 1. CÁLCULO DE AHORRO VS RESTAURANTES / DELIVERY
  // =========================================================================

  /// Calcula las métricas de ahorro por cocinar en casa
  static Map<String, dynamic> calcularAhorroVsDelivery({
    required double costoTotalSuper,
    required int comidasPlaneadas,
  }) {
    final int divisor = comidasPlaneadas > 0 ? comidasPlaneadas : 14;
    final double costoPlatillo = costoTotalSuper > 0 ? (costoTotalSuper / divisor) : 0.0;

    final double gastoDeliveryEquivalente = divisor * benchmarkDeliveryPorPlatillo;
    final double ahorroSemanal = (costoTotalSuper > 0)
        ? (gastoDeliveryEquivalente - costoTotalSuper).clamp(0.0, 99999.0)
        : 0.0;

    final double ahorroMensual = ahorroSemanal * 4.33; // Semanas por mes promedio
    final double ahorroAnual = ahorroSemanal * 52.0;

    // Metáforas de ahorro en el mundo real
    String metafora;
    if (ahorroMensual >= 4500) {
      metafora = '¡Equivale a un viaje de fin de semana o 3 tanques completos de gasolina al mes! 🚗✈️';
    } else if (ahorroMensual >= 2500) {
      metafora = '¡Equivale a cubrir las suscripciones de servicios de tu hogar e internet por 3 meses! 📶🎬';
    } else if (ahorroMensual >= 1000) {
      metafora = '¡Equivale a más de 20 cafés de especialidad o un súper completo extra! ☕🛒';
    } else {
      metafora = '¡Cada platillo preparado en casa suma a tu fondo de ahorro familiar! 🐷';
    }

    return {
      'costoPorPlatillo': costoPlatillo,
      'ahorroSemanal': ahorroSemanal,
      'ahorroMensual': ahorroMensual,
      'ahorroAnual': ahorroAnual,
      'metafora': metafora,
    };
  }

  // =========================================================================
  // 2. MONITOR DE DINERO EN RIESGO DE DESPERDICIO (RESCATE CULINARIO)
  // =========================================================================

  /// Palabras clave de insumos perecederos típicos
  static const List<String> _palabrasPerecederas = [
    'jitomate',
    'tomate',
    'cebolla',
    'aguacate',
    'lechuga',
    'espinaca',
    'cilantro',
    'perejil',
    'calabacita',
    'pepino',
    'zanahoria',
    'chile',
    'plátano',
    'platano',
    'manzana',
    'fresa',
    'limón',
    'limon',
    'pollo',
    'pechuga',
    'carne',
    'molida',
    'bistec',
    'pescado',
    'atun fresco',
    'camaron',
    'queso',
    'leche',
    'crema',
    'yogurt',
    'huevo',
    'jamon',
    'jamón',
    'tocino',
    'pan',
    'tortilla',
  ];

  /// Analiza los artículos de la despensa e identifica los que tienen riesgo de merma
  static List<InsumoEnRiesgo> detectarInsumosEnRiesgo(List<Map<String, dynamic>> itemsDespensa) {
    final List<InsumoEnRiesgo> enRiesgo = [];
    final hoy = DateTime.now();

    for (var it in itemsDespensa) {
      final String nombre = (it['nombre'] ?? '').toString().toLowerCase().trim();
      if (nombre.isEmpty) continue;

      final dynamic cantidadRaw = it['cantidad'];
      final double cant = cantidadRaw is num
          ? cantidadRaw.toDouble()
          : (double.tryParse(cantidadRaw?.toString() ?? '') ?? 1.0);

      final dynamic precioRaw = it['precio'];
      final double precio = precioRaw is num
          ? precioRaw.toDouble()
          : (double.tryParse(precioRaw?.toString() ?? '') ?? 25.0);

      final double valorTotal = (precio > 0) ? (precio * (cant > 0 ? cant : 1.0)) : 25.0;

      final String fechaStr = it['fecha_ingreso']?.toString() ?? '';
      final fechaIngreso = DateTime.tryParse(fechaStr) ?? hoy.subtract(const Duration(days: 3));
      final int diasAntiguedad = hoy.difference(fechaIngreso).inDays;

      // Es perecedero si coincide con palabras clave o tiene más de 4 días en la despensa
      final bool esPerecederoPorNombre = _palabrasPerecederas.any((p) => nombre.contains(p));

      if (esPerecederoPorNombre || diasAntiguedad >= 4) {
        enRiesgo.add(InsumoEnRiesgo(
          id: it['id_item'] ?? it['id'],
          nombre: it['nombre'] ?? 'Ingrediente',
          cantidad: cant,
          precioEstimado: valorTotal,
          categoria: esPerecederoPorNombre ? 'Fresco Perecedero' : 'Por Consumir',
          diasEnDespensa: diasAntiguedad,
        ));
      }
    }

    // Ordenar de mayor a menor valor en riesgo
    enRiesgo.sort((a, b) => b.precioEstimado.compareTo(a.precioEstimado));
    return enRiesgo;
  }

  // =========================================================================
  // 3. RANKING COSTO-PROTEÍNA DEL MERCADO MEXICANO
  // =========================================================================

  /// Catálogo con precios y contenido proteico real calibrado en pesos mexicanos
  static List<ItemProteina> obtenerRankingCostoProteina() {
    return const [
      ItemProteina(
        nombre: 'Lentejas secas',
        categoria: 'Vegetal',
        precioReferencia: 38.0,
        unidadPresentacion: '1 kg seco (250g proteína)',
        gramosProteinaPorUnidad: 250.0,
        costoPorGramo: 0.15, // $38 / 250 = $0.15 MXN/g
        icono: Icons.grain,
        color: Color(0xFF6D4C41),
      ),
      ItemProteina(
        nombre: 'Frijol negro o pinto',
        categoria: 'Vegetal',
        precioReferencia: 42.0,
        unidadPresentacion: '1 kg seco (220g proteína)',
        gramosProteinaPorUnidad: 220.0,
        costoPorGramo: 0.19, // $42 / 220 = $0.19 MXN/g
        icono: Icons.spa,
        color: Color(0xFF4E342E),
      ),
      ItemProteina(
        nombre: 'Huevo fresco de gallina',
        categoria: 'Animal',
        precioReferencia: 46.0,
        unidadPresentacion: '1 kg / ~16 pzas (96g proteína)',
        gramosProteinaPorUnidad: 96.0,
        costoPorGramo: 0.48, // $46 / 96 = $0.48 MXN/g
        icono: Icons.egg_outlined,
        color: Color(0xFFF57F17),
      ),
      ItemProteina(
        nombre: 'Pechuga de Pollo sin piel',
        categoria: 'Animal',
        precioReferencia: 135.0,
        unidadPresentacion: '1 kg fresco (235g proteína)',
        gramosProteinaPorUnidad: 235.0,
        costoPorGramo: 0.57, // $135 / 235 = $0.57 MXN/g
        icono: Icons.kebab_dining,
        color: Color(0xFFD84315),
      ),
      ItemProteina(
        nombre: 'Filete de Tilapia',
        categoria: 'Animal',
        precioReferencia: 125.0,
        unidadPresentacion: '1 kg congelado (190g proteína)',
        gramosProteinaPorUnidad: 190.0,
        costoPorGramo: 0.66, // $125 / 190 = $0.66 MXN/g
        icono: Icons.set_meal,
        color: Color(0xFF00838F),
      ),
      ItemProteina(
        nombre: 'Atún en lata en agua',
        categoria: 'Animal',
        precioReferencia: 19.5,
        unidadPresentacion: '1 lata 140g (24g proteína)',
        gramosProteinaPorUnidad: 24.0,
        costoPorGramo: 0.81, // $19.5 / 24 = $0.81 MXN/g
        icono: Icons.waves,
        color: Color(0xFF0277BD),
      ),
      ItemProteina(
        nombre: 'Bistec de Res magro',
        categoria: 'Animal',
        precioReferencia: 210.0,
        unidadPresentacion: '1 kg fresco (220g proteína)',
        gramosProteinaPorUnidad: 220.0,
        costoPorGramo: 0.95, // $210 / 220 = $0.95 MXN/g
        icono: Icons.restaurant,
        color: Color(0xFFC2185B),
      ),
    ];
  }
}
