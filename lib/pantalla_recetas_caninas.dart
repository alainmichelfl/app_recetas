import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pantalla_detalle_receta.dart';
import 'menu_lateral.dart';

class PantallaRecetasCaninas extends StatefulWidget {
  const PantallaRecetasCaninas({super.key});

  @override
  State<PantallaRecetasCaninas> createState() => _PantallaRecetasCaninasState();
}

class _PantallaRecetasCaninasState extends State<PantallaRecetasCaninas> {
  List<Map<String, dynamic>> recetasCaninas = [];
  List<Map<String, dynamic>> recetasFiltradas = [];
  bool cargando = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    cargarRecetasCaninas();
    _searchController.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> cargarRecetasCaninas() async {
    setState(() => cargando = true);
    try {
      final respuesta = await Supabase.instance.client
          .from('recetas')
          .select()
          .eq('tipo_comida', 'Premio Perruno')
          .order('id_receta', ascending: false);

      if (!mounted) return;
      setState(() {
        recetasCaninas = List<Map<String, dynamic>>.from(respuesta);
        recetasFiltradas = recetasCaninas;
        cargando = false;
      });
    } catch (e) {
      debugPrint('Error al cargar recetas caninas: $e');
      if (mounted) setState(() => cargando = false);
    }
  }

  void _filtrar() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      recetasFiltradas = recetasCaninas.where((r) {
        final titulo = r['titulo']?.toString().toLowerCase() ?? '';
        return titulo.contains(query);
      }).toList();
    });
  }

  Future<void> _eliminarReceta(int idReceta) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client
          .from('recetas')
          .delete()
          .eq('id_receta', idReceta);

      if (!mounted) return;
      cargarRecetasCaninas();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Receta canina eliminada 🐾'),
          backgroundColor: Colors.brown,
        ),
      );
    } catch (e) {
      debugPrint('Error al eliminar: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      drawer: const MenuLateral(rutaActual: 'caninas'),
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menú principal',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.pets, size: 24),
            SizedBox(width: 8),
            Text(
              'Recetario Canino 🐾',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar premio o receta canina...',
                prefixIcon: const Icon(Icons.search, color: Colors.brown),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filtrar();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.brown[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cargando
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.brown),
                  )
                : recetasFiltradas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pets, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 15),
                        const Text(
                          'No hay recetas caninas guardadas aún',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Usa el Chef Perruno para crear una 🐶',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: recetasFiltradas.length,
                    itemBuilder: (context, index) {
                      final receta = recetasFiltradas[index];
                      final id = receta['id_receta'];
                      final titulo = receta['titulo'] ?? 'Premio Perruno';
                      final descripcion = receta['descripcion'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: Colors.brown[100],
                            radius: 26,
                            child: const Icon(
                              Icons.pets,
                              color: Colors.brown,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            titulo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.brown[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Apto para perros 🐶',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.brown,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.redAccent,
                            ),
                            tooltip: 'Eliminar receta canina',
                            onPressed: () => _eliminarReceta(id),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PantallaDetalleReceta(
                                  idReceta: id,
                                  titulo: titulo,
                                  descripcion: descripcion,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
