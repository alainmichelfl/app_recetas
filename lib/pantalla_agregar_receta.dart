import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'conversor_unidades.dart';
import 'servicio_admin.dart';
import 'servicio_recetas.dart';
import 'servicio_ia.dart';

class PantallaAgregarReceta extends StatefulWidget {
  final String? tipoComidaInicial;

  const PantallaAgregarReceta({super.key, this.tipoComidaInicial});

  @override
  State<PantallaAgregarReceta> createState() => _PantallaAgregarRecetaState();
}

class _PantallaAgregarRecetaState extends State<PantallaAgregarReceta> {
  final _tituloController = TextEditingController();
  final _instruccionesController = TextEditingController();
  final _imagenUrlController = TextEditingController();
  final _caloriasController = TextEditingController();
  final _macrosController = TextEditingController();
  String _tipoComida = 'Comida';
  bool _esOficial = false;
  bool _compartirComunidad = false;
  bool _guardando = false;
  bool _calculandoNutricion = false;

  final Color verdeCilantro = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    final bool esAdmin = ServicioAdmin.esAdmin();
    _esOficial = esAdmin;
    if (widget.tipoComidaInicial != null) {
      _tipoComida = widget.tipoComidaInicial!;
      if (_tipoComida == 'Snack Canino') {
        _compartirComunidad = true;
      }
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _instruccionesController.dispose();
    _imagenUrlController.dispose();
    _caloriasController.dispose();
    _macrosController.dispose();
    super.dispose();
  }

  Future<void> _calcularNutricionConIA() async {
    final titulo = _tituloController.text.trim();
    final texto = _instruccionesController.text.trim();

    if (texto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor escribe primero los ingredientes o instrucciones para calcular.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _calculandoNutricion = true);

    try {
      final res = await ServicioIA.estimarCaloriasYMacros(
        titulo: titulo.isEmpty ? 'Platillo Casero' : titulo,
        textoReceta: texto,
      );

      if (res != null) {
        setState(() {
          if (res['calorias'] != null) {
            _caloriasController.text = res['calorias'].toString();
          }
          if (res['macros'] != null) {
            _macrosController.text = res['macros'].toString();
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Calorías y macros calculados con éxito con IA! 🥗✨'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo estimar la información nutricional. Intenta de nuevo.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al calcular nutrición: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _calculandoNutricion = false);
    }
  }

  Future<void> _guardarReceta() async {
    final titulo = _tituloController.text.trim();
    final instrucciones = _instruccionesController.text.trim();
    final imagenUrl = _imagenUrlController.text.trim();
    final int? calorias = int.tryParse(_caloriasController.text.trim());
    final String macros = _macrosController.text.trim();

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
      final sb = StringBuffer();
      if (calorias != null) sb.writeln('CALORÍAS: $calorias kcal');
      if (macros.isNotEmpty) sb.writeln('MACROS: $macros');
      sb.writeln(instrucciones);
      final String descCompleta = sb.toString().trim();

      final res = await ServicioRecetas.insertarReceta(
        titulo: titulo,
        descripcion: descCompleta,
        instrucciones: instrucciones,
        tipoComida: _tipoComida,
        calorias: calorias,
        macros: macros.isNotEmpty ? macros : null,
        imagenUrl: imagenUrl.isEmpty ? null : imagenUrl,
        esOficial: _esOficial,
        esPublica: _esOficial ? true : _compartirComunidad,
      );

      final int idNueva = res['id_receta'];
      await ConversorUnidades.sincronizarIngredientesDeTexto(
        Supabase.instance.client,
        idNueva,
        instrucciones,
      );

      if (mounted) {
        final bool esCanina = _tipoComida == 'Snack Canino';
        final String mensaje = esCanina
            ? '¡Receta canina guardada en el Recetario Canino 🐾 y compartida con la comunidad!'
            : _esOficial
                ? '¡Receta guardada en el Catálogo Oficial! 🌟'
                : _compartirComunidad
                    ? '¡Receta guardada y compartida con la comunidad! 🌎'
                    : '¡Receta guardada en tus recetas privadas! 👨‍🍳🔒';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: esCanina ? Colors.brown.shade700 : Colors.green,
          ),
        );
        Navigator.pop(context, true);
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
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esAdmin = ServicioAdmin.esAdmin();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Nueva Receta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E2022),
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
                hintText: 'Ej. Enchiladas Verdes Suizas',
                prefixIcon: const Icon(Icons.restaurant_menu),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Selector de Categoría
            DropdownButtonFormField<String>(
              initialValue: _tipoComida,
              decoration: InputDecoration(
                labelText: 'Momento del Día / Categoría',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'Desayuno', child: Text('🍳 Desayuno')),
                DropdownMenuItem(value: 'Comida', child: Text('🍲 Comida')),
                DropdownMenuItem(value: 'Cena', child: Text('🌙 Cena')),
                DropdownMenuItem(value: 'Snack', child: Text('🍎 Snack')),
                DropdownMenuItem(value: 'Postre', child: Text('🍰 Postre')),
                DropdownMenuItem(
                  value: 'Snack Canino',
                  child: Text('🐾 Snack / Premio Canino'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _tipoComida = val);
              },
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
                hintText: '📝 INGREDIENTES:\n- 500g Pechuga de pollo\n- 4 Tomates verdes\n- 1 Taza de crema\n\n🍳 INSTRUCCIONES:\n1. Hervir el pollo...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Sección de Información Nutricional (Calorías y Macros)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_fire_department, color: Colors.orange.shade800, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            'Información Nutricional',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: _calculandoNutricion ? null : _calcularNutricionConIA,
                        icon: _calculandoNutricion
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome, size: 16, color: Colors.teal),
                        label: Text(
                          _calculandoNutricion ? 'Calculando...' : 'Calcular con IA ✨',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _caloriasController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Calorías (kcal)',
                            hintText: 'Ej. 420',
                            prefixIcon: const Icon(Icons.fitness_center),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _macrosController,
                          decoration: InputDecoration(
                            labelText: 'Macros',
                            hintText: 'P: 25g | C: 35g | G: 12g',
                            prefixIcon: const Icon(Icons.pie_chart_outline),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Opciones de Privacidad y Audiencia
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        esAdmin ? Icons.admin_panel_settings : Icons.lock_outline,
                        color: esAdmin ? Colors.orange.shade800 : Colors.teal.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        esAdmin ? 'Opciones de Administrador' : 'Privacidad de la Receta',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (esAdmin)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('🌟 Receta Oficial de Jitomate y Cebolla'),
                      subtitle: const Text('Aparecerá en el catálogo insignia de todos los usuarios'),
                      activeTrackColor: Colors.orange.shade800,
                      value: _esOficial,
                      onChanged: (val) => setState(() => _esOficial = val),
                    )
                  else
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('🌎 Compartir con la comunidad'),
                      subtitle: Text(
                        _compartirComunidad
                            ? 'Visible en la pestaña "Comunidad" para todos'
                            : 'Solo tú podrás verla en "Mis Recetas"',
                      ),
                      activeTrackColor: Colors.teal.shade700,
                      value: _compartirComunidad,
                      onChanged: (val) => setState(() => _compartirComunidad = val),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 25),

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
