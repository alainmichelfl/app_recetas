import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/dialogo_contacto_soporte.dart';

void main() {
  group('DialogoContactoSoporte - Constantes y Renderizado', () {
    test('Las direcciones de correo corporativas y sitio web son canónicas', () {
      expect(DialogoContactoSoporte.emailHola, 'hola@jitomateycebolla.com');
      expect(DialogoContactoSoporte.emailContacto, 'contacto@jitomateycebolla.com');
      expect(DialogoContactoSoporte.emailAlain, 'alain@jitomateycebolla.com');
      expect(DialogoContactoSoporte.sitioWeb, 'https://www.jitomateycebolla.com');
    });

    testWidgets('Renderiza correctamente los 3 correos oficiales y la web', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DialogoContactoSoporte(),
          ),
        ),
      );

      // Esperar a que se asienten las animaciones y fuentes
      await tester.pumpAndSettle();

      // Verificar títulos de las tarjetas
      expect(find.text('Hola & Comunidad'), findsOneWidget);
      expect(find.text('Soporte Técnico & Cuenta'), findsOneWidget);
      expect(find.text('Alain Michel (Fundador)'), findsOneWidget);

      // Verificar que los correos están en pantalla
      expect(find.text('hola@jitomateycebolla.com'), findsOneWidget);
      expect(find.text('contacto@jitomateycebolla.com'), findsOneWidget);
      expect(find.text('alain@jitomateycebolla.com'), findsOneWidget);

      // Verificar el enlace a la web oficial
      expect(find.text('www.jitomateycebolla.com'), findsOneWidget);
    });
  });
}
