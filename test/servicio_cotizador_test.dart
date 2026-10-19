import 'package:flutter_test/flutter_test.dart';
import 'package:app_recetas/servicio_cotizador.dart';

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
}
