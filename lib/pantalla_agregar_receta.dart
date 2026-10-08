import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'conversor_unidades.dart';

class PantallaAgregarReceta extends StatefulWidget {
  const PantallaAgregarReceta({super.key});

  @override
  State<PantallaAgregarReceta> createState() => _PantallaAgregarRecetaState();
}

class _PantallaAgregarRecetaState extends State<PantallaAgregarReceta> {
  final _tituloController = TextEditingController();
  final _instruccionesController = TextEditingController();
  final _imagenUrlController = TextEditingController();
  bool _guardando = false;

  final Color verdeCilantro = const Color(0xFF2E7D32);

  Future<void> _guardarReceta() async {
    final titulo = _tituloController.text.trim();
    final instrucciones = _instruccionesController.text.trim();
    final imagenUrl = _imagenUrlController.text.trim();

    if (titulo.isEmpty || instrucciones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa el título y las instrucciones.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final res = await Supabase.instance.client.from('recetas').insert({
        'titulo': titulo,
        'descripcion': instrucciones,
        'instrucciones': instrucciones,
        'imagen_url': imagenUrl.isEmpty ? null : imagenUrl,
      }).select('id_receta').single();

      final int idNueva = res['id_receta'];
      await ConversorUnidades.sincronizarIngredientesDeTexto(
        Supabase.instance.client,
        idNueva,
        instrucciones,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Receta guardada con éxito! 🌮'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(
          context,
          true,
        ); // Regresamos a la pantalla anterior y avisamos que sí guardamos
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Nueva Receta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: verdeCilantro,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Qué vamos a cocinar hoy?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),

            // Campo Título
            TextField(
              controller: _tituloController,
              decoration: InputDecoration(
                labelText: 'Título del Platillo',
                hintText: 'Ej. Enchiladas Verdes',
                prefixIcon: const Icon(Icons.restaurant_menu),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Campo Imagen URL
            TextField(
              controller: _imagenUrlController,
              decoration: InputDecoration(
                labelText: 'Link de la imagen (Opcional)',
                hintText: 'https://ejemplo.com/foto.jpg',
                prefixIcon: const Icon(Icons.image_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Campo Instrucciones/Ingredientes
            TextField(
              controller: _instruccionesController,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: 'Ingredientes e Instrucciones',
                alignLabelWithHint: true,
                hintText: '1. Pollo\n2. Tomate verde\n\nHervir el pollo...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Botón Guardar
            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardarReceta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: verdeCilantro,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _guardando ? 'Guardando...' : 'Guardar Receta',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
