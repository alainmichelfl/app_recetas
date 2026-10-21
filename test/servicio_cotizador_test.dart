import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_cotizador.dart';
import 'package:app_recetas/pantalla_cotizador.dart';

void main() {
  group('ServicioCotizador - Detección de Supermercados (Crowdsourcing)', () {
    test('Deduce Walmart y Bodega Aurrera con ID 1', () {
      expect(ServicioCotizador.deducirIdSupermercado('Walmart Supercenter'), 1);
      expect(ServicioCotizador.deducirIdSupermercado('NUEVA WAL-MART DE MEXICO S. DE R.L.'), 1);
      expect(ServicioCotizador.deducirIdSupermercado('Bodega Aurrera Express'), 1);
      expect(ServicioCotizador.deducirIdSupermercado('Superama del Valle'), 1);
    });

    test('Deduce Soriana y City Club con ID 2', () {
      expect(ServicioCotizador.deducirIdSupermercado('Tiendas Soriana S.A. de C.V.'), 2);
      expect(ServicioCotizador.deducirIdSupermercado('Soriana Híper Mixcoac'), 2);
      expect(ServicioCotizador.deducirIdSupermercado('Soriana Súper'), 2);
      expect(ServicioCotizador.deducirIdSupermercado('City Club'), 2);
    });

    test('Deduce La Comer, Fresko y City Market con ID 3', () {
      expect(ServicioCotizador.deducirIdSupermercado('La Comer Insurgentes'), 3);
      expect(ServicioCotizador.deducirIdSupermercado('Fresko Tecamachalco'), 3);
      expect(ServicioCotizador.deducirIdSupermercado('City Market Pilares'), 3);
      expect(ServicioCotizador.deducirIdSupermercado('Comercial Mexicana'), 3);
    });

    test('Deduce Central de Abasto y Mercados con ID 4', () {
      expect(ServicioCotizador.deducirIdSupermercado('Central de Abasto Iztapalapa'), 4);
      expect(ServicioCotizador.deducirIdSupermercado('Click Abasto'), 4);
      expect(ServicioCotizador.deducirIdSupermercado('Mercado Jamaica'), 4);
      expect(ServicioCotizador.deducirIdSupermercado('Tianguis'), 4);
    });

    test('Tienda desconocida regresa por defecto Walmart (1)', () {
      expect(ServicioCotizador.deducirIdSupermercado('Minisuper Don Juan'), 1);
      expect(ServicioCotizador.deducirIdSupermercado(''), 1);
    });
  });

  group('ServicioCotizador - Cálculo Ponderado de Precios (40/60)', () {
    test('Calcula ponderación estándar 40% histórico y 60% nuevo', () {
      // (100.0 * 0.40) + (110.0 * 0.60) = 40.0 + 66.0 = 106.0
      expect(ServicioCotizador.calcularPrecioPonderado(100.0, 110.0), 106.0);

      // (50.0 * 0.40) + (40.0 * 0.60) = 20.0 + 24.0 = 44.0
      expect(ServicioCotizador.calcularPrecioPonderado(50.0, 40.0), 44.0);
    });

    test('Redondea a 2 decimales correctamente', () {
      // (10.0 * 0.4) + (10.33 * 0.6) = 4.0 + 6.198 = 10.198 -> 10.20
      expect(ServicioCotizador.calcularPrecioPonderado(10.0, 10.33), 10.20);
    });

    test('Maneja valores cero o negativos defensivamente', () {
      expect(ServicioCotizador.calcularPrecioPonderado(0.0, 45.50), 45.50);
      expect(ServicioCotizador.calcularPrecioPonderado(-10.0, 45.50), 45.50);
      expect(ServicioCotizador.calcularPrecioPonderado(30.0, 0.0), 30.0);
    });
  });

  group('ServicioCotizador - Extracción Segura de Números', () {
    test('Extrae valores numéricos o limpia cadenas de texto', () {
      expect(ServicioCotizador.extraerNumeroSeguro(null), 1.0);
      expect(ServicioCotizador.extraerNumeroSeguro(25), 25.0);
      expect(ServicioCotizador.extraerNumeroSeguro(32.75), 32.75);
      expect(ServicioCotizador.extraerNumeroSeguro('1.5 kg'), 1.5);
      expect(ServicioCotizador.extraerNumeroSeguro('\$89.90'), 89.90);
      expect(ServicioCotizador.extraerNumeroSeguro('sin numeros', valorPorDefecto: 2.0), 2.0);
    });
  });

  group('PantallaCotizador - Enlaces a Portales Oficiales de Compra en Línea (Base P7)', () {
    test('Contiene URLs oficiales válidas para compras de despensa en línea', () {
      final urls = PantallaCotizador.urlsSupermercados;

      expect(urls.containsKey('Walmart'), isTrue);
      expect(urls['Walmart'], contains('super.walmart.com.mx'));

      expect(urls.containsKey('Soriana'), isTrue);
      expect(urls['Soriana'], contains('soriana.com'));

      expect(urls.containsKey('La Comer'), isTrue);
      expect(urls['La Comer'], contains('lacomer.com.mx'));

      expect(urls.containsKey('Chedraui'), isTrue);
      expect(urls['Chedraui'], contains('chedraui.com.mx'));

      expect(urls.containsKey('Costco'), isTrue);
      expect(urls['Costco'], contains('costco.com.mx'));
    });

    test('Contiene paquetes de Android válidos para Deep Linking a apps nativas (Opción A)', () {
      final paquetes = PantallaCotizador.paquetesAndroidSupermercados;

      expect(paquetes['Walmart'], equals('com.walmart.mg'));
      expect(paquetes['Soriana'], equals('com.soriana.appsoriana'));
      expect(paquetes['La Comer'], equals('com.LaComerApp'));
      expect(paquetes['Chedraui'], equals('com.planetmedia.paymentsloyalty.chedraui'));
      expect(paquetes['Costco'], equals('com.costco.mx'));
      expect(paquetes['Sam\'s Club'], equals('air.SamsClubMexico'));
      expect(paquetes['Bodega Aurrera'], equals('com.mx.walmart.bodega'));
    });

    test('Genera URIs de Intent de Android con fallback automático a la web', () {
      final uriWalmart = PantallaCotizador.obtenerIntentUriAndroid('Walmart');
      expect(uriWalmart, isNotNull);
      expect(uriWalmart, startsWith('intent://super.walmart.com.mx/#Intent;'));
      expect(uriWalmart, contains('package=com.walmart.mg'));
      expect(uriWalmart, contains('S.browser_fallback_url=https%3A%2F%2Fsuper.walmart.com.mx%2F'));

      final uriSoriana = PantallaCotizador.obtenerIntentUriAndroid('Soriana');
      expect(uriSoriana, isNotNull);
      expect(uriSoriana, contains('package=com.soriana.appsoriana'));
      expect(uriSoriana, contains('soriana.com'));

      // Supermercado no registrado o sin app retorna null
      expect(PantallaCotizador.obtenerIntentUriAndroid('Desconocido'), isNull);
    });
  });
}
