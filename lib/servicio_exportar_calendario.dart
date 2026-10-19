import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as native_cal;

class ServicioExportarCalendario {
  /// Genera el contenido de un archivo iCalendar (.ics) estándar (RFC 5545)
  static String generarIcs(
    List<Map<String, dynamic>> items, {
    String nombreCalendario = 'Menú Semanal - Jitomate y Cebolla',
  }) {
    final StringBuffer sb = StringBuffer();
    sb.writeln('BEGIN:VCALENDAR');
    sb.writeln('VERSION:2.0');
    sb.writeln('PRODID:-//Jitomate y Cebolla//Menu Semanal//ES');
    sb.writeln('CALSCALE:GREGORIAN');
    sb.writeln('METHOD:PUBLISH');
    sb.writeln('X-WR-CALNAME:${_escaparTexto(nombreCalendario)}');

    final nowUtc = DateTime.now().toUtc();
    final dtStamp = _formatoUtc(nowUtc);

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final receta = item['recetas'] is Map ? item['recetas'] as Map : {};
      final titulo = (receta['titulo'] ?? 'Receta').toString().replaceAll('\n', ' ');
      final tipo = (item['tipo_comida'] ?? 'Comida').toString();
      final fechaStr = item['fecha']?.toString() ?? '';
      final calorias = receta['calorias']?.toString() ?? 'N/A';
      final descripcion = (receta['descripcion'] ?? '').toString();

      DateTime? fecha = DateTime.tryParse(fechaStr);
      if (fecha == null) continue;

      int hora = 14;
      if (tipo == 'Desayuno') hora = 9;
      if (tipo == 'Cena') hora = 20;
      if (tipo == 'Snack') hora = 17;

      final inicio = DateTime(fecha.year, fecha.month, fecha.day, hora, 0);
      final fin = inicio.add(const Duration(hours: 1));

      final dtStart = _formatoIcsLocal(inicio);
      final dtEnd = _formatoIcsLocal(fin);
      final uid = '${inicio.millisecondsSinceEpoch}-$i@jitomateycebolla.com';

      sb.writeln('BEGIN:VEVENT');
      sb.writeln('UID:$uid');
      sb.writeln('DTSTAMP:$dtStamp');
      sb.writeln('DTSTART:$dtStart');
      sb.writeln('DTEND:$dtEnd');
      sb.writeln('SUMMARY:${_escaparTexto('🧑‍🍳 Cocinar: $titulo ($tipo)')}');
      sb.writeln(
        'DESCRIPTION:${_escaparTexto('Platillo planeado desde Jitomate y Cebolla 🍅🧅\\nTipo: $tipo\\nCalorías: $calorias kcal\\n$descripcion')}',
      );
      sb.writeln('LOCATION:Mi Cocina');
      sb.writeln('STATUS:CONFIRMED');
      sb.writeln('END:VEVENT');
    }

    sb.writeln('END:VCALENDAR');
    return sb.toString();
  }

  /// Genera una URL directa para agregar un evento a Google Calendar Web / App
  static String generarUrlGoogleCalendar(Map<String, dynamic> item) {
    final receta = item['recetas'] is Map ? item['recetas'] as Map : {};
    final titulo = (receta['titulo'] ?? 'Receta').toString().replaceAll('\n', ' ');
    final tipo = (item['tipo_comida'] ?? 'Comida').toString();
    final fechaStr = item['fecha']?.toString() ?? '';
    final calorias = receta['calorias']?.toString() ?? 'N/A';
    final descripcion = (receta['descripcion'] ?? '').toString();

    DateTime fecha = DateTime.tryParse(fechaStr) ?? DateTime.now();

    int hora = 14;
    if (tipo == 'Desayuno') hora = 9;
    if (tipo == 'Cena') hora = 20;
    if (tipo == 'Snack') hora = 17;

    final inicio = DateTime(fecha.year, fecha.month, fecha.day, hora, 0);
    final fin = inicio.add(const Duration(hours: 1));

    final datesParam = '${_formatoUtc(inicio.toUtc())}/${_formatoUtc(fin.toUtc())}';
    final textParam = Uri.encodeComponent('🧑‍🍳 Cocinar: $titulo ($tipo)');
    final detailsParam = Uri.encodeComponent(
      'Platillo planeado desde Jitomate y Cebolla 🍅🧅\nTipo: $tipo\nCalorías: $calorias kcal\n$descripcion',
    );
    final locationParam = Uri.encodeComponent('Mi Cocina');

    return 'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$textParam&dates=$datesParam&details=$detailsParam&location=$locationParam';
  }

  /// Descarga o comparte el archivo .ics para importar en Apple Calendar, Google Calendar u Outlook
  static Future<void> exportarArchivoIcs({
    required BuildContext context,
    required List<Map<String, dynamic>> items,
    String nombreArchivo = 'menu_semanal_jitomate_y_cebolla.ics',
    String titulo = 'Menú Semanal - Jitomate y Cebolla',
  }) async {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay platillos para exportar en este período.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final contenidoIcs = generarIcs(items, nombreCalendario: titulo);
      final bytes = utf8.encode(contenidoIcs);

      final xFile = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'text/calendar',
        name: nombreArchivo,
      );

      final scaffoldMessenger = ScaffoldMessenger.of(context);

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          subject: titulo,
          text: 'Mi menú culinario planeado con Jitomate y Cebolla 🍅🧅',
          downloadFallbackEnabled: true,
        ),
      );

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡Archivo de calendario generado! 📅 Ábrelo para agregar los eventos a tu Apple Calendar o Google Calendar.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.teal.shade700,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar calendario: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Abre un platillo individual directamente en Google Calendar
  static Future<void> abrirEnGoogleCalendar(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    try {
      final url = generarUrlGoogleCalendar(item);
      final uri = Uri.parse(url);
      final lanzado = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!lanzado && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir Google Calendar automáticamente.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al conectar con Google Calendar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Despliega el modal interactivo de exportación de calendario con opciones universales
  static void mostrarModalExportacion({
    required BuildContext context,
    required List<Map<String, dynamic>> items,
    String titulo = 'Exportar a tu Calendario 📅',
    String? subtitulo,
  }) {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay platillos disponibles para exportar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final int totalPlatillos = items.length;
    final bool esUnSoloPlatillo = totalPlatillos == 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra superior de agarre
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Encabezado
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.teal.shade700,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          subtitulo ??
                              (esUnSoloPlatillo
                                  ? '1 platillo listo para agendar'
                                  : '$totalPlatillos platillos programados'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Tarjeta 1: Apple Calendar & Archivo Universal .ics
              _construirOpcionExportar(
                context: context,
                icono: Icons.apple,
                colorIcono: Colors.black87,
                colorFondo: const Color(0xFFF1F5F9),
                titulo: 'Apple Calendar, iPhone & Mac (.ics)',
                descripcion: esUnSoloPlatillo
                    ? 'Agrega este platillo a tu iPhone / iPad con 1 toque.'
                    : 'Añade los $totalPlatillos platillos a tu Calendario de Apple ("Agregar todos").',
                etiquetaBoton: esUnSoloPlatillo
                    ? 'Añadir a Apple Calendar'
                    : 'Añadir todos a Apple Calendar',
                onTap: () {
                  Navigator.pop(ctx);
                  exportarArchivoIcs(
                    context: context,
                    items: items,
                    nombreArchivo: esUnSoloPlatillo
                        ? 'platillo_jitomate_cebolla.ics'
                        : 'menu_semanal_jitomate_cebolla.ics',
                    titulo: esUnSoloPlatillo
                        ? 'Platillo - Jitomate y Cebolla'
                        : 'Menú Semanal - Jitomate y Cebolla',
                  );
                },
              ),
              const SizedBox(height: 12),

              // Tarjeta 2: Google Calendar
              _construirOpcionExportar(
                context: context,
                icono: Icons.g_mobiledata_rounded,
                colorIcono: const Color(0xFF4285F4),
                colorFondo: const Color(0xFFE8F0FE),
                titulo: 'Google Calendar (Android / Web)',
                descripcion: esUnSoloPlatillo
                    ? 'Abre directamente el formulario de Google Calendar con la hora y fecha pre-llenadas.'
                    : 'Descarga el archivo .ics compatible para importar tus $totalPlatillos comidas en Google Calendar.',
                etiquetaBoton: esUnSoloPlatillo
                    ? 'Abrir en Google Calendar'
                    : 'Exportar para Google Calendar (.ics)',
                onTap: () {
                  Navigator.pop(ctx);
                  if (esUnSoloPlatillo) {
                    abrirEnGoogleCalendar(context, items.first);
                  } else {
                    exportarArchivoIcs(
                      context: context,
                      items: items,
                      nombreArchivo: 'google_calendar_menu_semanal.ics',
                      titulo: 'Menú Semanal - Google Calendar',
                    );
                  }
                },
              ),

              // Tarjeta 3: Si no es Web y estamos en app móvil nativa, soporte de Add2Calendar
              if (!kIsWeb && esUnSoloPlatillo) ...[
                const SizedBox(height: 12),
                _construirOpcionExportar(
                  context: context,
                  icono: Icons.phone_android_rounded,
                  colorIcono: Colors.deepPurple,
                  colorFondo: Colors.deepPurple.shade50,
                  titulo: 'Calendario del Dispositivo',
                  descripcion: 'Usa el selector nativo de eventos de tu celular.',
                  etiquetaBoton: 'Abrir Calendario Nativo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportarNativoMovil(context, items.first);
                  },
                ),
              ],

              const SizedBox(height: 10),
              // Tip de ayuda
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        color: Colors.amber.shade800, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tip: Los platillos se agendan automáticamente en sus horarios ideales (Desayuno 9:00 AM, Comida 2:00 PM, Cena 8:00 PM).',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _construirOpcionExportar({
    required BuildContext context,
    required IconData icono,
    required Color colorIcono,
    required Color colorFondo,
    required String titulo,
    required String descripcion,
    required String etiquetaBoton,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorFondo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: colorIcono, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      descripcion,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: Text(etiquetaBoton),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
            ),
          ),
        ],
      ),
    );
  }

  static void _exportarNativoMovil(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    try {
      final receta = item['recetas'] is Map ? item['recetas'] as Map : {};
      final titulo = (receta['titulo'] ?? 'Receta').toString();
      final tipo = (item['tipo_comida'] ?? 'Comida').toString();
      final fechaStr = item['fecha']?.toString() ?? '';

      final fecha = DateTime.tryParse(fechaStr) ?? DateTime.now();
      int hora = 14;
      if (tipo == 'Desayuno') hora = 9;
      if (tipo == 'Cena') hora = 20;
      if (tipo == 'Snack') hora = 17;

      final inicio = DateTime(fecha.year, fecha.month, fecha.day, hora, 0);
      final fin = inicio.add(const Duration(hours: 1));

      final native_cal.Event evento = native_cal.Event(
        title: '🧑‍🍳 Cocinar: $titulo ($tipo)',
        description: 'Platillo planeado desde Jitomate y Cebolla 🍅🧅',
        location: 'Mi Cocina',
        startDate: inicio,
        endDate: fin,
        allDay: false,
      );

      native_cal.Add2Calendar.addEvent2Cal(evento);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar: $e')),
      );
    }
  }

  static String _escaparTexto(String texto) {
    return texto
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\n', r'\n');
  }

  static String _formatoIcsLocal(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}T$h$min$s';
  }

  static String _formatoUtc(DateTime dt) {
    final utc = dt.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final h = utc.hour.toString().padLeft(2, '0');
    final min = utc.minute.toString().padLeft(2, '0');
    final s = utc.second.toString().padLeft(2, '0');
    return '$y$m${d}T$h$min${s}Z';
  }
}
