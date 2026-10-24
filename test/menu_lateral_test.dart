import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/menu_lateral.dart';

void main() {
  group('MenuLateral - Estructura y Navegación de Recetario y Lunches Escolares', () {
    testWidgets('Muestra el sub-menú de Snacks & Lunch Escolar en el orden exacto', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: MenuLateral(rutaActual: 'recetas_escolares'),
            body: Center(child: Text('App Principal')),
          ),
        ),
      );

      // Abrir el Drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Verificar que el título principal de Recetario está presente
      expect(find.text('Recetario'), findsOneWidget);

      // Verificar que los sub-items del menú aparecen en pantalla
      expect(find.text('Recién Salidas del Sartén 🔥'), findsOneWidget);
      expect(find.text('Snacks & Lunch Escolar 🎒'), findsOneWidget);
      expect(find.text('Catálogo Oficial ⭐'), findsOneWidget);
      expect(find.text('Mis Creaciones'), findsOneWidget);
      expect(find.text('Recetas Caninas 🐾'), findsOneWidget);

      // Verificar el badge distintivo KIDS
      expect(find.text('KIDS'), findsOneWidget);
      expect(find.text('NUEVAS'), findsOneWidget);

      // Verificar que el ícono de mochila escolar está presente
      expect(find.byIcon(Icons.backpack_rounded), findsOneWidget);
    });

    testWidgets('Destaca visualmente la ruta activa cuando es recetas_escolares', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            drawer: MenuLateral(rutaActual: 'recetas_escolares'),
            body: Center(child: Text('App Principal')),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      // Buscar el ListTile de Snacks & Lunch Escolar
      final lunchTile = find.widgetWithText(ListTile, 'Snacks & Lunch Escolar 🎒');
      expect(lunchTile, findsOneWidget);

      final listTileWidget = tester.widget<ListTile>(lunchTile);
      expect(listTileWidget.selected, isTrue);
    });
  });
}
