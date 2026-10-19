import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_recetas/servicio_zonas_despensa.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ServicioZonasDespensa - Heurísticas de Detección Automática por Zona', () {
    test('Identifica insumos del Congelador correctamente', () {
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Camarones congelados'),
        ZonaDespensa.congelador,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Bolsa de hielo'),
        ZonaDespensa.congelador,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Helado de vainilla'),
        ZonaDespensa.congelador,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Pulpa congelada de mango'),
        ZonaDespensa.congelador,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Edamames'),
        ZonaDespensa.congelador,
      );
    });

    test('Identifica insumos del Refrigerador (frescos, lácteos, carnes) correctamente', () {
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Leche entera'),
        ZonaDespensa.refrigerador,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Queso panela'),
        ZonaDespensa.refrigerador,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Jitomate bola'),
        ZonaDespensa.refrigerador,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Pechuga de pollo'),
        ZonaDespensa.refrigerador,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Huevos'),
        ZonaDespensa.refrigerador,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Aguacate Hass'),
        ZonaDespensa.refrigerador,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Tupper de arroz y pollo preparado'),
        ZonaDespensa.refrigerador,
      );
    });

    test('Identifica insumos de Alacena Seca (granos, pastas, aceites, especias) correctamente', () {
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Arroz blanco'),
        ZonaDespensa.alacena,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Frijol negro'),
        ZonaDespensa.alacena,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Pasta espagueti'),
        ZonaDespensa.alacena,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Aceite de oliva extra virgen'),
        ZonaDespensa.alacena,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Atún en lata en agua'),
        ZonaDespensa.alacena,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Sal de mar y orégano'),
        ZonaDespensa.alacena,
      );
    });

    test('Identifica botellas de Cava & Bar correctamente', () {
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Vino Tinto Cabernet'),
        ZonaDespensa.cava,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Tequila Reposado'),
        ZonaDespensa.cava,
      );
      expect(
        ServicioZonasDespensa.detectarZonaPorDefecto('Cerveza Clara'),
        ZonaDespensa.cava,
      );
    });
  });

  group('ServicioZonasDespensa - Personalización y Overrides de Usuario', () {
    test('Permite cambiar un insumo a Congelador y lo respeta prioritariamente', () async {
      final item = {'id_item': 101, 'nombre': 'Pechuga de pollo'};
      
      // Por defecto pollo va a refrigerador
      expect(
        ServicioZonasDespensa.resolverZona(item, {}),
        ZonaDespensa.refrigerador,
      );

      // Usuario lo mueve a Congelador
      await ServicioZonasDespensa.asignarZona(
        item: item,
        nuevaZona: ZonaDespensa.congelador,
      );

      final overrides = await ServicioZonasDespensa.obtenerOverrides();
      expect(
        ServicioZonasDespensa.resolverZona(item, overrides),
        ZonaDespensa.congelador,
      );
    });

    test('Conteo por zonas agrupa correctamente los insumos', () {
      final items = [
        {'id_item': 1, 'nombre': 'Leche'},
        {'id_item': 2, 'nombre': 'Queso'},
        {'id_item': 3, 'nombre': 'Camarones congelados'},
        {'id_item': 4, 'nombre': 'Arroz'},
        {'id_item': 5, 'nombre': 'Frijol'},
        {'id_item': 6, 'nombre': 'Vino Tinto'},
      ];

      final conteos = ServicioZonasDespensa.contarPorZonas(items, {});
      expect(conteos[ZonaDespensa.refrigerador], 2);
      expect(conteos[ZonaDespensa.congelador], 1);
      expect(conteos[ZonaDespensa.alacena], 2);
      expect(conteos[ZonaDespensa.cava], 1);
    });
  });
}
