import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/pantalla_restablecer_password.dart';

void main() {
  group('PantallaRestablecerPassword - UI y Validaciones', () {
    testWidgets('Renderiza los campos y botones para restablecer contraseña', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool restablecidaLlamada = false;

      await tester.pumpWidget(
        MaterialApp(
          home: PantallaRestablecerPassword(
            onPasswordRestablecida: () {
              restablecidaLlamada = true;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar títulos e instrucciones
      expect(find.text('Establecer Nueva Contraseña'), findsOneWidget);
      expect(find.textContaining('Jitomate y Cebolla'), findsOneWidget);

      // Verificar campos de texto
      expect(find.text('Nueva Contraseña'), findsOneWidget);
      expect(find.text('Confirmar Nueva Contraseña'), findsOneWidget);

      // Verificar botones
      expect(find.text('Guardar y Acceder'), findsOneWidget);
      expect(find.text('Cancelar y volver al inicio'), findsOneWidget);

      // Probar validación con campos vacíos
      await tester.tap(find.text('Guardar y Acceder'));
      await tester.pumpAndSettle();

      expect(find.text('Por favor ingresa la nueva contraseña'), findsOneWidget);
      expect(restablecidaLlamada, isFalse);

      // Probar botón cancelar
      await tester.tap(find.text('Cancelar y volver al inicio'));
      await tester.pumpAndSettle();

      expect(restablecidaLlamada, isTrue);
    });

    testWidgets('Valida que las contraseñas coincidan y tengan mínimo 6 caracteres', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: PantallaRestablecerPassword(
            onPasswordRestablecida: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ingresar contraseña muy corta (< 6 caracteres)
      final campos = find.byType(TextFormField);
      await tester.enterText(campos.first, '123');
      await tester.enterText(campos.last, '123');
      await tester.tap(find.text('Guardar y Acceder'));
      await tester.pumpAndSettle();

      expect(find.text('La contraseña debe tener al menos 6 caracteres'), findsOneWidget);

      // Ingresar contraseñas que no coinciden
      await tester.enterText(campos.first, 'contrasena123');
      await tester.enterText(campos.last, 'otraDiferente123');
      await tester.tap(find.text('Guardar y Acceder'));
      await tester.pumpAndSettle();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });
  });
}
