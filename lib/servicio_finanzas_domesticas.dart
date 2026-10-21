import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'servicio_historial_cocina.dart';

/// Insignia desbloqueable del Reto Culinario Antidesperdicio
class InsigniaZeroWaste {
  final String id;
  final String titulo;
  final String subtitulo;
  final int diasRequeridos;
  final IconData icono;
  final Color color;
  final bool desbloqueada;

  const InsigniaZeroWaste({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.diasRequeridos,
    required this.icono,
    required this.color,
    required this.desbloqueada,
  });
}

/// Estado actual de la racha antidesperdicio y gamificación
class EstadoRachaZeroWaste {
  final int diasRacha;
  final int recordHistorico;
  final bool registradoHoy;
  final List<InsigniaZeroWaste> insignias;
  final InsigniaZeroWaste? proximaInsignia;
  final double progresoProxima; // 0.0 a 1.0
  final int diasFaltantesProxima;
  final double ahorroEstimadoAcumulado;

  const EstadoRachaZeroWaste({
    required this.diasRacha,
    required this.recordHistorico,
    required this.registradoHoy,
    required this.insignias,
    this.proximaInsignia,
    required this.progresoProxima,
    required this.diasFaltantesProxima,
    required this.ahorroEstimadoAcumulado,
  });
}

/// Desafío mensual de ahorro familiar ("Club del Súper")
class DesafioAhorroMensual {
  final double metaAhorroMensual;
  final double ahorroLogradoMes;
  final double porcentajeCumplido; // 0 a 100%+
  final int diasRestantesMes;
  final int comidasCaserasMes;
  final String estadoMensaje;
  final String metafora;

  const DesafioAhorroMensual({
    required this.metaAhorroMensual,
    required this.ahorroLogradoMes,
    required this.porcentajeCumplido,
    required this.diasRestantesMes,
    required this.comidasCaserasMes,
    required this.estadoMensaje,
    required this.metafora,
  });
}

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

/// Eco-Score y Huella Positiva generada al cocinar en casa y evitar mermas
class ImpactoEcologico {
  final double co2PrevenidoKg;
  final int aguaVirtualSalvadaLitros;
  final int envasesPlasticosAhorrados;
  final int comidasCaseras;
  final int insumosRescatados;
  final String nivelSostenibilidad;
  final String metaforaImpacto;
  final String equivalenciaArboles;

  const ImpactoEcologico({
    required this.co2PrevenidoKg,
    required this.aguaVirtualSalvadaLitros,
    required this.envasesPlasticosAhorrados,
    required this.comidasCaseras,
    required this.insumosRescatados,
    required this.nivelSostenibilidad,
    required this.metaforaImpacto,
    required this.equivalenciaArboles,
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
  final ImpactoEcologico? impactoEcologico;

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
    this.impactoEcologico,
  });

  /// Genera un documento HTML interactivo y listo para imprimir en PDF (Prioridad 10)
  String generarHtmlBalanceMensual() {
    final buffer = StringBuffer();
    final fechaHoy = DateTime.now();
    final nombreMes = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ][fechaHoy.month - 1];

    buffer.writeln('''<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Balance Mensual Culinario & Financiero - Jitomate y Cebolla</title>
  <style>
    :root {
      --primary: #C62828;
      --primary-dark: #1E2022;
      --secondary: #2E7D32;
      --accent: #FFA000;
      --bg: #F8F9FA;
      --card-bg: #FFFFFF;
      --text: #212121;
      --text-muted: #666666;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      margin: 0;
      padding: 24px;
      background: var(--bg);
      color: var(--text);
      line-height: 1.5;
    }
    .container {
      max-width: 820px;
      margin: 0 auto;
      background: var(--card-bg);
      border-radius: 16px;
      padding: 32px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.08);
    }
    .header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 2px solid #EEEEEE;
      padding-bottom: 20px;
      margin-bottom: 24px;
    }
    .header h1 {
      margin: 0;
      font-size: 24px;
      color: var(--primary);
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .header p {
      margin: 4px 0 0;
      color: var(--text-muted);
      font-size: 13px;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 16px;
      margin-bottom: 24px;
    }
    .kpi-card {
      background: #F4F6F8;
      border-radius: 12px;
      padding: 16px;
      border-left: 4px solid var(--primary);
    }
    .kpi-card.green { border-color: var(--secondary); background: #E8F5E9; }
    .kpi-card.blue { border-color: #1976D2; background: #E3F2FD; }
    .kpi-card.amber { border-color: var(--accent); background: #FFF8E1; }
    .kpi-title {
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      color: var(--text-muted);
      margin-bottom: 4px;
    }
    .kpi-value {
      font-size: 22px;
      font-weight: 800;
      color: var(--primary-dark);
    }
    .kpi-sub {
      font-size: 11px;
      color: var(--text-muted);
      margin-top: 2px;
    }
    .eco-box {
      background: linear-gradient(135deg, #E8F5E9 0%, #C8E6C9 100%);
      border-radius: 14px;
      padding: 20px;
      margin-bottom: 24px;
      border: 1px solid #A5D6A7;
    }
    .eco-box h3 {
      margin-top: 0;
      color: #1B5E20;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .btn-print {
      background: var(--primary);
      color: white;
      border: none;
      padding: 10px 18px;
      font-size: 14px;
      font-weight: bold;
      border-radius: 8px;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
    }
    .btn-print:hover { background: #B71C1C; }
    .footer {
      margin-top: 32px;
      padding-top: 16px;
      border-top: 1px solid #EEEEEE;
      text-align: center;
      font-size: 12px;
      color: var(--text-muted);
    }
    @media print {
      body { background: white; padding: 0; }
      .container { box-shadow: none; padding: 0; border-radius: 0; }
      .no-print { display: none !important; }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div>
        <h1>🍅🧅 Jitomate y Cebolla</h1>
        <p>Balance Ejecutivo Mensual • <strong>$nombreMes ${fechaHoy.year}</strong></p>
      </div>
      <div class="no-print">
        <button class="btn-print" onclick="window.print()">🖨️ Imprimir / Guardar en PDF</button>
      </div>
    </div>

    <div class="grid">
      <div class="kpi-card green">
        <div class="kpi-title">Ahorro Mensual vs Delivery</div>
        <div class="kpi-value">+\$${proyeccionAhorroMensual.toStringAsFixed(2)} MXN</div>
        <div class="kpi-sub">Proyección anual: +\$${proyeccionAhorroAnual.toStringAsFixed(2)} MXN</div>
      </div>
      <div class="kpi-card">
        <div class="kpi-title">Costo por Platillo Casero</div>
        <div class="kpi-value">\$${costoPorPlatillo.toStringAsFixed(2)} MXN</div>
        <div class="kpi-sub">vs \$140.00 MXN en delivery comercial</div>
      </div>
      <div class="kpi-card blue">
        <div class="kpi-title">Patrimonio en Despensa</div>
        <div class="kpi-value">\$${capitalDespensa.toStringAsFixed(2)} MXN</div>
        <div class="kpi-sub">Capital inventariado activo</div>
      </div>
      <div class="kpi-card amber">
        <div class="kpi-title">Presupuesto Semanal Súper</div>
        <div class="kpi-value">\$${presupuestoSemanal.toStringAsFixed(2)} MXN</div>
        <div class="kpi-sub">Costo cotizado: \$${costoSuperSemanal.toStringAsFixed(2)} MXN</div>
      </div>
    </div>''');

    if (impactoEcologico != null) {
      final eco = impactoEcologico!;
      buffer.writeln('''
    <div class="eco-box">
      <h3>🌱 Huella Positiva & Eco-Score del Hogar: ${eco.nivelSostenibilidad}</h3>
      <p style="margin: 0 0 12px; font-size: 13px; color: #2E7D32;">
        ${eco.metaforaImpacto} • ${eco.equivalenciaArboles}
      </p>
      <div style="display: flex; gap: 20px; flex-wrap: wrap;">
        <div><strong>🌍 ${eco.co2PrevenidoKg.toStringAsFixed(1)} kg</strong> de CO₂ prevenidos</div>
        <div><strong>💧 ${eco.aguaVirtualSalvadaLitros} Litros</strong> de agua virtual resguardada</div>
        <div><strong>🥡 ${eco.envasesPlasticosAhorrados} envases</strong> de unicel/plástico evitados</div>
      </div>
    </div>''');
    }

    buffer.writeln('''
    <div class="footer">
      <p>Generado oficialmente desde <strong>Jitomate y Cebolla</strong> (www.jitomateycebolla.com) • Tu asistente culinario y financiero.</p>
    </div>
  </div>
</body>
</html>''');

    return buffer.toString();
  }

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
    if (impactoEcologico != null) {
      final eco = impactoEcologico!;
      buffer.writeln('────────────────────────');
      buffer.writeln('🌱 *Eco-Score & Huella Positiva:* ${eco.nivelSostenibilidad}');
      buffer.writeln('  • CO₂ Prevenido: ${eco.co2PrevenidoKg.toStringAsFixed(1)} kg');
      buffer.writeln('  • Agua Virtual Salvada: ${eco.aguaVirtualSalvadaLitros} Litros');
      buffer.writeln('  • Envases Evitados: ${eco.envasesPlasticosAhorrados} recipientes');
      buffer.writeln('  • Impacto: ${eco.metaforaImpacto}');
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

  // =========================================================================
  // 4. RETO CULINARIO ANTIDESPERDICIO (ZERO-WASTE STREAK & INSIGNIAS)
  // =========================================================================

  static const String _keyRachaActual = 'zero_waste_racha_actual_v1';
  static const String _keyRecordHistorico = 'zero_waste_record_historico_v1';
  static const String _keyUltimaFecha = 'zero_waste_ultima_fecha_v1';
  static const String _keyMetaAhorroMensual = 'meta_ahorro_mensual_familiar_v1';

  /// Catálogo de las 4 insignias del Reto Antidesperdicio
  static List<InsigniaZeroWaste> _catalogoInsignias(int diasEfectivos) {
    return [
      InsigniaZeroWaste(
        id: 'guardian_despensa',
        titulo: 'Guardián de la Despensa 🛡️',
        subtitulo: '3 días continuos cocinando sin merma',
        diasRequeridos: 3,
        icono: Icons.shield_outlined,
        color: const Color(0xFF2E7D32), // Verde bosque
        desbloqueada: diasEfectivos >= 3,
      ),
      InsigniaZeroWaste(
        id: 'chef_consciente',
        titulo: 'Chef Consciente 🌱',
        subtitulo: '7 días continuos de aprovechamiento total',
        diasRequeridos: 7,
        icono: Icons.eco_outlined,
        color: const Color(0xFF00897B), // Teal esmeralda
        desbloqueada: diasEfectivos >= 7,
      ),
      InsigniaZeroWaste(
        id: 'maestro_cero_merma',
        titulo: 'Maestro Cero Merma 🏆',
        subtitulo: '14 días de maestría culinaria sin desperdicio',
        diasRequeridos: 14,
        icono: Icons.emoji_events_outlined,
        color: const Color(0xFFF57C00), // Ámbar dorado
        desbloqueada: diasEfectivos >= 14,
      ),
      InsigniaZeroWaste(
        id: 'inversionista_super',
        titulo: 'Inversionista del Súper 💰',
        subtitulo: '30 días optimizando el patrimonio de tu cocina',
        diasRequeridos: 30,
        icono: Icons.savings_outlined,
        color: const Color(0xFF6A1B9A), // Púrpura real
        desbloqueada: diasEfectivos >= 30,
      ),
    ];
  }

  static String _formatearFechaSimple(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Obtiene el estado actual de la racha antidesperdicio
  static Future<EstadoRachaZeroWaste> obtenerEstadoRachaZeroWaste() async {
    final prefs = await SharedPreferences.getInstance();
    final int savedRacha = prefs.getInt(_keyRachaActual) ?? 0;
    final int recordHistorico = prefs.getInt(_keyRecordHistorico) ?? savedRacha;
    final String? ultimaFechaStr = prefs.getString(_keyUltimaFecha);

    final hoy = DateTime.now();
    final fechaHoy = DateTime(hoy.year, hoy.month, hoy.day);

    int diasRacha = savedRacha;
    bool registradoHoy = false;

    if (ultimaFechaStr != null && ultimaFechaStr.isNotEmpty) {
      final parsed = DateTime.tryParse(ultimaFechaStr);
      if (parsed != null) {
        final fechaUltima = DateTime(parsed.year, parsed.month, parsed.day);
        final diff = fechaHoy.difference(fechaUltima).inDays;

        if (diff == 0) {
          registradoHoy = true;
          diasRacha = savedRacha;
        } else if (diff == 1) {
          // Racha vigente de ayer, aún pendiente de registrar hoy
          registradoHoy = false;
          diasRacha = savedRacha;
        } else {
          // Se rompió la racha al pasar más de 1 día sin registrar
          registradoHoy = false;
          diasRacha = 0;
          await prefs.setInt(_keyRachaActual, 0);
        }
      }
    } else {
      diasRacha = 0;
      registradoHoy = false;
    }

    final int diasParaInsignias = max(diasRacha, recordHistorico);
    final insignias = _catalogoInsignias(diasParaInsignias);

    // Calcular la próxima insignia por desbloquear
    InsigniaZeroWaste? proxima;
    for (var ins in insignias) {
      if (!ins.desbloqueada) {
        proxima = ins;
        break;
      }
    }

    double progresoProxima = 1.0;
    int diasFaltantes = 0;
    if (proxima != null) {
      diasFaltantes = max(0, proxima.diasRequeridos - diasRacha);
      progresoProxima = (diasRacha / proxima.diasRequeridos).clamp(0.0, 1.0);
    }

    // Ahorro estimado: cada día cocinando en casa sin merma genera un promedio de $85 MXN
    final double ahorroEstimado = diasRacha * 85.0;

    return EstadoRachaZeroWaste(
      diasRacha: diasRacha,
      recordHistorico: max(recordHistorico, diasRacha),
      registradoHoy: registradoHoy,
      insignias: insignias,
      proximaInsignia: proxima,
      progresoProxima: progresoProxima,
      diasFaltantesProxima: diasFaltantes,
      ahorroEstimadoAcumulado: ahorroEstimado,
    );
  }

  /// Registra un día de cocina sin merma / desperdicio, avanzando la racha
  static Future<EstadoRachaZeroWaste> registrarDiaSinDesperdicio({String? razon}) async {
    final prefs = await SharedPreferences.getInstance();
    final int savedRacha = prefs.getInt(_keyRachaActual) ?? 0;
    final int recordHistorico = prefs.getInt(_keyRecordHistorico) ?? savedRacha;
    final String? ultimaFechaStr = prefs.getString(_keyUltimaFecha);

    final hoy = DateTime.now();
    final fechaHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final fechaHoyStr = _formatearFechaSimple(fechaHoy);

    int nuevaRacha = 1;

    if (ultimaFechaStr != null && ultimaFechaStr.isNotEmpty) {
      final parsed = DateTime.tryParse(ultimaFechaStr);
      if (parsed != null) {
        final fechaUltima = DateTime(parsed.year, parsed.month, parsed.day);
        final diff = fechaHoy.difference(fechaUltima).inDays;

        if (diff == 0) {
          // Ya fue registrado hoy
          return await obtenerEstadoRachaZeroWaste();
        } else if (diff == 1) {
          // Día consecutivo: suma a la racha
          nuevaRacha = savedRacha + 1;
        } else {
          // Se reinicia la racha a 1 día
          nuevaRacha = 1;
        }
      }
    }

    final nuevoRecord = max(recordHistorico, nuevaRacha);
    await prefs.setInt(_keyRachaActual, nuevaRacha);
    await prefs.setInt(_keyRecordHistorico, nuevoRecord);
    await prefs.setString(_keyUltimaFecha, fechaHoyStr);

    return await obtenerEstadoRachaZeroWaste();
  }

  /// Reinicia la racha a ceros (para pruebas o reinicio voluntario)
  static Future<void> reiniciarRachaZeroWaste() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRachaActual);
    await prefs.remove(_keyUltimaFecha);
  }

  // =========================================================================
  // 5. DESAFÍO DE AHORRO FAMILIAR A 30 DÍAS ("CLUB DEL SÚPER")
  // =========================================================================

  /// Obtiene la meta mensual configurada (default $3,000 MXN)
  static Future<double> obtenerMetaAhorroMensual() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_keyMetaAhorroMensual) ?? 3000.0;
  }

  /// Guarda una nueva meta de ahorro mensual
  static Future<void> guardarMetaAhorroMensual(double nuevaMeta) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMetaAhorroMensual, max(500.0, nuevaMeta));
  }

  /// Obtiene el progreso del desafío familiar a 30 días
  static Future<DesafioAhorroMensual> obtenerDesafioAhorroMensual({
    double? gastoSemanalActual,
    int? comidasMes,
  }) async {
    final double meta = await obtenerMetaAhorroMensual();
    final hoy = DateTime.now();
    final diasEnMes = DateTime(hoy.year, hoy.month + 1, 0).day;
    final int diasRestantes = max(0, diasEnMes - hoy.day);

    int totalComidasCaseras = comidasMes ?? 0;
    if (comidasMes == null) {
      try {
        final todos = await ServicioHistorialCocina.obtenerTodos();
        totalComidasCaseras = todos
            .where((r) => r.fecha.year == hoy.year && r.fecha.month == hoy.month)
            .fold<int>(0, (acc, r) => acc + r.veces);
      } catch (e) {
        totalComidasCaseras = 0;
      }
    }

    // Ahorro promedio por platillo preparado en casa vs delivery ($140 - $55 = ~$85 MXN)
    final double ahorroPorPlatillos = totalComidasCaseras * 85.0;

    // Si hay un costo de súper semanal activo, comparar también su ahorro prorrateado
    double ahorroProyectadoSemanal = 0.0;
    if (gastoSemanalActual != null && gastoSemanalActual > 0) {
      final res = calcularAhorroVsDelivery(
        costoTotalSuper: gastoSemanalActual,
        comidasPlaneadas: 14,
      );
      final double ahorroSem = (res['ahorroSemanal'] as num?)?.toDouble() ?? 0.0;
      ahorroProyectadoSemanal = ahorroSem * (hoy.day / 7.0);
    }

    final double ahorroTotalMes = max(ahorroPorPlatillos, ahorroProyectadoSemanal);
    final double porcentaje = meta > 0 ? (ahorroTotalMes / meta) * 100.0 : 0.0;

    String mensaje;
    String metafora;

    if (porcentaje >= 100.0) {
      mensaje = '¡META CUMPLIDA! 🎉 Tu familia superó el desafío mensual de ahorro.';
      metafora = '¡Con +\$${ahorroTotalMes.toStringAsFixed(0)} MXN cubrieron el súper de dos semanas completas! 🛒✨';
    } else if (porcentaje >= 75.0) {
      mensaje = '¡Están en la recta final! 🚀 ${porcentaje.toStringAsFixed(0)}% de la meta lograda.';
      metafora = '¡Faltan solo \$${(meta - ahorroTotalMes).clamp(0.0, meta).toStringAsFixed(0)} MXN para completar el desafío del mes!';
    } else if (porcentaje >= 40.0) {
      mensaje = '¡Excelente ritmo familiar! 📈 Llevan el ${porcentaje.toStringAsFixed(0)}% acumulado.';
      metafora = '¡Han evitado el sobrecosto de delivery preparando comida casera de calidad!';
    } else {
      mensaje = '¡Desafío activo! Cada comida en casa suma a la alcancía familiar 🐷';
      metafora = 'Meta familiar: \$${meta.toStringAsFixed(0)} MXN. ¡Aún quedan $diasRestantes días para alcanzarla!';
    }

    return DesafioAhorroMensual(
      metaAhorroMensual: meta,
      ahorroLogradoMes: ahorroTotalMes,
      porcentajeCumplido: porcentaje,
      diasRestantesMes: diasRestantes,
      comidasCaserasMes: totalComidasCaseras,
      estadoMensaje: mensaje,
      metafora: metafora,
    );
  }

  // =========================================================================
  // 6. ECO-SCORE CULINARIO & HUELLA POSITIVA (PRIORIDAD 28)
  // =========================================================================

  /// Calcula el impacto ecológico positivo por cocinar en casa y evitar desperdicio
  static ImpactoEcologico calcularImpactoEcologico({
    required int comidasCaseras,
    int insumosRescatados = 0,
  }) {
    final int comidas = max(0, comidasCaseras);
    final int insumos = max(0, insumosRescatados);

    // Cada platillo casero vs moto de delivery + empaques previene ~0.82 kg de CO2
    final double co2 = (comidas * 0.82) + (insumos * 0.45);

    // Cada platillo resguarda agua vs cadena comercial (~45 L), y cada insumo salvado (~150 L huella hídrica virtual)
    final int agua = (comidas * 45) + (insumos * 150);

    // Contenedores unicel/plástico y bolsas desechables evitadas (~2 por pedido)
    final int envases = comidas * 2;

    final int puntaje = comidas + (insumos * 2);
    String nivel;
    String metafora;
    String equivalencia;

    if (puntaje >= 30) {
      nivel = 'Guardián del Planeta 🌍✨ (Nivel Élite)';
      metafora = '¡Tu cocina es un santuario sustentable de cero desperdicio!';
      equivalencia = 'Equivale a absorber el CO₂ emitido por un auto en un viaje de ${(co2 * 5.2).round()} km 🚗';
    } else if (puntaje >= 15) {
      nivel = 'Chef Sustentable 🌿 (Nivel 3)';
      metafora = '¡Gran reducción de huella hídrica y plásticos de un solo uso!';
      equivalencia = 'Equivale al agua de ${(agua / 70).round()} regaderazos de 5 minutos 🚿';
    } else if (puntaje >= 6) {
      nivel = 'Hogar Consciente 🍃 (Nivel 2)';
      metafora = '¡Estás transformando tus hábitos y protegiendo el entorno!';
      equivalencia = 'Has evitado $envases recipientes plásticos y unicel contaminante 🥡';
    } else {
      nivel = 'Semilla Verde 🌱 (Nivel 1)';
      metafora = 'Cada comida casera y cada ingrediente aprovechado marca la diferencia.';
      equivalencia = '¡Comenzando tu camino hacia la cocina de desperdicio cero!';
    }

    return ImpactoEcologico(
      co2PrevenidoKg: co2,
      aguaVirtualSalvadaLitros: agua,
      envasesPlasticosAhorrados: envases,
      comidasCaseras: comidas,
      insumosRescatados: insumos,
      nivelSostenibilidad: nivel,
      metaforaImpacto: metafora,
      equivalenciaArboles: equivalencia,
    );
  }
}

