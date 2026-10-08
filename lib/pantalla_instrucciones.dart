import 'package:flutter/material.dart';

class PantallaInstrucciones extends StatefulWidget {
  const PantallaInstrucciones({super.key});

  @override
  State<PantallaInstrucciones> createState() => _PantallaInstruccionesState();
}

class _PantallaInstruccionesState extends State<PantallaInstrucciones> {
  final PageController _controladorPagina = PageController();
  int _paginaActual = 0;

  final List<Map<String, dynamic>> _pasosTutorial = [
    {
      'titulo': '🌮 Tu Recetario Inteligente',
      'descripcion': 'Guarda tus recetas favoritas con foto, ingredientes y pasos. ¡Toca cualquier receta para leerla y presiona "A Cocinar" para entrar al modo paso a paso sin que se apague tu pantalla!',
      'icono': Icons.menu_book,
      'color': const Color(0xFFD32F2F), // rojoJitomate
    },
    {
      'titulo': '🥫 Mi Despensa y Tickets',
      'descripcion': 'Lleva el control de lo que tienes en casa. Toca el icono de la cámara para ESCANEAR TU TICKET del súper. La IA detectará los alimentos, su cantidad y su precio automáticamente.',
      'icono': Icons.document_scanner,
      'color': const Color(0xFF2E7D32), // verdeCilantro
    },
    {
      'titulo': '💰 Cotizador Dinámico',
      'descripcion': 'Desde cualquier receta, presiona "Cotizar en el Super". La app calculará dónde te sale más barato comprar los ingredientes. Si ya escaneaste tus tickets en la Despensa, ¡podrás descontar lo que ya tienes en casa para saber tu gasto real!',
      'icono': Icons.calculate,
      'color': Colors.deepPurple,
    },
    {
      'titulo': '🧑‍🍳 Chef IA',
      'descripcion': '¿No sabes qué cocinar? Ve al Chef IA, dile si quieres Desayuno, Comida o Cena, elige tu tipo de dieta y él inventará una receta usando SOLO los ingredientes que tienes en tu Despensa.',
      'icono': Icons.auto_awesome,
      'color': const Color(0xFFF57C00), // naranjaZanahoria
    },
    {
      'titulo': '📅 Planeador y 🛒 Carrito',
      'descripcion': 'Organiza tu semana agregando recetas al Planeador, o deja que el botón mágico "Autocompletar" lo haga por ti. Luego, envía los ingredientes que te faltan directo a tu Carrito de Compras.',
      'icono': Icons.calendar_month,
      'color': Colors.blue.shade700,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          '¿Cómo funciona?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controladorPagina,
              onPageChanged: (index) {
                setState(() {
                  _paginaActual = index;
                });
              },
              itemCount: _pasosTutorial.length,
              itemBuilder: (context, index) {
                final paso = _pasosTutorial[index];
                return Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: paso['color'].withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          paso['icono'],
                          size: 100,
                          color: paso['color'],
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        paso['titulo'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: paso['color'],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        paso['descripcion'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Indicadores de página (Puntitos)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pasosTutorial.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  height: 12,
                  width: _paginaActual == index ? 30 : 12,
                  decoration: BoxDecoration(
                    color: _paginaActual == index
                        ? _pasosTutorial[_paginaActual]['color']
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),

          // Botón de navegación
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  if (_paginaActual == _pasosTutorial.length - 1) {
                    Navigator.pop(
                      context,
                    ); // Cierra el tutorial si es la última página
                  } else {
                    _controladorPagina.nextPage(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pasosTutorial[_paginaActual]['color'],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  _paginaActual == _pasosTutorial.length - 1
                      ? '¡Entendido, a cocinar!'
                      : 'Siguiente',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
