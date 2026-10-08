import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'menu_lateral.dart';

class PantallaFinanzas extends StatefulWidget {
  final double? presupuestoSuperExterno;
  final String? supermercadoElegido;

  const PantallaFinanzas({
    super.key,
    this.presupuestoSuperExterno,
    this.supermercadoElegido,
  });

  @override
  State<PantallaFinanzas> createState() => _PantallaFinanzasState();
}

class _PantallaFinanzasState extends State<PantallaFinanzas> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool _cargando = true;
  double _capitalTotal = 0.0;
  int _totalItems = 0;
  String _articuloMayorValor = 'No hay datos';
  List<Map<String, dynamic>> _ultimosIngresos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosFinanzas();
  }

  // FUNCIÓN SEGURA PARA CONVERTIR CUALQUIER VALOR A DOUBLE
  double _parsearNumero(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is num) return valor.toDouble();
    if (valor is String) {
      final match = RegExp(r'[0-9]+(\.[0-9]+)?').firstMatch(valor);
      if (match != null) {
        return double.tryParse(match.group(0)!) ?? 0.0;
      }
    }
    return 0.0;
  }

  Future<void> _cargarDatosFinanzas() async {
    try {
      final data = await supabase
          .from('despensa_usuario')
          .select('nombre, cantidad, precio, fecha_ingreso')
          .order('fecha_ingreso', ascending: false);

      final List items = data as List;

      double capital = 0.0;
      int itemsCount = 0;
      double maxValor = -1.0;
      String mayorNombre = 'No hay datos';

      for (var item in items) {
        final double cant = _parsearNumero(item['cantidad']);
        final double precio = _parsearNumero(item['precio']);

        final double valorItem = (precio > 0)
            ? (precio * (cant > 0 ? cant : 1.0))
            : ((cant > 0 ? cant : 1.0) * 25.0);

        capital += valorItem;
        itemsCount += (cant > 0 ? cant.toInt() : 1);

        if (valorItem > maxValor) {
          maxValor = valorItem;
          final String nombreArt = item['nombre'] ?? 'Artículo';
          mayorNombre = '$nombreArt (\$${valorItem.toStringAsFixed(2)})';
        }
      }

      if (mounted) {
        setState(() {
          _capitalTotal = capital;
          _totalItems = itemsCount;
          _articuloMayorValor = mayorNombre;
          _ultimosIngresos = items.cast<Map<String, dynamic>>();
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar finanzas: $e');
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color colorPremium = Colors.red.shade800;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const MenuLateral(rutaActual: 'finanzas'),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú principal',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Mis Finanzas 📈',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorPremium,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _cargando
          ? Center(child: CircularProgressIndicator(color: colorPremium))
          : RefreshIndicator(
              color: colorPremium,
              onRefresh: _cargarDatosFinanzas,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen de tu Despensa',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1. TARJETA: Capital en Despensa
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.account_balance_wallet,
                              color: Colors.green.shade700,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Capital en Despensa',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${_capitalTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 2. TARJETA: Artículos Almacenados
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.inventory_2,
                              color: Colors.orange.shade800,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Artículos Almacenados',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_totalItems items',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // 3. TARJETA: Artículo de Mayor Valor
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.star,
                              color: Colors.purple.shade700,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Artículo de Mayor Valor',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _articuloMayorValor,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cotización externa si viene del carrito
                    if (widget.presupuestoSuperExterno != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorPremium.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shopping_cart_checkout,
                              color: colorPremium,
                              size: 30,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Cotización en ${widget.supermercadoElegido ?? "Súper"}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: colorPremium,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Total estimado: \$${widget.presupuestoSuperExterno!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const Text(
                      'Últimos Ingresos Valorados',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _ultimosIngresos.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 30),
                              child: Text(
                                'Escanea un ticket en "Mi Despensa" para ver el desglose financiero aquí.',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _ultimosIngresos.length > 5
                                ? 5
                                : _ultimosIngresos.length,
                            itemBuilder: (context, index) {
                              final ing = _ultimosIngresos[index];
                              final double cantItem = _parsearNumero(
                                ing['cantidad'],
                              );
                              final double precioItem = _parsearNumero(
                                ing['precio'],
                              );
                              final double subtotal = (precioItem > 0)
                                  ? (precioItem * cantItem)
                                  : (cantItem * 25.0);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                color: Colors.white,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.red.shade50,
                                    child: Icon(
                                      Icons.fastfood,
                                      color: colorPremium,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    ing['nombre'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Cantidad: $cantItem • ${ing['fecha_ingreso'] ?? ""}',
                                  ),
                                  trailing: Text(
                                    '\$${subtotal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: colorPremium,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
