import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_exportar_calendario.dart';

void main() {
  group('ServicioExportarCalendario - Generación RFC 5545 y Google Calendar', () {
    final mockPlan = [
      {
        'id_planeador': 101,
        'fecha': '2026-10-20',
        'tipo_comida': 'Desayuno',
        'recetas': {
          'id_receta': 1,
          'titulo': 'Omelette de Champiñones',
          'descripcion': 'Desayuno alto en proteína y fibra',
          'calorias': 320,
        },
      },
      {
        'id_planeador': 102,
        'fecha': '2026-10-20',
        'tipo_comida': 'Comida',
        'recetas': {
          'id_receta': 2,
          'titulo': 'Pollo a la Plancha con Verduras',
          'descripcion': 'Platillo balanceado',
          'calorias': 480,
        },
      },
      {
        'id_planeador': 103,
        'fecha': '2026-10-20',
        'tipo_comida': 'Cena',
        'recetas': {
          'id_receta': 3,
          'titulo': 'Ensalada César Ligera',
          'descripcion': 'Cena ligera sin carbohidratos',
          'calorias': 250,
        },
      },
      {
        'id_planeador': 104,
        'fecha': '2026-10-20',
        'tipo_comida': 'Snack',
        'recetas': {
          'id_receta': 4,
          'titulo': 'Smoothie de Frutos Rojos',
          'descripcion': 'Snack refrescante',
          'calorias': 150,
        },
      },
    ];

    test('generarIcs genera un archivo iCalendar válido con cabeceras RFC 5545', () {
      final ics = ServicioExportarCalendario.generarIcs(mockPlan);

      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('VERSION:2.0'));
      expect(ics, contains('PRODID:-//Jitomate y Cebolla//Menu Semanal//ES'));
      expect(ics, contains('CALSCALE:GREGORIAN'));
      expect(ics, contains('END:VCALENDAR'));
    });

    test('generarIcs incluye todos los eventos con sus horarios y descripciones', () {
      final ics = ServicioExportarCalendario.generarIcs(mockPlan);

      // Evento 1: Desayuno a las 9:00 AM (20261020T090000)
      expect(ics, contains('SUMMARY:🧑‍🍳 Cocinar: Omelette de Champiñones (Desayuno)'));
      expect(ics, contains('DTSTART:20261020T090000'));
      expect(ics, contains('DTEND:20261020T100000'));
      expect(ics, contains('Calorías: 320 kcal'));

      // Evento 2: Comida a las 2:00 PM (20261020T140000)
      expect(ics, contains('SUMMARY:🧑‍🍳 Cocinar: Pollo a la Plancha con Verduras (Comida)'));
      expect(ics, contains('DTSTART:20261020T140000'));
      expect(ics, contains('DTEND:20261020T150000'));

      // Evento 3: Cena a las 8:00 PM (20261020T200000)
      expect(ics, contains('SUMMARY:🧑‍🍳 Cocinar: Ensalada César Ligera (Cena)'));
      expect(ics, contains('DTSTART:20261020T200000'));
      expect(ics, contains('DTEND:20261020T210000'));

      // Evento 4: Snack a las 5:00 PM (20261020T170000)
      expect(ics, contains('SUMMARY:🧑‍🍳 Cocinar: Smoothie de Frutos Rojos (Snack)'));
      expect(ics, contains('DTSTART:20261020T170000'));
      expect(ics, contains('DTEND:20261020T180000'));
    });

    test('generarUrlGoogleCalendar crea un enlace web válido para Google Calendar', () {
      final url = ServicioExportarCalendario.generarUrlGoogleCalendar(mockPlan.first);

      expect(url, startsWith('https://calendar.google.com/calendar/render?action=TEMPLATE'));
      expect(url, contains('text='));
      expect(url, contains('dates='));
      expect(url, contains('details='));
      expect(url, contains('location=Mi%20Cocina'));
      expect(url, contains('Omelette'));
    });

    test('generarIcs maneja planes vacíos sin romper', () {
      final ics = ServicioExportarCalendario.generarIcs([]);

      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('END:VCALENDAR'));
      expect(ics, isNot(contains('BEGIN:VEVENT')));
    });
  });
}
