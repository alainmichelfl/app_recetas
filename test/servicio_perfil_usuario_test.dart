import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_perfil_usuario.dart';

void main() {
  group('ServicioPerfilUsuario - Extracción de Nombres y Saludos', () {
    test('Extrae nombre limpio desde email con puntos o guiones', () {
      expect(ServicioPerfilUsuario.extraerNombreDeEmail('alainmichel.fl@gmail.com'), 'Alain Michel');
      expect(ServicioPerfilUsuario.extraerNombreDeEmail('carlos@hotmail.com'), 'Carlos');
      expect(ServicioPerfilUsuario.extraerNombreDeEmail('maria_elena@yahoo.com'), 'Maria Elena');
      expect(ServicioPerfilUsuario.extraerNombreDeEmail('chef123@gmail.com'), 'Chef');
      expect(ServicioPerfilUsuario.extraerNombreDeEmail(null), 'Chef');
      expect(ServicioPerfilUsuario.extraerNombreDeEmail(''), 'Chef');
    });

    test('Genera saludos acordes al horario del día', () {
      // Mañana: 05:00 a 11:59
      final manana = DateTime(2026, 10, 19, 8, 30);
      expect(
        ServicioPerfilUsuario.obtenerSaludoHorario(nombre: 'Alain', horaReferencia: manana),
        '¡Buenos días, Alain! ☀️',
      );

      // Tarde: 12:00 a 18:59
      final tarde = DateTime(2026, 10, 19, 14, 15);
      expect(
        ServicioPerfilUsuario.obtenerSaludoHorario(nombre: 'Alain', horaReferencia: tarde),
        '¡Buenas tardes, Alain! 🍲',
      );

      // Noche: 19:00 a 04:59
      final noche = DateTime(2026, 10, 19, 21, 00);
      expect(
        ServicioPerfilUsuario.obtenerSaludoHorario(nombre: 'Alain', horaReferencia: noche),
        '¡Buenas noches, Alain! 🌙',
      );

      final madrugada = DateTime(2026, 10, 19, 3, 00);
      expect(
        ServicioPerfilUsuario.obtenerSaludoHorario(nombre: 'Alain', horaReferencia: madrugada),
        '¡Buenas noches, Alain! 🌙',
      );
    });

    test('Genera subtítulos culinarios motivacionales según horario', () {
      final manana = DateTime(2026, 10, 19, 9, 0);
      expect(
        ServicioPerfilUsuario.obtenerSubtituloHorario(horaReferencia: manana),
        contains('desayunamos'),
      );

      final tarde = DateTime(2026, 10, 19, 15, 0);
      expect(
        ServicioPerfilUsuario.obtenerSubtituloHorario(horaReferencia: tarde),
        contains('cocinar'),
      );

      final noche = DateTime(2026, 10, 19, 22, 0);
      expect(
        ServicioPerfilUsuario.obtenerSubtituloHorario(horaReferencia: noche),
        contains('cenar'),
      );
    });

    test('Valida longitud mínima y máxima de nombres', () async {
      final vacio = await ServicioPerfilUsuario.verificarDisponibilidad('');
      expect(vacio.disponible, false);

      final corto = await ServicioPerfilUsuario.verificarDisponibilidad('A');
      expect(corto.disponible, false);

      final largo = await ServicioPerfilUsuario.verificarDisponibilidad('NombreDemasiadoLargoParaUnChef123456');
      expect(largo.disponible, false);
    });

    test('Genera al menos 2 sugerencias creativas para nombres base', () async {
      final sugerencias = await ServicioPerfilUsuario.generarSugerencias('Alain');
      expect(sugerencias.length, greaterThanOrEqualTo(2));
      expect(sugerencias.any((s) => s.contains('Alain')), true);
      expect(sugerencias.any((s) => s.startsWith('Chef') || s.contains('Cocina') || s.contains('_')), true);
    });
  });
}
