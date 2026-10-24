import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_recetas/pantalla_chef.dart';
import 'package:app_recetas/tipos_cocina.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'preferencias_alergias': 'nueces',
      'preferencias_estilos': ['Libre'],
      'preferencias_utensilios': ['Sartén', 'Licuadora'],
    });
  });

  group('PantallaChef - Modos y Perfiles de Chef IA', () {
    testWidgets('Inicia correctamente en Modo Chef Lonchera Kids 🎒', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PantallaChef(modoEscolarInicial: true),
        ),
      );
      await tester.pumpAndSettle();

      // Título en AppBar
      expect(find.text('Chef Lonchera Kids 🎒'), findsOneWidget);

      // Selector superior de perfiles
      expect(find.text('Kids 🎒'), findsOneWidget);
      expect(find.text('Bistro 👨‍🍳'), findsOneWidget);
      expect(find.text('Lomitos 🐾'), findsOneWidget);

      // Reglas y opciones de la lonchera escolar
      expect(find.text('Reglas de Oro de la Lonchera 🎒'), findsOneWidget);
      expect(find.text('Tipo de Comida Escolar'), findsOneWidget);
      expect(find.text('Lunch Escolar'), findsOneWidget);
      expect(find.text('Snack Escolar'), findsOneWidget);
      expect(find.text('Etapa / Edad Escolar'), findsOneWidget);
      expect(find.text('Kínder (3-5 años)'), findsOneWidget);
      expect(find.text('Primaria (6-12 años)'), findsOneWidget);
      expect(find.text('Secundaria (13+ años)'), findsOneWidget);

      // Botón de acción principal
      expect(find.text('Cocinar Lonchera Escolar con IA 🎒✨'), findsOneWidget);
    });

    testWidgets('Permite alternar fluidamente entre Kids, Bistro y Lomitos', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: PantallaChef(modoEscolarInicial: false),
        ),
      );
      await tester.pumpAndSettle();

      // Por defecto inicia en Bistro (Adultos)
      expect(find.text('Chef IA 👨‍🍳'), findsOneWidget);
      expect(find.textContaining('Cocinar Receta'), findsWidgets);

      // Cambiar a Kids 🎒
      await tester.tap(find.text('Kids 🎒'));
      await tester.pumpAndSettle();

      expect(find.text('Chef Lonchera Kids 🎒'), findsOneWidget);
      expect(find.text('Cocinar Lonchera Escolar con IA 🎒✨'), findsOneWidget);

      // Cambiar a Lomitos 🐾
      await tester.tap(find.text('Lomitos 🐾'));
      await tester.pumpAndSettle();

      expect(find.text('Chef Perruno 🐾'), findsOneWidget);
      expect(find.text('Cocinar Snack Perruno 🐾'), findsOneWidget);

      // Regresar a Bistro 👨‍🍳
      await tester.tap(find.text('Bistro 👨‍🍳'));
      await tester.pumpAndSettle();

      expect(find.text('Chef IA 👨‍🍳'), findsOneWidget);
      expect(find.text('¿Poco tiempo o cansancio hoy? ⏱️'), findsOneWidget);
      expect(find.textContaining('Cocinar Receta'), findsWidgets);
    });
  });

  group('PantallaChef.generarPrompt - Reglas Estrictas de Generación', () {
    test('Modo Escolar incluye directrices pediátricas, lonchera y excluye maridaje de vino', () {
      final prompt = PantallaChef.generarPrompt(
        ingredientesBase: 'jamón de pavo, queso panela, zanahoria',
        tipoComida: 'Lunch Escolar',
        objetivoSalud: 'Nutrición Infantil',
        tipoCocina: TiposCocina.mexicana,
        esEscolar: true,
        etapaEscolar: 'Primaria (6-12 años)',
        alergias: 'cacahuates',
      );

      // Rol pediátrico
      expect(prompt, contains('Chef Nutriólogo Pediátrico'));
      expect(prompt, contains('Loncheras Escolares Saludables'));
      expect(prompt, contains('Primaria (6-12 años)'));

      // Reglas de transporte y tupper
      expect(prompt, contains('LOGÍSTICA DE TUPPER Y TRANSPORTE'));
      expect(prompt, contains('CERO derrames o salsas muy líquidas'));
      expect(prompt, contains('SEGURIDAD PEDIÁTRICA'));

      // Hidratación en lugar de maridaje de vino
      expect(prompt, contains('"bebida_escolar"'));
      expect(prompt, contains('"tip_lonchera"'));
      expect(prompt, isNot(contains('"maridaje"')));
      expect(prompt, isNot(contains('"destilado"')));

      // Restricción de alergias
      expect(prompt, contains('ALERGIAS Y RESTRICCIONES INFANTILES'));
      expect(prompt, contains('cacahuates'));
    });

    test('Modo Perruno incluye seguridad veterinaria estricta', () {
      final prompt = PantallaChef.generarPrompt(
        ingredientesBase: 'pechuga de pollo, zanahoria',
        tipoComida: 'Snack Canino',
        objetivoSalud: 'Salud Canina',
        tipoCocina: TiposCocina.todas,
        esPerruno: true,
      );

      expect(prompt, contains('Veterinario Nutricionista'));
      expect(prompt, contains('SEGURIDAD CANINA'));
      expect(prompt, contains('cebolla, ajo, chocolate, uvas, aguacate'));
      expect(prompt, isNot(contains('"maridaje"')));
    });

    test('Modo Bistro incluye maridaje de vino y cócteles para adultos', () {
      final prompt = PantallaChef.generarPrompt(
        ingredientesBase: 'salmón, espárragos',
        tipoComida: 'Cena',
        objetivoSalud: 'Mantenimiento 2,000 kcal',
        tipoCocina: TiposCocina.mediterranea,
      );

      expect(prompt, contains('app "Jitomate y Cebolla"'));
      expect(prompt, contains('"maridaje"'));
      expect(prompt, contains('"vino"'));
      expect(prompt, contains('"destilado"'));
      expect(prompt, isNot(contains('bebida_escolar')));
    });
  });
}
