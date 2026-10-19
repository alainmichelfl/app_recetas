import 'package:flutter/material.dart';

/// Resultado del cálculo metabólico personalizado Mifflin-St Jeor
class ResultadoMetabolico {
  final int bmr;
  final int tdee;
  final int caloriasObjetivo;
  final int proteinasGramos;
  final int carbohidratosGramos;
  final int grasasGramos;
  final String objetivo;

  const ResultadoMetabolico({
    required this.bmr,
    required this.tdee,
    required this.caloriasObjetivo,
    required this.proteinasGramos,
    required this.carbohidratosGramos,
    required this.grasasGramos,
    required this.objetivo,
  });

  Map<String, dynamic> toMap() {
    return {
      'bmr': bmr,
      'tdee': tdee,
      'calorias': caloriasObjetivo,
      'proteinas': proteinasGramos,
      'carbs': carbohidratosGramos,
      'grasas': grasasGramos,
      'objetivo': objetivo,
    };
  }
}

/// Estado calculado del temporizador de ayuno intermitente
class EstadoAyuno {
  final bool enAyuno;
  final String protocolo;
  final int horasObjetivo;
  final DateTime? inicio;
  final Duration tiempoTranscurrido;
  final Duration tiempoRestante;
  final double progreso; // 0.0 a 1.0
  final bool completado;
  final String faseFisiologica;
  final String descripcionFase;

  const EstadoAyuno({
    required this.enAyuno,
    required this.protocolo,
    required this.horasObjetivo,
    this.inicio,
    required this.tiempoTranscurrido,
    required this.tiempoRestante,
    required this.progreso,
    required this.completado,
    required this.faseFisiologica,
    required this.descripcionFase,
  });
}

/// Evaluación de densidad nutricional diaria
class EvaluacionNutricional {
  final int puntuacion; // 0 - 100
  final String grado; // A+, A, B, C
  final Color colorGrado;
  final String titulo;
  final String diagnostico;
  final List<String> consejos;

  const EvaluacionNutricional({
    required this.puntuacion,
    required this.grado,
    required this.colorGrado,
    required this.titulo,
    required this.diagnostico,
    required this.consejos,
  });
}

/// Servicio de Bienestar Inteligente: Métricas metabólicas, Ayuno y Calidad Nutricional
class ServicioBienestar {
  ServicioBienestar._();

  // =========================================================================
  // 🧮 1. CALCULADORA METABÓLICA (Mifflin-St Jeor)
  // =========================================================================

  /// Calcula la tasa metabólica basal (BMR) con la fórmula clínica Mifflin-St Jeor
  static int calcularBmr({
    required double pesoKg,
    required double alturaCm,
    required int edad,
    required bool esHombre,
  }) {
    if (pesoKg <= 0 || alturaCm <= 0 || edad <= 0) return 1500;
    final double base = (10.0 * pesoKg) + (6.25 * alturaCm) - (5.0 * edad);
    final double bmr = esHombre ? (base + 5.0) : (base - 161.0);
    return bmr.round().clamp(800, 4000);
  }

  /// Multiplicador de actividad física sobre el BMR para obtener el TDEE
  static double factorActividad(String nivelActividad) {
    switch (nivelActividad.toLowerCase()) {
      case 'sedentario':
        return 1.2;
      case 'ligero':
        return 1.375;
      case 'moderado':
        return 1.55;
      case 'intenso':
        return 1.725;
      case 'muy activo':
      case 'atleta':
        return 1.9;
      default:
        return 1.375;
    }
  }

  /// Calcula el plan nutricional completo según perfil individual
  static ResultadoMetabolico calcularPlanNutricional({
    required double pesoKg,
    required double alturaCm,
    required int edad,
    required bool esHombre,
    required String nivelActividad,
    required String objetivo, // 'Déficit', 'Mantenimiento', 'Superávit'
  }) {
    final int bmr = calcularBmr(
      pesoKg: pesoKg,
      alturaCm: alturaCm,
      edad: edad,
      esHombre: esHombre,
    );

    final double factor = factorActividad(nivelActividad);
    final int tdee = (bmr * factor).round();

    int caloriasObjetivo = tdee;
    double factorProteinaPorKg = 1.8;

    final objNorm = objetivo.toLowerCase();
    if (objNorm.contains('déficit') || objNorm.contains('baja') || objNorm.contains('deficit')) {
      caloriasObjetivo = (tdee - 450).clamp(1200, 5000);
      factorProteinaPorKg = 2.0; // Proteger masa magra en déficit
    } else if (objNorm.contains('superávit') || objNorm.contains('volumen') || objNorm.contains('alta')) {
      caloriasObjetivo = (tdee + 350).clamp(1500, 6000);
      factorProteinaPorKg = 2.0; // Apoyo anabólico para síntesis muscular
    }

    // Gramos de proteína: peso * factor
    int proteinas = (pesoKg * factorProteinaPorKg).round().clamp(60, 260);

    // Grasas saludables: ~25% de las calorías totales (9 kcal por gramo de grasa)
    int grasas = ((caloriasObjetivo * 0.25) / 9.0).round().clamp(30, 160);

    // Carbohidratos: calorías restantes entre 4 kcal/g
    final int caloriasProteina = proteinas * 4;
    final int caloriasGrasa = grasas * 9;
    final int caloriasRestantes = caloriasObjetivo - caloriasProteina - caloriasGrasa;
    int carbohidratos = (caloriasRestantes / 4.0).round().clamp(40, 500);

    return ResultadoMetabolico(
      bmr: bmr,
      tdee: tdee,
      caloriasObjetivo: caloriasObjetivo,
      proteinasGramos: proteinas,
      carbohidratosGramos: carbohidratos,
      grasasGramos: grasas,
      objetivo: objetivo,
    );
  }

  // =========================================================================
  // ⏱️ 2. TEMPORIZADOR DE AYUNO INTERMITENTE
  // =========================================================================

  /// Obtiene la cantidad de horas de ayuno según el protocolo
  static int horasPorProtocolo(String protocolo) {
    switch (protocolo) {
      case '16/8':
        return 16;
      case '14/10':
        return 14;
      case '12/12':
        return 12;
      case '18/6':
        return 18;
      case '20/4':
        return 20;
      default:
        return 16;
    }
  }

  /// Calcula el estado dinámico del ayuno
  static EstadoAyuno evaluarEstadoAyuno({
    required bool enAyuno,
    required String protocolo,
    DateTime? inicio,
    DateTime? ahora,
  }) {
    final DateTime tiempoActual = ahora ?? DateTime.now();
    final int horasMeta = horasPorProtocolo(protocolo);

    if (!enAyuno || inicio == null) {
      return EstadoAyuno(
        enAyuno: false,
        protocolo: protocolo,
        horasObjetivo: horasMeta,
        tiempoTranscurrido: Duration.zero,
        tiempoRestante: Duration(hours: horasMeta),
        progreso: 0.0,
        completado: false,
        faseFisiologica: 'Ventana de Alimentación 🥗',
        descripcionFase: 'Tu ventana para comer está abierta. Prioriza proteínas limpias, verduras e hidratación.',
      );
    }

    final Duration transcurrido = tiempoActual.difference(inicio);
    final Duration duracionTotal = Duration(hours: horasMeta);
    final Duration restante = transcurrido >= duracionTotal
        ? Duration.zero
        : duracionTotal - transcurrido;

    final double segundosTotales = duracionTotal.inSeconds.toDouble();
    final double progreso = segundosTotales > 0
        ? (transcurrido.inSeconds / segundosTotales).clamp(0.0, 1.0)
        : 0.0;
    final bool completado = transcurrido >= duracionTotal;

    final double horasTranscurridas = transcurrido.inMinutes / 60.0;
    String fase;
    String descripcion;

    if (completado) {
      fase = '¡Ayuno Cumplido con Éxito! 🎉';
      descripcion = 'Has alcanzado tus $horasMeta hrs de ayuno. Rompe tu ayuno con proteína suave o caldo nutritivo.';
    } else if (horasTranscurridas < 4.0) {
      fase = 'Fase 1: Digestión & Absorción 🥗';
      descripcion = 'El cuerpo digiere los nutrientes de tu última comida. Glucosa e insulina en niveles estándar.';
    } else if (horasTranscurridas < 12.0) {
      fase = 'Fase 2: Caída de Insulina & Vaciado de Glucógeno ⚡';
      descripcion = 'La insulina desciende y el cuerpo recurre a reservas de glucógeno hepático. ¡Toma agua!';
    } else if (horasTranscurridas < 16.0) {
      fase = 'Fase 3: Quema de Grasa & Autofagia Celular 🔥';
      descripcion = 'Inicio de autofagia y regeneración celular. Mayor proporción de energía proveniente de grasa.';
    } else {
      fase = 'Fase 4: Cetosis Leve & Limpieza Celular Profunda 🧬';
      descripcion = 'Máxima producción de cuerpos cetónicos y limpieza mitocondrial activa.';
    }

    return EstadoAyuno(
      enAyuno: true,
      protocolo: protocolo,
      horasObjetivo: horasMeta,
      inicio: inicio,
      tiempoTranscurrido: transcurrido,
      tiempoRestante: restante,
      progreso: progreso,
      completado: completado,
      faseFisiologica: fase,
      descripcionFase: descripcion,
    );
  }

  // =========================================================================
  // 🥗 3. SEMÁFORO DE DENSIDAD NUTRICIONAL Y CALIDAD
  // =========================================================================

  /// Evalúa el balance integral de la alimentación del día
  static EvaluacionNutricional evaluarDensidadDia({
    required int vasosAgua,
    required int metaVasosAgua,
    required int caloriasConsumidas,
    required int metaCalorias,
    required int proteinasConsumidas,
    required int metaProteinas,
    required int comidasPlaneadasHoy,
  }) {
    int puntos = 0;
    final List<String> consejos = [];

    // 1. Hidratación (25 pts)
    final double ratioAgua = metaVasosAgua > 0 ? (vasosAgua / metaVasosAgua).clamp(0.0, 1.0) : 0.0;
    puntos += (ratioAgua * 25).round();
    if (vasosAgua < (metaVasosAgua * 0.5)) {
      consejos.add('Te falta hidratarte: toma al menos ${(metaVasosAgua - vasosAgua) * 250} ml más de agua hoy 💧');
    } else if (vasosAgua >= metaVasosAgua) {
      consejos.add('¡Hidratación perfecta! Cumpliste tu meta de 2L diarios 💧✅');
    }

    // 2. Proteína (35 pts) - Crucial para saciedad y musculatura
    final double ratioProt = metaProteinas > 0 ? (proteinasConsumidas / metaProteinas).clamp(0.0, 1.0) : 0.0;
    puntos += (ratioProt * 35).round();
    if (metaProteinas - proteinasConsumidas > 30) {
      final faltante = metaProteinas - proteinasConsumidas;
      consejos.add('Te faltan ~${faltante}g de proteína: incluye pechuga de pollo, huevos, atún o legumbres 🍗');
    } else if (ratioProt >= 0.9) {
      consejos.add('Excelente aporte proteico para preservar y tonificar tu masa magra 💪');
    }

    // 3. Balance Calórico (25 pts)
    if (metaCalorias > 0 && caloriasConsumidas > 0) {
      final double desvio = ((caloriasConsumidas - metaCalorias).abs()) / metaCalorias;
      if (desvio <= 0.10) {
        puntos += 25; // Dentro del 10% de la meta
        consejos.add('Balance calórico impecable respecto a tu meta 🎯');
      } else if (desvio <= 0.20) {
        puntos += 18;
      } else if (desvio <= 0.35) {
        puntos += 10;
        if (caloriasConsumidas > metaCalorias) {
          consejos.add('Excediste ligeramente tus calorías de hoy. Puedes compensar con una cena ligera 🥗');
        } else {
          consejos.add('Vas por debajo de tu requerimiento calórico mínimo para energía óptima ⚡');
        }
      }
    }

    // 4. Planificación del Menú (15 pts)
    if (comidasPlaneadasHoy >= 3) {
      puntos += 15;
      consejos.add('Día completamente estructurado en tu planeador culinario 📅');
    } else if (comidasPlaneadasHoy > 0) {
      puntos += 10;
      consejos.add('Planea tus comidas restantes para evitar antojos imprevistos.');
    } else {
      consejos.add('Agrega tus platillos al planeador para un cálculo 100% exacto.');
    }

    final int puntuacionFinal = puntos.clamp(10, 100);

    String grado;
    Color colorGrado;
    String titulo;
    String diagnostico;

    if (puntuacionFinal >= 85) {
      grado = 'A+';
      colorGrado = const Color(0xFF2E7D32); // Verde esmeralda
      titulo = 'Densidad Nutricional Óptima 🌟';
      diagnostico = 'Excelente balance en hidratación, macronutrientes y planeación culinaria.';
    } else if (puntuacionFinal >= 70) {
      grado = 'A';
      colorGrado = const Color(0xFF00897B); // Teal
      titulo = 'Balance Saludable 🥗';
      diagnostico = 'Buen ritmo nutricional. Ajusta los pequeños detalles para alcanzar la excelencia.';
    } else if (puntuacionFinal >= 50) {
      grado = 'B';
      colorGrado = const Color(0xFFFB8C00); // Ámbar naranja
      titulo = 'En Progreso 🍎';
      diagnostico = 'Tienes un avance positivo, pero requieres asegurar más proteína o hidratación hoy.';
    } else {
      grado = 'C';
      colorGrado = const Color(0xFFD32F2F); // Rojo suave
      titulo = 'Atención Requerida ⚠️';
      diagnostico = 'Registra tus comidas del día e incrementa tu consumo de agua para activar tu metabolismo.';
    }

    return EvaluacionNutricional(
      puntuacion: puntuacionFinal,
      grado: grado,
      colorGrado: colorGrado,
      titulo: titulo,
      diagnostico: diagnostico,
      consejos: consejos,
    );
  }
}
